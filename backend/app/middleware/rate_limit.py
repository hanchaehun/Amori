from datetime import date, datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.database import MeetRequest, SimulationJob


async def check_simulation_quota(user_id: str, db: AsyncSession) -> bool:
    """Returns True if user is within daily simulation quota."""
    today_start = datetime.combine(date.today(), datetime.min.time()).replace(
        tzinfo=timezone.utc
    )
    result = await db.execute(
        select(func.count(SimulationJob.id))
        .where(SimulationJob.requested_by == user_id)
        .where(SimulationJob.created_at >= today_start)
    )
    count = result.scalar_one()
    return count < settings.daily_simulation_limit


async def check_meet_request_quota(user_id: str, db: AsyncSession) -> bool:
    """Returns True if user is within daily meet request quota."""
    today_start = datetime.combine(date.today(), datetime.min.time()).replace(
        tzinfo=timezone.utc
    )
    result = await db.execute(
        select(func.count(MeetRequest.id))
        .where(MeetRequest.requester_id == user_id)
        .where(MeetRequest.created_at >= today_start)
    )
    count = result.scalar_one()
    return count < settings.daily_meet_request_limit
