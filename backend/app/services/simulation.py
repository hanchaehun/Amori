"""2-에이전트 턴 루프 시뮬레이션 엔진 (리팩토링 결정 5 + 눈치).

원샷 생성(한 호출로 양쪽 대사 전부)은 두 페르소나의 말투가 섞이고(style bleed)
대화가 평탄한 핑퐁이 되는 구조적 품질 문제가 있다. 이 엔진은:

- 에이전트 A·B가 각각 자기 페르소나만 담긴 별도 시스템 프롬프트·별도 컨텍스트를 유지하고
- 턴마다 한쪽씩 호출해 발화를 생성하며
- 각 발화에 "눈치"(partner_read·strategy)를 함께 받아, 그 전략에 따라 대화를
  자연스럽게 마무리하거나 조기 종료한다.

별도 분석 콜은 없앴다 — 발화 콜이 돌려주는 strategy/partner_read가 곧 분석 데이터다
(사용자에겐 text만 보이고, partner_read·strategy는 DB에만 저장된다).

LLM 호출 자체는 provider가 콜백(``speak``)으로 주입한다.
"""

from datetime import date
from typing import AsyncIterator, Awaitable, Callable

from app.llm.prompts import build_agent_system_prompt

# speak(system_prompt, history) -> {"text", "partner_read", "strategy", "appointment_slot"}
# history: [{"role": "user"|"model", "text": str}] — 해당 에이전트 시점의 대화
SpeakFn = Callable[[str, list[dict]], Awaitable[dict]]


def slot_label(slot: dict) -> str:
    """{"date": "YYYY-MM-DD", "time": "점심"|"저녁"} → '6월 14일(토) 저녁'."""
    d = date.fromisoformat(slot["date"])
    weekday = "월화수목금토일"[d.weekday()]
    return f"{d.month}월 {d.day}일({weekday}) {slot['time']}"


def _slot_key(slot: dict) -> tuple[str, str]:
    return (slot["date"], slot["time"])

OPENING_INSTRUCTION = "(소개팅 첫 메시지를 보내며 대화를 시작하세요)"

# 약속이 잡혔다는 신호 — 한쪽이 제안하고 다른 쪽이 수락하면 성립
PROPOSE_STRATEGY = "약속 제안"
ACCEPT_STRATEGY = "약속 수락"
WRAPUP_STRATEGY = "마무리"

# 에이전트는 자기 과거 partner_read를 기억하지 못한다(컨텍스트엔 대화 텍스트뿐).
# 연속 긍정 횟수는 엔진이 세고, 임계치에 닿은 턴에만 명시적 신호를 주입한다.
ESCALATE_AFTER_POSITIVE_READS = 3

ESCALATE_NUDGE = (
    "(당신은 지금까지 상대 반응을 연속으로 긍정적이라고 읽었습니다. "
    "알아가기를 반복하지 말고 이번 발화에서 구체적인 만남을 제안하세요 — strategy는 '약속 제안')"
)
ESCALATE_WITH_SLOTS_SUFFIX = (
    " [가능한 일정] 중 하나를 골라 자연스럽게 시간을 제안하고 appointment_slot에 번호를 넣으세요."
)
RESPOND_TO_PROPOSAL_NUDGE = (
    "(상대가 방금 만남을 제안했습니다. 받아들일 마음이면 구체적으로 수락하세요 — strategy는 '약속 수락'. "
    "아직 이르다고 느끼면 부드럽게 다른 화제로 이어가세요)"
)


def respond_nudge_slot_ok(label: str, slot_id: str) -> str:
    """상대 제안 시간이 내 사용자도 가능 — 수락 시 슬롯 번호까지 안내."""
    return (
        f"(상대가 제안한 {label}은(는) 당신의 사용자도 가능한 시간입니다. "
        f"받아들일 마음이면 구체적으로 수락하고 appointment_slot에 {slot_id}을(를) 넣으세요 — "
        "strategy는 '약속 수락'. 아직 이르다고 느끼면 부드럽게 다른 화제로 이어가세요)"
    )


def respond_nudge_slot_unavailable() -> str:
    """상대 제안 시간이 내 사용자 일정에 없음 — 거절 후 역제안."""
    return (
        "(상대가 제안한 시간은 당신의 사용자가 안 되는 시간입니다. 미안함을 표하고 "
        "[가능한 일정] 중에서 역제안하세요 — strategy는 '약속 제안', appointment_slot에 번호)"
    )


def _with_nudge(history: list[dict], nudge: str) -> list[dict]:
    """이번 호출에만 쓰는 사본에 신호를 덧붙인다 — 영구 컨텍스트는 오염시키지 않는다."""
    last = history[-1]
    return [*history[:-1], {"role": last["role"], "text": f"{last['text']}\n{nudge}"}]


async def run_two_agent_simulation(
    speak: SpeakFn,
    my_persona: dict,
    their_persona: dict,
    max_turns: int = 20,
    my_slots: list[dict] | None = None,
    their_slots: list[dict] | None = None,
) -> AsyncIterator[dict]:
    """시뮬레이션 턴을 순차 생성한다.

    각 턴 dict: turn_index, speaker("me"|"them"), text, partner_read, strategy,
    appointment_slot, ai_generated. text만 사용자에게 노출하고 나머지는 내부용(DB 저장).

    일정 조율: 양쪽 다 가능 일정(available_slots)이 있으면 각 에이전트는 자기
    사용자의 일정만 알고(정보 비대칭) 실제 대화처럼 시간을 조율한다 — 엔진이
    상대 제안 시간의 가용 여부를 그 턴 넛지로 알려주고, 수락된 슬롯이 양쪽
    일정에 실제로 있는지 검증한다(LLM 환각 방지). 검증된 합의 슬롯만
    "appointment_slot"으로 턴에 실린다. 한쪽이라도 일정이 없으면 구체 날짜 없이
    의향만 합의하는 기존 동작으로 폴백.

    종료 조건:
    - 한 에이전트가 "약속 수락"(약속 성립) → 상대가 마무리 인사 한 번 더 하고 종료
    - 한 에이전트가 "마무리" → 그 인사를 끝으로 종료
    - 그 외에는 max_turns까지 진행
    """
    slots = {"a": my_slots or [], "b": their_slots or []}
    negotiating = bool(slots["a"]) and bool(slots["b"])
    common_keys = {_slot_key(s) for s in slots["a"]} & {_slot_key(s) for s in slots["b"]}

    def labels(key: str) -> list[str] | None:
        if not negotiating:
            return None
        return [f"S{i + 1}) {slot_label(s)}" for i, s in enumerate(slots[key])]

    def resolve(key: str, slot_id: str | None) -> dict | None:
        """에이전트가 답한 슬롯 번호(S1)를 자기 일정의 슬롯으로 푼다."""
        raw = (slot_id or "").strip().upper().lstrip("S")
        if not raw.isdigit():
            return None
        idx = int(raw) - 1
        return slots[key][idx] if 0 <= idx < len(slots[key]) else None

    def own_slot_id(key: str, slot: dict) -> str | None:
        for i, s in enumerate(slots[key]):
            if _slot_key(s) == _slot_key(slot):
                return f"S{i + 1}"
        return None

    system_a = build_agent_system_prompt(my_persona, slot_labels=labels("a"))
    system_b = build_agent_system_prompt(their_persona, slot_labels=labels("b"))

    history_a: list[dict] = [{"role": "user", "text": OPENING_INSTRUCTION}]
    history_b: list[dict] = []

    turn_index = 0
    end_after_next = False  # 약속 성립 후 상대의 마무리 인사 한 번을 허용하는 플래그
    positive_reads = {"a": 0, "b": 0}  # 각 에이전트가 상대를 연속 긍정적으로 읽은 횟수
    proposed = {"a": False, "b": False}
    last_strategy = {"a": "", "b": ""}
    pending_slot: dict | None = None  # 마지막 '약속 제안'에 실린 슬롯 (제안자 기준 해석)

    for step in range(max_turns):
        is_me = step % 2 == 0
        me, them = ("a", "b") if is_me else ("b", "a")
        system_prompt = system_a if is_me else system_b
        history = history_a if is_me else history_b

        call_history = history
        if last_strategy[them] == PROPOSE_STRATEGY:
            if negotiating and pending_slot:
                my_id = own_slot_id(me, pending_slot)
                nudge = (
                    respond_nudge_slot_ok(slot_label(pending_slot), my_id)
                    if my_id
                    else respond_nudge_slot_unavailable()
                )
            else:
                nudge = RESPOND_TO_PROPOSAL_NUDGE
            call_history = _with_nudge(history, nudge)
        elif positive_reads[me] >= ESCALATE_AFTER_POSITIVE_READS and not proposed[me]:
            nudge = ESCALATE_NUDGE + (ESCALATE_WITH_SLOTS_SUFFIX if negotiating else "")
            call_history = _with_nudge(history, nudge)

        out = await speak(system_prompt, call_history)
        text = out["text"]
        strategy = out.get("strategy", "알아가기")
        partner_read = out.get("partner_read", "중립")

        positive_reads[me] = positive_reads[me] + 1 if partner_read == "긍정적" else 0
        if strategy == PROPOSE_STRATEGY:
            proposed[me] = True
            pending_slot = resolve(me, out.get("appointment_slot")) if negotiating else None
        last_strategy[me] = strategy

        # 수락 턴: 합의 슬롯을 양쪽 일정과 대조해 검증한다.
        # 수락자가 답한 번호(자기 일정 기준)가 우선, 없으면 상대의 제안 슬롯.
        agreed_slot: dict | None = None
        if strategy == ACCEPT_STRATEGY and negotiating:
            candidate = resolve(me, out.get("appointment_slot")) or pending_slot
            if candidate and _slot_key(candidate) in common_keys:
                agreed_slot = candidate

        # 자기 컨텍스트엔 model 발화로, 상대 컨텍스트엔 user 발화로 쌓는다
        if is_me:
            history_a.append({"role": "model", "text": text})
            history_b.append({"role": "user", "text": text})
        else:
            history_b.append({"role": "model", "text": text})
            history_a.append({"role": "user", "text": text})

        yield {
            "turn_index": turn_index,
            "speaker": "me" if is_me else "them",
            "text": text,
            "partner_read": partner_read,
            "strategy": strategy,
            "appointment_slot": agreed_slot,
            "ai_generated": True,
        }
        turn_index += 1

        # 눈치 기반 종료 — 약속이 잡혔거나 한쪽이 마무리하면 자연스럽게 끝낸다
        if end_after_next:
            break
        if strategy == WRAPUP_STRATEGY:
            break
        if strategy == ACCEPT_STRATEGY:
            end_after_next = True  # 상대가 "그래요 그때 봬요" 한 번 더 하고 종료
