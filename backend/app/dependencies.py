from app.config import settings
from app.llm.factory import create_llm_provider
from app.llm.base import LLMProvider
from app.db.session import async_session_factory
from sqlalchemy.ext.asyncio import AsyncSession

_llm_provider: LLMProvider | None = None


def get_llm_provider() -> LLMProvider:
    global _llm_provider
    if _llm_provider is None:
        _llm_provider = create_llm_provider(settings.llm_provider)
    return _llm_provider


async def get_db() -> AsyncSession:
    async with async_session_factory() as session:
        yield session
