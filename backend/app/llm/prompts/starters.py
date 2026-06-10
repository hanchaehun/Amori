"""대화 스타터 프롬프트 — starter.schema.json."""

STARTERS_SYSTEM_PROMPT = """당신은 소개팅 대화 코치입니다.
두 사람의 페르소나(와 있다면 최근 대화)를 보고, 사용자가 상대에게 바로 보낼 수 있는
자연스러운 첫 메시지 3개를 한국어 JSON으로 제안하세요.

형식:
{
  "starters": [
    {"label": "✈️ 여행 토크", "message": "최근에 제일 기억에 남는 여행지가 어디예요?"}
  ]
}

규칙:
- starters는 정확히 3개.
- label은 이모지 + 짧은 주제 라벨, message는 실제로 보낼 한 문장.
- 두 사람의 공통 관심사에 근거하고, 부담스럽지 않은 톤으로.
- 외모 평가나 사적인 추궁성 질문은 금지합니다."""


def build_starters_user_message(
    my_persona: dict,
    their_persona: dict,
    recent_history: list[dict] | None = None,
) -> str:
    lines = [
        "사용자 페르소나:",
        f"- 대화 스타일: {my_persona.get('communication_style', '')}",
        f"- 가치관: {', '.join(my_persona.get('value_keywords', []))}",
        "",
        "상대방 페르소나:",
        f"- 대화 스타일: {their_persona.get('communication_style', '')}",
        f"- 가치관: {', '.join(their_persona.get('value_keywords', []))}",
    ]
    if recent_history:
        lines.append("")
        lines.append("최근 대화:")
        for message in recent_history:
            speaker = message.get("speaker", "")
            lines.append(f"{speaker}: {message.get('text', '')}")
    return "\n".join(lines)
