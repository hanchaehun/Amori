"""시차 송출(라이브 관전) — 한 번에 생성된 대화를 천천히 흘린다.

제품 설계 (2026-06-13, 한채훈): 자동 소개팅(auto_sim)은 시뮬레이션을 수십 초
만에 전부 생성하지만, 그 결과를 한꺼번에 보여주면 "에이전트가 실시간으로 대화하는"
관전 경험이 안 난다. 그래서 각 턴에 ``visible_at``(공개 예정 시각)을 박아 두고,
조회 시점에 그 시각이 지난 턴만 노출한다. 사용자에겐 한쪽이 말하면 상대가 한참 뒤에
답하는 컨베이어벨트처럼 보이지만, 실제 LLM 콜은 이미 끝나 있다.

핵심 성질 — "DB 상태는 진실, 공개만 지연":
- 약속 성립·리포트·게이트 분류는 생성 시점에 이미 DB에 확정된다.
- 송출이 끝나기 전(reveal_complete=False)까지는 조회 레이어가 그 결과를 가린다 —
  대화가 끝나기도 전에 "약속 조율 완료" 배지나 케미 점수가 새지 않도록.

이 모듈은 순수 함수만 둔다(now·rng 주입 가능) — 시간을 기다리지 않고 단위 검증한다.
``visible_at`` 은 항상 timezone-aware UTC ISO 문자열로 저장한다(JSONB 직렬화 가능).
``visible_at`` 이 없는 턴(구버전 행·SSE 즉시 공개 경로)은 "이미 공개됨"으로 본다.
"""

import random
from datetime import datetime, timedelta, timezone


def _parse(visible_at: str) -> datetime:
    """저장된 ISO 문자열을 aware UTC datetime으로. naive면 UTC로 간주(방어)."""
    dt = datetime.fromisoformat(visible_at)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def _is_visible(turn: dict, now: datetime) -> bool:
    va = turn.get("visible_at")
    return not va or _parse(va) <= now


def plan_reveal_schedule(
    turns: list[dict],
    start: datetime,
    settings,
    *,
    rng: random.Random | None = None,
) -> list[dict]:
    """각 턴에 ``visible_at``(UTC ISO)을 입힌 새 리스트를 반환한다.

    간격 = 최소간격 + 이번 발화 글자 수 × 글자당초 + 지터(0~최소간격),
    [min, max]로 클램프. cursor가 단조 증가하므로 공개 순서는 턴 순서와 같다.
    첫 턴은 start + 도입 딜레이 시점에 공개한다(에이전트가 막 입을 떼는 느낌).

    원본 턴 dict의 다른 필드(strategy·partner_read·appointment_slot 등)는
    그대로 보존한다 — 약속 판정은 이 turns로 계속 이뤄지기 때문이다.
    """
    r = rng or random
    planned: list[dict] = []
    cursor = start + timedelta(seconds=settings.reveal_first_delay_seconds)
    for i, turn in enumerate(turns):
        if i > 0:
            text = turn.get("text") or ""
            gap = (
                settings.reveal_min_gap_seconds
                + len(text) * settings.reveal_char_seconds
                + r.uniform(0, settings.reveal_min_gap_seconds)
            )
            gap = min(
                max(gap, settings.reveal_min_gap_seconds),
                settings.reveal_max_gap_seconds,
            )
            cursor = cursor + timedelta(seconds=gap)
        planned.append({**turn, "visible_at": cursor.isoformat()})
    return planned


def revealed_turns(turns: list[dict] | None, now: datetime) -> list[dict]:
    """지금까지 공개된 턴만(visible_at<=now 또는 visible_at 없음)."""
    return [t for t in (turns or []) if _is_visible(t, now)]


def reveal_complete(turns: list[dict] | None, now: datetime) -> bool:
    """모든 턴이 공개됐는가. 턴이 없으면(빈 리스트) 송출 끝난 것으로 본다."""
    return all(_is_visible(t, now) for t in (turns or []))
