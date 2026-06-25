import time
import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.config import settings
from app.dependencies import get_db, get_llm_provider
from app.llm.base import LLMProvider
from app.models.database import Persona
from app.routers.users import ensure_user
from app.schemas.persona import (
    PersonaBuildRequest,
    PersonaDailyStatusResponse,
    PersonaResponse,
    PersonaUpdateRequest,
)
from app.services.llm_log import log_llm_call

router = APIRouter()

DAILY_SCENARIO_CODES = [
    "9-1",
    "9-2",
    "9-3",
    "2-1",
    "7-3",
    "5-2",
    "4-2",
    "8-3",
    "6-2",
    "6-3",
    "7-1",
    "4-1",
    "5-1",
    "2-2",
    "8-2",
    "3-2",
    "3-3",
    "6-1",
    "5-3",
    "4-3",
    "1-2",
    "1-3",
    "2-3",
    "7-2",
]


def _answer_codes(answers: list[dict]) -> list[str]:
    return [str(a.get("code", "")).strip() for a in answers if a.get("code")]


def _merge_codes(existing: list | None, new_codes: list[str]) -> list[str]:
    merged = [str(code) for code in (existing or []) if code]
    for code in new_codes:
        if code and code not in merged:
            merged.append(code)
    return merged


def _confidence(answer_count: int | None, answered_codes: list[str]) -> str:
    count = answer_count or len(answered_codes)
    if count >= 18:
        return "high"
    if count >= 8:
        return "medium"
    return "low"


def _persona_dict(persona: Persona) -> dict:
    return {
        "user_id": persona.user_id,
        "traits": persona.traits,
        "communication_style": persona.communication_style,
        "humor_style": persona.humor_style,
        "value_keywords": persona.value_keywords,
        "speech_style": persona.speech_style,
        "sample_messages": persona.sample_messages,
        "embedding": list(persona.embedding) if persona.embedding is not None else None,
        "ai_generated": True,
    }


def _persona_response(persona: Persona) -> PersonaResponse:
    return PersonaResponse(
        **_persona_dict(persona),
        answer_count=persona.answer_count,
        answered_codes=persona.answered_codes or [],
        persona_revision=persona.persona_revision or 1,
        persona_confidence=persona.persona_confidence or "low",
        last_answered_on=(
            persona.last_answered_on.isoformat() if persona.last_answered_on else None
        ),
    )


def _daily_status_response(persona: Persona) -> PersonaDailyStatusResponse:
    completed_today = persona.last_answered_on == date.today()
    answered = persona.answered_codes or []
    scenario_code = None
    if not completed_today:
        scenario_code = next(
            (code for code in DAILY_SCENARIO_CODES if code not in answered),
            None,
        )
    return PersonaDailyStatusResponse(
        completed_today=completed_today,
        scenario_code=scenario_code,
        answer_count=persona.answer_count,
        answered_codes=answered,
        persona_revision=persona.persona_revision or 1,
    )


def _ensure_dev_user(user: dict) -> None:
    if settings.debug and user.get("is_dev"):
        return
    raise HTTPException(
        status_code=403,
        detail={
            "error_code": "DEV_ONLY",
            "message": "개발 모드에서만 사용할 수 있는 기능입니다.",
            "request_id": str(uuid.uuid4()),
        },
    )


def _apply_result(persona: Persona, result: dict) -> None:
    persona.traits = result["traits"]
    persona.communication_style = result["communication_style"]
    persona.humor_style = result["humor_style"]
    persona.value_keywords = result["value_keywords"]
    persona.speech_style = result["speech_style"]
    persona.sample_messages = result["sample_messages"]
    persona.embedding = result.get("embedding")


async def _get_persona(db: AsyncSession, user_id: str) -> Persona | None:
    result = await db.execute(select(Persona).where(Persona.user_id == user_id))
    return result.scalar_one_or_none()


def _not_found() -> HTTPException:
    return HTTPException(
        status_code=404,
        detail={
            "error_code": "NOT_FOUND",
            "message": "페르소나가 아직 생성되지 않았습니다.",
            "request_id": str(uuid.uuid4()),
        },
    )


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

    persona = await _get_persona(db, user["uid"])
    new_codes = _answer_codes(body.answers)
    if persona:
        _apply_result(persona, result)
        persona.persona_revision = (persona.persona_revision or 1) + 1
    else:
        persona = Persona(
            user_id=user["uid"],
            persona_revision=1,
            answer_count=0,
            answered_codes=[],
            persona_confidence="low",
        )
        _apply_result(persona, result)
        db.add(persona)
    persona.answered_codes = _merge_codes(persona.answered_codes, new_codes)
    persona.answer_count = len(persona.answered_codes)
    persona.persona_confidence = _confidence(persona.answer_count, persona.answered_codes)
    if new_codes:
        persona.last_answered_on = date.today()
    await db.commit()
    await db.refresh(persona)

    await log_llm_call(
        db,
        endpoint="persona/build",
        provider=settings.llm_provider,
        request_body={"answers_count": len(body.answers)},
        response_status=200,
        response_time_ms=elapsed_ms,
        user_id=user["uid"],
    )

    return _persona_response(persona)


@router.get("/daily", response_model=PersonaDailyStatusResponse)
async def get_daily_persona_question(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    persona = await _get_persona(db, user["uid"])
    if not persona:
        raise _not_found()
    return _daily_status_response(persona)


@router.post("/dev/advance-day", response_model=PersonaDailyStatusResponse)
async def advance_persona_day_for_dev(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _ensure_dev_user(user)
    persona = await _get_persona(db, user["uid"])
    if not persona:
        raise _not_found()
    persona.last_answered_on = date.today() - timedelta(days=1)
    await db.commit()
    await db.refresh(persona)
    return _daily_status_response(persona)


@router.post("/update", response_model=PersonaResponse)
async def update_persona(
    body: PersonaUpdateRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm: LLMProvider = Depends(get_llm_provider),
):
    persona = await _get_persona(db, user["uid"])
    if not persona:
        raise _not_found()
    if persona.last_answered_on == date.today():
        raise HTTPException(
            status_code=409,
            detail={
                "error_code": "ALREADY_UPDATED_TODAY",
                "message": "오늘의 페르소나 답변은 이미 반영되었습니다.",
                "request_id": str(uuid.uuid4()),
            },
        )

    started = time.monotonic()
    result = await llm.update_persona(user["uid"], _persona_dict(persona), body.answer)
    elapsed_ms = int((time.monotonic() - started) * 1000)

    _apply_result(persona, result)
    new_codes = _answer_codes([body.answer])
    persona.answered_codes = _merge_codes(persona.answered_codes, new_codes)
    persona.answer_count = len(persona.answered_codes)
    persona.persona_revision = (persona.persona_revision or 1) + 1
    persona.persona_confidence = _confidence(persona.answer_count, persona.answered_codes)
    persona.last_answered_on = date.today()
    await db.commit()
    await db.refresh(persona)

    await log_llm_call(
        db,
        endpoint="persona/update",
        provider=settings.llm_provider,
        request_body={
            "answer_code": body.answer.get("code"),
            "category": body.answer.get("category"),
        },
        response_status=200,
        response_time_ms=elapsed_ms,
        user_id=user["uid"],
    )

    return _persona_response(persona)


@router.get("/me", response_model=PersonaResponse)
async def get_my_persona(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    persona = await _get_persona(db, user["uid"])
    if not persona:
        raise _not_found()
    return _persona_response(persona)
