import uuid
from datetime import date as date_cls, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.config import settings
from app.dependencies import get_db
from app.matching import find_candidates
from app.models.database import ChatMessage, Match, Persona, Report, SimulationJob, User
from app.schemas.common import (
    AgentTurnItem,
    AppointmentSetRequest,
    AppointmentSetResponse,
    ChatMessageItem,
    ChatSendRequest,
    MatchAcceptResponse,
    MatchCancelResponse,
    MatchConversationResponse,
    MatchListItem,
    MatchResponse,
)
from app.services.booking import get_booked_matches, slot_label
from app.services.reveal import reveal_complete, revealed_turns

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


@router.get("", response_model=list[MatchListItem])
async def list_my_matches(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """내 대화 목록 — 연결(inbox) 화면이 소비한다.

    시뮬레이션이 한 번이라도 돌았던 매치만 반환한다(candidate 제외).
    클라이언트는 status로 진행 중(simulated)/만남 예정(scheduled)을 나누고,
    appointment_ready 카드를 맨 위로 올린다.

    케미 점수(리포트)가 게이트 미만이면 failed=True로 분리해 보낸다 —
    '닿지 않은 인연' 화면용. TTL이 지난 실패 건은 목록에서 자연 소멸한다.
    """
    uid = user["uid"]
    result = await db.execute(
        select(Match)
        .where(Match.participant_ids.any(uid), Match.status != "candidate")
        .order_by(Match.updated_at.desc())
    )
    matches = result.scalars().all()
    if not matches:
        return []

    match_ids = [m.id for m in matches]
    partner_ids = [
        next((p for p in m.participant_ids if p != uid), uid) for m in matches
    ]

    # 매치별 최신 *완료* 시뮬레이션 한 건 (DISTINCT ON) — 카드 미리보기용.
    # 끊기거나 실패한 잡(0턴)이 마지막 성공 대화를 가리지 않도록 completed만 본다.
    jobs_result = await db.execute(
        select(SimulationJob)
        .distinct(SimulationJob.match_id)
        .where(
            SimulationJob.match_id.in_(match_ids),
            SimulationJob.status == "completed",
        )
        .order_by(SimulationJob.match_id, SimulationJob.created_at.desc())
    )
    latest_jobs = {j.match_id: j for j in jobs_result.scalars().all()}

    users_result = await db.execute(select(User).where(User.id.in_(partner_ids)))
    partner_users = {u.id: u for u in users_result.scalars().all()}
    partner_names = {uid: u.display_name for uid, u in partner_users.items()}

    reports_result = await db.execute(
        select(Report).where(Report.match_id.in_(match_ids))
    )
    reports = {r.match_id: r for r in reports_result.scalars().all()}

    now = datetime.now(timezone.utc)
    ttl = timedelta(days=settings.failed_match_ttl_days)

    items: list[MatchListItem] = []
    for match_obj, partner_id in zip(matches, partner_ids):
        job = latest_jobs.get(match_obj.id)
        all_turns = (job.turns if job else None) or []
        # 시차 송출: 지금까지 공개된 턴만 카드에 반영한다. 송출이 끝나기 전이면
        # live=True — 약속·리포트·게이트 결과는 대화가 다 흐른 뒤에만 공개한다.
        shown = revealed_turns(all_turns, now)
        live = bool(job) and not reveal_complete(all_turns, now)
        last_text = shown[-1].get("text") if shown else None
        report = reports.get(match_obj.id)
        # 진행 실패: 케미 점수가 게이트 미만인 simulated 매치 — 75점 게이트가 왕.
        # 분위기에 휩쓸려 약속이 잡혔어도 게이트 미만이면 약속째로 무효
        # (리포트 생성 시점에 appointment_ready를 내리지만, 구버전 행 방어로
        # 응답에서도 약속 필드를 무효화한다). 송출 중(live)이면 결과 미확정이라
        # 실패 분류를 보류한다 — 대화가 끝나기 전에 '닿지 않은 인연'으로 새지 않도록.
        failed = (
            not live
            and report is not None
            and report.score < settings.report_pass_score
            and match_obj.status == "simulated"
        )
        failed_expires_at = None
        if failed:
            failed_expires_at = report.created_at + ttl
            if failed_expires_at <= now:
                continue  # TTL 지난 실패 건은 자연 소멸 (행은 보존)
        # 수락 관련 필드는 송출 중(live)이거나 게이트 미만(failed)이면 가린다.
        # 단 report_score는 '닿지 않은 인연' 화면이 실패 점수를 보여줘야 하므로
        # failed일 땐 노출하고, 송출 중(결과 미확정)일 때만 가린다.
        hide_appointment = live or failed
        # '수락 가능'(appointment_ready) = 리포트가 게이트를 통과한 매치.
        # 시뮬은 약속을 잡지 않으므로(2026-07-04 결정 — 약속은 수락 후 직접 채팅에서)
        # 필드명은 Flutter 하위호환용으로 유지하고 의미만 재정의한다.
        ready = (
            not hide_appointment
            and report is not None
            and report.score >= settings.report_pass_score
        )
        items.append(
            MatchListItem(
                match_id=str(match_obj.id),
                partner_id=partner_id,
                partner_name=partner_names.get(partner_id),
                partner_photo_url=(
                    p.photo_url if (p := partner_users.get(partner_id)) else None
                ),
                status=match_obj.status,
                score=match_obj.score,
                appointment_ready=ready,
                you_accepted=not hide_appointment and uid in match_obj.accepted_by,
                partner_accepted=not hide_appointment
                and any(
                    p in match_obj.accepted_by for p in match_obj.participant_ids if p != uid
                ),
                last_message=last_text,
                turn_count=len(shown),
                updated_at=match_obj.updated_at.isoformat(),
                # 사용자들이 직접 채팅에서 확정한 약속 라벨 (시뮬은 약속을 잡지 않음)
                appointment_slot=(
                    slot_label(match_obj.appointment_slot)
                    if match_obj.appointment_slot and not hide_appointment
                    else None
                ),
                report_score=None if live else (report.score if report else None),
                failed=failed,
                # warnings 항목은 {title, body} dict — 문자열 필드에 dict를 넣으면
                # 응답 검증이 죽어 목록 전체가 500이 된다 (E2E 7/15 발견).
                failure_reason=(
                    (report.warnings[0].get("title") or report.warnings[0].get("body"))
                    if failed and report.warnings
                    else None
                ),
                failed_expires_at=(
                    failed_expires_at.isoformat() if failed_expires_at else None
                ),
                agent_live=live,
            )
        )
    return items


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

    # 관심 성별 상호 필터 — 내 프로필의 성별/관심 성별 기준 (없으면 무필터)
    me_result = await db.execute(select(User).where(User.id == user["uid"]))
    me = me_result.scalar_one_or_none()

    candidates = await find_candidates(
        db,
        my_persona.embedding,
        exclude_user_id=user["uid"],
        top_k=top_k,
        my_gender=me.gender if me else None,
        my_interest_gender=me.interest_gender if me else None,
        my_region=me.region if me else None,
        my_birth_date=me.birth_date if me else None,
        my_age_older=me.match_age_older if me else None,
        my_age_younger=me.match_age_younger if me else None,
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


async def _load_my_match(db: AsyncSession, match_id: str, uid: str, request_id: str) -> Match:
    """참가자 본인의 매치 행을 불러온다. 없거나 남의 매치면 404."""
    try:
        match_uuid = uuid.UUID(match_id)
    except ValueError:
        match_uuid = None
    match_obj = None
    if match_uuid:
        result = await db.execute(select(Match).where(Match.id == match_uuid))
        match_obj = result.scalar_one_or_none()
    if not match_obj or uid not in match_obj.participant_ids:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "NOT_FOUND", "message": "매칭 정보를 찾을 수 없습니다.", "request_id": request_id},
        )
    return match_obj


class PartnerProfileResponse(BaseModel):
    """리포트 내 '상대 프로필 보기' — 매칭된 쌍에게만 공개하는 최소 프로필."""

    user_id: str
    display_name: str | None = None
    age: int | None = None
    region: str | None = None
    mbti: str | None = None
    bio: str | None = None
    photo_url: str | None = None


@router.get("/{match_id}/partner-profile", response_model=PartnerProfileResponse)
async def get_partner_profile(
    match_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """매치 상대의 공개 프로필. 참가자 본인만 조회 가능 (그 외 404)."""
    request_id = str(uuid.uuid4())
    match_obj = await _load_my_match(db, match_id, user["uid"], request_id)
    other_uid = next(
        pid for pid in match_obj.participant_ids if pid != user["uid"]
    )
    result = await db.execute(select(User).where(User.id == other_uid))
    partner = result.scalar_one_or_none()
    if not partner:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "상대 프로필을 찾을 수 없습니다.",
                "request_id": request_id,
            },
        )
    age = None
    if partner.birth_date:
        today = date_cls.today()
        born = partner.birth_date
        age = (
            today.year
            - born.year
            - ((today.month, today.day) < (born.month, born.day))
        )
    return PartnerProfileResponse(
        user_id=partner.id,
        display_name=partner.display_name,
        age=age,
        region=partner.region,
        mbti=partner.mbti,
        bio=partner.bio,
        photo_url=partner.photo_url,
    )


@router.get("/{match_id}/conversation", response_model=MatchConversationResponse)
async def get_conversation(
    match_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """대화방 화면 데이터 — 에이전트 대화 + 직접 채팅 + 입력 가능 여부.

    직접 채팅은 양쪽이 만남을 수락해 status='scheduled'일 때만 열린다.
    '진행 중' 매치는 에이전트 대화를 읽기 전용으로 보여준다. 약속이 취소된
    뒤에도 방은 열리므로 시스템 안내문구(취소 알림)는 상대에게 보인다.
    """
    uid = user["uid"]
    request_id = str(uuid.uuid4())
    match_obj = await _load_my_match(db, match_id, uid, request_id)

    # 에이전트 대화 — 최신 시뮬레이션 1건. 턴의 me/them은 잡 요청자 기준이라
    # 보는 사람이 요청자가 아니면 뒤집는다.
    job_result = await db.execute(
        select(SimulationJob)
        .where(
            SimulationJob.match_id == match_obj.id,
            SimulationJob.status == "completed",
        )
        .order_by(SimulationJob.created_at.desc())
        .limit(1)
    )
    job = job_result.scalar_one_or_none()
    # 시차 송출: 지금까지 공개된 턴만 보여준다. live면 다음 턴이 곧 도착한다 —
    # 클라이언트는 이걸로 타이핑 인디케이터를 켜고 폴링을 이어간다.
    now = datetime.now(timezone.utc)
    all_turns = (job.turns if job else None) or []
    shown = revealed_turns(all_turns, now)
    agent_live = bool(job) and not reveal_complete(all_turns, now)
    agent_turns: list[AgentTurnItem] = []
    if job:
        flip = job.requested_by != uid
        for t in shown:
            speaker = t.get("speaker", "me")
            if flip:
                speaker = "them" if speaker == "me" else "me"
            agent_turns.append(AgentTurnItem(speaker=speaker, text=t.get("text", "")))

    msgs_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.match_id == match_obj.id)
        .order_by(ChatMessage.created_at)
    )
    messages = [
        ChatMessageItem(
            id=str(m.id),
            kind=m.kind,
            is_me=m.kind == "user" and m.sender_id == uid,
            text=m.text,
            created_at=m.created_at.isoformat(),
        )
        for m in msgs_result.scalars().all()
    ]

    partner_id = next((p for p in match_obj.participant_ids if p != uid), uid)
    partner_result = await db.execute(select(User).where(User.id == partner_id))
    partner = partner_result.scalar_one_or_none()

    return MatchConversationResponse(
        match_id=str(match_obj.id),
        partner_name=partner.display_name if partner else None,
        status=match_obj.status,
        appointment_slot=(
            slot_label(match_obj.appointment_slot) if match_obj.appointment_slot else None
        ),
        chat_enabled=match_obj.status == "scheduled",
        agent_live=agent_live,
        agent_turns=agent_turns,
        messages=messages,
    )


@router.post("/{match_id}/messages", response_model=ChatMessageItem)
async def send_message(
    match_id: str,
    body: ChatSendRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """직접 채팅 전송 — 만남이 확정된(scheduled) 인연만.

    '진행 중'은 에이전트들이 대화하는 단계라 사용자 채팅이 잠겨 있다 —
    클라이언트가 입력을 막지만 서버에서도 차단한다.
    """
    uid = user["uid"]
    request_id = str(uuid.uuid4())
    match_obj = await _load_my_match(db, match_id, uid, request_id)

    if match_obj.status != "scheduled":
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "CHAT_LOCKED",
                "message": "서로 만남을 수락하면 직접 대화할 수 있어요.",
                "request_id": request_id,
            },
        )

    msg = ChatMessage(match_id=match_obj.id, sender_id=uid, kind="user", text=body.text)
    db.add(msg)
    await db.commit()
    await db.refresh(msg)
    return ChatMessageItem(
        id=str(msg.id),
        kind="user",
        is_me=True,
        text=msg.text,
        created_at=msg.created_at.isoformat(),
    )


@router.post("/{match_id}/cancel", response_model=MatchCancelResponse)
async def cancel_appointment(
    match_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """만남 예정 약속을 취소한다 — 어느 한쪽이든 가능.

    매치는 '진행 중'(simulated)으로 돌아가고 약속 상태가 모두 풀린다.
    available_slots(입력)는 원래 손대지 않았으므로, 예약(파생)이 사라지는
    순간 그 시간은 자동으로 다시 가능한 일정이 된다. 상대가 알 수 있게
    채팅방에 시스템 안내문구를 남긴다 — 취소 후 채팅은 다시 잠기지만
    방은 읽기 전용으로 열려 있어 안내문구가 보인다.
    """
    uid = user["uid"]
    request_id = str(uuid.uuid4())
    match_obj = await _load_my_match(db, match_id, uid, request_id)

    if match_obj.status != "scheduled":
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "NOT_SCHEDULED",
                "message": "취소할 약속이 없어요.",
                "request_id": request_id,
            },
        )

    canceller_result = await db.execute(select(User).where(User.id == uid))
    canceller = canceller_result.scalar_one_or_none()
    name = (canceller.display_name if canceller else None) or "상대"
    label = slot_label(match_obj.appointment_slot) if match_obj.appointment_slot else None
    notice = (
        f"{name}님이 {label} 약속을 취소했어요. 그 시간은 다시 비어 있는 일정이 됐어요."
        if label
        else f"{name}님이 약속을 취소했어요."
    )

    match_obj.status = "simulated"
    match_obj.appointment_ready = False
    match_obj.appointment_slot = None
    match_obj.accepted_by = []
    db.add(ChatMessage(match_id=match_obj.id, kind="system", text=notice))
    await db.commit()

    return MatchCancelResponse(
        match_id=str(match_obj.id), status=match_obj.status, notice=notice
    )


@router.post("/{match_id}/accept", response_model=MatchAcceptResponse)
async def accept_match(
    match_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """사용자가 만남을 수락한다. 양쪽 참가자가 모두 수락하면 status='scheduled'.

    수락 조건 = 케미 리포트가 생성됐고 점수 게이트를 통과한 매치.
    양쪽 수락으로 scheduled가 되면 직접 채팅이 열리고, 약속(날짜·시간)은
    두 사용자가 그 채팅에서 직접 잡는다 (시뮬은 약속을 잡지 않는다 — 07-04 결정).
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

    # 시차 송출 중이면 결과(약속·점수)가 아직 사용자에게 다 안 보였다 —
    # 대화가 다 흐르기 전 수락을 막는다(DB의 appointment_ready는 생성 시점에
    # 이미 True일 수 있으나, 클라이언트엔 송출 완료 전까지 가려져 있다).
    job_result = await db.execute(
        select(SimulationJob)
        .where(
            SimulationJob.match_id == match_uuid,
            SimulationJob.status == "completed",
        )
        .order_by(SimulationJob.created_at.desc())
        .limit(1)
    )
    latest_job = job_result.scalar_one_or_none()
    if (
        match_obj.status != "scheduled"
        and latest_job
        and not reveal_complete(latest_job.turns, datetime.now(timezone.utc))
    ):
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "STILL_REVEALING",
                "message": "아직 에이전트들이 대화 중이에요. 잠시 후 다시 시도해 주세요.",
                "request_id": request_id,
            },
        )

    # 수락 가능 조건 = 리포트 생성 + 점수 게이트 통과. 클라이언트가 버튼을
    # 안 보여주지만 서버에서도 최종 차단한다.
    report_result = await db.execute(
        select(Report.score).where(Report.match_id == match_uuid)
    )
    report_score = report_result.scalar_one_or_none()
    if report_score is None:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "NOT_READY",
                "message": "케미 리포트가 준비된 뒤 수락할 수 있습니다.",
                "request_id": request_id,
            },
        )
    if report_score < settings.report_pass_score:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "BELOW_GATE",
                "message": "케미 점수가 기준에 닿지 않아 수락할 수 없는 인연입니다.",
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
        appointment_ready=True,  # 게이트 통과 = 수락 가능 (하위호환 필드)
        accepted_by=list(match_obj.accepted_by),
        both_accepted=both_accepted,
    )


@router.post("/{match_id}/appointment", response_model=AppointmentSetResponse)
async def set_appointment(
    match_id: str,
    body: AppointmentSetRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """직접 채팅에서 합의한 약속을 기록한다 — 약속의 주체는 사용자다.

    시뮬은 약속을 잡지 않으므로(2026-07-04 결정) 만남이 확정된(scheduled) 매치에서
    두 사용자가 채팅으로 시간을 정한 뒤 이 엔드포인트로 확정한다. 여기 기록된
    슬롯이 카드의 만남 예정 라벨·일정 시트 잠금(booked_slots)의 근거가 된다.
    """
    request_id = str(uuid.uuid4())
    match_obj = await _load_my_match(db, match_id, user["uid"], request_id)

    if match_obj.status != "scheduled":
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "NOT_SCHEDULED",
                "message": "만남을 서로 수락한 뒤에 약속을 잡을 수 있습니다.",
                "request_id": request_id,
            },
        )
    try:
        date_cls.fromisoformat(body.date)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "INVALID_INPUT",
                "message": "날짜 형식이 올바르지 않습니다 (YYYY-MM-DD).",
                "request_id": request_id,
            },
        )

    # 중복 약속 차단 — 두 사람 중 누구든 같은 시간에 이미 다른 약속이 있으면 거부
    slot = {"date": body.date, "time": body.time}
    for participant in match_obj.participant_ids:
        booked = {
            (m.appointment_slot["date"], m.appointment_slot["time"])
            for m in await get_booked_matches(db, participant)
            if m.id != match_obj.id
        }
        if (slot["date"], slot["time"]) in booked:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "SLOT_TAKEN",
                    "message": f"{slot_label(slot)}에 이미 다른 약속이 있어요.",
                    "request_id": request_id,
                },
            )

    match_obj.appointment_slot = slot
    label = slot_label(slot)
    db.add(
        ChatMessage(
            match_id=match_obj.id,
            sender_id=None,
            kind="system",
            text=f"📅 {label}에 만나기로 약속했어요",
        )
    )
    await db.commit()

    return AppointmentSetResponse(
        match_id=str(match_obj.id),
        status=match_obj.status,
        appointment_slot=label,
    )
