from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.database import MeetRequest, SimulationJob


def _local_today_start() -> datetime:
    """'오늘'의 시작 = 서버 로컬(KST) 자정, tz-aware.

    구버전은 UTC 자정 기준이라 KST 00~09시 사이엔 비교 시점이 미래가 되어
    일일 한도가 사실상 꺼져 있었다.
    """
    return datetime.now().astimezone().replace(
        hour=0, minute=0, second=0, microsecond=0
    )


async def check_simulation_quota(user_id: str, db: AsyncSession) -> bool:
    """Returns True if user is within daily simulation quota."""
    result = await db.execute(
        select(func.count(SimulationJob.id))
        .where(SimulationJob.requested_by == user_id)
        .where(SimulationJob.created_at >= _local_today_start())
    )
    count = result.scalar_one()
    return count < settings.daily_simulation_limit


async def check_meet_request_quota(user_id: str, db: AsyncSession) -> bool:
    """Returns True if user is within daily meet request quota."""
    today_start = _local_today_start()
    result = await db.execute(
        select(func.count(MeetRequest.id))
        .where(MeetRequest.requester_id == user_id)
        .where(MeetRequest.created_at >= today_start)
    )
    count = result.scalar_one()
    return count < settings.daily_meet_request_limit
