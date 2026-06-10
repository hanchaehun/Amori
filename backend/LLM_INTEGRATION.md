# 백엔드 ↔ LLM 연동 가이드 — 폐기됨 (2026-06-10)

> 이 문서는 "별도 LLM HTTP 서비스(Mi:dm 셀프호스팅)를 백엔드가 호출한다"는
> 피벗 이전 전제로 작성되었습니다. 외부 LLM API(Gemini)로 피벗하면서
> LLM 호출은 백엔드 프로세스 안에서 SDK로 직접 이루어집니다.
> 이전 내용은 git 히스토리(`git log -- backend/LLM_INTEGRATION.md`)에서 볼 수 있습니다.

## 지금 봐야 할 문서

| 주제 | 위치 |
|---|---|
| 리팩토링 근거·전체 방향 | `docs/AMORI_리팩토링_방향.docx`, `refatodo.md` |
| 프롬프트 작업 가이드 (이현정) | [`app/llm/prompts/README.md`](app/llm/prompts/README.md) |
| LLM provider 구조 (mock/gemini) | [`README.md`](README.md#llm-provider) |
| 입출력 계약 | [`../shared/schemas/README.md`](../shared/schemas/README.md) |

## 요약: 무엇이 어떻게 바뀌었나

- `POST /llm/persona` 등 HTTP 엔드포인트 4개 → `LLMProvider` 의 4개 도메인 메서드 (in-process)
- 프롬프트 엔지니어링 → `app/llm/prompts/` 패키지 (이현정 소유, 협업 경계 유지)
- JSON 스키마 강제 → Gemini responseSchema + Pydantic (`SCHEMA_VIOLATION` 소멸)
- 임베딩 → Gemini Embedding, `output_dimensionality=1024` (채팅과 같은 키)
- 시뮬레이션 → 원샷 생성이 아닌 2-에이전트 턴 루프 (`app/services/simulation.py`)
