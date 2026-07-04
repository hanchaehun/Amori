"""원샷 시뮬레이션 출력 후처리 — 턴 확정.

provider가 한 번의 호출로 받은 대화(ConversationOutput.turns)를 다운스트림 계약
(turn dict 리스트)으로 바꾼다. 약속 슬롯 검증은 시뮬 약속 폐지(2026-07-04 결정 —
만남은 수락 후 직접 채팅에서)로 제거됐다(git 이력 참조).
"""

from typing import Iterator


def iter_finalized_turns(turns, max_turns: int) -> Iterator[dict]:
    """ConvTurn 시퀀스를 turn dict로 확정한다 (턴 수 상한 + ai_generated 라벨)."""
    for i, t in enumerate(turns):
        if i >= max_turns:
            break
        yield {
            "turn_index": i,
            "speaker": t.speaker,
            "text": t.text,
            "partner_read": t.partner_read,
            "strategy": t.strategy,
            "ai_generated": True,
        }
