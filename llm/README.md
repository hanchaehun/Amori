# AMORI LLM Module

KT Mi:dm 2.0 Base 추론과 프롬프트 엔지니어링을 담당합니다. **이현정 담당.** 구현 방식은 자유롭게 선택하실 수 있습니다.

## 책임

한국어 데이팅 도메인에 맞는 LLM 호출을 책임집니다. 백엔드는 본 모듈을 통해서만 LLM 을 호출합니다.

## 만들어야 하는 것

### 1. HTTP API 4개 — JSON 스키마 강제 출력

LLM 모듈은 **HTTP API** 를 노출하며, 백엔드가 이를 호출합니다. 입출력은 모두 [`shared/schemas/`](../shared/schemas/) 의 스키마를 100% 따릅니다. 응답에는 `"ai_generated": true` 라벨이 필수입니다 (AI 기본법 준수).

| 엔드포인트 | 입력 (body) | 출력 |
|---|---|---|
| `POST /llm/persona` | `{user_id, answers}` | `persona.schema.json` (8 카테고리 traits + 1024차원 임베딩 벡터) |
| `POST /llm/simulate` | `{my_persona, their_persona, max_turns: 20}` | **SSE 스트림** · 각 이벤트는 `simulation_turn.schema.json` |
| `POST /llm/report` | `{my_persona, their_persona, simulation_log}` | `report.schema.json` |
| `POST /llm/starters` | `{my_persona, their_persona, recent_history}` | `starter.schema.json` |

각 출력 필드는 Flutter UI 와 1:1 로 매칭됩니다 — `lib/features/matching/full_report_screen.dart` 의 `_Finding`, `_GuideItem` 등을 참고하시면 됩니다.

상세 합의 사항은 [`shared/schemas/README.md`](../shared/schemas/README.md#합의-사항-한채훈-확정) 참조.

### 2. 추론 환경

**GPU 없을 때:** Colab / Kaggle 등 무료 GPU 의 메모리 한도 안에서 동작하는 양자화 버전을 사용합니다 (예: 4-bit AWQ). 추론 속도가 느리더라도 프롬프트 검증과 평가셋 실행에는 충분합니다.

**예선 통과 후:** 대회 GPU 에서 운영합니다. 추론 프레임워크는 자유롭게 선택합니다 (예: vLLM, TGI, Ollama 등). LLM 모듈은 HTTP 엔드포인트(`/llm/*`) 만 그대로 노출하면 되며, 내부 구현 방식은 owner 가 결정합니다.

KT 공식 GitHub 의 튜토리얼을 활용합니다: <https://github.com/K-intelligence-Midm/Midm-2.0>

### 3. 한국어 임베딩 (페르소나 벡터)

- **차원: 1024** (백엔드 벡터 DB 인덱스 차원과 일치 — 합의 사항)
- 모델은 1024차원 출력을 보장하는 것으로 자유롭게 선택합니다 (예: BGE-M3, e5-large-multilingual, BGE-Korean 등).
- `/llm/persona` 응답의 `embedding` 필드에 벡터를 포함하여 반환합니다.

### 4. 평가셋

한국어 데이팅 도메인 30케이스를 목표로 합니다. 측정 지표:

- JSON 파싱 성공률 (스키마 위반 0건 목표)
- RAI 통과율 (외모·재산·차별 표현 0건)
- 응답 일관성 (같은 입력에 비슷한 출력)

### 5. 파인튜닝 (선택, 예선 통과 후)

데이팅 도메인 적응이 필요하다고 판단되면 진행합니다. 데이터셋·학습 도구 선택은 자유 (예: SimpleQA-GenX2, AI Hub 데이터셋, KT 공식 SFTTrainer 튜토리얼 등).

### 6. 에러 응답

모든 에러 응답은 [`shared/schemas/README.md`](../shared/schemas/README.md#6-에러-응답-규약) 의 합의 규약을 따릅니다.

```json
{ "error_code": "RAI_BLOCKED", "message": "...", "request_id": "..." }
```

RAI 필터에 걸리면 `RAI_BLOCKED`, 출력이 JSON 스키마에 맞지 않으면 `SCHEMA_VIOLATION` 으로 반환합니다.

### 7. 비용 통제 설계 (제안서 차별점)

- 페르소나는 한 번 임베딩 후 캐싱하여, 매번 전체 프로필 토큰을 재전송하지 않습니다.
- 가치관 패턴 결과를 캐싱합니다 (같은 입력 = 같은 출력).
- 소형 / 양자화 모델 선택으로 단가 자체를 절감합니다.

## 단계

1. **발표(6월 8일) 전까지** — 무료 GPU 환경(Colab / Kaggle 등)에서 양자화된 Mi:dm + 1024차원 임베딩 모델로 4개 엔드포인트 + 평가셋 30케이스 완성.
2. **예선 통과 후** — 대회 GPU 로 이전. 양자화 버전과 풀 정밀도의 품질 비교 결과를 팀에 공유. 필요 시 파인튜닝 진행.

세부 일정은 정해두지 않습니다. 추후 합의 사항(토큰 / 타임아웃 / 캐싱 / 로깅 / RAI 필터 위치 등)은 손지민님과 자율적으로 정해 [`shared/schemas/README.md`](../shared/schemas/README.md) 에 기록합니다.

## 작업 규칙

- 브랜치 prefix: `llm/*`
- 작업 디렉토리: `llm/` 만 사용합니다. `backend/`, `lib/` 는 수정하지 않습니다.
- [`shared/schemas/`](../shared/schemas/) 변경 시 양쪽(손지민) 리뷰가 필수입니다.
- 모든 응답에 `"ai_generated": true` 라벨을 포함합니다 (AI 기본법 준수).
- RAI 가이드라인을 따릅니다 — 인종·외모·재산·차별 표현은 출력에 포함하지 않습니다.
