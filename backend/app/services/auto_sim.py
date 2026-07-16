"""에이전트 자동 소개팅 — 하루 24시간 중 랜덤 N회, 서버가 알아서 실행.

제품 설계 (2026-06-13, 한채훈): 질문지를 끝내면 페르소나 생성까지만 하고,
매칭+시뮬레이션은 사용자가 시키는 게 아니라 에이전트가 "알아서 다녀온다".
클라이언트 주도 즉시 실행(구 AgentFlow 파이프라인)을 대체한다.

- 스케줄: 유저별로 그날 남은 시간 창에서 랜덤 시각 N개 추첨(메모리 보관,
  재시작 시 재추첨). 일일 한도(daily_simulation_limit)는 DB 기준이라
  재시작해도 초과 실행은 없다.
- 실행: 매칭 후보 중 아직 시뮬레이션이 없던 상대 우선 → 시뮬레이션 →
  리포트까지 한 번에 (inbox 카드가 점수·게이트 분류를 바로 갖도록).
- SSE 없음 — 결과는 DB로만. 클라이언트는 GET /matches로 소비한다.
"""

import asyncio
import logging
import random
import time
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import async_session_factory
from app.llm.base import LLMProvider
from app.middleware.rate_limit import check_simulation_quota
from app.models.database import Match, Persona, Report, SimulationJob
from app.matching import find_candidates
from app.services.llm_log import log_llm_call
from app.services.style_gate import gate_turn

logger = logging.getLogger(__name__)

# uid -> 오늘 남은 발사 시각 (서버 로컬 시간). 재시작하면 재추첨된다.
_pending: dict[str, list[datetime]] = {}
_scheduled_date: dict[str, object] = {}


def _persona_dict(p: Persona, *, voice: bool) -> dict:
    d = {
        "traits": p.traits,
        "communication_style": p.communication_style,
        "humor_style": p.humor_style,
        "value_keywords": p.value_keywords,
    }
    if voice:
        d["speech_style"] = p.speech_style
        d["sample_messages"] = p.sample_messages
        d["voice_stats"] = p.voice_stats  # 실측 말투 — _speech_block v2 수치 지시
        # P0-B 심리 기저층 — _behavior_block 행동 지시 (갈등 모드·되묻기·성격 마커)
        d["conversation_policy"] = p.conversation_policy
        d["psych_profile"] = p.psych_profile
    return d


async def _pick_target(
    db: AsyncSession, uid: str, my_persona: Persona
) -> str | None:
    """매칭 후보 중 아직 시뮬레이션이 없던 상대 우선, 없으면 최고 점수.

    후보군 자체가 관심 성별 상호 필터를 통과한 쌍으로 제한된다.
    """
    from app.models.database import User

    me_result = await db.execute(select(User).where(User.id == uid))
    me = me_result.scalar_one_or_none()
    candidates = await find_candidates(
        db,
        my_persona.embedding,
        uid,
        top_k=5,
        my_gender=me.gender if me else None,
        my_interest_gender=me.interest_gender if me else None,
        my_region=me.region if me else None,
        my_birth_date=me.birth_date if me else None,
        my_age_older=me.match_age_older if me else None,
        my_age_younger=me.match_age_younger if me else None,
    )
    if not candidates:
        return None
    for c in candidates:
        result = await db.execute(
            select(func.count(SimulationJob.id))
            .join(Match, Match.id == SimulationJob.match_id)
            .where(
                Match.participant_ids.contains([uid, c.user_id]),
                SimulationJob.status == "completed",
            )
        )
        if result.scalar_one() == 0:
            return c.user_id
    return candidates[0].user_id


async def run_auto_simulation(
    db: AsyncSession,
    llm: LLMProvider,
    uid: str,
    target_user_id: str | None = None,
) -> dict | None:
    """매칭→시뮬레이션→리포트 한 사이클. 결과 요약 dict, 못 돌면 None."""
    if not await check_simulation_quota(uid, db):
        logger.info("auto-sim skip (daily quota): %s", uid)
        return None

    result = await db.execute(select(Persona).where(Persona.user_id == uid))
    my_persona = result.scalar_one_or_none()
    if my_persona is None or my_persona.embedding is None:
        return None

    target = target_user_id or await _pick_target(db, uid, my_persona)
    if target is None:
        logger.info("auto-sim skip (no candidates): %s", uid)
        return None

    result = await db.execute(select(Persona).where(Persona.user_id == target))
    their_persona = result.scalar_one_or_none()
    if their_persona is None:
        return None

    # 순환 임포트 방지를 위해 지연 임포트 (routers.matches → services.booking)
    from app.routers.matches import get_or_create_match
    from app.models.database import User

    match_obj = await get_or_create_match(db, uid, target)

    job = SimulationJob(match_id=match_obj.id, requested_by=uid, status="running")
    db.add(job)
    await db.commit()
    await db.refresh(job)

    users_result = await db.execute(select(User).where(User.id.in_([uid, target])))
    name_map = {u.id: u.display_name for u in users_result.scalars().all()}

    # 에이전트가 서로를 이름으로 부르도록 페르소나 dict에 이름을 실어 보낸다.
    # (일정은 시뮬에 주지 않는다 — 약속은 수락 후 직접 채팅에서.)
    my_pd = {**_persona_dict(my_persona, voice=True), "display_name": name_map.get(uid)}
    their_pd = {**_persona_dict(their_persona, voice=True), "display_name": name_map.get(target)}

    started = time.monotonic()
    turns: list[dict] = []
    try:
        async for turn in llm.run_simulation(my_pd, their_pd, 20):
            # 스타일 게이트 — 실측 말투에 없는 습관이 새면 결정적으로 제거
            stats = my_pd.get("voice_stats") if turn.get("speaker") == "me" else their_pd.get("voice_stats")
            turns.append(gate_turn(turn, stats))

        # 시차 송출: 각 턴에 visible_at을 박아 라이브 관전처럼 천천히 공개한다.
        if settings.reveal_enabled:
            from app.services.reveal import plan_reveal_schedule

            turns = plan_reveal_schedule(turns, datetime.now(timezone.utc), settings)

        job.status = "completed"
        job.turns = turns
        job.completed_at = func.now()
        match_obj.status = "simulated"
        await db.commit()

        await log_llm_call(
            db,
            endpoint="simulation/auto",
            provider=settings.llm_provider,
            request_body={"target": target, "total_turns": len(turns)},
            response_status=200,
            response_time_ms=int((time.monotonic() - started) * 1000),
            user_id=uid,
        )
    except Exception as exc:
        logger.exception("auto-sim failed (uid=%s job=%s): %s", uid, job.id, exc)
        job.status = "failed"
        await db.commit()
        return None

    # 리포트까지 생성해야 inbox 카드가 점수·75점 게이트 분류를 바로 갖는다.
    report_score = await _ensure_report(db, llm, match_obj, my_persona, their_persona, turns, uid)

    logger.info(
        "auto-sim done: %s ↔ %s, %d턴, 점수=%s",
        uid, target, len(turns), report_score,
    )
    return {
        "match_id": str(match_obj.id),
        "target_user_id": target,
        "total_turns": len(turns),
        "report_score": report_score,
    }


async def _ensure_report(
    db: AsyncSession,
    llm: LLMProvider,
    match_obj: Match,
    my_persona: Persona,
    their_persona: Persona,
    turns: list[dict],
    uid: str,
) -> int | None:
    """리포트가 없으면 생성 — routers/report.py 의 게이트 규칙과 동일."""
    result = await db.execute(
        select(Report).where(Report.match_id == match_obj.id)
    )
    cached = result.scalar_one_or_none()
    if cached is not None:
        return cached.score

    started = time.monotonic()
    try:
        # 정답지(response_preferences)는 리포트 평가 전용 — 시뮬 프롬프트엔 절대 넣지 않는다.
        report_data = await llm.generate_report(
            {**_persona_dict(my_persona, voice=False),
             "response_preferences": my_persona.response_preferences or []},
            {**_persona_dict(their_persona, voice=False),
             "response_preferences": their_persona.response_preferences or []},
            turns,
        )
    except Exception as exc:
        # 리포트 실패는 치명적이지 않다 — 카드가 점수 없이 뜨고,
        # 다음 GET /report 호출이 재시도한다.
        logger.exception("auto-sim report failed (match=%s): %s", match_obj.id, exc)
        return None

    db.add(
        Report(
            match_id=match_obj.id,
            score=report_data["score"],
            findings=report_data["findings"],
            warnings=report_data["warnings"],
            places=report_data["places"],
            starters=report_data["starters"],
            tip=report_data.get("tip"),
            ai_generated=True,
        )
    )
    # 게이트가 왕 — 75점 미만이면 수락 진행분도 무효 (scheduled는 불가침)
    if (
        report_data["score"] < settings.report_pass_score
        and match_obj.status == "simulated"
    ):
        match_obj.accepted_by = []
    await db.commit()

    await log_llm_call(
        db,
        endpoint="report/auto",
        provider=settings.llm_provider,
        request_body={"match_id": str(match_obj.id), "turns_count": len(turns)},
        response_status=200,
        response_time_ms=int((time.monotonic() - started) * 1000),
        user_id=uid,
    )
    return report_data["score"]


def _draw_times(now: datetime, count: int) -> list[datetime]:
    """지금부터 자정까지 남은 창에서 랜덤 시각 count개 (최소 5분 뒤)."""
    end_of_day = now.replace(hour=23, minute=59, second=0, microsecond=0)
    window = (end_of_day - now).total_seconds()
    if window <= 300 or count <= 0:
        return []
    return sorted(
        now + timedelta(seconds=random.uniform(300, window)) for _ in range(count)
    )


async def _count_jobs_today(db: AsyncSession, uid: str) -> int:
    today_start = datetime.now().astimezone().replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    result = await db.execute(
        select(func.count(SimulationJob.id))
        .where(SimulationJob.requested_by == uid)
        .where(SimulationJob.created_at >= today_start)
    )
    return result.scalar_one()


async def _tick(get_llm) -> None:
    now = datetime.now()
    async with async_session_factory() as db:
        result = await db.execute(
            select(Persona.user_id).where(Persona.embedding.isnot(None))
        )
        uids = [row[0] for row in result.all()]

        for uid in uids:
            if _scheduled_date.get(uid) != now.date():
                remaining = max(
                    0, settings.auto_sim_per_day - await _count_jobs_today(db, uid)
                )
                _pending[uid] = _draw_times(now, remaining)
                _scheduled_date[uid] = now.date()
                if _pending[uid]:
                    logger.info(
                        "auto-sim schedule %s: %s", uid,
                        [t.strftime("%H:%M") for t in _pending[uid]],
                    )

            due = [t for t in _pending.get(uid, []) if t <= now]
            if not due:
                continue
            # 한 틱에 유저당 1회만 — 밀린 건 다음 틱에 (쿼터 완충)
            _pending[uid] = [t for t in _pending[uid] if t > now]
            _pending[uid].extend(due[1:])
            await run_auto_simulation(db, get_llm(), uid)


async def auto_sim_scheduler() -> None:
    """앱 lifespan에서 띄우는 백그라운드 루프 — 60초 틱."""
    from app.dependencies import get_llm_provider

    logger.info(
        "auto-sim scheduler 시작 (per_day=%d, provider=%s)",
        settings.auto_sim_per_day, settings.llm_provider,
    )
    await asyncio.sleep(10)  # 기동 직후 안정화
    while True:
        try:
            await _tick(get_llm_provider)
        except Exception:
            logger.exception("auto-sim tick 실패 — 다음 틱에 재시도")
        await asyncio.sleep(60)
