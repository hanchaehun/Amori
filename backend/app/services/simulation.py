import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.database import LLMCallLog


async def log_llm_call(
    db: AsyncSession,
    endpoint: str,
    provider: str,
    request_body: dict,
    response_status: int,
    response_time_ms: int,
    user_id: str | None = None,
) -> LLMCallLog:
    """Record an LLM API call in the llm_call_logs table for auditing."""
    log = LLMCallLog(
        endpoint=endpoint,
        provider=provider,
        request_body=request_body,
        response_status=response_status,
        response_time_ms=response_time_ms,
        user_id=user_id,
        request_id=str(uuid.uuid4()),
    )
    db.add(log)
    await db.commit()
    return log
