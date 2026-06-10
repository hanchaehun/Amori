import time
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.config import settings
from app.dependencies import get_db, get_llm_provider
from app.llm.base import LLMProvider
from app.models.database import Persona
from app.routers.users import ensure_user
from app.schemas.persona import PersonaBuildRequest, PersonaResponse
from app.services.llm_log import log_llm_call

router = APIRouter()


@router.post("/build", response_model=PersonaResponse)
async def build_persona(
    body: PersonaBuildRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm: LLMProvider = Depends(get_llm_provider),
):
    started = time.monotonic()
    result = await llm.build_persona(user["uid"], body.answers)
    elapsed_ms = int((time.monotonic() - started) * 1000)

    # FK 전제: User 행 보장 후 페르소나 upsert
    await ensure_user(db, user["uid"], user.get("email"))

    existing = await db.execute(
        select(Persona).where(Persona.user_id == user["uid"])
    )
    persona = existing.scalar_one_or_none()
    if persona:
        persona.traits = result["traits"]
        persona.communication_style = result["communication_style"]
        persona.humor_style = result["humor_style"]
        persona.value_keywords = result["value_keywords"]
        persona.speech_style = result["speech_style"]
        persona.sample_messages = result["sample_messages"]
        persona.embedding = result.get("embedding")
    else:
        persona = Persona(
            user_id=user["uid"],
            traits=result["traits"],
            communication_style=result["communication_style"],
            humor_style=result["humor_style"],
            value_keywords=result["value_keywords"],
            speech_style=result["speech_style"],
            sample_messages=result["sample_messages"],
            embedding=result.get("embedding"),
        )
        db.add(persona)
    await db.commit()

    await log_llm_call(
        db,
        endpoint="persona/build",
        provider=settings.llm_provider,
        request_body={"answers_count": len(body.answers)},
        response_status=200,
        response_time_ms=elapsed_ms,
        user_id=user["uid"],
    )

    result["user_id"] = user["uid"]
    return PersonaResponse(**result)


@router.get("/me", response_model=PersonaResponse)
async def get_my_persona(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Persona).where(Persona.user_id == user["uid"])
    )
    persona = result.scalar_one_or_none()
    if not persona:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "페르소나가 아직 생성되지 않았습니다.",
                "request_id": str(uuid.uuid4()),
            },
        )
    return PersonaResponse(
        user_id=persona.user_id,
        traits=persona.traits,
        communication_style=persona.communication_style,
        humor_style=persona.humor_style,
        value_keywords=persona.value_keywords,
        speech_style=persona.speech_style,
        sample_messages=persona.sample_messages,
        embedding=list(persona.embedding) if persona.embedding is not None else None,
    )
