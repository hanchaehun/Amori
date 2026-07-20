"""사용자 프로필 — Firestore 직접 쓰기를 대체하는 단일 원천 (Postgres)."""

import uuid
from datetime import date

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.dependencies import get_db
from app.llm.psych_mapping import valid_mbti
from app.matching.ranker import ADULT_AGE, age_years
from app.models.database import Feedback, LLMCallLog, Match, User
from app.services.booking import get_booked_matches

router = APIRouter()


class AvailableSlot(BaseModel):
    """소개팅 가능 일정 한 칸 — 에이전트는 이 시간 중에서만 약속을 잡는다."""

    date: date
    time: Literal["점심", "저녁"]


class BookedSlot(BaseModel):
    """수락한 약속이 점유한 칸 — 일정 시트에서 잠금 표시되고 편집할 수 없다."""

    date: date
    time: Literal["점심", "저녁"]
    partner_name: str | None = None


class UserProfileUpsert(BaseModel):
    # 길이 상한은 DB 컬럼과 일치 — 없으면 초과 입력이 DB DataError로 500이 된다 (보안 점검 7/15).
    display_name: str | None = Field(default=None, max_length=100)
    birth_date: date | None = None
    gender: str | None = Field(default=None, max_length=20)
    interest_gender: str | None = Field(default=None, max_length=20)
    region: str | None = Field(default=None, max_length=30)  # 활동 지역(시/도)
    # 매칭 허용 나이 — 나보다 위로/아래로 몇 살까지. 미설정(None)이면 매칭에서 기본 5.
    # 하한은 매칭 쿼리가 만 19세(성인)에서 자른다.
    match_age_older: int | None = Field(default=None, ge=0, le=30)
    match_age_younger: int | None = Field(default=None, ge=0, le=30)
    # MBTI 16유형 — 프로필 표시 + big_five prior 전용. 매칭·시뮬 규칙 사용 금지
    # (rationale §9 금지선). 빈 문자열 = 삭제.
    mbti: str | None = None
    bio: str | None = Field(default=None, max_length=200)  # 한줄 소개
    photo_url: str | None = Field(default=None, max_length=2000)
    fcm_token: str | None = None
    available_slots: list[AvailableSlot] | None = Field(default=None, max_length=30)


class UserProfileResponse(BaseModel):
    user_id: str
    email: str | None
    display_name: str | None
    birth_date: date | None
    gender: str | None
    interest_gender: str | None
    region: str | None = None
    match_age_older: int | None = None
    match_age_younger: int | None = None
    mbti: str | None = None
    bio: str | None = None
    photo_url: str | None
    available_slots: list[AvailableSlot] = []
    booked_slots: list[BookedSlot] = []  # GET에서만 채워진다


async def ensure_user(db: AsyncSession, uid: str, email: str | None = None) -> User:
    """User 행이 없으면 만든다 — personas 등 FK의 전제."""
    result = await db.execute(select(User).where(User.id == uid))
    user_obj = result.scalar_one_or_none()
    if not user_obj:
        user_obj = User(id=uid, email=email)
        db.add(user_obj)
        await db.flush()
    return user_obj


@router.put("/me", response_model=UserProfileResponse)
async def upsert_my_profile(
    body: UserProfileUpsert,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_obj = await ensure_user(db, user["uid"], user.get("email"))
    if body.display_name is not None:
        user_obj.display_name = body.display_name
    if body.birth_date is not None:
        # 데이팅 서비스 법적 하한 — 미성년(만 19세 미만) 프로필 저장 거부.
        # 앱 피커도 막지만 API 직접 호출 방어선 (본인인증 실연동 전 임시).
        if age_years(body.birth_date) < ADULT_AGE:
            raise HTTPException(
                status_code=422,
                detail={
                    "error_code": "UNDERAGE",
                    "message": "만 19세 이상만 이용할 수 있습니다.",
                },
            )
        user_obj.birth_date = body.birth_date
    if body.gender is not None:
        user_obj.gender = body.gender
    if body.interest_gender is not None:
        user_obj.interest_gender = body.interest_gender
    if body.region is not None:
        # 빈 문자열은 "지역 미설정" 의도 — None으로 정규화 (프로필 시트의
        # '선택 안 함'과 정합, 매칭 쿼리가 빈 지역을 무시하도록).
        user_obj.region = body.region or None
    if body.match_age_older is not None:
        user_obj.match_age_older = body.match_age_older
    if body.match_age_younger is not None:
        user_obj.match_age_younger = body.match_age_younger
    if body.mbti is not None:
        # 16유형 검증 — 빈 문자열은 삭제, 무효 값은 422
        if body.mbti == "":
            user_obj.mbti = None
        else:
            normalized = valid_mbti(body.mbti)
            if normalized is None:
                raise HTTPException(
                    status_code=422,
                    detail={
                        "error_code": "INVALID_MBTI",
                        "message": "MBTI는 16유형 코드여야 합니다 (예: ENFP).",
                    },
                )
            user_obj.mbti = normalized
    if body.bio is not None:
        user_obj.bio = body.bio.strip() or None
    if body.photo_url is not None:
        # 빈 문자열은 "사진 삭제" 의도로 보고 None 처리 (bio와 동일 규칙).
        if body.photo_url == "":
            user_obj.photo_url = None
        else:
            # 상대방 앱에서 그대로 로드되는 URL — https만 허용 (보안 점검 7/15)
            if not body.photo_url.startswith("https://"):
                raise HTTPException(
                    status_code=422,
                    detail={
                        "error_code": "INVALID_PHOTO_URL",
                        "message": "사진 URL은 https여야 합니다.",
                    },
                )
            user_obj.photo_url = body.photo_url
    if body.fcm_token is not None:
        user_obj.fcm_token = body.fcm_token
    if body.available_slots is not None:
        user_obj.available_slots = [
            {"date": s.date.isoformat(), "time": s.time} for s in body.available_slots
        ]
    await db.commit()

    return UserProfileResponse(
        user_id=user_obj.id,
        email=user_obj.email,
        display_name=user_obj.display_name,
        birth_date=user_obj.birth_date,
        gender=user_obj.gender,
        interest_gender=user_obj.interest_gender,
        region=user_obj.region,
        match_age_older=user_obj.match_age_older,
        match_age_younger=user_obj.match_age_younger,
        mbti=user_obj.mbti,
        bio=user_obj.bio,
        photo_url=user_obj.photo_url,
        available_slots=user_obj.available_slots or [],
    )


@router.delete("/me")
async def delete_my_account(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """회원 탈퇴 — 사용자의 도메인 데이터를 실제로 삭제한다.

    - 참가한 matches 삭제 → FK CASCADE로 simulation_jobs·chat_messages·
      reports·meet_requests·해당 매치 feedback까지 연쇄 정리.
    - users 삭제 → CASCADE로 personas 정리.
    - user_id로만 연결된 feedback·llm_call_logs는 명시 삭제.

    Firebase Auth 계정 삭제는 클라이언트가 재인증 후 처리한다.
    """
    uid = user["uid"]

    matches = await db.execute(
        select(Match).where(Match.participant_ids.any(uid))
    )
    for match in matches.scalars().all():
        await db.delete(match)  # CASCADE: sim/chat/report/meet/feedback

    await db.execute(delete(Feedback).where(Feedback.user_id == uid))
    await db.execute(delete(LLMCallLog).where(LLMCallLog.user_id == uid))

    result = await db.execute(select(User).where(User.id == uid))
    user_obj = result.scalar_one_or_none()
    if user_obj:
        await db.delete(user_obj)  # CASCADE: personas

    await db.commit()
    return {"deleted": True}


@router.get("/me", response_model=UserProfileResponse)
async def get_my_profile(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user["uid"]))
    user_obj = result.scalar_one_or_none()
    if not user_obj:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "사용자 프로필이 없습니다.",
                "request_id": str(uuid.uuid4()),
            },
        )

    # 수락한 약속이 점유한 칸 — 상대 이름과 함께 (일정 시트의 잠금 표시용)
    booked_matches = await get_booked_matches(db, user["uid"])
    partner_ids = [
        next((p for p in m.participant_ids if p != user["uid"]), None)
        for m in booked_matches
    ]
    names = {}
    if any(partner_ids):
        names_result = await db.execute(
            select(User).where(User.id.in_([p for p in partner_ids if p]))
        )
        names = {u.id: u.display_name for u in names_result.scalars().all()}
    booked = [
        BookedSlot(
            date=m.appointment_slot["date"],
            time=m.appointment_slot["time"],
            partner_name=names.get(pid),
        )
        for m, pid in zip(booked_matches, partner_ids)
    ]

    return UserProfileResponse(
        user_id=user_obj.id,
        email=user_obj.email,
        display_name=user_obj.display_name,
        birth_date=user_obj.birth_date,
        gender=user_obj.gender,
        interest_gender=user_obj.interest_gender,
        region=user_obj.region,
        match_age_older=user_obj.match_age_older,
        match_age_younger=user_obj.match_age_younger,
        mbti=user_obj.mbti,
        bio=user_obj.bio,
        photo_url=user_obj.photo_url,
        available_slots=user_obj.available_slots or [],
        booked_slots=booked,
    )
