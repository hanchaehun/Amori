# AMORI 리팩토링 TODO

> 근거 문서: `docs/AMORI_리팩토링_방향.docx` (2026-06-10)
> 핵심 한 줄: **"LLM 호출 경로를 Flutter→Groq에서 Flutter→BFF→Gemini로 일원화하고, 그 전제 작업으로 존재하지 않는 DB 모델부터 작성한다."**

---

## ✅ 실제 Gemini E2E 검증 완료 (2026-06-11)

`backend/scripts/e2e_gemini.py`로 **persona(voice 포함)→matches/find(임베딩)→simulation(SSE)→report 전 구간 실 Gemini 통과**. 결과 전문: `backend/scripts/e2e_result.md`.

**확인된 것:**
- speech_style·sample_messages 자연스럽게 생성됨 (A 차분/사려깊음 vs B 긍정/활발 — 톤·에너지·문장 길이 구분 뚜렷)
- 시뮬레이션 8턴 + 시그널 분석 2회 (✨즉흥 만남 제안 → ✅약속 조율) 정상 동작
- 리포트가 페르소나 대비를 실제로 짚음 (warnings: "즉흥성과 신중함의 차이", "유머 코드 차이") — score 75
- 임베딩 매칭 score 86.24, 1024차원

**한계 실증 (voice 2차의 근거):** 대조적 답변(신중형 vs 장난기형)을 넣어도 둘 다 존댓말/ㅎㅎ/이모지 가끔으로 **수렴** — 객관식만으로는 formality가 중립 기본값에 머묾. 진단("객관식은 말투를 못 잡는다")이 실 LLM에서 그대로 재현됨 → 질문지 주관식 추가(2차)가 차별화의 실제 병목.

**이번에 고친 것 (미커밋):**
- `backend/app/llm/gemini.py` — 429 응답의 RetryInfo retryDelay 존중 (무료 티어 RPM 쿼터에서 시뮬레이션 턴 루프가 끊기던 문제)
- `backend/alembic.ini` — em-dash가 Windows cp949 locale에서 alembic 기동을 깨던 문제 (ASCII로 교체)
- `backend/scripts/e2e_gemini.py` 신설 — 인증만 모킹(dependency_overrides), LLM·DB 실물. `--skip-persona`로 쿼터 절약 재실행 가능

**운영 노트 — 현재 키(AQ. 선불형) 무료 쿼터가 매우 작음:** gemini-2.5-flash **5 RPM / 20 RPD**. 쿼터는 모델별이라 소진 시 `.env`의 `GEMINI_CHAT_MODEL=gemini-2.5-flash-lite`로 우회 가능 (현재 .env가 이 상태). 데모/발표 전엔 RPD 잔량 확인 필수. 실서비스 전 유료 티어 전환은 기존 P2 항목 그대로.

## ✅ 눈치 엔진 + 약속조율/수락 플로우 (2026-06-11)

소개팅 대화에 "눈치"(상대 반응을 읽고 행동을 정함)를 넣고, 그게 분석·케미점수·자연스러운 종료·약속조율 감지까지 하나의 메커니즘으로 묶이도록 재설계.

**백엔드 (눈치):**
- `_SpeechOutput`에 `partner_read`(긍정적/중립/미온적) + `strategy`(알아가기/약속 제안/약속 수락/마무리) 추가 — 발화 한 콜 안에서 상대를 읽고→전략을 정한 뒤→발화. **사용자에겐 text만 노출, partner_read·strategy는 DB에만 저장**(SSE에서 분리).
- **4턴마다 돌던 분석 콜 완전 제거** — strategy/partner_read가 곧 분석 데이터. `ANALYSIS_SYSTEM_PROMPT`·`build_analysis_user_message`·`_AnalysisOutput` 삭제, `analyze` 콜백 제거. (콜 수 감소)
- **눈치 기반 조기 종료** — `services/simulation.py`: strategy="마무리"면 종료, "약속 수락"이면 상대 마무리 한 턴 더 후 종료. 고정 max_turns → 가변 길이 (비용 절감 + 현실적).
- **약속조율 감지** — strategy="약속 수락"이 나오면 `Match.appointment_ready=True`. `Match`에 `appointment_ready`(bool) + `accepted_by`(uid 배열) 컬럼 추가, alembic 0002.
- **수락 엔드포인트** — `POST /matches/{id}/accept`: 멱등 수락, 양쪽 참가자 모두 수락 시 `status="scheduled"`. mock provider도 약속수락까지 가는 대화로 교체.

**Flutter (연결 화면 = inbox_screen):**
- 진행 중 탭에서 **약속조율 완료 카드를 맨 위로 정렬 + 민트 테두리 + "약속 조율 완료" 배지**.
- 카드에 **[만남 수락하기]** 버튼 — 누르면 상대가 이미 수락한 경우 양쪽 성립 → **만남 예정 탭으로 이동**, 아니면 "상대 수락 대기" 표시. `Conversation`에 appointmentReady/partnerAccepted/youAccepted + copyWith 추가.

**검증:** 눈치 필드 실 Gemini로 정상 생성 확인(`verify_nunchi.py`), 약속조율→A수락(대기)→B수락(scheduled) mock 풀스택 통과(`verify_accept_flow.py`), flutter analyze 0 issues, 위젯 테스트 통과.

**남은 seam (다음 단계):**
- ~~⚠️ inbox는 아직 더미 데이터~~ → **2026-06-12 결선 완료** (아래 "inbox ↔ 백엔드 결선" 섹션)
- 매칭 화면(match_list): "대화 후 리포트 75점↑만 표시 + 유료 리포트"는 구조상 이미 75점 게이트+페이월 존재. 단 현재는 *대화 전* 벡터후보를 보여줌 → *대화 후* 결과 기반으로 바꾸는 건 inbost↔백엔드 결선과 함께.

## ✅ 실 Gemini 검증 + 에스컬레이션 엔진화 (2026-06-11 밤)

**voice 2차 추출 검증 통과** (`verify_voice2.py`, flash): sample_messages가 사용자 문장 *그대로* 보존, 표지 4종(ㅋㅋ/ㅠㅠ/헉/!!) 전부 생존, formality "혼용"으로 정확 추출(중립 수렴 없음), habits "헉, 헐" 포착. 1차의 한계(객관식→수렴)가 주관식으로 실제 해소됨을 실증.

**눈치 에스컬레이션 — 프롬프트 넛지로는 실패, 엔진 신호로 해결:**
- 재현된 실패: flash 8턴 + flash-lite 10턴 모두 연속 "긍정적" 읽기에도 끝까지 "알아가기" (7턴에서 제안성 *텍스트*를 내고도 strategy 라벨은 알아가기인 불일치도 관찰). 원인: 에이전트 컨텍스트엔 대화 텍스트뿐이라 자기 과거 partner_read를 셀 수 없음 — "서너 번 연속이면"은 신호 없는 희망사항.
- 수정 (`services/simulation.py`): 엔진이 연속 긍정 횟수·상대 제안 여부를 추적, **연속 긍정 3회면 ESCALATE_NUDGE, 상대 strategy="약속 제안" 직후엔 RESPOND_TO_PROPOSAL_NUDGE를 그 턴 호출에만 주입** (영구 컨텍스트 비오염, `_with_nudge` 사본). 프롬프트엔 strategy-text 일치 규칙 추가.
- 검증: 오프라인 스모크(`smoke_nunchi_engine.py`) — 주입 위치·제안→수락→마무리·9턴 종료·컨텍스트 비오염 통과. **실 Gemini에서 에스컬레이션 발화 확인** — flash-lite: B "같이 재즈바 가는 건 어때요?"=약속 제안, flash: A "조용한 카페에서 이야기 나누는 건 어떠세요?"=약속 제안 (라벨-텍스트 일치, 페르소나에 맞는 제안 내용까지).
- ⚠️ 마지막 한 단계 미검증: "약속 수락" 턴 직전에 양 모델 RPD 소진(각 20/20). **`verify_accept_turn.py` 신설 — 제안으로 끝나는 수제 history로 1콜만에 수락 판정.** 쿼터 리셋(자정 PT=한국 16시) 후 실행.

## ✅ inbox ↔ 백엔드 결선 + 풀스택 검증 (2026-06-12)

연결(inbox) 화면이 더미 대신 **GET /matches 실데이터**를 소비하고, [만남 수락하기]가 실제 `POST /matches/{id}/accept`를 때리도록 결선. Firebase 키 없이 로컬 개발이 가능하도록 dev 인증 경로 추가.

**구현:**
- `GET /matches` 신설 (`routers/matches.py` + `MatchListItem` 스키마) — 시뮬레이션이 있었던 매치만, 카드 미리보기용 최신 잡 1건 DISTINCT ON, 파트너 이름 일괄 조회
- **dev 인증 우회** — 백엔드 `DEBUG=true`에서 `Bearer dev:<uid>` 허용(`auth/firebase.py`), Flutter는 `.env`의 `DEV_UID` 설정 시 자동 사용(릴리스 빌드 항상 null, `app_config.dart`)
- `MatchRepository.listMatches()/acceptMatch()` + `inbox_screen._load()` — 백엔드 모드/더미 폴백 분기(`_fromBackend`), 수락 결과(both_accepted)에 따라 만남 예정 탭 이동 vs 상대 수락 대기
- `scripts/seed_dev_inbox.py` — mock provider 쿼터 0콜로 수아(수락대기)/민준(상대 선수락)/서연(조율 미완) 3종 카드 시드, 재실행 멱등

**풀스택 검증 통과 (실 HTTP, uvicorn 기동):**
- 무인증 401 / `dev:dev_hanchaehun` 200 — dev 경로 정상
- GET /matches 3건, 카드 상태·last_message·turn_count 정확
- accept 3케이스: 민준(상대 선수락)→**scheduled·both_accepted=true**, 수아(단독)→대기, 서연(조율 미완)→**400 NOT_READY**
- flutter analyze 0 issues, flutter test 통과. 검증 후 시드 원복 완료 — `flutter run` + `DEV_UID=dev_hanchaehun`으로 바로 데모 가능

**실기기(USB 폰) 로딩 수 분 버그 수정 (2026-06-12):**
- 원인: `AppConfig.apiBaseUrl`이 Android면 무조건 `10.0.2.2`(에뮬레이터 전용 별칭) — 실기기에선 도달 불가 주소라 요청이 90초 타임아웃까지 블랙홀 → 매 로드/새로고침 90초 후 조용히 더미 폴백(김현우/서민준/박지수가 그 증거)
- 수정: `.env`에 `API_BASE_URL=http://localhost:8000` + `adb reverse tcp:8000 tcp:8000`(USB 실기기·에뮬레이터 공통, 기기 재연결 시 재실행 필요). ApiClient 타임아웃 분리 — GET/PUT 15초(`readTimeout`, 주입 가능), LLM 경유 POST 90초 유지. 타임아웃을 `ApiException(TIMEOUT)`으로 변환(화면 일관 처리), inbox 더미 폴백 시 debugPrint로 원인 노출
- 검증: 회귀 테스트 `test/api_client_timeout_test.dart`(무응답 서버 → readTimeout 내 TIMEOUT 예외), 실폰 재빌드 후 백엔드 로그에 `GET /matches 200` 즉시 도착 + **실폰 화면에서 실데이터 카드 사용자 확인 완료**. analyze 0, test 전체 통과
- adb reverse는 영속 설정이 아님 — USB 재연결·폰/PC 재부팅·`adb kill-server` 후에만 재실행하면 됨 (앱 재실행마다는 아님)

## ▶ 다음 작업

1. **`verify_accept_turn.py` 실행 (1콜)** — 약속 수락 턴 실 Gemini 확인으로 눈치 검증 완결. 현재 .env는 flash 상태. 쿼터 리셋: 자정 PT = 한국 16시.
2. **카톡 import 설계 착수** — `docs/data_import_feasibility.md` 결정 반영: 카톡만, 온디바이스 파싱으로 본인 발화만 서버 전송, 별도 동의 화면. (Spotify/Instagram 보류)
3. match_list를 *대화 후* 결과 기반으로 — 75점 게이트+페이월은 있으나 현재는 대화 전 벡터후보 노출 (inbox 결선 완료로 착수 가능)
4. P2 잔여: agent_chat_screen SSE 실시간 결선

---

## P0 — 백엔드를 살린다 (다른 모든 것의 전제)

- [x] `backend/app/models/database.py` 작성 — User, Persona, Match, SimulationJob, Report, MeetRequest, Feedback, LLMCallLog (pgvector 1024차원 + HNSW 인덱스)
- [x] Alembic 초기 마이그레이션 (`alembic/versions/0001_initial.py`)
- [x] `backend/app/llm/prompts/` 패키지 신설 — Flutter의 검증된 한국어 프롬프트를 시드로 이관 (페르소나/시뮬레이션/리포트/스타터)
- [x] `backend/app/llm/gemini.py` provider — google-genai SDK 직접 호출, structured outputs(responseSchema), Gemini 임베딩(output_dimensionality=1024)
- [x] `factory.py`에 gemini 케이스 추가, `config.py`에 Gemini 설정 추가
- [x] KT 유산 제거 — `midm_local.py`, `hf.py` 삭제 (`mock.py`는 테스트·오프라인 데모용 유지)
- [x] `matches.py` 버그 수정 — match_id 문자열/UUID 불일치 (Match 행을 find-or-create하고 실제 UUID 반환), 거리계산 N+1 제거
- [x] 미사용 `log_llm_call` 결선 — persona/report 라우터 + 시뮬레이션 완료 시 기록
- [x] `POST /feedback` 라우터 추가 (Feedback 모델은 있었으나 엔드포인트 부재)
- [x] `PUT /users/me` 라우터 추가 — 회원가입 프로필을 Firestore 대신 Postgres에 저장
- [x] `requirements.txt`에 `google-genai` 추가
- [x] LLM_PROVIDER=mock 기준 임포트/문법 검증 (Postgres 기동 후 E2E는 별도)

## 결정 1·구조 — llm/ 폐기, matching/ 흡수

- [x] `llm/` 별도 HTTP 서비스 계획 폐기 — README를 폐기 공지 + 새 위치(`backend/app/llm/prompts/`) 안내로 교체
- [x] `matching/` 모듈을 `backend/app/matching/` 패키지로 — top-K 코사인 랭킹 로직을 라우터에서 분리, 카테고리 가중치·피드백 루프의 진화 지점 마련
- [x] `shared/schemas/` 의미 재정의 — "백엔드↔LLM서비스 HTTP 계약" → "LLM structured output 스키마 + 백엔드↔Flutter 응답 계약" (README 갱신)

## P1 — Flutter를 백엔드에 연결한다

- [x] `lib/main.dart` 문법 오류 수정 (`async async` — 컴파일 불가 상태였음)
- [x] 즉시 청소 — `app_config 2.dart`, `debug_storage_service 2.dart` (macOS 복사 충돌 중복 파일) 삭제
- [x] `AppConfig` — Groq 키/모델 제거, `API_BASE_URL` 기반 BFF 주소로 교체 (GROQ_API_KEY 앱 번들 유출 경로 차단)
- [x] 클라이언트 직접 LLM 호출 3종 제거 — `llm_service.dart`, `persona_service.dart`, `conversation_service.dart` 삭제
- [x] `lib/data/api/api_client.dart` — Firebase ID 토큰 Bearer 헤더, 공통 에러 처리(error_code/message/request_id)
- [x] `lib/data/repositories/` 계층 신설 — Persona/Match/Simulation/Report/Meet/Feedback/User repository (화면은 repository만 알게)
- [x] 시뮬레이션 SSE 소비 — `SimulationRepository`가 `/simulation/run` SSE 스트림을 파싱해 턴 단위 Stream 제공
- [x] `PersonaStore` 정적 싱글톤 폐기 — `ChangeNotifier` 기반 인스턴스 스토어(`AgentSessionStore`)로 교체, `reset()` 결선
- [x] `persona_loading_screen.dart` — initState 속 LLM 3연속 호출 제거, BFF 경유 파이프라인(persona→simulation→report)으로 교체. LLM 실패를 삼키고 null로 진행하던 경로를 명시적 폴백 플래그로 전환
- [x] 클라이언트의 Firestore 도메인 데이터 쓰기 제거 — `amori_backend.dart`를 Auth + FCM 토큰만 남기고 정리 (personas/matches/reports/meetRequests/feedback 쓰기 삭제)
- [x] 화면 결선 교체 — match_list(BFF 매칭, 빈 결과 시 더미 폴백), meet_request_send(BFF 신청), feedback(BFF 제출), login/signup(데모 시딩 제거)

## P2 — 제품 품질을 올린다

- [x] 2-에이전트 턴 루프 — `services/simulation.py` 재작성: A·B 별도 시스템 프롬프트·별도 컨텍스트, 턴마다 한쪽씩 호출, N턴마다 시그널 분석 호출 (style bleed 해소)
- [ ] Flutter 실시간 턴 표시 — agent_chat_screen의 가짜 타이핑을 SSE 실데이터 스트리밍으로 교체 (Repository는 준비됨, 화면 결선 남음)
- [ ] 임베딩 기반 `/matches/find` 실데이터화 — 실유저 페르소나가 쌓이면 더미 매치 4명(kMatches) 졸업
- [ ] match_list 카테고리별 점수(가치관/유머/대화 패턴) — `backend/app/matching/` 카테고리 가중치 고도화와 함께
- [ ] 한국어 대화 품질 평가셋 30케이스 운영 (구 llm/ 계획 승계)
- [ ] Riverpod 도입 검토 (현재는 최소 변경인 ChangeNotifier 적용 상태)
- [ ] 실서비스 전환 시 Gemini 유료 티어 전환 (무료 티어는 프롬프트 학습 사용 가능 — 실유저 PII 유입 전 필수)

## 페르소나 충실도 (voice) — 에이전트가 "나처럼" 말하기

> 진단: 24문항이 전부 객관식이라 "성향"(매칭 궁합엔 충분)은 잡지만 "말투"는 못 잡음.
> 게다가 24답변 → 8 trait → 발화의 이중 lossy 변환으로 목소리가 두 번 희석되어,
> 에이전트들이 Gemini 기본 말투로 수렴할 위험. → voice 소스 확보가 핵심.
> 방향: 단계적 (1차 백엔드 추론으로 구조부터, 2차 자유 텍스트로 실제 목소리 주입).

### 1차 — 백엔드 추론 (질문지 불변, 완료)

- [x] persona 계약에 `speech_style`(formality/emoji/laugh/sentence_length/tone/habits) + `sample_messages`(발화 예시 3개) 추가 — `shared/schemas/persona.schema.json`, Pydantic, DB 모델, alembic 0001 동시 반영 (voice-ready: 자유 텍스트 입력 추가 시 스키마 불변으로 추출만 교체)
- [x] 생성 프롬프트가 객관식 답변에서 말투를 추론하고 그 말투를 반영한 sample_messages 3개를 함께 생성
- [x] `build_agent_system_prompt`에 `[당신의 말투]` 섹션 + 발화 예시 few-shot 주입 — persona→simulation 라우터→에이전트까지 voice 결선
- [x] mock provider에도 voice 필드 (오프라인 데모/스모크 유지)

### 2차 — 자유 텍스트 입력 (2026-06-11 구현 완료)

- [x] 질문지에 주관식 3문항 추가 — `scenarios.dart` 9-1(난처함 대처)/9-2(취향 티키타카)/9-3(칭찬 반응), `isFreeText`+`hint` 필드, 플레이어에 `_FreeTextCard` 입력 UI(최소 5자, "내 AI 에이전트의 말투를 조정해요" 안내), answerLetter="주관식"으로 전송 (한채훈이 직접 설계·결정)
- [x] `build_persona`가 [말투 샘플] 섹션에서 *추출* — 샘플 우선 원칙, sample_messages는 사용자 문장 거의 그대로. 샘플 없으면 추론 폴백 + 못 뽑는 항목은 기본값(중간/빈 문자열)
- [x] 말투 감도 상향 — SpeechStyle에 `punctuation_habits`(ㅠㅠ/!!/…/~ 부호 습관) + `reaction_style`(공감형/논리형/중간) 추가. shared 스키마/Pydantic/mock/에이전트 프롬프트 주입까지 동기화. JSONB라 마이그레이션 불필요, 구 행 하위호환(기본값) 검증됨
- [x] 프롬프트 토큰 최적화 — 시뮬 시스템 프롬프트(매 턴 핫패스) ~40% 압축, 페르소나 프롬프트 ~30% 압축. 제약·의미 불변, _speech_block은 빈 값 줄 생략
- [x] 실 Gemini 추출 검증 통과 (2026-06-11, flash) — 표지 4종(ㅋㅋ/ㅠㅠ/헉/!!) 전부 생존, 사용자 문장 그대로 sample_messages, formality "혼용" 정확 추출
- [ ] (선택) 매칭 임베딩에 말투 신호 일부 반영할지 검토 — 단 궁합은 성향 기반이 맞아 신중히

## README 갱신

- [x] `README.md` (루트) — 모노레포 구조·역할·마일스톤을 피벗 이후 기준으로
- [x] `backend/README.md` — Gemini provider, 새 엔드포인트(users/feedback), prompts/ 소유권(이현정)
- [x] `llm/README.md` — 폐기 공지 + 이관 안내
- [x] `matching/README.md` — `backend/app/matching/` 패키지로 흡수 안내
- [x] `shared/schemas/README.md` — 계약 의미 재정의
- [x] `backend/app/llm/prompts/README.md` — 프롬프트 소유권·작업 가이드 신설
