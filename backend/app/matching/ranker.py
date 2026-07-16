"""페르소나 벡터 기반 후보 랭킹.

베이스라인: pgvector 코사인 거리 top-K. 진화 방향(매칭 모듈 로드맵):
- 카테고리(가치관/유머/대화 패턴)별 가중 점수
- 만남 후 피드백(Feedback 테이블)을 반영하는 품질 개선 신호
"""

from dataclasses import dataclass
from datetime import date

from sqlalchemy import and_, func, or_, select
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

# 나이 하드필터 — 만 나이 차이가 서로의 허용 범위(위로 match_age_older, 아래로
# match_age_younger, NULL=기본 5) 안에 드는 쌍만 매칭. 생년월일이 비어 있는 쪽은
# 와일드카드로 통과한다(구버전 행 호환 — 실가입 유저는 생년월일이 필수라 실서비스에선
# 전원 적용된다). 미성년(만 19세 미만)은 설정과 무관하게 항상 제외.
DEFAULT_AGE_GAP = 5
ADULT_AGE = 19


def _allowed_regions(my_region: str) -> frozenset[str]:
    """내 지역과 매칭 가능한 지역 집합."""
    return CAPITAL_AREA if my_region in CAPITAL_AREA else frozenset({my_region})


def age_years(birth: date, today: date | None = None) -> int:
    """만 나이."""
    today = today or date.today()
    years = today.year - birth.year
    if (today.month, today.day) < (birth.month, birth.day):
        years -= 1
    return years


async def find_candidates(
    db: AsyncSession,
    query_embedding,
    exclude_user_id: str,
    top_k: int = 10,
    my_gender: str | None = None,
    my_interest_gender: str | None = None,
    my_region: str | None = None,
    my_birth_date: date | None = None,
    my_age_older: int | None = None,
    my_age_younger: int | None = None,
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

    나이 필터 (제품 규칙, 2026-07-16): 나이 차이가 내 허용 범위(위로/아래로)와
    상대 허용 범위 *둘 다* 안에 드는 쌍만 매칭 (성별 필터와 같은 상호 원칙).
    허용 범위 미설정은 기본 5살, 생년월일 미설정은 와일드카드 통과.
    미성년(만 19세 미만) 후보는 설정과 무관하게 제외한다.
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
    if my_birth_date:
        my_age = age_years(my_birth_date)
        # 미성년 유저는 후보 자체를 주지 않는다 — 가입 검증(users PUT 422)을
        # 뚫고 들어온 구버전 행 방어선.
        if my_age < ADULT_AGE:
            return []
        older = my_age_older if my_age_older is not None else DEFAULT_AGE_GAP
        younger = my_age_younger if my_age_younger is not None else DEFAULT_AGE_GAP
        # 후보 만 나이 — Postgres age()는 생일 경과 여부까지 반영한 정확한 만 나이.
        candidate_age = func.date_part("year", func.age(User.birth_date))
        query = query.where(
            or_(
                User.birth_date.is_(None),
                and_(
                    # 내 허용 범위 — 아래쪽은 성인 하한(만 19세)에서 잘린다.
                    candidate_age <= my_age + older,
                    candidate_age >= max(my_age - younger, ADULT_AGE),
                    # 상대 허용 범위 (상호 원칙): 상대 기준 위로/아래로 나를 허용해야 한다.
                    my_age - candidate_age
                    <= func.coalesce(User.match_age_older, DEFAULT_AGE_GAP),
                    candidate_age - my_age
                    <= func.coalesce(User.match_age_younger, DEFAULT_AGE_GAP),
                ),
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
