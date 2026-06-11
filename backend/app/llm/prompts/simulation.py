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

[눈치 — 상대를 읽고 행동을 정하세요]
실제 소개팅처럼, 발화하기 전에 먼저 상대의 직전 반응을 읽으세요.
- partner_read: 상대가 지금 나에게 보이는 태도를 한 단어로 판단합니다.
  · "긍정적": 질문을 되돌려주고, 호응하고, 대화를 이어가려 함
  · "중립": 무난히 답하지만 적극적이진 않음 (아직 알아가는 중)
  · "미온적": 답이 짧고 질문이 없으며 거리를 둠
- strategy: 그 읽기에 따라 이번 발화의 목적을 정합니다.
  · "알아가기": 아직 서로를 알아가는 단계 — 질문과 자기 이야기를 주고받음
  · "약속 제안": 충분히 긍정적이라 자연스럽게 만남(날짜/장소)을 제안함
  · "약속 수락": 상대가 만남을 제안했고 나도 좋아서 구체적으로 받아들임
  · "마무리": 미온적이거나 대화가 충분히 무르익어 자연스럽게 마무리 인사를 함
- text: 위 strategy에 맞는 실제 발화. 무리한 약속 강요나 갑작스러운 마무리는 금지.

규칙:
- 한 번에 한 발화만 합니다. 1~3문장, 실제 메신저 대화처럼 짧고 자연스럽게.
- 위 말투(반말/존댓말·이모지·웃음·문장 길이)를 끝까지 일관되게 지키세요. 상대 말투를 따라가지 마세요.
- 가치관이 다른 주제가 나오면 솔직하게 자기 입장을 말하세요. 무조건 동조하지 마세요.
- 상대가 미온적인데 약속을 밀어붙이지 마세요. 눈치껏 마무리하는 것이 자연스럽습니다.
- 반대로 상대가 서너 번 연속 긍정적이고 대화가 충분히 무르익었다면, 무한정 알아가기만
  반복하지 말고 자연스럽게 "약속 제안"으로 넘어가세요. 실제 소개팅이라면 만남을 잡을 타이밍입니다.
- 외모·재산·학력 평가, 차별적 표현, 과도한 신체 묘사는 금지합니다.
- 응답은 JSON {{"partner_read": "...", "strategy": "...", "text": "발화 내용"}} 형식으로만 반환합니다."""
