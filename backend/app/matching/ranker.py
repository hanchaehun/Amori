"""페르소나 벡터 기반 후보 랭킹.

베이스라인: pgvector 코사인 거리 top-K. 진화 방향(매칭 모듈 로드맵):
- 카테고리(가치관/유머/대화 패턴)별 가중 점수
- 만남 후 피드백(Feedback 테이블)을 반영하는 품질 개선 신호
"""

from dataclasses import dataclass

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.database import Persona, User


@dataclass
class RankedCandidate:
    user_id: str
    display_name: str | None
    score: float  # 0~100 기반, (1 - cosine_distance) * 100 + 지역 가점


# 지역 하드필터 — 같은 시/도끼리만 매칭. 예외로 수도권(서울·경기·인천)은
# 상호 매칭 허용. 지역이 비어 있는 쪽(구버전 행·미설정)은 와일드카드로 통과한다.
# 허용 집합 안에서는 정확히 같은 지역이 가점을 받아 먼저 온다(수도권 예외 대비).
CAPITAL_AREA = frozenset({"서울", "경기", "인천"})
SAME_REGION_BONUS = 5.0


def _allowed_regions(my_region: str) -> frozenset[str]:
    """내 지역과 매칭 가능한 지역 집합."""
    return CAPITAL_AREA if my_region in CAPITAL_AREA else frozenset({my_region})


async def find_candidates(
    db: AsyncSession,
    query_embedding,
    exclude_user_id: str,
    top_k: int = 10,
    my_gender: str | None = None,
    my_interest_gender: str | None = None,
    my_region: str | None = None,
) -> list[RankedCandidate]:
    """쿼리 임베딩과 가장 유사한 후보 top_k 를 점수와 함께 반환한다.

    관심 성별 상호 필터 (제품 규칙, 2026-06-13): 후보의 성별이 내 관심 성별이고,
    후보의 관심 성별에 내가 들어가는 — *서로* 맞는 쌍만 매칭된다.
    값은 가입 화면 기준 gender ∈ {female, male, other},
    interest_gender ∈ {female, male, both} — 'both'는 모든 성별 허용.
    프로필이 비어 있는 쪽(개발 계정·구버전 행)은 와일드카드로 통과 —
    실가입 유저는 성별/관심 성별이 필수라 실서비스에선 전원 적용된다.

    지역 필터 (제품 규칙, 2026-07-14): 같은 시/도끼리만 매칭하되
    수도권(서울·경기·인천)은 상호 허용. 지역 미설정은 와일드카드 통과.
    """
    distance = Persona.embedding.cosine_distance(query_embedding).label("distance")
    query = (
        select(Persona.user_id, User.display_name, User.region, distance)
        .join(User, User.id == Persona.user_id, isouter=True)
        .where(Persona.user_id != exclude_user_id)
        .where(Persona.embedding.isnot(None))
    )
    if my_interest_gender and my_interest_gender != "both":
        query = query.where(
            or_(User.gender.is_(None), User.gender == my_interest_gender)
        )
    if my_gender:
        query = query.where(
            or_(
                User.interest_gender.is_(None),
                User.interest_gender == "both",
                User.interest_gender == my_gender,
            )
        )
    if my_region:
        query = query.where(
            or_(
                User.region.is_(None),
                User.region.in_(_allowed_regions(my_region)),
            )
        )
    # 지역 가점이 top_k 경계를 바꿀 수 있으므로 여유 있게 뽑아 재정렬한다.
    fetch_k = top_k * 3 if my_region else top_k
    result = await db.execute(query.order_by(distance).limit(fetch_k))
    candidates = [
        RankedCandidate(
            user_id=row.user_id,
            display_name=row.display_name,
            score=round(
                (1 - row.distance) * 100
                + (SAME_REGION_BONUS if my_region and row.region == my_region else 0),
                2,
            ),
        )
        for row in result.all()
    ]
    candidates.sort(key=lambda c: c.score, reverse=True)
    return candidates[:top_k]
