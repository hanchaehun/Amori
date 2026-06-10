"""궁합 리포트 프롬프트 — 시뮬레이션 로그 → report.schema.json."""

REPORT_SYSTEM_PROMPT = """당신은 연애 궁합 분석 전문가입니다.
두 AI 에이전트의 페르소나와 시뮬레이션 대화 내용을 분석해서 호환성 리포트를 한국어 JSON으로 생성하세요.

형식:
{
  "score": 85,
  "findings": [
    {"emoji": "🎵", "title": "공통점 제목", "sub": "상세 설명"}
  ],
  "warnings": [
    {"title": "주의할 점 제목", "body": "상세 설명"}
  ],
  "places": [
    {"emoji": "🍵", "title": "장소명", "sub": "추천 이유"}
  ],
  "starters": [
    "첫 대화 시작 문장1",
    "첫 대화 시작 문장2",
    "첫 대화 시작 문장3"
  ],
  "tip": "만남 시 유용한 팁 한 문장"
}

규칙:
- score: 0~100 정수. 대화에서 실제로 관찰된 시그널에 근거해 산정하세요.
- findings: 2~5개. 대화에서 발견된 실제 공통점·궁합 포인트만.
- warnings: 1~2개. 아직 확인되지 않았거나 부딪힐 수 있는 지점.
- places: 2~4개. 두 사람의 취향이 겹치는 실제 데이트 장소 유형.
- starters: 2~5개. 바로 보낼 수 있는 자연스러운 첫 메시지.
- 외모·재산·학력 평가, 차별적 표현은 금지합니다."""


def build_report_user_message(
    my_persona: dict,
    their_persona: dict,
    simulation_log: list[dict],
) -> str:
    conversation_lines = []
    for turn in simulation_log:
        if turn.get("speaker") == "system":
            conversation_lines.append(f"[시스템] {turn['text']}")
        else:
            speaker = "사용자AI" if turn.get("speaker") == "me" else "상대방AI"
            conversation_lines.append(f"{speaker}: {turn['text']}")

    return "\n".join(
        [
            "사용자 페르소나:",
            f"- 대화 스타일: {my_persona.get('communication_style', '')}",
            f"- 유머: {my_persona.get('humor_style', '')}",
            f"- 가치관: {', '.join(my_persona.get('value_keywords', []))}",
            "",
            "상대방 페르소나:",
            f"- 대화 스타일: {their_persona.get('communication_style', '')}",
            f"- 유머: {their_persona.get('humor_style', '')}",
            f"- 가치관: {', '.join(their_persona.get('value_keywords', []))}",
            "",
            "AI 시뮬레이션 대화:",
            *conversation_lines,
        ]
    )
