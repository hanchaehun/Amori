"""눈치 엔진 오프라인 스모크 — LLM 없이 넛지 주입·종료 로직 검증.

가짜 speak로 '항상 긍정적으로 읽고 알아가기만 하는' 에이전트를 흉내내고,
- 연속 긍정 3회 후 ESCALATE_NUDGE가 주입되는지
- 넛지를 받은 턴이 '약속 제안'을 내면 상대에게 RESPOND_TO_PROPOSAL_NUDGE가 가는지
- '약속 수락' 후 상대 마무리 한 턴 뒤 종료되는지
- 영구 history에 넛지 텍스트가 남지 않는지
확인한다. 실행: .venv/Scripts/python.exe -X utf8 scripts/smoke_nunchi_engine.py
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.simulation import (
    ESCALATE_NUDGE,
    RESPOND_TO_PROPOSAL_NUDGE,
    run_two_agent_simulation,
)

PERSONA = {"traits": [], "communication_style": "", "humor_style": "", "value_keywords": []}


async def main() -> int:
    calls = []  # (마지막 user 텍스트, 직전까지 누적 history 길이)

    async def speak(system_prompt: str, history: list[dict]) -> dict:
        last = history[-1]["text"]
        calls.append(last)
        if ESCALATE_NUDGE in last:
            return {"text": "이번 주말에 만날래요?", "partner_read": "긍정적", "strategy": "약속 제안"}
        if RESPOND_TO_PROPOSAL_NUDGE in last:
            return {"text": "좋아요, 토요일에 봬요!", "partner_read": "긍정적", "strategy": "약속 수락"}
        return {"text": "재밌네요! 또 뭐 좋아하세요?", "partner_read": "긍정적", "strategy": "알아가기"}

    turns = [t async for t in run_two_agent_simulation(speak, PERSONA, PERSONA, max_turns=20)]

    strategies = [t["strategy"] for t in turns]
    print("전략 시퀀스:", strategies)

    # A는 자기 턴(0,2,4,...)에서 긍정 읽기 누적 — 3회 누적 후인 step 6에서 넛지 기대
    escalate_steps = [i for i, c in enumerate(calls) if ESCALATE_NUDGE in c]
    respond_steps = [i for i, c in enumerate(calls) if RESPOND_TO_PROPOSAL_NUDGE in c]
    print(f"ESCALATE 주입 step: {escalate_steps} | RESPOND 주입 step: {respond_steps}")

    ok = True
    if escalate_steps != [6]:
        ok = False
        print("FAIL: 에스컬레이션 넛지가 step 6 한 번이어야 함")
    if respond_steps != [7]:
        ok = False
        print("FAIL: 제안 응답 넛지가 step 7 한 번이어야 함")
    if strategies[6:9] != ["약속 제안", "약속 수락", "알아가기"]:
        ok = False
        print("FAIL: 제안→수락→상대 마무리 한 턴 흐름이 아님")
    if len(turns) != 9:
        ok = False
        print(f"FAIL: 수락 후 한 턴 뒤 종료(총 9턴)여야 하는데 {len(turns)}턴")
    # 넛지가 영구 history를 오염시키면 다음 턴 상대 user 텍스트에 괄호 안내가 섞인다
    if any(ESCALATE_NUDGE in c or RESPOND_TO_PROPOSAL_NUDGE in c for c in calls[8:]):
        ok = False
        print("FAIL: 넛지가 영구 컨텍스트에 남음")

    print("스모크 통과" if ok else "스모크 실패")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
