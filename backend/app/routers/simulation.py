import json
import logging
import time
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sse_starlette.sse import EventSourceResponse

from app.auth.firebase import get_current_user
from app.config import settings
from app.dependencies import get_db, get_llm_provider
from app.llm.base import LLMProvider
from app.middleware.rate_limit import check_simulation_quota
from app.models.database import Match, Persona, SimulationJob, User
from app.routers.matches import get_or_create_match
from app.schemas.simulation import SimulationRunRequest, SimulationJobResponse
from app.services.llm_log import log_llm_call
from app.services.style_gate import gate_turn

router = APIRouter()
logger = logging.getLogger(__name__)


async def simulation_event_generator(
    llm: LLMProvider,
    my_persona_dict: dict,
    their_persona_dict: dict,
    max_turns: int,
    job: SimulationJob,
    db: AsyncSession,
    match: Match,
):
    """Yield SSE events for each simulation turn, then finalize the job."""
    turns: list[dict] = []
    started = time.monotonic()
    try:
        async for turn in llm.run_simulation(
            my_persona_dict, their_persona_dict, max_turns,
        ):
            # 스타일 게이트 — 실측 말투(voice_stats)에 없는 습관(이모지·부호·웃음)이
            # 발화에 새면 결정적으로 제거한다 (원샷 style bleed 후처리 방어).
            stats = (
                my_persona_dict.get("voice_stats")
                if turn.get("speaker") == "me"
                else their_persona_dict.get("voice_stats")
            )
            turn = gate_turn(turn, stats)
            # DB엔 눈치(partner_read·strategy) 포함 전체를 저장하고,
            # 사용자에게 가는 SSE는 대화에 필요한 필드만 보낸다 (분석은 비노출).
            turns.append(turn)
            public_turn = {
                "turn_index": turn["turn_index"],
                "speaker": turn["speaker"],
                "text": turn["text"],
            }
            yield {"event": "turn", "data": json.dumps(public_turn, ensure_ascii=False)}

        # Save completed job — 시뮬은 약속을 잡지 않는다(만남은 수락 후 직접 채팅에서).
        # 수락 가능 여부는 리포트 점수 게이트가 정한다 (routers/matches.py accept).
        job.status = "completed"
        job.turns = turns
        job.completed_at = func.now()
        match.status = "simulated"
        await db.commit()

        await log_llm_call(
            db,
            endpoint="simulation/run",
            provider=settings.llm_provider,
            request_body={"max_turns": max_turns, "total_turns": len(turns)},
            response_status=200,
            response_time_ms=int((time.monotonic() - started) * 1000),
            user_id=job.requested_by,
        )

        yield {
            "event": "done",
            "data": json.dumps(
                {"status": "completed", "total_turns": len(turns)},
                ensure_ascii=False,
            ),
        }
    except Exception as exc:
        # SSE로만 흘리면 서버 쪽엔 흔적이 없다 — 원인 추적용으로 반드시 남긴다.
        logger.exception("simulation failed (job=%s): %s", job.id, exc)
        job.status = "failed"
        await db.commit()
        yield {
            "event": "error",
            "data": json.dumps(
                {"status": "failed", "message": str(exc)},
                ensure_ascii=False,
            ),
        }


@router.post("/run")
async def run_simulation(
    body: SimulationRunRequest,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm: LLMProvider = Depends(get_llm_provider),
):
    request_id = str(uuid.uuid4())

    # 1. Check simulation quota
    if not await check_simulation_quota(user["uid"], db):
        raise HTTPException(
            status_code=429,
            detail={
                "error_code": "QUOTA_EXCEEDED",
                "message": "일일 시뮬레이션 횟수를 초과했습니다.",
                "request_id": request_id,
            },
        )

    # 2. Get both users' personas
    result = await db.execute(
        select(Persona).where(Persona.user_id == user["uid"])
    )
    my_persona = result.scalar_one_or_none()

    result = await db.execute(
        select(Persona).where(Persona.user_id == body.target_user_id)
    )
    their_persona = result.scalar_one_or_none()

    if not my_persona or not their_persona:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "두 사용자 모두 페르소나가 필요합니다.",
                "request_id": request_id,
            },
        )

    # 3. Find existing match by participant_ids, or create a new one
    match_obj = await get_or_create_match(db, user["uid"], body.target_user_id)

    # 4. Create SimulationJob
    job = SimulationJob(
        match_id=match_obj.id,
        requested_by=user["uid"],
        status="running",
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)

    # 5. Build persona dicts for the LLM
    #    speech_style·sample_messages를 포함해야 에이전트가 '그 사람 말투'로 발화한다.
    #    voice_stats(실측 말투 통계)가 있으면 _speech_block이 수치 지시로 승격한다.
    my_persona_dict = {
        "traits": my_persona.traits,
        "communication_style": my_persona.communication_style,
        "humor_style": my_persona.humor_style,
        "value_keywords": my_persona.value_keywords,
        "speech_style": my_persona.speech_style,
        "sample_messages": my_persona.sample_messages,
        "voice_stats": my_persona.voice_stats,
    }
    their_persona_dict = {
        "traits": their_persona.traits,
        "communication_style": their_persona.communication_style,
        "humor_style": their_persona.humor_style,
        "value_keywords": their_persona.value_keywords,
        "speech_style": their_persona.speech_style,
        "sample_messages": their_persona.sample_messages,
        "voice_stats": their_persona.voice_stats,
    }

    # 6. 에이전트가 서로를 이름으로 부르도록 페르소나 dict에 이름을 싣는다.
    #    (일정은 더 이상 시뮬에 주지 않는다 — 약속은 수락 후 직접 채팅에서.)
    users_result = await db.execute(
        select(User).where(User.id.in_([user["uid"], body.target_user_id]))
    )
    name_map = {u.id: u.display_name for u in users_result.scalars().all()}
    my_persona_dict["display_name"] = name_map.get(user["uid"])
    their_persona_dict["display_name"] = name_map.get(body.target_user_id)

    # 7. Return SSE stream
    return EventSourceResponse(
        simulation_event_generator(
            llm, my_persona_dict, their_persona_dict,
            body.max_turns, job, db, match_obj,
        ),
        media_type="text/event-stream",
    )


@router.post("/auto-run")
async def trigger_auto_simulation(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm: LLMProvider = Depends(get_llm_provider),
):
    """[DEBUG 전용] 자동 소개팅 1회를 지금 즉시 실행 — 데모/개발용.

    실서비스 동작은 services/auto_sim.py 스케줄러(하루 랜덤 N회)가 담당하고,
    이 엔드포인트는 랜덤 시각을 기다릴 수 없는 시연 상황을 위한 수동 방아쇠다.
    """
    request_id = str(uuid.uuid4())
    if not settings.debug:
        raise HTTPException(status_code=404, detail={
            "error_code": "NOT_FOUND",
            "message": "Not found.",
            "request_id": request_id,
        })

    from app.services.auto_sim import run_auto_simulation

    summary = await run_auto_simulation(db, llm, user["uid"])
    if summary is None:
        raise HTTPException(status_code=429, detail={
            "error_code": "QUOTA_EXCEEDED",
            "message": "오늘 에이전트 소개팅 횟수를 다 썼거나 후보가 없습니다.",
            "request_id": request_id,
        })
    return summary


@router.get("/{job_id}", response_model=SimulationJobResponse)
async def get_simulation_job(
    job_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    request_id = str(uuid.uuid4())

    result = await db.execute(
        select(SimulationJob).where(SimulationJob.id == job_id)
    )
    job = result.scalar_one_or_none()

    if not job:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "시뮬레이션 작업을 찾을 수 없습니다.",
                "request_id": request_id,
            },
        )

    # Verify the requesting user owns this job
    if job.requested_by != user["uid"]:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "시뮬레이션 작업을 찾을 수 없습니다.",
                "request_id": request_id,
            },
        )

    return SimulationJobResponse(
        job_id=str(job.id),
        match_id=str(job.match_id),
        status=job.status,
    )
