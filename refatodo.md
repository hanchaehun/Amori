# AMORI 리팩토링 TODO

> 근거 문서: `docs/AMORI_리팩토링_방향.docx` (2026-06-10)
> 핵심 한 줄: **"LLM 호출 경로를 Flutter→Groq에서 Flutter→BFF→Gemini로 일원화하고, 그 전제 작업으로 존재하지 않는 DB 모델부터 작성한다."**

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

## README 갱신

- [x] `README.md` (루트) — 모노레포 구조·역할·마일스톤을 피벗 이후 기준으로
- [x] `backend/README.md` — Gemini provider, 새 엔드포인트(users/feedback), prompts/ 소유권(이현정)
- [x] `llm/README.md` — 폐기 공지 + 이관 안내
- [x] `matching/README.md` — `backend/app/matching/` 패키지로 흡수 안내
- [x] `shared/schemas/README.md` — 계약 의미 재정의
- [x] `backend/app/llm/prompts/README.md` — 프롬프트 소유권·작업 가이드 신설
