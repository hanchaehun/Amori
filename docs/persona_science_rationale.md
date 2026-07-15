# AMORI 페르소나 설계의 심리학·인문학적 근거 (2026-07-15)

> 이 문서의 역할: "왜 이렇게 설계하고 문항을 이렇게 구성했는가"를 나중에 다시 추적할 수
> 있게 하는 근거 원장. 실행 계획은 `refatodo.md`, 기술 설계는
> `docs/persona_fidelity_design.md`, 코드 매핑은 `backend/app/llm/psych_mapping.py`.

## 1. 대전제 — 매칭은 예측이 안 되므로, 페르소나 충실도가 제품의 전부다

- **Joel, Eastwick & Finkel (2017, *Psychological Science*)**: 스피드데이팅 참가자의
  100+ 특성·선호에 머신러닝(랜덤 포레스트)을 적용해도 **쌍(dyad) 고유의 끌림은 예측
  불가**했다 (개인 성향 분산은 4~18% 예측, 관계 분산은 0에 수렴).
  [논문](https://journals.sagepub.com/doi/10.1177/0956797617714580)
- **Eastwick & Finkel (2008, *JPSP*)**: 사전에 진술한 이상형(명시적 선호)은 실제
  대면 후의 끌림을 예측하지 못한다.
- **AMORI에의 함의**: "특성이 비슷하면/보완적이면 잘 맞는다"는 매칭 공식은 만들 수 없다.
  그래서 AMORI는 예측 대신 **시뮬레이션**(에이전트끼리 실제로 대화)을 택했고, 이 선택이
  성립하려면 **에이전트가 본인을 충실히 재현해야 한다**. 페르소나가 부정확하면 시뮬은
  소설이다. 같은 근거로 ① 매칭 임베딩은 후보 검색까지만 ② 정답지(받고 싶은 반응)는
  매칭 하드필터 금지 ③ MBTI 유형 궁합 규칙 금지.

## 2. 왜 설문보다 자유 발화(와 궁극적으로는 인터뷰)인가

- **Park et al. (2024→HAI '25), "Generative Agent Simulations of 1,000 People"**:
  1,052명을 **2시간 자유 응답 인터뷰**로 수집해 LLM 에이전트를 만들자, 2주 뒤 본인의
  General Social Survey 응답을 **본인 재검사 신뢰도의 85%** 수준으로 재현. 설문+인구통계
  기반 에이전트보다 정확했고 인종·이념 편향도 줄었다.
  [arXiv](https://arxiv.org/pdf/2411.10109) ·
  [Stanford HAI 해설](https://hai.stanford.edu/news/ai-agents-simulate-1052-individuals-personalities-impressive-accuracy)
- **함의**: 정보는 문항 수가 아니라 **형식**에서 나온다. 객관식 1문항 ≈ 2비트,
  자유 발화 한 문장은 내용(성향)+형식(말투)을 동시에 실어 나른다. 그래서 온보딩에
  주관식(9-1·9-2)을 편입했고, 장기적으로 온보딩 전체의 대화형 전환(팀 합의 대기)이
  A등급 개선이다. LLM 대화 기반 성격 평가의 타당성 검증도 진행 중인 연구 흐름이다
  ([arXiv 2602.15848](https://www.arxiv.org/pdf/2602.15848)).

## 3. trait 가변화 — 바넘 효과 제거 (P0-A)

- **Forer (1949)의 고전 실험**: 누구에게나 맞는 모호한 성격 기술문을 주면 사람들은
  "정확히 나다"라고 평가한다(바넘/포러 효과). 점성술·혈액형 성격론이 작동하는 기제.
- **역설**: 바넘 문장은 "나 같다"는 착각을 만들지만, AMORI에선 정반대로 작동한다 —
  사용자는 자기 답변(5문항)을 기억하므로, 답하지 않은 영역의 단정("돈 관리에 계획적이에요")은
  즉시 "근거 없음"으로 read되고 제품 신뢰를 무너뜨린다.
- **구현**: 답변이 근거(evidence)를 주는 카테고리만 trait 생성, confidence는 LLM
  자기보고가 아니라 **코드가 evidence 개수로 계산**(LLM의 확신도 자기보고는 보정되지
  않은 값이라 신뢰 불가). 빈 카테고리는 "아직 알아가는 중" — 정직함이 곧 데일리 질문의
  리텐션 훅이 된다.

## 4. 온보딩 7문항 — "축당 2문항" 하한

- **초단축 척도의 전통**: Gosling et al. (2003) **TIPI**(Big Five를 10문항 = 축당 2개),
  Rammstedt & John (2007) **BFI-10**(동일), Wei et al. (2007) **ECR-S**(애착 2축을
  12문항). 공통 원칙: **축당 1문항은 노이즈, 2문항이 실용 하한, 3+는 이탈 비용이
  정확도 이득을 넘는다.**
- **AMORI 적용**: 온보딩이 확보해야 할 축 = 관계 목적(1), 애착(2: R-2·8-3), 갈등(1: R-3),
  가치관(1: R-5) + 말투 표본(주관식 2). 합계 7문항 — 지금 구성이 심리측정학적 하한이며,
  줄일 것도 늘릴 것도 없다. 8문항 여유가 생기면 객관식이 아니라 **주관식(9-3)**을 넣는
  것이 최고 효율(주관식 3개 = voice_confidence 0.35, 격식·웃음 습관 안정선).
- **R-4 → 8-3 교체 이유**: R-4("어떤 위로를 받고 싶나")는 선호 문항이라 trait 근거가
  못 되고(6절), 8-3("답장이 짧아졌을 때 나는")은 애착-불안 축의 행동 문항이다.
  교체로 애착 축이 2문항 하한을 채운다.

## 5. 애착 이론 — 데이팅 도메인의 최강 예측 변수 (P0-B)

- **이론 계보**: Bowlby(애착 이론) → Ainsworth(유형화) → Hazan & Shaver (1987,
  성인 연애로 확장) → Brennan, Clark & Shaver (1998, **ECR**: 불안/회피 2차원 척도).
- **경험적 근거**: 애착 불안/회피는 관계 만족·갈등 행동·이별 반응을 일관되게 예측하는,
  연애 도메인에서 Big Five보다 강한 축이다. 데이팅 앱 연구에서도 표준 —
  [PRISMA 체계적 문헌고찰 (European Psychologist)](https://econtent.hogrefe.com/doi/10.1027/1016-9040/a000576),
  [ECR-S 단축형](https://novopsych.com/assessments/formulation/experience-in-close-relationship-scale-short-form-ecr-s/).
  불안 애착 사용자는 답장 지연에 민감하고 재확인을 추구하며, 회피 애착은 자기개방이
  낮고 거리를 조절한다 — 시뮬레이션의 "서운할 때 반응"이 이 축에서 나온다.
- **AMORI 구현 원칙**: ECR 문항을 새로 받지 않는다(설문 피로 금지). 기존 R-2(연락
  민감도)·R-3(서운함 대처)·8-3(관계 불안 시 행동)이 이미 애착 축과 겹치므로
  **결정적 매핑 테이블**(psych_mapping.py, P0-B)로 변환한다. 산출은 "안정-약간 불안"
  같은 **hint 어투만** — 단정 진단 금지, 사용자 공개·수정 가능(11절 프라이버시).

## 6. 관점 분리 — behavior vs preference (P0-F)

- **근거 1**: Eastwick & Finkel (2008) — 명시적 선호("이런 사람/반응이 좋다")는 실제
  행동·끌림과 분리된 별개 축이다. 선호 답변으로 "이 사람은 이렇다"는 trait을 만들면
  범주 오류.
- **근거 2**: **Vazire (2010, *JPSP*) SOKA 모델** — 자기보고는 내면 상태(불안 등)에
  강하고 관찰 가능한 행동 습관엔 타인 평가보다 약하다. 자기보고(객관식)와 행동
  표본(자유 발화)을 병행하는 현 구조의 이론적 근거.
- **구현**: 문항마다 `measures: behavior|preference` 분류(psych_mapping.py).
  behavior → trait evidence + conversation_policy. preference → 정답지·리포트
  반응성 축(Reis의 '지각된 파트너 반응성' — 이해·인정·관심). 유머 문항(2-x)이 전부
  preference(상대 유머 수용도)라는 발견이 이 분류의 대표 사례 — 내 유머는 주관식
  실발화에서만 관측된다.

## 7. 말투 — 측정·재현·후편집의 3단 구조

- **스타일로메트리 전통**: Pennebaker & King (1999) 이후 언어 스타일 연구의 합의 —
  **스타일 지문은 내용어가 아니라 기능어**에 있다. 한국어에선 어미·조사가 그 역할
  (LIWC 계열). 그래서 voice_features.py는 어미(존/반말)·웃음·부호·문장 길이를 재고,
  형태소 분석기(Kiwi) 도입이 P1 해상도 업그레이드다.
- **LLM 한계 근거**: "Catch Me If You Can" (2025) — few-shot 2~5개 in-context
  learning은 **평균 스타일로 회귀**해 일반인 모사가 안 된다. 보완책이 ① 측정값 수치
  지시 ② 생성 후 결정적 후편집(style_gate) ③ 표본 확대(미리보기 수정문·데일리 주관식) —
  전부 현 파이프라인에 반영됨. 트레이트→언어 마커 변환 자체는 반복 검증됨
  (Mairesse et al. 2007; PersonaLLM; [Big5-Chat, ACL 2025](https://aclanthology.org/2025.acl-long.999.pdf)).
- **왜 말투 통계를 LLM에 안 맡기나**: LLM은 세고(count) 비율을 내는 작업에서 값을
  지어낸다. 정규식 카운팅은 정확·재현 가능·무비용. "말투는 추측하지 말고 측정한다"
  (persona_fidelity_design.md §4)의 근거.
- **조율(accommodation) 허용 범위**: Giles의 의사소통 조율 이론(CAT)과 Ireland &
  Pennebaker의 언어 스타일 매칭(LSM) 연구 — 실제 사람은 대화 상대에게 어느 정도
  수렴하며, 수렴 정도가 관계 관심의 신호이기도 하다. 따라서 "상대 말투를 절대 따라가지
  마라"는 전면 금지는 style bleed는 막지만 부자연스럽다. 시뮬 지시는 **"화제·에너지는
  수렴 가능, 어미·습관·이모지·부호는 고정"**으로 수렴 허용 범위를 명시한다 (P0-B).

## 8. 의도적 오타·비표준 표기 — 지우지도, 과장하지도 않는다 (P0-D)

- **사회언어학 근거**: 표기 선택은 오류가 아니라 **정체성 수행**이다 — Sebba (2007,
  *Spelling and Society*): 규범을 벗어난 철자는 사회적 의미를 실어 나르는 기호 자원.
  한국 온라인 언어의 "마쟈", "넹", "구캥" 류 변이도 동일 기제(친밀도·귀여움·세대 표지).
  맞춤법 교정은 곧 목소리 삭제다.
- **빈도의 문제 (2026-07-15 팀 논의)**: 변형 표기에는 "항상 쓰는 것"과 "가끔 쓰는 것"이
  있다. 1회 관측된 표기를 모든 발화에 재현하면 모사가 아니라 캐리커처가 된다.
  - v1: 프롬프트 빈도 보정 — "반복 관측된 표기는 자주, 1회 관측은 가끔만".
  - v2(표본 축적 후): voice_features에 변형 토큰 빈도 통계 추가 + style_gate 과다 사용 감쇠.
  - 자유입력("평소에 이렇게 써요")은 사용자의 **습관 선언**이므로 항상-급으로 취급.

## 9. MBTI — 심리측정학이 아니라 제품 논리로 받는다 (P0-E)

- **비판 문헌**: Pittenger (1993; 2005) — 이분법 강제(연속 분포를 절단해 중간 점수인
  다수가 극단과 같은 유형이 됨), 유형 재검사 불안정. 학계 표준은 요인분석 기반
  **Big Five**. 단 2025년 메타분석(Erford, [*J. Counseling & Development*](https://onlinelibrary.wiley.com/doi/10.1002/jcad.70006))에서
  내적 일관성 자체는 양호(α .85~.92) — "신뢰도는 있으나 유형론이 문제"가 공정한 요약.
  [비교 정리](https://www.thepersonalitylab.org/blog-posts/the-science-of-personality-comparing-mbti-big-five-and-enneagram-validity-in-2025)
- **그래도 받는 이유**: ① 한국 사용자 전원이 이미 알고 있는 무료 데이터 ② 데이팅
  프로필의 사실상 기대 기능 ③ **McCrae & Costa (1989)**: MBTI 4축은 Big Five와 유의미한
  상관(E/I↔외향성, S/N↔개방성, T/F↔친화성, J/P↔성실성) — 약한 prior로 변환 가능.
- **금지선**: 유형 궁합표 기반 매칭 금지(근거 없음 + 1절의 예측 불가 결론), 시뮬 주입
  금지(v1), "MBTI로 매칭" 문구 금지. 용도는 프로필 표시 + big_five 초기값(confidence
  0.2, 실답변 증거가 쌓이면 자연 희석)뿐.

## 10. 미리보기·수정권 — 충실도 루프의 심장 (P0-C)

- **왜**: 자기보고와 LLM 추론 모두 오류가 있고(6절 SOKA), 그 오류를 본인만이 교정할
  수 있다. 수정문은 최고 등급(user_written) 표본으로 재수집되므로, 수정 행위 자체가
  데이터 파이프라인이다 — "고칠수록 나다워진다"가 문자 그대로 참.
- **측정 프록시**: 미리보기 수정률(발화 3개 중 몇 개를 고치는가)이 충실도의 무료
  지표. LLM 저지 블라인드 테스트(실발화 vs 에이전트 발화 구분율 60% 이하 목표)와
  삼각측량(P1).

## 11. 프라이버시·윤리 원칙

- 추론된 심리 프로파일(애착 hint, big_five)은 **사용자에게 공개하고 수정·숨김권**을
  준다. 리포트에서 단정적 성격 판정 문구 금지("당신은 불안 애착입니다" ✕).
- 심리 추론은 프로파일링 고지 대상으로 취급 — 매칭 선호 성별(민감정보) 분리 동의와
  같은 결의 원칙 (상세: persona_fidelity_design.md §3-3 동의 화면 요건).
- 정답지·선호 데이터는 평가 전용 — 시뮬 주입 시 "모두가 모두와 잘 맞는" 조작이 된다.

## 12. 문항 → 축 매핑 요약 (v1)

| 문항 | measures | 잡는 축 | 비고 |
|---|---|---|---|
| R-1 | behavior | 관계 목적/속도 | 명시적 사실 — 1문항 충분 |
| R-2 | preference | 애착-불안 ① | 선택지 재작성 제안(고불안 선택지 부재) — 팀 결정 |
| R-3 | behavior | 갈등 모드, 접근/회피 | conversation_policy 직결 |
| 8-3 | behavior | 애착-불안 ② | 온보딩 승격(구 R-4 자리) |
| R-5 | behavior | 가치관 | value_keywords |
| 9-1·9-2 | behavior | 말투(난처/취향 레지스터) | voice_stats·few-shot 원천 |
| R-4, 8-1 | preference | 위로 선호 → 정답지 | 데일리 정답지 페어로 이동 |
| 2-x | preference | 유머 수용도 | 내 유머는 주관식·10-9에서만 |
| 전체 분류 | — | — | `backend/app/llm/psych_mapping.py` MEASURES |

## 참고 문헌 (본문 순)

- Joel, Eastwick & Finkel (2017). Is Romantic Desire Predictable? *Psych. Science*. — [link](https://journals.sagepub.com/doi/10.1177/0956797617714580)
- Eastwick & Finkel (2008). Sex differences in mate preferences revisited. *JPSP*.
- Park et al. (2024). Generative Agent Simulations of 1,000 People. — [arXiv:2411.10109](https://arxiv.org/pdf/2411.10109), [Stanford HAI](https://hai.stanford.edu/news/ai-agents-simulate-1052-individuals-personalities-impressive-accuracy)
- Can LLMs Assess Personality? (2026). — [arXiv:2602.15848](https://www.arxiv.org/pdf/2602.15848)
- Forer (1949). The fallacy of personal validation. *J. Abnormal & Social Psych.*
- Gosling, Rentfrow & Swann (2003). TIPI. *J. Research in Personality*.
- Rammstedt & John (2007). BFI-10. *J. Research in Personality*.
- Hazan & Shaver (1987). Romantic love conceptualized as attachment. *JPSP*.
- Brennan, Clark & Shaver (1998). ECR. In *Attachment Theory and Close Relationships*.
- Wei et al. (2007). ECR-Short Form. *J. Personality Assessment*. — [scale](https://novopsych.com/assessments/formulation/experience-in-close-relationship-scale-short-form-ecr-s/)
- Attachment Styles and Dating App Use: PRISMA review. *European Psychologist*. — [link](https://econtent.hogrefe.com/doi/10.1027/1016-9040/a000576)
- Vazire (2010). Who knows what about a person? SOKA model. *JPSP*.
- Pennebaker & King (1999). Linguistic styles. *JPSP*. (LIWC 계열)
- Mairesse et al. (2007). Using linguistic cues for personality recognition. *JAIR*.
- Big5-Chat (2025). *ACL*. — [paper](https://aclanthology.org/2025.acl-long.999.pdf)
- Catch Me If You Can (2025). few-shot 스타일 모사의 평균 회귀. (persona_fidelity_design.md §9-3)
- Sebba (2007). *Spelling and Society*. Cambridge UP.
- Giles (1973~). Communication Accommodation Theory (CAT).
- Ireland & Pennebaker (2010). Language style matching in writing. *JPSP*.
- Pittenger (1993; 2005). MBTI 비판. *Review of Educational Research*; *Consulting Psych. J.*
- Erford (2025). MBTI Form M 25-year synthesis. *J. Counseling & Development*. — [link](https://onlinelibrary.wiley.com/doi/10.1002/jcad.70006)
- McCrae & Costa (1989). Reinterpreting the MBTI. *J. Personality*.
- Reis & Shaver (1988). Intimacy as interpersonal process. (지각된 파트너 반응성)
