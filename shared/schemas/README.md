# Shared Schemas

LLM 호출의 입출력 계약입니다. **이현정·손지민 두 분이 공통으로 의존합니다.**

- `persona.schema.json` — 24문항 답변 → 페르소나 카드
- `simulation_turn.schema.json` — 에이전트 시뮬레이션의 한 턴
- `report.schema.json` — 시뮬레이션 결과 → 케미 리포트
- `starter.schema.json` — 인간 채팅에서 추천하는 대화 시작 문구

## 변경 규칙

1. 아래의 합의 사항은 한채훈이 확정한 결정이며, 발표(6월 8일) 전까지는 변경하지 않습니다. 부득이한 경우 양쪽 리뷰가 필요합니다.
2. 스키마 변경 시 백엔드의 데이터 모델과 LLM 응답 형식이 동시에 업데이트되어야 합니다.
3. Flutter `lib/data/` 의 모델 클래스 역시 동시 업데이트가 필요합니다.

## 검증

각 owner 가 자신의 환경에서 스키마 유효성 검증을 수행합니다 (Python `jsonschema`, Node `ajv` 등).

---

## 합의 사항 (한채훈 확정)

### 1. 호출 인터페이스

LLM 모듈은 **HTTP API** 를 노출합니다. 백엔드는 HTTP 로 호출하며, 라이브러리 import 방식은 사용하지 않습니다.

> 이유: 언어 독립, mock 만들기 쉬움, 예선 통과 후 셀프호스팅 추론 서버로 이전할 때도 호출 측 코드 변경 없음.

### 2. LLM HTTP 엔드포인트 4개

LLM 모듈이 노출할 엔드포인트:

| 엔드포인트 | 입력 (body) | 출력 |
|---|---|---|
| `POST /llm/persona` | `{user_id, answers}` | `persona.schema.json` |
| `POST /llm/simulate` | `{my_persona, their_persona, max_turns: 20}` | **SSE 스트림** · 각 이벤트는 `simulation_turn.schema.json` |
| `POST /llm/report` | `{my_persona, their_persona, simulation_log}` | `report.schema.json` |
| `POST /llm/starters` | `{my_persona, their_persona, recent_history}` | `starter.schema.json` |

백엔드는 위 4개 엔드포인트를 호출하는 `LLMProvider` 추상화를 만들어, mock / hf / midm_local 사이를 환경변수로 스위치합니다.

### 3. 임베딩 차원

- **차원: 1024** (벡터 DB 의 인덱스 차원은 생성 시점에 고정되므로 미리 확정 필요)
- **책임: LLM 모듈** 이 `/llm/persona` 응답의 `embedding` 필드에 1024차원 벡터를 포함하여 반환합니다.
- 백엔드는 받은 벡터를 그대로 저장합니다.
- 모델 선택은 LLM owner 자유 — 1024차원 출력만 보장하면 됩니다 (예: BGE-M3, e5-large-multilingual, BGE-Korean 등).

### 4. 시뮬레이션 스트리밍

**SSE (Server-Sent Events).** LLM → 백엔드 → Flutter 모든 구간에서 SSE 를 사용합니다.

> 이유: 단방향 + HTTP 호환 + 자동 재연결. 주요 추론 서버의 스트리밍 표준이 SSE 기반이라 추후 이전이 용이함.

### 5. 임베딩 생성 책임

`/llm/persona` 응답에 임베딩 벡터까지 포함합니다. 백엔드는 별도로 임베딩 모델을 호출하지 않습니다.

### 6. 에러 응답 규약

모든 에러 응답은 다음 JSON 형식을 따릅니다.

```json
{
  "error_code": "RAI_BLOCKED",
  "message": "사용자에게 보여줄 수 있는 한국어 메시지",
  "request_id": "abc123"
}
```

| 상황 | HTTP status | error_code |
|---|---|---|
| 잘못된 입력 | 400 | `INVALID_INPUT` |
| LLM 출력이 JSON 스키마 위반 | 502 | `SCHEMA_VIOLATION` |
| RAI 필터 차단 | 451 | `RAI_BLOCKED` |
| Rate limit 초과 | 429 | `RATE_LIMITED` |
| LLM 서버 다운 | 503 | `LLM_UNAVAILABLE` |
| 타임아웃 | 504 | `LLM_TIMEOUT` |

Flutter 는 `error_code` 로 분기하여 `quota_exceeded_screen`, `request_timeout_screen` 등 해당 화면을 띄웁니다.

---

## 추후 합의 사항 (자율)

다음 항목들은 이현정·손지민 두 분이 작업을 진행하면서 자율적으로 합의해 정합니다. 합의 후 본 문서에 추가 기록합니다.

- 토큰 / 타임아웃 한도 (각 엔드포인트별)
- 캐싱 책임 (페르소나 임베딩, 같은 페르소나 쌍의 시뮬 결과 등)
- 로깅 / 관측성 포맷 (request_id 전파 방식 포함)
- RAI 필터 구현 위치 (LLM 모듈 내부 vs 백엔드)
