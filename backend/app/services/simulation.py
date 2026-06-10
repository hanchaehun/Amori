"""2-에이전트 턴 루프 시뮬레이션 엔진 (리팩토링 결정 5).

원샷 생성(한 호출로 양쪽 대사 전부)은 두 페르소나의 말투가 섞이고(style bleed)
대화가 평탄한 핑퐁이 되는 구조적 품질 문제가 있다. 이 엔진은:

- 에이전트 A·B가 각각 자기 페르소나만 담긴 별도 시스템 프롬프트·별도 컨텍스트를 유지하고
- 턴마다 한쪽씩 호출해 발화를 생성하며
- ``analyze_every`` 턴마다 별도의 가벼운 분석 호출로 시그널을 추출해 system 턴으로 끼워 넣는다.

LLM 호출 자체는 provider가 콜백(``speak``, ``analyze``)으로 주입한다.
"""

from typing import AsyncIterator, Awaitable, Callable

from app.llm.prompts import build_agent_system_prompt, build_analysis_user_message

# speak(system_prompt, history) -> 발화 텍스트
# history: [{"role": "user"|"model", "text": str}] — 해당 에이전트 시점의 대화
SpeakFn = Callable[[str, list[dict]], Awaitable[str]]
# analyze(user_message) -> {"has_signal": bool, "system_text": str, "signal": str}
AnalyzeFn = Callable[[str], Awaitable[dict]]

ANALYZE_EVERY = 4
OPENING_INSTRUCTION = "(소개팅 첫 메시지를 보내며 대화를 시작하세요)"


async def run_two_agent_simulation(
    speak: SpeakFn,
    analyze: AnalyzeFn,
    my_persona: dict,
    their_persona: dict,
    max_turns: int = 20,
    analyze_every: int = ANALYZE_EVERY,
) -> AsyncIterator[dict]:
    """시뮬레이션 턴을 simulation_turn.schema.json 형태로 순차 생성한다."""
    system_a = build_agent_system_prompt(my_persona)
    system_b = build_agent_system_prompt(their_persona)

    history_a: list[dict] = [{"role": "user", "text": OPENING_INSTRUCTION}]
    history_b: list[dict] = []

    spoken_turns: list[dict] = []
    last_analyzed = 0
    turn_index = 0

    for step in range(max_turns):
        is_me = step % 2 == 0
        system_prompt = system_a if is_me else system_b
        history = history_a if is_me else history_b

        text = await speak(system_prompt, history)

        # 자기 컨텍스트엔 model 발화로, 상대 컨텍스트엔 user 발화로 쌓는다
        if is_me:
            history_a.append({"role": "model", "text": text})
            history_b.append({"role": "user", "text": text})
        else:
            history_b.append({"role": "model", "text": text})
            history_a.append({"role": "user", "text": text})

        turn = {
            "turn_index": turn_index,
            "speaker": "me" if is_me else "them",
            "text": text,
            "signal": None,
            "ai_generated": True,
        }
        turn_index += 1
        spoken_turns.append(turn)
        yield turn

        # N턴마다 시그널 분석 — 발견된 경우에만 system 턴 삽입
        if len(spoken_turns) - last_analyzed >= analyze_every:
            recent = spoken_turns[last_analyzed:]
            last_analyzed = len(spoken_turns)
            try:
                result = await analyze(build_analysis_user_message(recent))
            except Exception:
                continue  # 분석 실패가 시뮬레이션 자체를 막지 않게
            if result.get("has_signal") and result.get("system_text"):
                system_turn = {
                    "turn_index": turn_index,
                    "speaker": "system",
                    "text": result["system_text"],
                    "signal": result.get("signal") or None,
                    "ai_generated": True,
                }
                turn_index += 1
                yield system_turn
