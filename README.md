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

## 로컬 개발 (USB 실기기 포함)

```bash
# 1. 백엔드 — backend/.env에 DEBUG=true 필요 (dev 인증 경로 활성화)
cd backend && .venv/Scripts/python -m uvicorn app.main:app --port 8000

# 2. (선택) 연결 화면용 시드 — mock provider, Gemini 쿼터 0콜
.venv/Scripts/python -X utf8 scripts/seed_dev_inbox.py

# 3. Flutter — 루트 .env (gitignore) 에 아래 두 줄
#    API_BASE_URL=http://localhost:8000
#    DEV_UID=dev_hanchaehun        ← Firebase 로그인 없이 'Bearer dev:<uid>' 인증
flutter run
```

**USB 실기기에서는 `adb reverse`가 필수입니다.**

```bash
adb reverse tcp:8000 tcp:8000
```

폰에서 `localhost:8000`은 폰 자신을 가리키므로, 이 명령으로 폰의 8000 포트를
USB 너머 PC의 백엔드로 터널링합니다. 한 번 실행하면 USB가 연결된 동안 유지되며,
**케이블 재연결·폰/PC 재부팅·`adb kill-server` 후에만 다시 실행**하면 됩니다 (앱 재실행과는 무관).

| 실행 타깃 | API_BASE_URL | 비고 |
|---|---|---|
| USB 실기기 | `http://localhost:8000` | `adb reverse` 필수. **`10.0.2.2`는 에뮬레이터 전용 별칭이라 실기기에선 요청이 타임아웃까지 매달림** |
| Android 에뮬레이터 | 미설정 (기본값 `10.0.2.2`) 또는 `localhost` + `adb reverse` | |
| Windows/웹 | 미설정 (기본값 `localhost`) | |

백엔드 연결 실패 시 화면은 더미 데이터로 폴백합니다 — 연결 화면에 **수아/민준/서연이 아닌
다른 이름**(김현우 등)이 보이면 백엔드에 닿지 않은 것입니다 (콘솔에 `inbox: GET /matches 실패` 로그).

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
