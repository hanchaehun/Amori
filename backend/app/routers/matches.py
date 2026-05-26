import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.dependencies import get_db
from app.auth.firebase import get_current_user
from app.models.database import Persona, User
from app.schemas.common import MatchResponse

router = APIRouter()


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

    user_embedding = my_persona.embedding

    # Query pgvector for top_k most similar personas (exclude self)
    candidates = await db.execute(
        select(Persona)
        .where(Persona.user_id != user["uid"])
        .where(Persona.embedding.isnot(None))
        .order_by(Persona.embedding.cosine_distance(user_embedding))
        .limit(top_k)
    )
    candidate_personas = candidates.scalars().all()

    # Build match responses
    matches: list[MatchResponse] = []
    for candidate in candidate_personas:
        # Calculate score: (1 - cosine_distance) * 100
        # Fetch cosine distance via Python; pgvector returns ordered results
        # We re-compute the distance for the score value
        distance_result = await db.execute(
            select(
                Persona.embedding.cosine_distance(user_embedding).label("distance")
            ).where(Persona.id == candidate.id)
        )
        distance = distance_result.scalar_one()
        score = round((1 - distance) * 100, 2)

        # Build match_id from sorted UIDs for deterministic ID
        sorted_uids = sorted([user["uid"], candidate.user_id])
        match_id = f"{sorted_uids[0]}_{sorted_uids[1]}"

        # Fetch display_name from users table
        user_result = await db.execute(
            select(User.display_name).where(User.id == candidate.user_id)
        )
        display_name = user_result.scalar_one_or_none()

        matches.append(
            MatchResponse(
                match_id=match_id,
                user_id=candidate.user_id,
                display_name=display_name,
                score=score,
            )
        )

    return matches
