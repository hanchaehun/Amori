# AMORI Backend (BFF)

Flutter 앱의 유일한 백엔드입니다. LLM 호출(Gemini SDK 직접), 벡터 매칭, 도메인
데이터 저장을 모두 이 프로세스가 담당합니다 — 별도 LLM HTTP 서비스는 없습니다
(2026-06-10 리팩토링, `docs/AMORI_리팩토링_방향.docx`).

## 기술 스택

- **Framework**: FastAPI (Python 3.11+)
- **Database**: PostgreSQL 16 + pgvector (1024차원, HNSW 코사인 인덱스) — 도메인 데이터 단일 원천
- **ORM**: SQLAlchemy 2.0 (async) + asyncpg
- **Auth**: Firebase Admin SDK (ID 토큰 검증)
- **LLM**: google-genai SDK — 채팅(gemini-2.5-flash) + 임베딩(gemini-embedding-001)을 단일 키로
- **Migration**: Alembic
- **Streaming**: SSE (sse-starlette)

## 빠른 시작

```bash
cd backend

# 1. 환경변수 설정
cp .env.example .env        # LLM_PROVIDER=mock 이면 GEMINI_API_KEY 불필요

# 2. Docker로 DB + API 실행
docker-compose up -d

# 또는 로컬 개발 (DB만 Docker)
docker-compose up -d db
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

API 문서: http://localhost:8000/docs

## 엔드포인트

| 메서드 | 경로 | 설명 | 인증 |
|--------|------|------|------|
| `GET` | `/health` | 헬스체크 | - |
| `PUT` | `/users/me` | 프로필 저장 (Firestore 대체) | O |
| `GET` | `/users/me` | 내 프로필 조회 | O |
| `POST` | `/persona/build` | 24문항 답변 → 페르소나 + 임베딩 생성 | O |
| `GET` | `/persona/me` | 내 페르소나 조회 | O |
| `GET` | `/matches/find?top_k=10` | 벡터 유사도 매칭 (Match 행 find-or-create, UUID 반환) | O |
| `POST` | `/simulation/run` | 2-에이전트 시뮬레이션 (SSE 턴 스트림) | O |
| `GET` | `/simulation/{job_id}` | 시뮬레이션 상태 조회 | O |
| `GET` | `/report/{match_id}` | 케미 리포트 (서버 캐싱) | O |
| `POST` | `/meet/request` | 만남 신청 (24시간 만료) | O |
| `GET` | `/meet/request/{id}` | 만남 신청 조회 | O |
| `POST` | `/meet/request/{id}/respond` | 만남 수락/거절 | O |
| `POST` | `/feedback` | 만남 후 피드백 (매칭 학습 루프 입력) | O |

## LLM Provider

환경변수 `LLM_PROVIDER`로 전환합니다. 코드 변경 불필요.

| 값 | 동작 | 사용 시점 |
|----|------|----------|
| `mock` (기본) | 하드코딩된 한국어 응답 | 개발/테스트/오프라인 데모 |
| `gemini` | Gemini API 직접 호출 (structured output + 임베딩) | 실 서비스·발표 |

시뮬레이션은 **2-에이전트 턴 루프**(`app/services/simulation.py`)로 동작합니다:
에이전트 A·B가 각자 자기 페르소나만 담긴 별도 컨텍스트를 유지하고, 턴마다 한쪽씩
발화를 생성하며, 4턴마다 별도 분석 호출이 궁합 시그널(system 턴)을 추출합니다.
원샷 생성 대비 말투 섞임(style bleed)이 없고, 각 턴이 생성 즉시 SSE로 전송됩니다.

## 디렉토리 구조와 소유권

```
backend/
├── app/
│   ├── main.py            # FastAPI 앱 진입점
│   ├── config.py          # 환경변수 설정
│   ├── dependencies.py    # DI (DB, LLM)
│   ├── auth/              # Firebase ID 토큰 검증
│   ├── db/                # 세션, 초기화
│   ├── llm/               # LLMProvider 추상화 (mock | gemini)
│   │   └── prompts/       # 한국어 프롬프트 ─ 이현정 소유
│   ├── matching/          # 벡터 매칭 패키지 ─ 명세현 소유
│   ├── middleware/        # 에러 핸들러, 일일 쿼터
│   ├── models/            # SQLAlchemy 모델 (8 테이블)
│   ├── routers/           # API 라우터
│   ├── schemas/           # Pydantic 응답 스키마 (shared/schemas 계약)
│   └── services/          # 2-에이전트 시뮬 엔진, LLM 호출 로그
├── alembic/               # DB 마이그레이션 (0001_initial)
├── tests/
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
└── .env.example
```

## 데이터베이스

8개 테이블: `users`, `personas`, `matches`, `simulation_jobs`, `reports`,
`meet_requests`, `feedback`, `llm_call_logs`

- 페르소나 임베딩: `vector(1024)` + HNSW 코사인 인덱스
- 모든 LLM 호출은 `llm_call_logs` 에 기록 (비용 추적·감사)
- `matches.id` 는 UUID — `/matches/find` 가 행을 find-or-create 하므로
  클라이언트는 받은 `match_id` 를 report/meet/feedback 에 그대로 사용

## 에러 응답

```json
{ "error_code": "QUOTA_EXCEEDED", "message": "일일 시뮬레이션 횟수를 초과했습니다.", "request_id": "..." }
```

| HTTP | error_code | 설명 |
|------|-----------|------|
| 400 | `INVALID_INPUT` / `PERSONA_REQUIRED` | 잘못된 입력 / 페르소나 필요 |
| 401 | `UNAUTHORIZED` | 인증 필요 |
| 404 | `NOT_FOUND` | 리소스 없음 |
| 429 | `QUOTA_EXCEEDED` | 일일 한도 초과 |
| 451 | `RAI_BLOCKED` | RAI 필터 차단 |
| 500 | `INTERNAL_ERROR` | 내부 오류 |
| 503 | `LLM_UNAVAILABLE` | LLM API 연결 불가 |
| 504 | `LLM_TIMEOUT` | LLM 응답 시간 초과 |
