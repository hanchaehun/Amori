"""사용자 프로필 — Firestore 직접 쓰기를 대체하는 단일 원천 (Postgres)."""

import uuid
from datetime import date

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.config import settings
from app.dependencies import get_db
from app.llm.psych_mapping import valid_mbti
from app.matching.ranker import ADULT_AGE, age_years
from app.models.database import BlockedContact, User
from app.services import contact_hash
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
    # 자기신고 휴대전화 번호 (지인 필터 실효화, 2026-07-19) — 빈 문자열 = 삭제.
    # 본인인증 도입 시 인증 번호로 덮어쓴다.
    phone_number: str | None = Field(default=None, max_length=30)
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
    phone_number: str | None = None
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
    # 지인 필터용 이메일 해시 유지 (구버전 행 백필 겸) — 전화 해시는
    # 본인인증(PASS) 도입 시 인증된 번호로 채운다.
    if user_obj.email and not user_obj.email_hash:
        user_obj.email_hash = contact_hash.email_hash(user_obj.email)
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
        user_obj.region = body.region
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
    if body.phone_number is not None:
        if body.phone_number == "":
            user_obj.phone_number = None
            user_obj.phone_hash = None
        else:
            # 한국 휴대전화(01x, 10~11자리)로 정규화 — 지인 필터 해시의 원천
            normalized = contact_hash.normalize_phone(body.phone_number)
            if (
                normalized is None
                or not normalized.startswith("01")
                or len(normalized) not in (10, 11)
            ):
                raise HTTPException(
                    status_code=422,
                    detail={
                        "error_code": "INVALID_PHONE",
                        "message": "올바른 휴대전화 번호가 아니에요. (예: 010-1234-5678)",
                    },
                )
            user_obj.phone_number = normalized
            user_obj.phone_hash = contact_hash.sha256_hex(normalized)
    if body.photo_url is not None and body.photo_url != "":
        # 상대방 앱에서 그대로 로드되는 URL — https만 허용 (보안 점검 7/15)
        if not body.photo_url.startswith("https://"):
            raise HTTPException(
                status_code=422,
                detail={
                    "error_code": "INVALID_PHOTO_URL",
                    "message": "사진 URL은 https여야 합니다.",
                },
            )
    if body.photo_url is not None:
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
        phone_number=user_obj.phone_number,
        photo_url=user_obj.photo_url,
        available_slots=user_obj.available_slots or [],
    )


# ---- 지인 필터 (blocked contacts) ------------------------------------------
# 주소록의 지인과 매칭되지 않게 하는 기능. 클라이언트가 연락처를 정규화+
# SHA-256 해시해 올린다(원문은 서버로 오지 않는다 — services/contact_hash.py
# 계약). 본인인증 도입 전엔 실효가 없어 서버 플래그로 잠근다.


class BlockedContactItem(BaseModel):
    id: str
    kind: Literal["phone", "email"]
    label: str | None = None


class BlockedContactsResponse(BaseModel):
    enabled: bool  # 수집 가능 여부 (끄면 쓰기 API 403 — 클라이언트 잠금 게이트)
    # 매칭 실적용 여부 — 본인인증 도입 시 켠다. false면 앱이
    # "본인인증 도입 후 매칭에 적용" 안내를 띄우되 등록은 받는다.
    enforced: bool = False
    synced_count: int  # 주소록 동기화로 등록된 해시 수
    manual: list[BlockedContactItem] = []


class ContactHashItem(BaseModel):
    hash: str = Field(min_length=64, max_length=64)
    kind: Literal["phone", "email"]


class ContactSyncRequest(BaseModel):
    hashes: list[ContactHashItem]


class ManualContactRequest(BaseModel):
    hash: str = Field(min_length=64, max_length=64)
    kind: Literal["phone", "email"]
    # 표시용 라벨(이름 또는 클라이언트가 만든 마스킹 문자열) — 원문 금지 계약
    label: str | None = Field(default=None, max_length=60)


def _require_contact_filter() -> None:
    """쓰기 API 게이트 — 본인인증 도입 전엔 403 (플래그로 개방)."""
    if not settings.contact_filter_enabled:
        raise HTTPException(
            status_code=403,
            detail={
                "error_code": "FEATURE_DISABLED",
                "message": "지인 필터는 본인인증 도입 후 이용할 수 있습니다.",
                "request_id": str(uuid.uuid4()),
            },
        )


def _valid_hashes(items: list) -> list:
    """형식(64자 hex 소문자)이 맞는 항목만 — 나머지는 조용히 버린다."""
    return [i for i in items if contact_hash.is_valid_hash(i.hash)]


@router.get("/me/blocked-contacts", response_model=BlockedContactsResponse)
async def list_blocked_contacts(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """지인 필터 현황 — enabled 플래그는 클라이언트 UI 노출 게이트를 겸한다."""
    rows = (
        await db.execute(
            select(BlockedContact)
            .where(BlockedContact.user_id == user["uid"])
            .order_by(BlockedContact.created_at)
        )
    ).scalars().all()
    return BlockedContactsResponse(
        enabled=settings.contact_filter_enabled,
        enforced=settings.contact_filter_enforced,
        synced_count=sum(1 for r in rows if r.source == "contacts"),
        manual=[
            BlockedContactItem(id=str(r.id), kind=r.kind, label=r.label)
            for r in rows
            if r.source == "manual"
        ],
    )


@router.put("/me/blocked-contacts/sync", response_model=BlockedContactsResponse)
async def sync_blocked_contacts(
    body: ContactSyncRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """주소록 동기화 — source='contacts' 전량 교체 (수동 항목은 보존)."""
    _require_contact_filter()
    if len(body.hashes) > settings.contact_sync_max_hashes:
        raise HTTPException(
            status_code=422,
            detail={
                "error_code": "TOO_MANY_CONTACTS",
                "message": f"한 번에 {settings.contact_sync_max_hashes}개까지 동기화할 수 있습니다.",
                "request_id": str(uuid.uuid4()),
            },
        )
    uid = user["uid"]
    await db.execute(
        delete(BlockedContact).where(
            BlockedContact.user_id == uid, BlockedContact.source == "contacts"
        )
    )
    # 수동 항목과 중복되는 해시는 건너뛴다 (user_id+hash 유니크 제약)
    manual_hashes = set(
        (
            await db.execute(
                select(BlockedContact.contact_hash).where(
                    BlockedContact.user_id == uid
                )
            )
        ).scalars().all()
    )
    seen: set[str] = set()
    for item in _valid_hashes(body.hashes):
        if item.hash in manual_hashes or item.hash in seen:
            continue
        seen.add(item.hash)
        db.add(
            BlockedContact(
                user_id=uid,
                contact_hash=item.hash,
                kind=item.kind,
                source="contacts",
            )
        )
    await db.commit()
    return await list_blocked_contacts(user, db)


@router.post("/me/blocked-contacts", response_model=BlockedContactItem)
async def add_blocked_contact(
    body: ManualContactRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """수동 등록 — 주소록에 없는 지인의 전화번호/이메일 (멱등)."""
    _require_contact_filter()
    if not contact_hash.is_valid_hash(body.hash):
        raise HTTPException(
            status_code=422,
            detail={
                "error_code": "INVALID_HASH",
                "message": "해시 형식이 올바르지 않습니다.",
                "request_id": str(uuid.uuid4()),
            },
        )
    uid = user["uid"]
    existing = (
        await db.execute(
            select(BlockedContact).where(
                BlockedContact.user_id == uid,
                BlockedContact.contact_hash == body.hash,
            )
        )
    ).scalar_one_or_none()
    if existing:
        # 이미 있으면 수동 항목으로 승격 — 다음 sync가 지우지 못하게
        existing.source = "manual"
        existing.label = body.label or existing.label
        await db.commit()
        return BlockedContactItem(
            id=str(existing.id), kind=existing.kind, label=existing.label
        )
    row = BlockedContact(
        user_id=uid,
        contact_hash=body.hash,
        kind=body.kind,
        source="manual",
        label=body.label,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return BlockedContactItem(id=str(row.id), kind=row.kind, label=row.label)


@router.delete("/me/blocked-contacts/{contact_id}", response_model=BlockedContactsResponse)
async def delete_blocked_contact(
    contact_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """수동 항목 삭제 — 동기화 항목은 주소록에서 지우고 재동기화가 원칙."""
    _require_contact_filter()
    request_id = str(uuid.uuid4())
    try:
        row_uuid = uuid.UUID(contact_id)
    except ValueError:
        row_uuid = None
    row = None
    if row_uuid:
        row = (
            await db.execute(
                select(BlockedContact).where(
                    BlockedContact.id == row_uuid,
                    BlockedContact.user_id == user["uid"],
                    BlockedContact.source == "manual",
                )
            )
        ).scalar_one_or_none()
    if not row:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "삭제할 항목을 찾을 수 없습니다.",
                "request_id": request_id,
            },
        )
    await db.delete(row)
    await db.commit()
    return await list_blocked_contacts(user, db)


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
        phone_number=user_obj.phone_number,
        photo_url=user_obj.photo_url,
        available_slots=user_obj.available_slots or [],
        booked_slots=booked,
    )
