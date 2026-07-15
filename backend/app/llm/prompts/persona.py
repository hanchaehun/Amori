"""페르소나 생성/보정 프롬프트 — 시나리오 답변 → persona.schema.json."""

import json

from app.llm.psych_mapping import measures

PERSONA_TRAIT_CATEGORIES = [
    "연락 템포",
    "유머",
    "갈등",
    "데이트",
    "돈·시간",
    "관계 속도",
    "경계선",
    "위로",
]

PERSONA_SYSTEM_PROMPT = """당신은 연애 심리 분석 전문가입니다. 사용자의 시나리오 응답을 분석해
데이팅 페르소나 JSON을 한국어로 생성하세요.

- traits: **답변이 실제 근거를 주는 카테고리만** 생성하세요 (1~8개). 카테고리는
  연락 템포, 유머, 갈등, 데이트, 돈·시간, 관계 속도, 경계선, 위로 중에서만.
  근거 없는 카테고리를 지어내는 것은 금지입니다 — 빈 카테고리는 앱이 따로 처리합니다.
- 각 trait에 evidence: 그 성향의 근거가 된 답변 코드 목록 (예 ["R-3:A", "3-1:B"]).
  evidence를 쓸 수 없는 trait이라면 그 trait은 만들지 마세요.
- evidence는 [성향·행동 답변] 섹션에서만 가져오세요. [선호 답변] 섹션은 "상대에게
  원하는 것"이라 이 사람의 성향 근거가 아닙니다 — value_keywords 참고로만 쓰세요.
- summary는 "~해요"체 한 문장, keywords 2~4개.
- communication_style·humor_style: 명사구 한 줄. value_keywords: 연애 가치관 키워드 3~7개.
  humor_style은 말투 샘플에서 유머가 실제로 관측될 때만 구체적으로 — 아니면 "아직 파악 중"으로.
- 없는 정보를 단정하지 말고, 관측된 답변만으로 보수적으로 추론하세요.
- big_five: 답변이 근거를 주면 5축(E 외향성/A 친화성/C 성실성/N 신경성/O 개방성)을
  0~1로 추정하고 evidence에 근거 답변 코드를 쓰세요. 근거가 약한 축은 0.5로 두고,
  전체적으로 근거가 없으면 big_five 자체를 생략하세요.

[가장 중요] speech_style — 이 사람이 메신저에서 실제로 말하는 방식.
[말투 샘플] 섹션이 있으면 추론하지 말고 샘플에서 그대로 추출하세요. 잡아낼 것:
반말/존댓말/혼용(반존대), ㅋㅋ/ㅎㅎ, 이모지, 문장 길이, 감탄사(헉/헐 등),
ㅠㅠ·!!·…·~ 같은 부호 습관(punctuation_habits), 공감형/논리형 반응(reaction_style).
객관식 성향과 다르면 샘플이 우선. 이때 sample_messages는 새로 짓지 말고
사용자가 쓴 문장을 **한 글자도 다듬지 말고** 그대로 쓰세요. 오타·줄임·비표준
표기도 그 사람의 목소리입니다 — 맞춤법 교정은 목소리를 지우는 일입니다.
샘플이 없으면 답변 성향에서 추론하되, 근거가 약한 항목은 기본값:
존댓말/가끔/보통/reaction_style=중간/verbal_habits·punctuation_habits=빈 문자열.

- formality: 반말|존댓말|혼용  - emoji_usage: 거의 안 씀|가끔|자주
- laugh_style: 예 "ㅋㅋ","ㅎㅎ","안 씀"  - sentence_length: 짧고 간결|보통|길게 풀어 씀
- tone_keywords: 2~4개  - verbal_habits: 감탄사·말버릇 (없으면 "")
- punctuation_habits: ㅠㅠ/!!/…/~ 등 (없으면 "")  - reaction_style: 공감형|논리형|중간

sample_messages: 사용자가 직접 쓴 말투 샘플 1~3개. 에이전트 말투의 기준점.
외모·재산·학력 평가, 차별적 표현 금지."""


def build_persona_user_message(answers: list[dict]) -> str:
    """시나리오 답변 목록을 분석용 사용자 메시지로 변환한다.

    answers 항목은 Flutter가 보내는 형태를 따른다:
    ``{code, category, question, answer_letter, answer_text}`` (snake/camel 혼용 허용).

    주관식(말투 샘플) 답변은 객관식과 분리해 [말투 샘플] 섹션으로 모은다 —
    시스템 프롬프트가 이 섹션에서 speech_style을 추출하고 사용자 문장을
    sample_messages로 쓰도록 지시한다 (voice 2차).
    """
    behavior_lines: list[str] = []
    preference_lines: list[str] = []
    sample_lines: list[str] = []
    for answer in answers:
        category = answer.get("category") or answer.get("code") or ""
        question = answer.get("question", "")
        letter = answer.get("answer_letter") or answer.get("answerLetter") or ""
        text = answer.get("answer_text") or answer.get("answerText") or ""
        if letter == "정답지" or category == "정답지":
            # 정답지("받고 싶은 답장")는 평가 전용 축 — 내 성향·말투가 아니므로
            # 페르소나 생성 프롬프트에서 제외한다 (services/voice.py가 별도 저장).
            continue
        if letter == "주관식" or category == "말투 샘플":
            sample_lines.append(f"상황: {question}")
            sample_lines.append(f'사용자가 직접 쓴 메시지: "{text}"')
            sample_lines.append("")
            continue
        # 관점 분리 (P0-F): 행동·취향 답변만 trait 근거, 선호 답변은 참고 —
        # 분류표·근거는 psych_mapping.py / docs/persona_science_rationale.md
        code = str(answer.get("code") or "")
        target = behavior_lines if measures(code) == "behavior" else preference_lines
        target.append(f"[{category}] ({code}) {question}")
        target.append(f"→ {letter}: {text}")
        target.append("")

    lines = ["아래는 사용자의 시나리오 응답입니다:", ""]
    if behavior_lines:
        lines.append("[성향·행동 답변] 이 사람이 어떻게 행동하고 무엇을 중요하게 여기는지:")
        lines.append("")
        lines.extend(behavior_lines)
    if preference_lines:
        lines.append("[선호 답변] 상대·관계에서 원하는 것 — trait 근거 금지, 참고만:")
        lines.append("")
        lines.extend(preference_lines)
    if sample_lines:
        lines.append("[말투 샘플] 아래는 사용자가 평소 말투 그대로 직접 쓴 메시지입니다.")
        lines.append("speech_style은 여기서 추출하고, sample_messages는 이 문장들을 거의 그대로 쓰세요:")
        lines.append("")
        lines.extend(sample_lines)
    return "\n".join(lines)


def build_persona_update_user_message(current_persona: dict, answer: dict) -> str:
    """기존 페르소나와 오늘의 단일 답변을 보정용 사용자 메시지로 변환한다."""
    # embedding은 LLM에 무의미한 1024개 수치(토큰 낭비)인 데다 pgvector가
    # numpy float32로 돌려줘 json.dumps가 죽는다 — 프롬프트에서 제외 (E2E 7/15 발견).
    current_persona = {k: v for k, v in current_persona.items() if k != "embedding"}
    return "\n".join(
        [
            "아래 기존 페르소나를 기준으로 오늘의 단일 답변만 반영해 업데이트하세요.",
            "새 답변이 강한 근거를 주는 항목만 보정하고, 나머지 trait/style/value는 유지하세요.",
            "새 답변이 아직 없던 카테고리의 근거가 되면 그 trait을 추가하세요 (evidence에 답변 코드).",
            "기존 trait의 evidence는 유지하고, 이번 답변이 근거가 되면 코드를 추가하세요.",
            "user_edited=true인 trait은 절대 수정하지 말고 그대로 반환하세요.",
            "말투 샘플 답변이면 sample_messages에 추가하되 전체는 최대 3개까지만 유지하세요.",
            "",
            "[기존 페르소나 JSON]",
            json.dumps(current_persona, ensure_ascii=False),
            "",
            "[오늘의 답변]",
            json.dumps(answer, ensure_ascii=False),
        ]
    )


def persona_embedding_text(persona: dict) -> str:
    """페르소나 임베딩 입력 텍스트 — 매칭 벡터의 의미 표면."""
    trait_lines = [
        f"{t['category']}: {t['summary']} ({', '.join(t['keywords'])})"
        for t in persona.get("traits", [])
    ]
    return "\n".join(
        [
            f"대화 스타일: {persona.get('communication_style', '')}",
            f"유머 스타일: {persona.get('humor_style', '')}",
            f"가치관: {', '.join(persona.get('value_keywords', []))}",
            *trait_lines,
        ]
    )
