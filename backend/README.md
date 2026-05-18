# AMORI Backend (BFF)

Flutter 앱과 LLM 사이의 중간 레이어입니다. **손지민 담당.** 기술 스택은 자유롭게 선택하실 수 있습니다.

## 책임

Flutter 앱이 LLM 을 직접 호출하지 않도록 합니다. 키 보호, 데이터베이스, 인증, 비용 통제, 비동기 작업 처리를 담당합니다.

## 만들어야 하는 것

### 1. 엔드포인트 (Flutter 가 호출)

JSON 입출력은 모두 [`shared/schemas/`](../shared/schemas/) 의 스키마를 따릅니다.

| 메서드 | 경로 | 하는 일 | 출력 스키마 |
|---|---|---|---|
| `POST` | `/persona/build` | 24문항 답변 → 페르소나 카드 + 임베딩 저장 | `persona.schema.json` |
| `GET`  | `/matches/find?user_id=&top_k=` | 페르소나 벡터 유사도 기반 매칭 후보 (단순 top-K 코사인 — 발표 이후 [`matching/`](../matching/) 모듈로 교체 예정) | (자유 — id/name/score 등) |
| `POST` | `/simulation/run` | 두 사용자 페르소나 → 멀티턴 시뮬레이션 (스트리밍) | `simulation_turn.schema.json` × N |
| `GET`  | `/report/{match_id}` | 시뮬 결과 → 케미 리포트 | `report.schema.json` |
| `POST` | `/meet/request` | 오프라인 만남 신청 (24시간 만료) | (자유) |
| `GET`  | `/health` | 헬스체크 | (자유) |

### 2. LLM 호출 추상화 (필수)

LLM 모듈은 **HTTP API** 로 호출합니다. 백엔드는 4개 엔드포인트를 호출하는 `LLMProvider` 추상화를 두고, 환경변수로 백엔드 종류를 스위치할 수 있도록 구현합니다 — **GPU 없는 동안에도 끝까지 동작하게 만드는 핵심 요건입니다.**

| 값 | 동작 | 사용 시점 |
|---|---|---|
| `mock` | 하드코딩된 JSON 응답을 반환합니다 | 기본값. GPU 없이 Flutter 통합 테스트에 사용합니다. |
| `hf` | HuggingFace Inference Endpoint 를 호출합니다 | 예선 탈락 시 폴백으로 사용합니다. |
| `midm_local` | 셀프호스팅된 LLM 모듈(`/llm/*`) 을 호출합니다 | 예선 통과 후 대회 GPU 로 운영합니다. |

구현 방식(인터페이스 / 팩토리 / DI 등)은 자유입니다. 다만 코드 변경 없이 환경변수만으로 갈아끼울 수 있어야 합니다.

LLM 모듈이 노출하는 HTTP 엔드포인트 4개 — 상세 스펙은 [`shared/schemas/README.md`](../shared/schemas/README.md#2-llm-http-엔드포인트-4개) 의 합의 사항을 참조합니다.

| 엔드포인트 | 출력 |
|---|---|
| `POST /llm/persona` | `persona.schema.json` (1024차원 임베딩 벡터 포함) |
| `POST /llm/simulate` | SSE 스트림 (각 이벤트 = `simulation_turn.schema.json`) |
| `POST /llm/report` | `report.schema.json` |
| `POST /llm/starters` | `starter.schema.json` |

시뮬레이션은 SSE 로 받아 그대로 Flutter 에 중계합니다 (이중 SSE).

### 3. 데이터베이스

벡터 검색이 필요하므로 pgvector(PostgreSQL) 또는 동등한 솔루션을 사용합니다. 최소한 다음 테이블이 필요합니다.

- 사용자
- 페르소나 (JSON + 임베딩 벡터, **차원 = 1024**)
- 매칭 / 시뮬레이션 로그
- 리포트 (캐싱)
- 만남 신청 (상태·만료)
- 만남 후 피드백 (학습 루프용)

임베딩은 LLM 모듈이 `/llm/persona` 응답에 포함하여 반환합니다. 백엔드는 받은 벡터를 그대로 저장합니다.

### 4. 인증

Firebase Auth 또는 동등한 솔루션을 사용합니다. Flutter 가 ID 토큰을 전달하면 백엔드가 검증한 뒤 사용자를 식별합니다.

### 5. 비동기 작업

시뮬레이션은 멀티턴이라 응답이 길어집니다 (20턴 × 5초 ≈ 100초). 작업 큐로 분리하여 Flutter 에 즉시 응답합니다.

### 6. 에러 응답

모든 에러 응답은 [`shared/schemas/README.md`](../shared/schemas/README.md#6-에러-응답-규약) 의 합의 규약을 따릅니다.

```json
{ "error_code": "RAI_BLOCKED", "message": "...", "request_id": "..." }
```

Flutter 는 `error_code` 로 분기하여 `quota_exceeded_screen`, `request_timeout_screen` 등 해당 화면을 띄웁니다.

### 7. 운영 / 보안

- 시크릿은 `.env` (gitignore) 와 GitHub Secrets 에 보관하며, 코드나 PR 에는 포함하지 않습니다.
- LLM 호출 로그를 보관합니다 (감사 추적).
- 사용자당 일일 시뮬레이션 한도를 둡니다 (비용 통제). Flutter 의 `quota_exceeded_screen.dart` 와 연결됩니다.

## 단계

1. **발표(6월 8일) 전까지** — `mock` provider 로 5개 엔드포인트 + DB + Firebase Auth + 비동기 작업 큐 + Flutter 통합 테스트까지 완성. 필요 시 `hf` provider 도 구현.
2. **예선 통과 후** — `midm_local` provider 추가. 환경변수만 스위치하면 됩니다.

세부 일정은 정해두지 않습니다. 추후 합의 사항(토큰 / 타임아웃 / 캐싱 / 로깅 / RAI 필터 위치 등)은 이현정님과 자율적으로 정해 [`shared/schemas/README.md`](../shared/schemas/README.md) 에 기록합니다.

## 작업 규칙

- 브랜치 prefix: `be/*`
- 작업 디렉토리: `backend/` 만 사용합니다. `llm/`, `lib/` 는 수정하지 않습니다.
- [`shared/schemas/`](../shared/schemas/) 변경 시 양쪽(이현정) 리뷰가 필수입니다.
