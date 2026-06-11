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

from typing import AsyncIterator, Awaitable, Callable

from app.llm.prompts import build_agent_system_prompt

# speak(system_prompt, history) -> {"text", "partner_read", "strategy"}
# history: [{"role": "user"|"model", "text": str}] — 해당 에이전트 시점의 대화
SpeakFn = Callable[[str, list[dict]], Awaitable[dict]]

OPENING_INSTRUCTION = "(소개팅 첫 메시지를 보내며 대화를 시작하세요)"

# 약속이 잡혔다는 신호 — 한쪽이 제안하고 다른 쪽이 수락하면 성립
ACCEPT_STRATEGY = "약속 수락"
WRAPUP_STRATEGY = "마무리"


async def run_two_agent_simulation(
    speak: SpeakFn,
    my_persona: dict,
    their_persona: dict,
    max_turns: int = 20,
) -> AsyncIterator[dict]:
    """시뮬레이션 턴을 순차 생성한다.

    각 턴 dict: turn_index, speaker("me"|"them"), text, partner_read, strategy, ai_generated.
    text만 사용자에게 노출하고, partner_read·strategy는 내부 분석용(DB 저장)이다.

    종료 조건:
    - 한 에이전트가 "약속 수락"(약속 성립) → 상대가 마무리 인사 한 번 더 하고 종료
    - 한 에이전트가 "마무리" → 그 인사를 끝으로 종료
    - 그 외에는 max_turns까지 진행
    """
    system_a = build_agent_system_prompt(my_persona)
    system_b = build_agent_system_prompt(their_persona)

    history_a: list[dict] = [{"role": "user", "text": OPENING_INSTRUCTION}]
    history_b: list[dict] = []

    turn_index = 0
    end_after_next = False  # 약속 성립 후 상대의 마무리 인사 한 번을 허용하는 플래그

    for step in range(max_turns):
        is_me = step % 2 == 0
        system_prompt = system_a if is_me else system_b
        history = history_a if is_me else history_b

        out = await speak(system_prompt, history)
        text = out["text"]
        strategy = out.get("strategy", "알아가기")
        partner_read = out.get("partner_read", "중립")

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
