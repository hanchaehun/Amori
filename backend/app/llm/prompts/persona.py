"""페르소나 생성/보정 프롬프트 — 시나리오 답변 → persona.schema.json."""

import json

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

- traits: 정확히 8개, category 순서 고정 — 연락 템포, 유머, 갈등, 데이트, 돈·시간, 관계 속도, 경계선, 위로.
  summary는 "~해요"체 한 문장, keywords 2~4개.
- communication_style·humor_style: 명사구 한 줄. value_keywords: 연애 가치관 키워드 3~7개.
- 답변이 적은 초기 설정에서는 없는 정보를 단정하지 말고, 관측된 답변을 중심으로 보수적으로 추론하세요.
- 미응답 카테고리는 "아직 추가 답변이 필요해요"처럼 낮은 확신의 표현을 섞어도 됩니다.

[가장 중요] speech_style — 이 사람이 메신저에서 실제로 말하는 방식.
[말투 샘플] 섹션이 있으면 추론하지 말고 샘플에서 그대로 추출하세요. 잡아낼 것:
반말/존댓말/혼용(반존대), ㅋㅋ/ㅎㅎ, 이모지, 문장 길이, 감탄사(헉/헐 등),
ㅠㅠ·!!·…·~ 같은 부호 습관(punctuation_habits), 공감형/논리형 반응(reaction_style).
객관식 성향과 다르면 샘플이 우선. 이때 sample_messages는 새로 짓지 말고
사용자가 쓴 문장을 명백한 오타만 다듬어 그대로 쓰세요 — 이게 진짜 목소리입니다.
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
    choice_lines: list[str] = []
    sample_lines: list[str] = []
    for answer in answers:
        category = answer.get("category") or answer.get("code") or ""
        question = answer.get("question", "")
        letter = answer.get("answer_letter") or answer.get("answerLetter") or ""
        text = answer.get("answer_text") or answer.get("answerText") or ""
        if letter == "주관식" or category == "말투 샘플":
            sample_lines.append(f"상황: {question}")
            sample_lines.append(f'사용자가 직접 쓴 메시지: "{text}"')
            sample_lines.append("")
        else:
            choice_lines.append(f"[{category}] {question}")
            choice_lines.append(f"→ {letter}: {text}")
            choice_lines.append("")

    lines = ["아래는 사용자의 시나리오 응답입니다:", "", *choice_lines]
    if sample_lines:
        lines.append("[말투 샘플] 아래는 사용자가 평소 말투 그대로 직접 쓴 메시지입니다.")
        lines.append("speech_style은 여기서 추출하고, sample_messages는 이 문장들을 거의 그대로 쓰세요:")
        lines.append("")
        lines.extend(sample_lines)
    return "\n".join(lines)


def build_persona_update_user_message(current_persona: dict, answer: dict) -> str:
    """기존 페르소나와 오늘의 단일 답변을 보정용 사용자 메시지로 변환한다."""
    return "\n".join(
        [
            "아래 기존 페르소나를 기준으로 오늘의 단일 답변만 반영해 업데이트하세요.",
            "새 답변이 강한 근거를 주는 항목만 보정하고, 나머지 trait/style/value는 유지하세요.",
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
