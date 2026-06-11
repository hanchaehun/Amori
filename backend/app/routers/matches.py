import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.dependencies import get_db
from app.matching import find_candidates
from app.models.database import Match, Persona
from app.schemas.common import MatchAcceptResponse, MatchResponse

router = APIRouter()


async def get_or_create_match(
    db: AsyncSession, uid_a: str, uid_b: str
) -> Match:
    """두 사용자의 Match 행을 찾거나 생성한다. match_id는 항상 실제 UUID."""
    sorted_uids = sorted([uid_a, uid_b])
    result = await db.execute(
        select(Match).where(Match.participant_ids == sorted_uids)
    )
    match_obj = result.scalar_one_or_none()
    if not match_obj:
        match_obj = Match(participant_ids=sorted_uids, status="candidate")
        db.add(match_obj)
        await db.flush()
    return match_obj


@router.get("/find", response_model=list[MatchResponse])
async def find_matches(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    top_k: int = Query(default=10, ge=1, le=50),
):
    request_id = str(uuid.uuid4())

    # Get current user's persona + embedding
    result = await db.execute(
        select(Persona).where(Persona.user_id == user["uid"])
    )
    my_persona = result.scalar_one_or_none()

    if not my_persona or my_persona.embedding is None:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "PERSONA_REQUIRED",
                "message": "매칭을 위해 먼저 페르소나를 생성해 주세요.",
                "request_id": request_id,
            },
        )

    candidates = await find_candidates(
        db, my_persona.embedding, exclude_user_id=user["uid"], top_k=top_k
    )

    # 후보마다 Match 행을 find-or-create — 응답의 match_id가 곧 DB UUID라
    # report/meet 라우터의 UUID 파싱과 일치한다 (구 uid_uid 문자열 버그 수정)
    matches: list[MatchResponse] = []
    for candidate in candidates:
        match_obj = await get_or_create_match(db, user["uid"], candidate.user_id)
        if match_obj.score != candidate.score:
            match_obj.score = candidate.score
        matches.append(
            MatchResponse(
                match_id=str(match_obj.id),
                user_id=candidate.user_id,
                display_name=candidate.display_name,
                score=candidate.score,
            )
        )
    await db.commit()

    return matches


@router.post("/{match_id}/accept", response_model=MatchAcceptResponse)
async def accept_match(
    match_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """사용자가 약속을 수락한다. 양쪽 참가자가 모두 수락하면 status='scheduled'.

    약속 조율이 끝난(appointment_ready) 매치에서만 수락할 수 있다 —
    '진행 중'에서 강조된 카드의 [수락] 버튼이 이 엔드포인트를 호출한다.
    """
    request_id = str(uuid.uuid4())
    try:
        match_uuid = uuid.UUID(match_id)
    except ValueError:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "NOT_FOUND", "message": "매칭 정보를 찾을 수 없습니다.", "request_id": request_id},
        )

    result = await db.execute(select(Match).where(Match.id == match_uuid))
    match_obj = result.scalar_one_or_none()

    if not match_obj or user["uid"] not in match_obj.participant_ids:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "NOT_FOUND", "message": "매칭 정보를 찾을 수 없습니다.", "request_id": request_id},
        )

    if not match_obj.appointment_ready:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "NOT_READY",
                "message": "아직 약속 조율이 완료되지 않은 대화입니다.",
                "request_id": request_id,
            },
        )

    # 멱등적으로 수락자 추가 (ARRAY 컬럼은 새 리스트 할당으로 변경 감지)
    if user["uid"] not in match_obj.accepted_by:
        match_obj.accepted_by = [*match_obj.accepted_by, user["uid"]]

    both_accepted = all(uid in match_obj.accepted_by for uid in match_obj.participant_ids)
    if both_accepted:
        match_obj.status = "scheduled"
    await db.commit()

    return MatchAcceptResponse(
        match_id=str(match_obj.id),
        status=match_obj.status,
        appointment_ready=match_obj.appointment_ready,
        accepted_by=list(match_obj.accepted_by),
        both_accepted=both_accepted,
    )
