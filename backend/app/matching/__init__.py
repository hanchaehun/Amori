"""매칭 알고리즘 패키지 — 구 ``matching/`` 모듈을 백엔드 내 패키지로 흡수.

별도 서비스가 아닌 같은 프로세스의 라이브러리로 동작한다 (배포 단위 최소화).
베이스라인은 pgvector top-K 코사인 유사도이며, 카테고리별 가중치·피드백
피드백 기반 품질 개선 로직은 이 패키지 안에서 고도화한다.

담당: 명세현
"""

from app.matching.ranker import RankedCandidate, find_candidates

__all__ = ["RankedCandidate", "find_candidates"]
