# Shared Schemas

LLM 입출력과 백엔드 응답의 계약입니다. **LLM·백엔드 양쪽이 공통으로 의존합니다.**

> **2026-06-10 리팩토링으로 계약의 의미가 바뀌었습니다.**
> 구: "백엔드 ↔ 별도 LLM HTTP 서비스" 간 HTTP 계약
> 신: **① LLM structured output 스키마** (Gemini responseSchema로 API 레벨 강제)
> **② 백엔드 ↔ Flutter 응답 계약** (FastAPI Pydantic 스키마 ↔ `lib/data/` 모델)

- `persona.schema.json` — 초기/누적 시나리오 답변 → 페르소나 카드 (8 카테고리 traits + 1024차원 임베딩)
- `simulation_turn.schema.json` — 에이전트 시뮬레이션의 한 턴 (SSE 이벤트 단위)
- `report.schema.json` — 시뮬레이션 결과 → 케미 리포트
- `starter.schema.json` — 인간 채팅에서 추천하는 대화 시작 문구

## 스키마가 강제되는 위치

| 구간 | 강제 수단 |
|---|---|
| Gemini 출력 | `backend/app/llm/gemini.py` 의 Pydantic responseSchema — `SCHEMA_VIOLATION` 오류 클래스 자체가 소멸 |
| 백엔드 응답 | `backend/app/schemas/` Pydantic (`response_model`) |
| Flutter 소비 | `lib/data/repositories/` 의 매핑 (모델 클래스는 `lib/data/models/`) |

## 변경 규칙

1. 스키마 변경 시 `backend/app/schemas/`(Pydantic)와 `backend/app/llm/gemini.py` 의 output 모델, Flutter `lib/data/` 모델이 동시에 업데이트되어야 합니다.
2. 변경은 LLM·백엔드 양쪽 리뷰가 필수입니다.

## 핵심 합의 사항 (유지)

### 1. 임베딩 차원: 1024

- pgvector 인덱스 차원은 생성 시점에 고정 — `personas.embedding vector(1024)`
- 생성 책임: 백엔드의 Gemini provider (`output_dimensionality=1024`, 정규화 포함). 별도 임베딩 업체 불필요.

### 2. 시뮬레이션 스트리밍: SSE

백엔드 → Flutter 구간 SSE 유지. 백엔드의 2-에이전트 턴 루프가 턴을 생성하는 즉시
`/simulation/run` 으로 흘려보내며, 각 이벤트는 `simulation_turn.schema.json` 을 따릅니다.

### 3. `ai_generated: true` 라벨

모든 LLM 생성 응답에 필수 (AI 기본법 준수). 서버에서 일괄 강제합니다.

### 4. 에러 응답 규약

```json
{
  "error_code": "QUOTA_EXCEEDED",
  "message": "사용자에게 보여줄 수 있는 한국어 메시지",
  "request_id": "abc123"
}
```

| 상황 | HTTP status | error_code |
|---|---|---|
| 잘못된 입력 | 400 | `INVALID_INPUT` |
| 인증 필요/만료 | 401 | `UNAUTHORIZED` |
| 일일 한도 초과 | 429 | `QUOTA_EXCEEDED` |
| RAI 필터 차단 | 451 | `RAI_BLOCKED` |
| 내부 오류 | 500 | `INTERNAL_ERROR` |
| LLM API 다운 | 503 | `LLM_UNAVAILABLE` |
| LLM 타임아웃 | 504 | `LLM_TIMEOUT` |

Flutter 는 `ApiException.errorCode` 로 분기하여 `quota_exceeded_screen`,
`request_timeout_screen` 등 해당 화면을 띄웁니다.

## 검증

각 owner 가 자신의 환경에서 스키마 유효성 검증을 수행합니다 (Python `jsonschema`, Dart 단위 테스트 등).
