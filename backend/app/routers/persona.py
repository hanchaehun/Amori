import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.dependencies import get_db, get_llm_provider
from app.auth.firebase import get_current_user
from app.llm.base import LLMProvider
from app.schemas.persona import PersonaBuildRequest, PersonaResponse
from app.models.database import Persona

router = APIRouter()


@router.post("/build", response_model=PersonaResponse)
async def build_persona(
    body: PersonaBuildRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm: LLMProvider = Depends(get_llm_provider),
):
    request_id = str(uuid.uuid4())
    result = await llm.build_persona(user["uid"], body.answers)

    # Upsert persona
    existing = await db.execute(
        select(Persona).where(Persona.user_id == user["uid"])
    )
    persona = existing.scalar_one_or_none()
    if persona:
        persona.traits = result["traits"]
        persona.communication_style = result["communication_style"]
        persona.humor_style = result["humor_style"]
        persona.value_keywords = result["value_keywords"]
        persona.embedding = result.get("embedding")
    else:
        persona = Persona(
            user_id=user["uid"],
            traits=result["traits"],
            communication_style=result["communication_style"],
            humor_style=result["humor_style"],
            value_keywords=result["value_keywords"],
            embedding=result.get("embedding"),
        )
        db.add(persona)
    await db.commit()

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
        embedding=list(persona.embedding) if persona.embedding is not None else None,
    )
