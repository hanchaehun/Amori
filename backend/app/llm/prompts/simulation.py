"""2-에이전트 시뮬레이션 프롬프트.

각 에이전트는 자기 페르소나만 담긴 별도 시스템 프롬프트를 가진다 —
한 컨텍스트에서 양쪽 대사를 생성할 때 생기는 말투 수렴(style bleed)을 막기 위함.
"""


def _persona_block(persona: dict) -> str:
    trait_lines = [
        f"- {t['category']}: {t['summary']} (키워드: {', '.join(t['keywords'])})"
        for t in persona.get("traits", [])
    ]
    return "\n".join(
        [
            f"대화 스타일: {persona.get('communication_style', '')}",
            f"유머 스타일: {persona.get('humor_style', '')}",
            f"가치관 키워드: {', '.join(persona.get('value_keywords', []))}",
            *trait_lines,
        ]
    )


def _speech_block(persona: dict) -> str:
    """말투 지시 + 발화 예시(few-shot). 에이전트가 '이 사람처럼' 말하게 하는 앵커."""
    style = persona.get("speech_style") or {}
    samples = persona.get("sample_messages") or []
    lines = []
    if style:
        habits = style.get("verbal_habits") or "특별한 말버릇 없음"
        lines.append(
            "말투를 다음과 같이 일관되게 유지하세요:\n"
            f"- 말투: {style.get('formality', '존댓말')}\n"
            f"- 이모지: {style.get('emoji_usage', '가끔')}\n"
            f"- 웃음 표현: {style.get('laugh_style', 'ㅎㅎ')}\n"
            f"- 문장 길이: {style.get('sentence_length', '보통')}\n"
            f"- 톤: {', '.join(style.get('tone_keywords', []))}\n"
            f"- 말버릇: {habits}"
        )
    if samples:
        example_lines = "\n".join(f'  · "{s}"' for s in samples)
        lines.append(
            "이 사람이 실제로 쓸 법한 메시지 예시입니다. 이 어투를 그대로 따르세요:\n"
            f"{example_lines}"
        )
    return "\n\n".join(lines)


def build_agent_system_prompt(own_persona: dict, partner_hint: str = "") -> str:
    """한쪽 에이전트의 시스템 프롬프트 — 자기 페르소나만 안다."""
    partner_line = f"\n상대에 대해 알고 있는 것: {partner_hint}" if partner_hint else ""
    speech_block = _speech_block(own_persona)
    speech_section = f"\n\n[당신의 말투]\n{speech_block}" if speech_block else ""
    return f"""당신은 소개팅 앱에서 사용자를 대신해 대화하는 AI 에이전트입니다.
아래 페르소나를 가진 사람처럼 자연스러운 한국어 구어체로 대화하세요.

[당신의 페르소나]
{_persona_block(own_persona)}
{partner_line}{speech_section}

규칙:
- 한 번에 한 발화만 합니다. 1~3문장, 실제 메신저 대화처럼 짧고 자연스럽게.
- 위 말투(반말/존댓말·이모지·웃음·문장 길이)를 끝까지 일관되게 지키세요. 상대 말투를 따라가지 마세요.
- 상대를 알아가기 위한 질문과 자기 이야기의 균형을 지키세요.
- 가치관이 다른 주제가 나오면 솔직하게 자기 입장을 말하세요. 무조건 동조하지 마세요.
- 외모·재산·학력 평가, 차별적 표현, 과도한 신체 묘사는 금지합니다.
- 응답은 JSON {{"text": "발화 내용"}} 형식으로만 반환합니다."""


ANALYSIS_SYSTEM_PROMPT = """당신은 소개팅 대화 분석가입니다.
두 AI 에이전트의 최근 대화를 보고 궁합 시그널을 추출하세요.
반드시 한국어 JSON으로만 응답합니다:

{
  "has_signal": true,
  "system_text": "🔍 공통 관심사 발견: 여행",
  "signal": "여행 시그널"
}

규칙:
- 새로 발견된 공통점·가치관 일치·대화 패턴 궁합이 있을 때만 has_signal을 true로.
- system_text는 이모지로 시작하는 한 줄 분석 메시지.
- signal은 짧은 라벨 (예: "여행 시그널", "가치관 매치", "대화 템포 일치").
- 특별한 시그널이 없으면 has_signal을 false로 하고 나머지는 빈 문자열로."""


def build_analysis_user_message(recent_turns: list[dict]) -> str:
    lines = ["최근 대화:"]
    for turn in recent_turns:
        speaker = "사용자AI" if turn["speaker"] == "me" else "상대방AI"
        lines.append(f"{speaker}: {turn['text']}")
    return "\n".join(lines)
