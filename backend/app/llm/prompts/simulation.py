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
    """말투 지시 + 발화 예시(few-shot). 에이전트가 '이 사람처럼' 말하게 하는 앵커.

    매 턴 시스템 프롬프트로 재전송되는 핫패스 — 한 줄 key:value로 압축한다.
    빈 값(말버릇·부호 습관 없음, reaction_style 중간)은 줄 자체를 생략해 토큰을 아낀다.
    """
    style = persona.get("speech_style") or {}
    samples = persona.get("sample_messages") or []
    lines = []
    if style:
        parts = [
            style.get("formality", "존댓말"),
            f"이모지 {style.get('emoji_usage', '가끔')}",
            f"웃음 {style.get('laugh_style', 'ㅎㅎ')}",
            f"문장 {style.get('sentence_length', '보통')}",
        ]
        tones = style.get("tone_keywords") or []
        if tones:
            parts.append(f"톤 {','.join(tones)}")
        if style.get("verbal_habits"):
            parts.append(f"말버릇 {style['verbal_habits']}")
        if style.get("punctuation_habits"):
            parts.append(f"부호 습관 {style['punctuation_habits']}")
        if style.get("reaction_style") and style["reaction_style"] != "중간":
            parts.append(f"반응 {style['reaction_style']}")
        lines.append("말투(일관 유지): " + " | ".join(parts))
    if samples:
        example_lines = "\n".join(f'  · "{s}"' for s in samples)
        lines.append(f"발화 예시 — 이 어투 그대로:\n{example_lines}")
    return "\n".join(lines)


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

[눈치] 발화 전에 상대의 직전 반응을 읽고 행동을 정하세요.
- partner_read: 긍정적(호응하고 질문을 되돌려줌) | 중립(무난하지만 적극적이진 않음) | 미온적(답이 짧고 질문 없음)
- strategy: 알아가기(질문과 자기 이야기를 주고받음) | 약속 제안(충분히 긍정적일 때 만남 제안)
  | 약속 수락(상대의 만남 제안을 구체적으로 받아들임) | 마무리(미온적이거나 충분히 무르익었을 때 마무리 인사)
- text: strategy에 맞는 실제 발화. strategy와 text는 반드시 일치 — 만남·약속을 제안하는
  발화면 strategy도 '약속 제안', 상대 제안을 받아들이는 발화면 '약속 수락'이어야 합니다.
미온적인 상대에게 약속을 밀어붙이지 말고 눈치껏 마무리하세요. 반대로 상대가 계속 긍정적이면
무한정 알아가기를 반복하지 말고 약속 제안으로 넘어가세요. (괄호 안내)가 오면 그 지시를 따르세요.

규칙:
- 한 번에 한 발화, 1~3문장, 실제 메신저처럼 짧고 자연스럽게.
- 위 말투를 끝까지 일관되게 유지하고 상대 말투를 따라가지 마세요.
- 가치관이 다른 주제엔 솔직하게 자기 입장을 말하세요. 무조건 동조 금지.
- 외모·재산·학력 평가, 차별적 표현, 과도한 신체 묘사 금지.
- 응답은 JSON {{"partner_read", "strategy", "text"}} 형식으로만 반환합니다."""
