# AMORI LLM Module — 폐기됨 (2026-06-10)

이 모듈은 **KT Mi:dm 2.0을 대회 GPU에 셀프호스팅**한다는 전제 위에 설계된
별도 HTTP 추론 서비스 계획이었습니다. 외부 LLM API(Gemini)로 피벗하면서
별도 LLM 서비스 계층의 존재 이유가 사라져 백엔드 안으로 흡수되었습니다.

근거: `docs/AMORI_리팩토링_방향.docx` 결정 1 — 백엔드→LLM서비스→외부API의
HTTP 홉은 지연·장애지점·배포단위만 늘리는 순수 비용.

## 책임 이관

| 구 책임 | 새 위치 |
|---|---|
| 한국어 프롬프트 엔지니어링 | [`backend/app/llm/prompts/`](../backend/app/llm/prompts/) |
| `/llm/persona` 등 HTTP 엔드포인트 4개 | `backend/app/llm/base.py` 의 4개 도메인 메서드 (HTTP 홉 제거) |
| Mi:dm 추론 서버 (`midm_local.py`, `hf.py`) | 삭제 — Gemini SDK 직접 호출 (`backend/app/llm/gemini.py`) |
| 한국어 임베딩 (1024차원) | Gemini Embedding `output_dimensionality=1024` (같은 키) |
| 평가셋 30케이스 | P2 과제로 승계 (`refatodo.md` 참조) |
| RAI 필터·`ai_generated` 라벨링 | 백엔드 프롬프트 규칙 + Pydantic 스키마 강제 |

이 디렉토리는 팀원 혼동 방지를 위해 안내문만 남기며, 추후 삭제 예정입니다.
