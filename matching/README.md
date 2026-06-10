# AMORI Matching Module — `backend/app/matching/` 으로 흡수됨 (2026-06-10)

매칭 알고리즘은 별도 서비스가 아닌 **백엔드 내 패키지**
[`backend/app/matching/`](../backend/app/matching/) 으로 이동했습니다. **명세현 담당.**

근거: `docs/AMORI_리팩토링_방향.docx` — 본 README가 허용하던 "라이브러리 import"
통합 방식 채택. 4인 팀·짧은 일정에서 배포 단위는 적을수록 좋고, `/matches/find`
베이스라인(top-K 코사인)이 이미 백엔드에 있어 같은 프로세스 교체가 자연스러움.

## 현재 상태

- `backend/app/matching/ranker.py` — pgvector 코사인 거리 top-K 베이스라인 (단일 쿼리, User 조인 포함)
- `/matches/find` 라우터가 이 패키지를 호출하고, Match 행을 find-or-create해 실제 UUID를 반환

## 진화 로드맵 (이 패키지 안에서)

1. **카테고리별 가중치** — 가치관/유머/대화 패턴 등 trait 카테고리별 부분 점수 (match_list 필터의 실데이터화)
2. **시뮬레이션 오케스트레이션** — 어떤 쌍을 언제 시뮬레이션할지 결정 (사용자당 매일 N건)
3. **피드백 학습 루프** — `feedback` 테이블(만남 후 피드백)을 매칭 점수에 반영 (제안서 차별점)

## 작업 규칙

- 브랜치 prefix: `match/*`
- 작업 디렉토리: `backend/app/matching/` 만 수정합니다.
- 매칭 점수 산식 변경 시 손지민(백엔드) 리뷰 필수.
