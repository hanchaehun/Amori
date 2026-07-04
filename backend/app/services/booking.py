"""약속 일정 유틸 + 예약 조회 — 수락된 약속이 점유한 시간 계산.

available_slots(사용자 입력)는 변형하지 않는다. "예약됨"은 파생 상태 —
내가 수락한(accepted_by에 포함) 매치의 appointment_slot이 곧 예약이다.
시뮬레이션은 (입력 일정 − 예약 일정)만 에이전트에게 주고, 수락 API는
이미 예약된 시간과 겹치면 거부한다 → 더블부킹 원천 차단.
"""

from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.database import Match


def slot_label(slot: dict) -> str:
    """{"date": "YYYY-MM-DD", "time": "점심"|"저녁"} → '6월 14일(토) 저녁'."""
    d = date.fromisoformat(slot["date"])
    weekday = "월화수목금토일"[d.weekday()]
    return f"{d.month}월 {d.day}일({weekday}) {slot['time']}"


async def get_booked_matches(db: AsyncSession, uid: str) -> list[Match]:
    """내가 수락했고 합의 일정이 있는 매치들."""
    result = await db.execute(
        select(Match).where(
            Match.accepted_by.any(uid),
            Match.appointment_slot.is_not(None),
        )
    )
    return list(result.scalars().all())


async def get_booked_slot_keys(db: AsyncSession, uid: str) -> set[tuple[str, str]]:
    """예약된 (date, time) 키 집합 — 가용 일정 차감·충돌 검사용."""
    return {
        (m.appointment_slot["date"], m.appointment_slot["time"])
        for m in await get_booked_matches(db, uid)
    }


def subtract_booked(
    slots: list[dict], booked_keys: set[tuple[str, str]]
) -> list[dict]:
    """입력 일정에서 예약된 칸을 뺀 실제 가용 일정."""
    return [s for s in slots if (s["date"], s["time"]) not in booked_keys]
