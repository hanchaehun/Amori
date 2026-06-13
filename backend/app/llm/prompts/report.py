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
- score: 0~100 정수. 실질 궁합 근거로만 산정하세요 — 가치관·유머 코드·취향의 겹침,
  대화 리듬과 호응의 질. 약속 성사 여부로 점수를 끌어올리거나 깎지 마세요.
- [대화 신호]는 엔진이 기록한 대화 흐름의 사실입니다. 사실관계와 모순되는 서술은 금지
  (예: 약속이 잡혔는데 "호감이 없었다"고 쓰기). 단 약속 성사는 분위기가 좋았다는 신호
  하나일 뿐 점수 하한이 아닙니다 — 분위기에 휩쓸려 약속이 잡혔어도 실질 결이 다르면
  낮은 점수를 줄 수 있고, 그렇게 판단한 이유를 warnings에 쓰세요.
- findings: 2~5개. 대화에서 발견된 실제 공통점·궁합 포인트만.
- warnings: 1~2개. 아직 확인되지 않았거나 부딪힐 수 있는 지점.
- places: 2~4개. 두 사람의 취향이 겹치는 실제 데이트 장소 유형.
- starters: 2~5개. 바로 보낼 수 있는 자연스러운 첫 메시지.
- 외모·재산·학력 평가, 차별적 표현은 금지합니다."""


def _signal_block(simulation_log: list[dict]) -> list[str]:
    """엔진이 턴마다 기록한 눈치 신호(partner_read/strategy)를 사실 기록으로 요약한다.

    리포트가 사실관계(약속 성사 등)와 모순되는 서술을 하지 않게 하기 위한 것이지,
    점수를 끌어올리는 근거가 아니다 — 약속은 엔진 넛지가 밀어준 결과일 수 있어
    점수 하한으로 삼으면 순환 인플레가 된다. 점수는 실질 궁합으로만 매긴다.
    """
    labels = {"me": "사용자AI", "them": "상대방AI"}
    reads: dict[str, dict[str, int]] = {k: {} for k in labels}
    accepted = False
    for turn in simulation_log:
        speaker = turn.get("speaker")
        if speaker not in labels:
            continue
        read = turn.get("partner_read")
        if read:
            reads[speaker][read] = reads[speaker].get(read, 0) + 1
        if turn.get("strategy") == "약속 수락":
            accepted = True

    lines = ["", "대화 신호 (엔진 기록):"]
    for key, label in labels.items():
        if reads[key]:
            summary = ", ".join(f"{r} {n}회" for r, n in reads[key].items())
            lines.append(f"- {label}가 상대 반응을 읽음: {summary}")
    lines.append(f"- 약속 성사: {'성사됨 (만남 약속까지 잡음)' if accepted else '안 됨'}")
    return lines


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
            *_signal_block(simulation_log),
        ]
    )
