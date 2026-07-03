"""원샷 시뮬레이션 출력 후처리 — 슬롯 교집합 계산 + 턴 확정.

provider가 한 번의 호출로 받은 대화(ConversationOutput.turns)를 다운스트림 계약
(turn dict 리스트)으로 바꾼다. 약속 슬롯은 양쪽 일정 교집합에 실재할 때만 인정한다
(LLM 환각 방어) — 어떤 채팅 백엔드든 동일한 안전장치.

gemini.py는 스크립트 호환을 위해 같은 로직을 자체 보유한다. modoo는 이 모듈을 쓴다.
"""

from typing import Iterator

from app.services.simulation import slot_label


def common_slots(
    my_slots: list[dict] | None, their_slots: list[dict] | None
) -> tuple[list[dict], list[str] | None]:
    """양쪽 가능 일정의 교집합과, 프롬프트용 라벨('S1) ...')을 반환한다."""
    my_slots = my_slots or []
    their_slots = their_slots or []
    their_keys = {(s["date"], s["time"]) for s in their_slots}
    common = [s for s in my_slots if (s["date"], s["time"]) in their_keys]
    labels = (
        [f"S{i + 1}) {slot_label(s)}" for i, s in enumerate(common)] if common else None
    )
    return common, labels


def iter_finalized_turns(
    turns, common: list[dict], max_turns: int
) -> Iterator[dict]:
    """ConvTurn 시퀀스를 turn dict로 확정한다. 합의 슬롯은 교집합에 실재할 때만."""

    def resolve(slot_id: str) -> dict | None:
        raw = (slot_id or "").strip().upper().lstrip("S")
        if not raw.isdigit():
            return None
        idx = int(raw) - 1
        return common[idx] if 0 <= idx < len(common) else None

    for i, t in enumerate(turns):
        if i >= max_turns:
            break
        # 합의 슬롯은 '약속 수락' 턴에서만, 그리고 교집합에 실재할 때만 인정한다.
        agreed = resolve(t.appointment_slot) if (common and t.strategy == "약속 수락") else None
        yield {
            "turn_index": i,
            "speaker": t.speaker,
            "text": t.text,
            "partner_read": t.partner_read,
            "strategy": t.strategy,
            "appointment_slot": agreed,
            "ai_generated": True,
        }
