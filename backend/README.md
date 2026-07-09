# AMORI Backend (BFF)

Flutter 앱의 유일한 백엔드입니다. LLM 호출, 벡터 매칭, 도메인 데이터 저장을 모두
이 프로세스가 담당합니다 — 별도 LLM HTTP 서비스는 없습니다
(2026-06-10 리팩토링 — 방향은 `refatodo.md`, 당시 결정 문서는 git 이력 adf2921).

## 기술 스택

- **Framework**: FastAPI (Python 3.11+)
- **Database**: 팀 공용 관리형 Postgres + pgvector (1024차원, HNSW 코사인 인덱스) — 도메인 데이터 단일 원천
- **ORM**: SQLAlchemy 2.0 (async) + asyncpg
- **Auth**: Firebase Admin SDK (ID 토큰 검증)
- **LLM**: `LLM_PROVIDER` 스위치 — gemini(google-genai SDK) | modoo(DevDive 채팅 + Gemini 임베딩) | mock
- **Migration**: Alembic
- **Streaming**: SSE (sse-starlette)

## 빠른 시작

```bash
cd backend

# 1. 환경변수 설정 — DATABASE_URL은 팀 공용 DB URL (시크릿 채널에서 받기)
cp .env.example .env        # LLM_PROVIDER=mock 이면 GEMINI_API_KEY 불필요

# 2. 의존성 설치 (최초 1회, Docker 불필요 — 2026-07-04부로 제거)
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt

# 3. 실행
.venv/Scripts/python -m uvicorn app.main:app --reload --port 8000
```

## 데이터베이스 — 공용 관리형 Postgres

Docker/로컬 Postgres 대신 **팀이 하나의 관리형 Postgres를 공유**합니다.

**최초 셋업은 완료됐습니다 (2026-07-05, Neon):** DB 생성·pgvector 확장·스키마
마이그레이션(`alembic upgrade head`)·개발용 시드까지 적용된 상태입니다.
새로 합류하는 사람은 **팀 시크릿 채널에서 DATABASE_URL을 받아 `.env`에 넣기만
하면 됩니다** — DB를 만들거나 마이그레이션을 돌릴 필요가 없습니다.

**공용 DB 운영 규칙:**

- **마이그레이션은 스키마를 변경한 사람이 merge 후 1회만** `alembic upgrade head` 실행.
  나머지 팀원은 실행할 필요도, 해서도 안 됩니다(멱등이지만 동시 실행은 피할 것).
- 시드/삭제 스크립트(`seed_dev_inbox.py`, `seed_fake_users.py` 등)는 **공용 데이터를
  건드리므로 팀 공지 후 실행**. 개인 실험은 각자 DEV_UID를 다르게 쓰면 격리됩니다.
- Supabase 사용 시 pooler(6543) 말고 **직접 연결 포트(5432)** — asyncpg가 pooler와 충돌.

### 개발용 매칭 풀 시드 (100명)

실 가입자가 가입 직후 바로 매칭 상대를 만나도록, 이름에 `(개발용)`이 붙은
가짜 계정 100명을 실제 Gemini 임베딩(1024차원)과 함께 깔 수 있습니다.
`.env`의 `DATABASE_URL`·`GEMINI_API_KEY`만 있으면 1회 실행으로 끝납니다
(재실행 멱등 — 기존 시드는 건너뜀, `--force`로 재생성):

```bash
python -X utf8 scripts/seed_fake_users.py --count 100
```

실행 끝에 시드 1명 기준 top-5 매칭 쿼리(pgvector 코사인 + 성별 상호 필터)까지
자동 검증합니다.

API 문서: http://localhost:8000/docs

## 엔드포인트

| 메서드 | 경로 | 설명 | 인증 |
|--------|------|------|------|
| `GET` | `/health` | 헬스체크 | - |
| `PUT` | `/users/me` | 프로필 저장 (Firestore 대체) | O |
| `GET` | `/users/me` | 내 프로필 조회 | O |
| `POST` | `/persona/build` | 초기 대표 답변 → 페르소나 + 임베딩 생성 | O |
| `GET` | `/persona/daily` | 오늘의 1문항 상태 조회 | O |
| `POST` | `/persona/update` | 오늘의 1문항 → 기존 페르소나 보정 | O |
| `GET` | `/persona/me` | 내 페르소나 조회 | O |
| `GET` | `/matches/find?top_k=10` | 벡터 유사도 매칭 (Match 행 find-or-create, UUID 반환) | O |
| `GET` | `/matches` | 대화 카드 목록 — 수락 가능 여부(리포트 게이트)·실패 분류 포함 | O |
| `POST` | `/matches/{id}/accept` | 만남 수락 (조건: 리포트 75점+, 양쪽 수락 시 scheduled) | O |
| `POST` | `/matches/{id}/appointment` | 직접 채팅에서 합의한 약속 확정 (scheduled 전용) | O |
| `POST` | `/matches/{id}/cancel` | 약속·만남 취소 (시스템 안내 메시지 남김) | O |
| `POST` | `/simulation/run` | 에이전트 시뮬레이션 (SSE 턴 스트림) | O |
| `GET` | `/simulation/{job_id}` | 시뮬레이션 상태 조회 | O |
| `GET` | `/report/{match_id}` | 케미 리포트 (서버 캐싱) | O |
| `POST` | `/meet/request` | 만남 신청 (24시간 만료) | O |
| `GET` | `/meet/request/{id}` | 만남 신청 조회 | O |
| `POST` | `/meet/request/{id}/respond` | 만남 수락/거절 | O |
| `POST` | `/feedback` | 만남 후 피드백 (매칭 품질 개선 신호) | O |

## LLM Provider

환경변수 `LLM_PROVIDER`로 전환합니다. 코드 변경 불필요.

| 값 | 동작 | 사용 시점 |
|----|------|----------|
| `mock` (기본) | 하드코딩된 한국어 응답 | 개발/테스트/오프라인 데모 |
| `gemini` | Gemini API 직접 호출 (structured output + 임베딩) | 실 서비스·발표 |
| `modoo` | DevDive 채팅 + Gemini 임베딩 (프롬프트 JSON 유도 + Pydantic 검증) | 실 서비스 대안 |

시뮬레이션은 **원샷 생성**으로 동작합니다: 양쪽 페르소나를 한 번에 주고 대화 전체
(눈치 신호 partner_read·strategy 포함)를 1콜로 생성합니다. **시뮬은 약속을 잡지
않습니다**(2026-07-04 결정) — 만남은 두 사용자가 리포트를 보고 수락하면(수락 게이트 =
리포트 점수 75 이상) 직접 채팅이 열리고, 약속은 거기서 직접 잡습니다.

말투 섞임(style bleed)은 3중으로 방지합니다: ① 프롬프트의 "각자 말투 유지" 강제
② 페르소나별 실측 말투 카드(`voice_stats` — 코드가 측정, LLM 추측 금지) ③ **스타일
게이트**(`app/services/style_gate.py`) — 생성된 발화에서 실측에 없는 습관(이모지·부호·
웃음)을 결정적으로 제거하는 후처리. 사용자가 미리 적어둔 **정답지**("받고 싶은 반응",
`response_preferences`)는 리포트 채점에만 쓰고 시뮬 프롬프트엔 넣지 않습니다 —
넣으면 상대 에이전트가 정답지에 맞춰버려 정직한 시뮬이 무너집니다.

## 디렉토리 구조

```
backend/
├── app/
│   ├── main.py            # FastAPI 앱 진입점
│   ├── config.py          # 환경변수 설정
│   ├── dependencies.py    # DI (DB, LLM)
│   ├── auth/              # Firebase ID 토큰 검증
│   ├── db/                # 세션, 초기화
│   ├── llm/               # LLMProvider 추상화 (mock | gemini | modoo)
│   │   └── prompts/       # 한국어 프롬프트
│   ├── matching/          # 벡터 매칭 패키지
│   ├── middleware/        # 에러 핸들러, 일일 쿼터
│   ├── models/            # SQLAlchemy 모델 (8 테이블)
│   ├── routers/           # API 라우터
│   ├── schemas/           # Pydantic 응답 스키마 (shared/schemas 계약)
│   └── services/          # 자동 소개팅·시차 송출·예약·voice 배선·LLM 호출 로그
├── alembic/               # DB 마이그레이션
├── tests/
├── requirements.txt
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
