"""페르소나 벡터 기반 후보 랭킹.

베이스라인: pgvector 코사인 거리 top-K. 진화 방향(매칭 모듈 로드맵):
- 카테고리(가치관/유머/대화 패턴)별 가중 점수
- 만남 후 피드백(Feedback 테이블)을 반영하는 학습 루프
"""

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.database import Persona, User


@dataclass
class RankedCandidate:
    user_id: str
    display_name: str | None
    score: float  # 0~100, (1 - cosine_distance) * 100


async def find_candidates(
    db: AsyncSession,
    query_embedding,
    exclude_user_id: str,
    top_k: int = 10,
) -> list[RankedCandidate]:
    """쿼리 임베딩과 가장 유사한 후보 top_k 를 점수와 함께 반환한다."""
    distance = Persona.embedding.cosine_distance(query_embedding).label("distance")
    result = await db.execute(
        select(Persona.user_id, User.display_name, distance)
        .join(User, User.id == Persona.user_id, isouter=True)
        .where(Persona.user_id != exclude_user_id)
        .where(Persona.embedding.isnot(None))
        .order_by(distance)
        .limit(top_k)
    )
    return [
        RankedCandidate(
            user_id=row.user_id,
            display_name=row.display_name,
            score=round((1 - row.distance) * 100, 2),
        )
        for row in result.all()
    ]
