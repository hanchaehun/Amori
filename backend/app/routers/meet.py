import uuid as uuid_mod
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.dependencies import get_db
from app.middleware.rate_limit import check_meet_request_quota
from app.models.database import Match, MeetRequest
from app.schemas.common import MeetRequestCreate, MeetRequestResponse

router = APIRouter()


class MeetRespondRequest(BaseModel):
    action: Literal["accept", "decline"]


def _parse_uuid(value: str, request_id: str, message: str) -> uuid_mod.UUID:
    """Parse a string to UUID, raising 404 if invalid."""
    try:
        return uuid_mod.UUID(value)
    except ValueError:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": message,
                "request_id": request_id,
            },
        )


@router.post("/request", response_model=MeetRequestResponse)
async def create_meet_request(
    body: MeetRequestCreate,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    request_id = str(uuid_mod.uuid4())

    # 1. Check meet request quota
    if not await check_meet_request_quota(user["uid"], db):
        raise HTTPException(
            status_code=429,
            detail={
                "error_code": "QUOTA_EXCEEDED",
                "message": "일일 만남 신청 횟수를 초과했습니다.",
                "request_id": request_id,
            },
        )

    # 2. Verify match exists and user is a participant
    match_uuid = _parse_uuid(body.match_id, request_id, "매칭 정보를 찾을 수 없습니다.")

    result = await db.execute(
        select(Match).where(Match.id == match_uuid)
    )
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

    # 3. Ensure receiver is the other participant
    if body.receiver_id not in match_obj.participant_ids:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "INVALID_RECEIVER",
                "message": "수신자가 매칭 참가자가 아닙니다.",
                "request_id": request_id,
            },
        )

    if body.receiver_id == user["uid"]:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "INVALID_RECEIVER",
                "message": "자기 자신에게 만남을 신청할 수 없습니다.",
                "request_id": request_id,
            },
        )

    # 4. Create MeetRequest with 24h expiration
    meet_request = MeetRequest(
        match_id=match_uuid,
        requester_id=user["uid"],
        receiver_id=body.receiver_id,
        message=body.message,
        status="pending",
        expires_at=datetime.now(timezone.utc) + timedelta(hours=24),
    )
    db.add(meet_request)
    await db.commit()
    await db.refresh(meet_request)

    return MeetRequestResponse(
        id=str(meet_request.id),
        match_id=str(meet_request.match_id),
        requester_id=meet_request.requester_id,
        receiver_id=meet_request.receiver_id,
        message=meet_request.message or "",
        status=meet_request.status,
        expires_at=meet_request.expires_at.isoformat(),
        created_at=meet_request.created_at.isoformat(),
    )


@router.get("/request/{meet_request_id}", response_model=MeetRequestResponse)
async def get_meet_request(
    meet_request_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    err_request_id = str(uuid_mod.uuid4())
    mr_uuid = _parse_uuid(meet_request_id, err_request_id, "만남 신청을 찾을 수 없습니다.")

    result = await db.execute(
        select(MeetRequest).where(MeetRequest.id == mr_uuid)
    )
    meet_request = result.scalar_one_or_none()

    if not meet_request:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "만남 신청을 찾을 수 없습니다.",
                "request_id": err_request_id,
            },
        )

    # Only requester or receiver can view
    if user["uid"] not in (meet_request.requester_id, meet_request.receiver_id):
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "만남 신청을 찾을 수 없습니다.",
                "request_id": err_request_id,
            },
        )

    return MeetRequestResponse(
        id=str(meet_request.id),
        match_id=str(meet_request.match_id),
        requester_id=meet_request.requester_id,
        receiver_id=meet_request.receiver_id,
        message=meet_request.message or "",
        status=meet_request.status,
        expires_at=meet_request.expires_at.isoformat(),
        created_at=meet_request.created_at.isoformat(),
    )


@router.post("/request/{meet_request_id}/respond", response_model=MeetRequestResponse)
async def respond_to_meet_request(
    meet_request_id: str,
    body: MeetRespondRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    err_request_id = str(uuid_mod.uuid4())
    mr_uuid = _parse_uuid(meet_request_id, err_request_id, "만남 신청을 찾을 수 없습니다.")

    result = await db.execute(
        select(MeetRequest).where(MeetRequest.id == mr_uuid)
    )
    meet_request = result.scalar_one_or_none()

    if not meet_request:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "만남 신청을 찾을 수 없습니다.",
                "request_id": err_request_id,
            },
        )

    # Only the receiver can respond
    if meet_request.receiver_id != user["uid"]:
        raise HTTPException(
            status_code=403,
            detail={
                "error_code": "FORBIDDEN",
                "message": "수신자만 만남 신청에 응답할 수 있습니다.",
                "request_id": err_request_id,
            },
        )

    # Validate status transition: only pending requests can be responded to
    if meet_request.status != "pending":
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "INVALID_STATUS",
                "message": f"이미 처리된 만남 신청입니다. (현재 상태: {meet_request.status})",
                "request_id": err_request_id,
            },
        )

    # Check expiration
    if meet_request.expires_at and meet_request.expires_at < datetime.now(timezone.utc):
        meet_request.status = "expired"
        await db.commit()
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "REQUEST_EXPIRED",
                "message": "만남 신청이 만료되었습니다.",
                "request_id": err_request_id,
            },
        )

    # Update status
    meet_request.status = "accepted" if body.action == "accept" else "declined"
    await db.commit()
    await db.refresh(meet_request)

    return MeetRequestResponse(
        id=str(meet_request.id),
        match_id=str(meet_request.match_id),
        requester_id=meet_request.requester_id,
        receiver_id=meet_request.receiver_id,
        message=meet_request.message or "",
        status=meet_request.status,
        expires_at=meet_request.expires_at.isoformat(),
        created_at=meet_request.created_at.isoformat(),
    )
