"""사용자 프로필 — Firestore 직접 쓰기를 대체하는 단일 원천 (Postgres)."""

import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.dependencies import get_db
from app.models.database import User

router = APIRouter()


class UserProfileUpsert(BaseModel):
    display_name: str | None = None
    birth_date: date | None = None
    gender: str | None = None
    interest_gender: str | None = None
    photo_url: str | None = None
    fcm_token: str | None = None


class UserProfileResponse(BaseModel):
    user_id: str
    email: str | None
    display_name: str | None
    birth_date: date | None
    gender: str | None
    interest_gender: str | None
    photo_url: str | None


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
        user_obj.birth_date = body.birth_date
    if body.gender is not None:
        user_obj.gender = body.gender
    if body.interest_gender is not None:
        user_obj.interest_gender = body.interest_gender
    if body.photo_url is not None:
        user_obj.photo_url = body.photo_url
    if body.fcm_token is not None:
        user_obj.fcm_token = body.fcm_token
    await db.commit()

    return UserProfileResponse(
        user_id=user_obj.id,
        email=user_obj.email,
        display_name=user_obj.display_name,
        birth_date=user_obj.birth_date,
        gender=user_obj.gender,
        interest_gender=user_obj.interest_gender,
        photo_url=user_obj.photo_url,
    )


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
    return UserProfileResponse(
        user_id=user_obj.id,
        email=user_obj.email,
        display_name=user_obj.display_name,
        birth_date=user_obj.birth_date,
        gender=user_obj.gender,
        interest_gender=user_obj.interest_gender,
        photo_url=user_obj.photo_url,
    )
