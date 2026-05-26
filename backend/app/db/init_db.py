"""Database initialisation helpers."""

from sqlalchemy import text

from app.db.session import engine
from app.models.database import Base


async def init_db() -> None:
    """Create all tables defined in Base.metadata.

    The ``before_create`` event listener on ``Base.metadata`` ensures the
    pgvector extension is installed before any table DDL runs.
    """
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def check_db_health() -> bool:
    """Return ``True`` if the database is reachable, ``False`` otherwise."""
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
