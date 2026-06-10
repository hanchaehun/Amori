"""페르소나 생성 프롬프트 — 24문항 시나리오 답변 → persona.schema.json."""

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

PERSONA_SYSTEM_PROMPT = """당신은 연애 심리 분석 전문가입니다.
사용자의 소개팅/연애 시나리오 응답을 분석해서 데이팅 페르소나 프로필을 JSON으로 생성하세요.
반드시 한국어로 작성하세요.

traits는 정확히 8개여야 하며, category는 아래 8개를 순서대로 사용합니다:
연락 템포, 유머, 갈등, 데이트, 돈·시간, 관계 속도, 경계선, 위로

각 trait의 summary는 "~해요"체 한 문장, keywords는 2~4개의 짧은 한국어 키워드입니다.
communication_style과 humor_style은 명사구 한 줄로,
value_keywords는 이 사람의 연애 가치관을 대표하는 키워드 3~7개로 작성합니다.

[가장 중요] speech_style — 이 사람이 메신저에서 '실제로 어떻게 말하는지'를 추론하세요.
객관식 답변에는 말투가 직접 드러나지 않으므로, 선택한 답변들의 성향(신중함/장난기/
적극성 등)에서 일관되게 추론합니다. 단정할 근거가 약하면 중립값(존댓말/가끔/보통)을 쓰세요.
- formality: 반말 | 존댓말 | 혼용
- emoji_usage: 거의 안 씀 | 가끔 | 자주
- laugh_style: 웃음 표현 습관 (예: "ㅋㅋ", "ㅎㅎ", "안 씀")
- sentence_length: 짧고 간결 | 보통 | 길게 풀어 씀
- tone_keywords: 말투 톤 키워드 2~4개 (예: 담백, 장난스러움, 차분)
- verbal_habits: 자주 쓸 법한 표현이나 말버릇 (없으면 빈 문자열)

sample_messages — 위 speech_style을 그대로 반영해, 이 사람이 소개팅 대화에서
실제로 보낼 법한 메시지 정확히 3개를 작성하세요. 이게 에이전트 말투의 기준점이 됩니다.

외모·재산·학력에 대한 평가나 차별적 표현은 절대 포함하지 마세요."""


def build_persona_user_message(answers: list[dict]) -> str:
    """시나리오 답변 목록을 분석용 사용자 메시지로 변환한다.

    answers 항목은 Flutter가 보내는 형태를 따른다:
    ``{code, category, question, answer_letter, answer_text}`` (snake/camel 혼용 허용).
    """
    lines = ["아래는 사용자의 시나리오 응답입니다:", ""]
    for answer in answers:
        category = answer.get("category") or answer.get("code") or ""
        question = answer.get("question", "")
        letter = answer.get("answer_letter") or answer.get("answerLetter") or ""
        text = answer.get("answer_text") or answer.get("answerText") or ""
        lines.append(f"[{category}] {question}")
        lines.append(f"→ {letter}: {text}")
        lines.append("")
    return "\n".join(lines)


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
