# AMORI

AI Pre-Dating 플랫폼입니다. 사용자의 AI 에이전트가 먼저 소개팅을 다녀와 대화 미리보기를 제공하고,
사용자는 그 결과를 보고 만남을 정합니다.

> 제품 방향·핵심 설계·궁합 원칙·남은 작업: [`refatodo.md`](refatodo.md)
>
> 페르소나·문항 설계의 심리학적 근거(출처 포함): [`docs/persona_science_rationale.md`](docs/persona_science_rationale.md)
>
> https://aistudio.worksmobile.com/chat/app/6a4b0d8dee604f31165120c6/room

## 아키텍처

LLM 호출 경로는 **Flutter → BFF → LLM API** 하나뿐입니다. 클라이언트는 LLM API 키를 갖지 않으며,
LLM provider는 환경변수로 스위치합니다(`mock` | `gemini` | `modoo`).

```
Flutter 앱
 ├─ Firebase Auth (로그인, ID 토큰 발급)        ← Firebase 책임은 Auth + FCM까지
 └─ ApiClient (Bearer ID토큰) ──→ FastAPI BFF (backend/)
                                   ├─ auth/        Firebase ID 토큰 검증
                                   ├─ routers/     users·persona·matches·simulation(SSE)·report·meet·feedback
                                   ├─ llm/         LLMProvider 추상화 (mock | gemini | modoo)
                                   │   └─ prompts/ 한국어 프롬프트
                                   ├─ services/    자동 소개팅·시차 송출·말투 측정/게이트
                                   ├─ matching/    관심 성별 상호 + 벡터 매칭
                                   └─ 팀 공용 관리형 Postgres + pgvector (도메인 데이터 단일 원천)
                                        + 외부: Gemini API (대화·임베딩) / DevDive API (대화)
```

## 모노레포 구조

```
amori/
├── lib/                  Flutter 앱 (iOS·Android)
│   └── data/dummy/       가입 질문지(시나리오)
├── backend/              FastAPI BFF + LLM + 매칭 (단일 배포 단위)
│   └── app/llm/prompts/  한국어 프롬프트 가공
├── shared/schemas/       LLM structured output + 백엔드↔Flutter 응답 계약
└── refatodo.md           제품 방향 & 진행
```

## 핵심 원칙

1. **클라이언트는 LLM을 직접 호출하지 않습니다.** API 키 유출·쿼터 우회·데이터 유실 방지를 위해 모든 LLM 호출은 BFF를 경유합니다.
2. **도메인 데이터의 단일 원천은 Postgres입니다.** Firebase는 Authentication과 FCM 푸시 토큰까지만 사용합니다.
3. **`shared/schemas/` 가 계약입니다.** LLM structured output 스키마이자 백엔드↔Flutter 응답 형태입니다.
4. **LLM provider는 환경변수로 스위치합니다.** `LLM_PROVIDER=mock`(오프라인 데모/테스트) ↔ `gemini`(실 LLM).
5. **`main` 에 직접 푸시하지 않습니다.** 변경은 모두 PR로 진행합니다.

## 로컬 개발 (USB 실기기 포함)

```bash
# 0. 최초 1회 — 백엔드 의존성 설치 + 시크릿 채널에서 backend/.env 받기
#    (.env 항목은 backend/.env.example 참고. DB는 팀 공용 Neon — 각자 설치할 것 없음)
cd backend
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt

# 1. 백엔드 실행
.venv/Scripts/python -m uvicorn app.main:app --port 8000

# 2. (선택) 연결 화면용 시드 — mock provider, Gemini 쿼터 0콜. 공용 DB를 건드리니 팀 공지 후 실행
.venv/Scripts/python -X utf8 scripts/seed_dev_inbox.py [본인 DEV_UID]

# 3. Flutter — 루트 .env (gitignore) 에 아래 두 줄.
#    ⚠ 이 파일이 없으면 flutter run이 asset 오류로 빌드조차 안 된다 (pubspec asset)
#    API_BASE_URL=http://localhost:8000
#    DEV_UID=dev_<본인이름>      ← Firebase 로그인 없이 'Bearer dev:<uid>' 인증.
#                                  uid가 다르면 공용 DB 안에서도 서로 데이터가 격리된다
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
| USB 실기기 (Android) | `http://localhost:8000` | `adb reverse` 필수. **`10.0.2.2`는 에뮬레이터 전용 별칭이라 실기기에선 요청이 타임아웃까지 매달림** |
| Android 에뮬레이터 | 미설정 (기본값 `10.0.2.2`) 또는 `localhost` + `adb reverse` | |
| Windows/웹 | 미설정 (기본값 `localhost`) | |
| iOS 실기기 | (로컬 백엔드 불가) | 빌드에 Mac+Xcode 필요. iOS엔 `adb reverse`가 없고 ATS가 평문 http를 차단하므로 **https 배포 백엔드가 필요** (iOS 시뮬레이터는 Mac에서 `localhost` 가능) |

백엔드에 닿지 않으면 연결 화면은 **빈 상태**로 표시됩니다 (더미 인물 폴백은 제거됨).
시드를 깔았는데도 카드가 안 보이면 백엔드 연결부터 의심하세요 — 콘솔에
`inbox: GET /matches 실패` 로그가 남습니다.

## 로드맵

- **MVP 출시** — iOS·Android 베타, 시드 유저 100명
- **PMF 검증**
