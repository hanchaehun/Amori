# 백엔드 ↔ LLM 연동 가이드

> **대상**: 이현정 (LLM 모듈 담당)
> **작성일**: 2026-05-26
> **작성자**: 손지민 (백엔드 담당)

---

## 1. 백엔드 현재 진행 상황

### 완료된 것

| 항목 | 상태 | 비고 |
|------|------|------|
| FastAPI 서버 구조 | ✅ 완료 | Python 3.11 + FastAPI |
| PostgreSQL + pgvector | ✅ 완료 | Docker로 로컬 실행, 1024차원 HNSW 인덱스 |
| Firebase Auth 검증 | ✅ 완료 | Flutter가 보내는 ID 토큰 검증 |
| 6개 API 엔드포인트 | ✅ 완료 | persona/matches/simulation/report/meet/health |
| LLMProvider 추상화 | ✅ 완료 | mock / hf / midm_local 환경변수로 전환 |
| Mock provider | ✅ 완료 | 한국어 하드코딩 데이터로 전 기능 동작 |
| HF provider | ✅ 완료 | HuggingFace Inference Endpoint 호출 구현 |
| MiDM Local provider | ✅ 완료 | 셀프호스팅 LLM 서버 호출 구현 |
| SSE 시뮬레이션 스트리밍 | ✅ 완료 | LLM → 백엔드 → Flutter 이중 SSE |
| 에러 응답 규약 | ✅ 완료 | `shared/schemas/README.md` 규약 준수 |
| Rate limiting | ✅ 완료 | 일일 시뮬레이션 5회, 만남 신청 1회 |
| LLM 호출 감사 로그 | ✅ 완료 | `llm_call_logs` 테이블 |
| DB 테이블 8개 | ✅ 완료 | users, personas, matches, simulation_jobs, reports, meet_requests, feedback, llm_call_logs |

### 아직 안 된 것

| 항목 | 상태 | 비고 |
|------|------|------|
| 실제 LLM 연동 테스트 | ❌ 미진행 | LLM 서버가 올라와야 가능 |
| 통합 테스트 코드 | ❌ 미진행 | mock 기반 pytest 작성 예정 |
| 배포 (CI/CD) | ❌ 미진행 | 발표 후 진행 |

---

## 2. 백엔드가 호출하는 LLM 엔드포인트 4개

백엔드는 아래 4개 엔드포인트를 HTTP로 호출합니다.
**이현정 님이 이 4개를 구현해 주시면 연동이 완료됩니다.**

LLM 서버의 base URL은 환경변수 `LLM_BASE_URL`로 설정합니다 (기본값: `http://localhost:8001`).

---

### 2-1. `POST /llm/persona`

24문항 답변을 받아 페르소나 카드 + 임베딩 벡터를 반환합니다.

**요청 (백엔드가 보내는 것)**
```json
{
  "user_id": "firebase-uid-abc123",
  "answers": [
    {"question_id": 1, "answer": "..."},
    {"question_id": 2, "answer": "..."}
  ]
}
```

**응답 (LLM이 반환해야 하는 것)** — `persona.schema.json` 준수
```json
{
  "user_id": "firebase-uid-abc123",
  "traits": [
    {"category": "연락 템포", "summary": "답장은 천천히, 하지만 진심을 담아요", "keywords": ["느긋", "진심", "깊은 대화"]},
    {"category": "유머", "summary": "잔잔한 드라이 유머를 좋아해요", "keywords": ["드라이", "잔잔", "센스"]},
    {"category": "갈등", "summary": "대화로 풀되, 시간이 좀 필요해요", "keywords": ["대화", "냉각기", "이해"]},
    {"category": "데이트", "summary": "소소한 일상 데이트를 선호해요", "keywords": ["산책", "카페", "일상"]},
    {"category": "돈·시간", "summary": "각자 편하게, 가끔은 서프라이즈", "keywords": ["더치페이", "서프라이즈", "균형"]},
    {"category": "관계 속도", "summary": "천천히 알아가는 걸 좋아해요", "keywords": ["천천히", "자연스럽게", "신중"]},
    {"category": "경계선", "summary": "개인 시간은 꼭 필요해요", "keywords": ["독립", "존중", "개인시간"]},
    {"category": "위로", "summary": "말보다 함께 있어주는 게 좋아요", "keywords": ["함께", "공감", "조용한 위로"]}
  ],
  "communication_style": "사려깊은 경청형",
  "humor_style": "잔잔한 드라이 유머",
  "value_keywords": ["진정성", "개인 존중", "일상의 소소함", "솔직한 소통", "느긋한 사랑"],
  "embedding": [0.012, -0.034, 0.056, ...],
  "ai_generated": true
}
```

**주의사항**
- `traits`는 정확히 **8개** 카테고리 (연락 템포 / 유머 / 갈등 / 데이트 / 돈·시간 / 관계 속도 / 경계선 / 위로)
- `embedding`은 **1024차원** float 배열 (필수)
- `value_keywords`는 3~7개
- `communication_style`, `humor_style`은 **문자열** (dict 아님)
- `ai_generated`는 반드시 `true`

---

### 2-2. `POST /llm/simulate`

두 사용자의 페르소나를 받아 멀티턴 대화 시뮬레이션을 **SSE 스트림**으로 반환합니다.

**요청**
```json
{
  "my_persona": {
    "traits": [...],
    "communication_style": "...",
    "humor_style": "...",
    "value_keywords": [...]
  },
  "their_persona": {
    "traits": [...],
    "communication_style": "...",
    "humor_style": "...",
    "value_keywords": [...]
  },
  "max_turns": 20
}
```

**응답** — SSE 스트림, 각 이벤트는 `simulation_turn.schema.json` 준수

```
data: {"turn_index": 0, "speaker": "me", "text": "안녕하세요! ...", "signal": null, "ai_generated": true}

data: {"turn_index": 1, "speaker": "them", "text": "안녕하세요~ ...", "signal": null, "ai_generated": true}

data: {"turn_index": 2, "speaker": "system", "text": "🔍 공통 관심사 발견: 여행", "signal": "여행 시그널", "ai_generated": true}

data: [DONE]
```

**SSE 형식 규칙**
- 각 이벤트는 `data: {JSON}\n\n` 형식
- 스트림 종료 시 `data: [DONE]\n\n` 전송
- `speaker`는 `"me"`, `"them"`, `"system"` 중 하나
- `signal`은 Flutter UI의 SignalChip에 표시될 태그 (없으면 `null`)
- `system` 턴은 분석 코멘트용 (대화 턴 수에 포함하지 않아도 됨)

---

### 2-3. `POST /llm/report`

시뮬레이션 결과를 분석해 케미 리포트를 반환합니다.

**요청**
```json
{
  "my_persona": { "traits": [...], ... },
  "their_persona": { "traits": [...], ... },
  "simulation_log": [
    {"turn_index": 0, "speaker": "me", "text": "...", "signal": null, "ai_generated": true},
    {"turn_index": 1, "speaker": "them", "text": "...", "signal": null, "ai_generated": true}
  ]
}
```

**응답** — `report.schema.json` 준수
```json
{
  "score": 82,
  "findings": [
    {"emoji": "✈️", "title": "여행 스타일 궁합", "sub": "둘 다 자연 속 힐링 여행을 선호해요."},
    {"emoji": "🎵", "title": "음악 취향 교집합", "sub": "인디 밴드와 소규모 공연장을 함께 즐길 수 있어요."}
  ],
  "warnings": [
    {"title": "깊은 가치관 대화 필요", "body": "갈등 해결 방식에 대한 대화는 아직 나누지 않았어요."}
  ],
  "places": [
    {"emoji": "☕", "title": "연남동 카페 거리", "sub": "카페와 산책을 좋아하는 두 분에게 딱이에요"},
    {"emoji": "🎶", "title": "문화비축기지", "sub": "소규모 공연과 야외 산책을 함께 즐길 수 있어요"}
  ],
  "starters": [
    "혹시 이번 주말에 연남동 카페 탐방 같이 하실래요?",
    "좋아하는 인디 밴드 공연 있으면 같이 가봐요!"
  ],
  "tip": "첫 만남은 카페처럼 편한 공간에서 시작하면 대화가 더 자연스러워요.",
  "ai_generated": true
}
```

**주의사항**
- `score`는 0~100 정수
- `findings`는 2~5개, 각각 `emoji` / `title` / `sub`
- `warnings`는 0개 이상, 각각 `title` / `body`
- `places`는 2~4개, 각각 `emoji` / `title` / `sub`
- `starters`는 2~5개 **문자열** 배열 (객체 아님)
- `tip`은 선택 (없으면 `null`)
- 응답에 `match_id`는 **포함하지 않아도 됩니다** — 백엔드가 추가합니다

---

### 2-4. `POST /llm/starters`

두 사용자 페르소나 기반으로 대화 시작 문구 3개를 반환합니다.

**요청**
```json
{
  "my_persona": { "traits": [...], ... },
  "their_persona": { "traits": [...], ... },
  "recent_history": []
}
```

**응답** — `starter.schema.json` 준수
```json
{
  "starters": [
    {"label": "✈️ 여행 토크", "message": "최근에 제일 기억에 남는 여행지가 어디예요?"},
    {"label": "☕ 카페 탐방", "message": "혹시 주말에 카페 가시는 거 좋아하세요?"},
    {"label": "📸 프로필 칭찬", "message": "프로필 사진이 되게 좋은 곳에서 찍으셨더라고요~ 어디예요?"}
  ],
  "ai_generated": true
}
```

**주의사항**
- `starters`는 정확히 **3개**
- 각각 `label` (이모지 + 짧은 태그)과 `message` (실제 입력 문구)
- `recent_history`가 비어있으면 콜드스타트, 있으면 이전 대화 기반 후속 문구

---

## 3. 에러 응답 규약

LLM 서버에서 에러가 발생하면 아래 형식으로 반환해 주세요.

```json
{
  "error_code": "RAI_BLOCKED",
  "message": "부적절한 내용이 감지되었습니다.",
  "request_id": "req-xxx"
}
```

| 상황 | HTTP status | error_code |
|------|-------------|------------|
| 입력 형식 오류 | 400 | `INVALID_INPUT` |
| RAI 필터 차단 | 451 | `RAI_BLOCKED` |
| 스키마 위반 출력 | 502 | `SCHEMA_VIOLATION` |
| 서버 내부 오류 | 500 | `INTERNAL_ERROR` |

`request_id`는 백엔드가 요청 시 `X-Request-ID` 헤더로 전달할 수도 있습니다 (아직 미구현, 추후 합의).

---

## 4. 백엔드에서 LLM을 호출하는 방식

백엔드 코드 위치: `backend/app/llm/`

```
backend/app/llm/
├── base.py          # LLMProvider 추상 클래스 (4개 메서드)
├── mock.py          # 하드코딩 한국어 응답 (현재 기본값)
├── hf.py            # HuggingFace Inference Endpoint 호출
├── midm_local.py    # 셀프호스팅 LLM 서버 호출
└── factory.py       # 환경변수 기반 provider 선택
```

**환경변수로 전환하는 법**
```bash
# .env 파일
LLM_PROVIDER=midm_local          # mock → midm_local로 변경
LLM_BASE_URL=http://localhost:8001  # LLM 서버 주소
```

이현정 님이 LLM 서버를 `http://localhost:8001`에 띄우면, 백엔드 `.env`만 바꿔서 바로 연동됩니다.

---

## 5. 빠른 연동 테스트 방법

### 5-1. 백엔드 서버 띄우기

```bash
cd backend
cp .env.example .env
docker-compose up -d          # PostgreSQL + API 서버 실행
# http://localhost:8000/docs  # Swagger UI에서 엔드포인트 확인
```

### 5-2. LLM 서버 연동 테스트

```bash
# .env 에서 LLM_PROVIDER=midm_local, LLM_BASE_URL=http://localhost:8001 로 수정 후
docker-compose restart api

# /health 엔드포인트로 상태 확인
curl http://localhost:8000/health
# → {"status":"ok","llm_provider":"midm_local","database":"ok"}
```

### 5-3. LLM 엔드포인트 단독 테스트 (백엔드 없이)

이현정 님 쪽에서 LLM 서버만 따로 테스트할 때:

```bash
# persona 생성
curl -X POST http://localhost:8001/llm/persona \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-user", "answers": [{"question_id": 1, "answer": "test"}]}'

# 시뮬레이션 (SSE 스트림)
curl -X POST http://localhost:8001/llm/simulate \
  -H "Content-Type: application/json" \
  -d '{"my_persona": {"traits": [], "communication_style": "", "humor_style": "", "value_keywords": []}, "their_persona": {"traits": [], "communication_style": "", "humor_style": "", "value_keywords": []}, "max_turns": 5}'
```

---

## 6. 합의가 필요한 사항

아래 항목들은 작업하면서 같이 정하고, `shared/schemas/README.md`에 기록하면 됩니다.

| 항목 | 설명 | 현재 상태 |
|------|------|----------|
| **타임아웃** | 각 엔드포인트별 최대 응답 시간 | 백엔드 기본값: connect 10초, read 120초 |
| **토큰 한도** | LLM 출력 최대 토큰 수 | 미정 |
| **캐싱** | 같은 페르소나 쌍의 시뮬/리포트 재사용 여부 | 리포트는 백엔드에서 DB 캐싱 중 |
| **RAI 필터 위치** | LLM 내부 vs 백엔드 | 미정 — LLM 내부 권장 |
| **request_id 전파** | 백엔드 → LLM 로깅 연결 | 미구현, 필요 시 X-Request-ID 헤더 |
| **persona 입력 형식** | `answers` 배열의 정확한 구조 | 현재 `[{question_id, answer}]` 가정 중 |
| **max_turns 기본값** | 시뮬레이션 기본 턴 수 | 백엔드 기본값: 20 |
| **임베딩 모델** | 어떤 모델로 1024차원 벡터 생성 | 이현정 님 선택 (BGE-M3 등) |

---

## 7. 타임라인

| 날짜 | 백엔드 | LLM |
|------|--------|-----|
| ~5/31 | mock provider로 Flutter 통합 테스트 | `/llm/persona` 구현 |
| ~6/4 | HF provider 실 테스트 | `/llm/simulate` SSE 구현 |
| ~6/7 | 전 엔드포인트 E2E 검증 | `/llm/report`, `/llm/starters` 구현 |
| **6/8** | **발표** | **발표** |
| 이후 | `midm_local` provider 전환 | 대회 GPU에 배포 |

---

## 8. 연락

질문이나 스키마 변경이 필요하면 언제든 말씀해 주세요.
`shared/schemas/` 변경 시에는 양쪽 리뷰가 필요합니다.
