import json
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sse_starlette.sse import EventSourceResponse

from app.auth.firebase import get_current_user
from app.dependencies import get_db, get_llm_provider
from app.llm.base import LLMProvider
from app.middleware.rate_limit import check_simulation_quota
from app.models.database import Match, Persona, SimulationJob
from app.schemas.simulation import SimulationRunRequest, SimulationJobResponse

router = APIRouter()


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
    try:
        async for turn in llm.run_simulation(my_persona_dict, their_persona_dict, max_turns):
            turns.append(turn)
            yield {"event": "turn", "data": json.dumps(turn, ensure_ascii=False)}

        # Save completed job
        job.status = "completed"
        job.turns = turns
        job.completed_at = func.now()
        match.status = "simulated"
        await db.commit()

        yield {
            "event": "done",
            "data": json.dumps(
                {"status": "completed", "total_turns": len(turns)},
                ensure_ascii=False,
            ),
        }
    except Exception as exc:
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
    sorted_uids = sorted([user["uid"], body.target_user_id])
    result = await db.execute(
        select(Match).where(Match.participant_ids == sorted_uids)
    )
    match_obj = result.scalar_one_or_none()
    if not match_obj:
        match_obj = Match(
            participant_ids=sorted_uids,
            status="candidate",
        )
        db.add(match_obj)
        await db.flush()

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
    my_persona_dict = {
        "traits": my_persona.traits,
        "communication_style": my_persona.communication_style,
        "humor_style": my_persona.humor_style,
        "value_keywords": my_persona.value_keywords,
    }
    their_persona_dict = {
        "traits": their_persona.traits,
        "communication_style": their_persona.communication_style,
        "humor_style": their_persona.humor_style,
        "value_keywords": their_persona.value_keywords,
    }

    # 6. Return SSE stream
    return EventSourceResponse(
        simulation_event_generator(
            llm, my_persona_dict, their_persona_dict,
            body.max_turns, job, db, match_obj,
        ),
        media_type="text/event-stream",
    )


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
