# AMORI

AI Pre-Dating 플랫폼입니다. 사용자의 AI 에이전트가 백그라운드에서 가상 소개팅을 진행하고,
케미가 검증된 인연만 오프라인으로 연결합니다.

> 2026 인공지능 루키 대회 출전작 — 본선 미진출 후 **외부 LLM API(Gemini) 기반으로 피벗** (2026-05-29).
> 리팩토링 근거와 진행 상황: [`docs/AMORI_리팩토링_방향.docx`](docs/) · [`refatodo.md`](refatodo.md)

## 아키텍처 (2026-06-10 리팩토링 이후)

LLM 호출 경로는 **Flutter → BFF → Gemini** 하나뿐입니다. 클라이언트는 LLM API 키를 갖지 않습니다.

```
Flutter 앱
 ├─ Firebase Auth (로그인, ID 토큰 발급)        ← Firebase 책임은 Auth + FCM까지
 └─ ApiClient (Bearer ID토큰) ──→ FastAPI BFF (backend/)
                                   ├─ auth/        Firebase ID 토큰 검증
                                   ├─ routers/     users·persona·matches·simulation(SSE)·report·meet·feedback
                                   ├─ llm/         LLMProvider 추상화 (mock | gemini)
                                   │   └─ prompts/ 한국어 프롬프트 (구 llm/ 모듈의 책임 이관)
                                   ├─ services/    2-에이전트 턴 루프 시뮬레이션 엔진
                                   ├─ matching/    벡터 매칭 패키지 (구 matching/ 모듈 흡수)
                                   └─ PostgreSQL + pgvector (도메인 데이터 단일 원천)
                                        + 외부: Gemini API (대화 + 임베딩, 단일 키)
```

## 모노레포 구조

```
amori/
├── lib/                  Flutter 앱 (iOS·Android)                  ─ 한채훈
├── backend/              FastAPI BFF + LLM + 매칭 (단일 배포 단위)    ─ 손지민
│   └── app/llm/prompts/  한국어 프롬프트 엔지니어링                   ─ 이현정
│   └── app/matching/     매칭 알고리즘                              ─ 명세현
├── llm/                  (폐기) → backend/app/llm/ 로 흡수
├── matching/             (폐기) → backend/app/matching/ 으로 흡수
├── shared/schemas/       LLM structured output + 백엔드↔Flutter 응답 계약
└── refatodo.md           리팩토링 TODO 및 진행 현황
```

## 핵심 원칙

1. **클라이언트는 LLM을 직접 호출하지 않습니다.** API 키 유출·쿼터 우회·데이터 유실 방지를 위해 모든 LLM 호출은 BFF를 경유합니다.
2. **도메인 데이터의 단일 원천은 Postgres입니다.** Firebase는 Authentication과 FCM 푸시 토큰까지만 사용합니다.
3. **`shared/schemas/` 가 계약입니다.** LLM structured output 스키마이자 백엔드↔Flutter 응답 형태입니다.
4. **LLM provider는 환경변수로 스위치합니다.** `LLM_PROVIDER=mock`(오프라인 데모/테스트) ↔ `gemini`(실 LLM).
5. **`main` 에 직접 푸시하지 않습니다.** 변경은 모두 PR로 진행합니다.

## 역할 분담

| 영역 | 담당 | 브랜치 prefix |
|---|---|---|
| Flutter 앱 | 한채훈 | `feat/fe-*` |
| 백엔드 (BFF·DB·배포) | 손지민 | `be/*` |
| LLM 프롬프트·품질 (`backend/app/llm/prompts/`) | 이현정 | `llm/*` |
| 매칭 알고리즘 (`backend/app/matching/`) | 명세현 | `match/*` |
| 공유 계약 (`shared/`) | 모두 리뷰 | `shared/*` |

## 마일스톤

| 시점 | 마일스톤 |
|---|---|
| 2026-05-31 | α — Gemini 연동 E2E (페르소나→시뮬레이션→리포트) |
| 2026-06-06 | 실유저 페르소나 기반 벡터 매칭 |
| 2026-06-08 | 발표 |
| 2026-08 | MVP 출시 (iOS·Android 베타), 시드 유저 100명 |
| 2026-11 | PMF 검증 |
