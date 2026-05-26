import uuid as uuid_mod

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase import get_current_user
from app.dependencies import get_db, get_llm_provider
from app.llm.base import LLMProvider
from app.models.database import Match, Persona, Report, SimulationJob
from app.schemas.report import ReportResponse

router = APIRouter()


@router.get("/{match_id}", response_model=ReportResponse)
async def get_report(
    match_id: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm: LLMProvider = Depends(get_llm_provider),
):
    request_id = str(uuid_mod.uuid4())

    # Parse match_id as UUID
    try:
        match_uuid = uuid_mod.UUID(match_id)
    except ValueError:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "매칭 정보를 찾을 수 없습니다.",
                "request_id": request_id,
            },
        )

    # 1. Verify match exists and user is a participant
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

    # 2. Check for cached report
    result = await db.execute(
        select(Report).where(Report.match_id == match_uuid)
    )
    cached_report = result.scalar_one_or_none()

    if cached_report:
        return ReportResponse(
            match_id=str(cached_report.match_id),
            score=cached_report.score,
            findings=cached_report.findings,
            warnings=cached_report.warnings,
            places=cached_report.places,
            starters=cached_report.starters,
            tip=cached_report.tip,
            ai_generated=True,
        )

    # 3. Get both personas
    participant_ids = match_obj.participant_ids
    other_uid = participant_ids[0] if participant_ids[1] == user["uid"] else participant_ids[1]

    result = await db.execute(
        select(Persona).where(Persona.user_id == user["uid"])
    )
    my_persona = result.scalar_one_or_none()

    result = await db.execute(
        select(Persona).where(Persona.user_id == other_uid)
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

    # 4. Get the latest completed simulation log for this match
    result = await db.execute(
        select(SimulationJob)
        .where(SimulationJob.match_id == match_uuid)
        .where(SimulationJob.status == "completed")
        .order_by(desc(SimulationJob.completed_at))
        .limit(1)
    )
    sim_job = result.scalar_one_or_none()

    if not sim_job or not sim_job.turns:
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "완료된 시뮬레이션이 없습니다. 먼저 시뮬레이션을 실행해 주세요.",
                "request_id": request_id,
            },
        )

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

    # 6. Call LLM to generate report
    report_data = await llm.generate_report(
        my_persona_dict, their_persona_dict, sim_job.turns,
    )

    # 7. Cache the report in DB
    report = Report(
        match_id=match_uuid,
        score=report_data["score"],
        findings=report_data["findings"],
        warnings=report_data["warnings"],
        places=report_data["places"],
        starters=report_data["starters"],
        tip=report_data.get("tip"),
        ai_generated=True,
    )
    db.add(report)
    await db.commit()

    # 8. Return response
    return ReportResponse(
        match_id=match_id,
        score=report_data["score"],
        findings=report_data["findings"],
        warnings=report_data["warnings"],
        places=report_data["places"],
        starters=report_data["starters"],
        tip=report_data.get("tip"),
        ai_generated=True,
    )
