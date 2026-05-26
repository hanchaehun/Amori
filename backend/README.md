# AMORI Backend (BFF)

Flutter 앱과 LLM 모듈 사이의 중간 레이어입니다.

## 기술 스택

- **Framework**: FastAPI (Python 3.11+)
- **Database**: PostgreSQL 16 + pgvector (1024차원 벡터 검색)
- **ORM**: SQLAlchemy 2.0 (async) + asyncpg
- **Auth**: Firebase Admin SDK (ID 토큰 검증)
- **Migration**: Alembic
- **Streaming**: SSE (sse-starlette)

## 빠른 시작

```bash
cd backend

# 1. 환경변수 설정
cp .env.example .env

# 2. Docker로 DB + API 실행
docker-compose up -d

# 또는 로컬 개발 (DB만 Docker)
docker-compose up -d db
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

API 문서: http://localhost:8000/docs

## 엔드포인트

| 메서드 | 경로 | 설명 | 인증 |
|--------|------|------|------|
| `GET` | `/health` | 헬스체크 | - |
| `POST` | `/persona/build` | 24문항 답변 → 페르소나 생성 | O |
| `GET` | `/persona/me` | 내 페르소나 조회 | O |
| `GET` | `/matches/find?top_k=10` | 벡터 유사도 매칭 | O |
| `POST` | `/simulation/run` | 시뮬레이션 실행 (SSE) | O |
| `GET` | `/simulation/{job_id}` | 시뮬레이션 상태 조회 | O |
| `GET` | `/report/{match_id}` | 케미 리포트 (캐싱) | O |
| `POST` | `/meet/request` | 만남 신청 (24시간 만료) | O |
| `GET` | `/meet/request/{id}` | 만남 신청 조회 | O |
| `POST` | `/meet/request/{id}/respond` | 만남 수락/거절 | O |

## LLM Provider

환경변수 `LLM_PROVIDER`로 전환합니다. 코드 변경 불필요.

| 값 | 동작 | 사용 시점 |
|----|------|----------|
| `mock` (기본) | 하드코딩된 한국어 응답 | 개발/테스트 |
| `hf` | HuggingFace Inference Endpoint | 폴백 |
| `midm_local` | 셀프호스팅 LLM | 대회 GPU 운영 |

## 데이터베이스

8개 테이블: `users`, `personas`, `matches`, `simulation_jobs`, `reports`, `meet_requests`, `feedback`, `llm_call_logs`

페르소나 임베딩은 1024차원 벡터로 저장되며, HNSW 인덱스를 사용한 코사인 유사도 검색을 지원합니다.

## 디렉토리 구조

```
backend/
├── app/
│   ├── main.py          # FastAPI 앱 진입점
│   ├── config.py         # 환경변수 설정
│   ├── dependencies.py   # DI (DB, LLM)
│   ├── auth/             # Firebase Auth
│   ├── db/               # 세션, 초기화
│   ├── llm/              # Provider 추상화 (mock/hf/midm)
│   ├── middleware/        # 에러 핸들러, Rate Limit
│   ├── models/            # SQLAlchemy 모델
│   ├── routers/           # API 라우터
│   ├── schemas/           # Pydantic 스키마
│   └── services/          # 비즈니스 로직
├── alembic/              # DB 마이그레이션
├── tests/
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
└── .env.example
```

## 에러 응답

```json
{ "error_code": "QUOTA_EXCEEDED", "message": "일일 시뮬레이션 횟수를 초과했습니다.", "request_id": "..." }
```

| HTTP | error_code | 설명 |
|------|-----------|------|
| 400 | `INVALID_INPUT` | 잘못된 입력 |
| 401 | `UNAUTHORIZED` | 인증 필요 |
| 429 | `QUOTA_EXCEEDED` | 일일 한도 초과 |
| 451 | `RAI_BLOCKED` | RAI 필터 차단 |
| 502 | `SCHEMA_VIOLATION` | LLM 응답 스키마 위반 |
| 503 | `LLM_UNAVAILABLE` | LLM 서버 다운 |
| 504 | `LLM_TIMEOUT` | LLM 응답 시간 초과 |
