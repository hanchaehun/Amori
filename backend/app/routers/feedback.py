"""만남 후 피드백 — 매칭 알고리즘 학습 루프의 입력 데이터."""

import uuid as uuid_mod

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.dependencies import get_db
from app.models.database import Feedback, Match
from app.schemas.common import FeedbackCreate

router = APIRouter()


class FeedbackResponse(BaseModel):
    id: str
    match_id: str
    status: str = "saved"


@router.post("", response_model=FeedbackResponse)
async def submit_feedback(
    body: FeedbackCreate,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    request_id = str(uuid_mod.uuid4())

    try:
        match_uuid = uuid_mod.UUID(body.match_id)
    except ValueError:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "매칭 정보를 찾을 수 없습니다.",
                "request_id": request_id,
            },
        )

    result = await db.execute(select(Match).where(Match.id == match_uuid))
    match_obj = result.scalar_one_or_none()
    if not match_obj or user["uid"] not in match_obj.participant_ids:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "매칭 정보를 찾을 수 없습니다.",
                "request_id": request_id,
            },
        )

    feedback = Feedback(
        match_id=match_uuid,
        user_id=user["uid"],
        impression=body.impression,
        accuracy=body.accuracy,
        next_step=body.next_step,
        note=body.note,
    )
    db.add(feedback)
    await db.commit()
    await db.refresh(feedback)

    return FeedbackResponse(id=str(feedback.id), match_id=body.match_id)
