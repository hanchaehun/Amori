"""페르소나 미리보기 프롬프트 — "당신의 에이전트는 이렇게 말해요" (refatodo P0-C).

시뮬과 같은 컨디셔닝(_persona_block + _speech_block)을 재사용해 세 상황의
발화를 1콜로 생성한다. 사용자가 수정한 문장은 user_written 최고 등급 데이터로
sample_bank에 쌓인다 — 이 화면이 곧 말투 데이터 수집 루프다.
"""

from app.llm.prompts.simulation import _persona_block, _speech_block

# 상황 3개 — 서로 다른 레지스터(오프닝/공감/완곡 거절)를 트리거한다.
# 거절 레지스터는 '나 같지 않음'이 가장 잘 드러나는 지점(체면·완곡 전략의 개인차).
PREVIEW_SITUATIONS: list[dict] = [
    {
        "register": "첫인사",
        "situation": "매칭된 상대에게 보내는 첫 메시지. 아직 서로 프로필 정도만 아는 사이다.",
    },
    {
        "register": "공감 리액션",
        "situation": '대화 중 상대가 "오늘 일이 진짜 힘들었어요…"라고 보냈다.',
    },
    {
        "register": "완곡 거절",
        "situation": "상대가 이번 주말에 만나자고 했지만 일정이 안 된다. 관계는 계속 이어가고 싶다.",
    },
]

PREVIEW_SYSTEM_PROMPT = """당신은 이 사용자의 AI 에이전트입니다. 아래 페르소나와 말투 지시를
철저히 따라, 각 상황에서 이 사람이 실제로 보낼 법한 메신저 메시지를 1개씩 생성하세요.

- 말투 지시(측정값·발화 예시)가 최우선입니다. 예시의 맞춤법·표기를 교정하지 말고,
  비표준 표기(의도적 오타·줄임)는 빈도까지 흉내 내세요 — 반복 관측된 표기는 자주,
  한 번만 보인 표기는 가끔만 (모든 문장에 넣으면 과장입니다).
- 메시지는 실제 카톡처럼 자연스럽게 — 설명이나 따옴표 없이 메시지 본문만.
- 출력은 JSON 하나: {"utterances":[{"register":"첫인사","text":"..."}, ...]} — 상황 순서대로 3개."""


def build_preview_user_message(persona: dict) -> str:
    lines = [
        "[페르소나]",
        _persona_block(persona),
    ]
    speech = _speech_block(persona)
    if speech:
        lines.extend(["", "[말투 지시]", speech])
    lines.extend(["", "[상황]"])
    for i, item in enumerate(PREVIEW_SITUATIONS, start=1):
        lines.append(f"{i}. ({item['register']}) {item['situation']}")
    return "\n".join(lines)
