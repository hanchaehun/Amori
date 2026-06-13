"""일정 조율 엔진 오프라인 스모크 — LLM 없이 각본 speak로 엔진 로직만 검증.

시나리오 1 (조율 성공): A가 자기 일정에서 제안 → B는 그 시간이 안 됨(엔진이
unavailable 넛지 주입) → B가 역제안 → A 수락(엔진이 slot-ok 넛지 + 슬롯 검증)
→ 합의 슬롯이 양쪽 교집합의 그 슬롯인지 확인.

시나리오 2 (일정 없음 폴백): 슬롯 미전달 시 기존 동작 — 넛지에 슬롯 언급 없고
턴에 appointment_slot 없음.

시나리오 3 (환각 방어): 수락 턴이 교집합에 없는 슬롯 번호를 답하면 버려진다.

실행: .venv/Scripts/python.exe -X utf8 scripts/smoke_slot_negotiation.py
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.simulation import run_two_agent_simulation

# A: 토 저녁(S1), 일 점심(S2) / B: 일 점심(S1), 월 저녁(S2) → 교집합 = 일 점심
A_SLOTS = [
    {"date": "2026-06-13", "time": "저녁"},
    {"date": "2026-06-14", "time": "점심"},
]
B_SLOTS = [
    {"date": "2026-06-14", "time": "점심"},
    {"date": "2026-06-15", "time": "저녁"},
]


def scripted_speak(script: list[dict]):
    """각본 응답을 순서대로 돌려주고, 받은 (system_prompt, history)를 기록한다."""
    calls = []

    async def speak(system_prompt: str, history: list[dict]) -> dict:
        calls.append({"system": system_prompt, "history": history})
        return script[len(calls) - 1]

    return speak, calls


async def scenario_negotiation() -> None:
    script = [
        # A: 인사 / B: 호응 / A: 토 저녁 제안(S1) / B: 그날 안 됨 → 일 점심 역제안(자기 S1)
        {"partner_read": "중립", "strategy": "알아가기", "text": "안녕하세요!", "appointment_slot": ""},
        {"partner_read": "긍정적", "strategy": "알아가기", "text": "반가워요 ㅎㅎ", "appointment_slot": ""},
        {"partner_read": "긍정적", "strategy": "약속 제안", "text": "토요일 저녁 어때요?", "appointment_slot": "S1"},
        {"partner_read": "긍정적", "strategy": "약속 제안", "text": "토요일은 어렵고 일요일 점심은 어때요?", "appointment_slot": "S1"},
        {"partner_read": "긍정적", "strategy": "약속 수락", "text": "좋아요, 일요일 점심에 봬요!", "appointment_slot": "S2"},
        {"partner_read": "긍정적", "strategy": "마무리", "text": "그때 봬요 ㅎㅎ", "appointment_slot": ""},
    ]
    speak, calls = scripted_speak(script)
    turns = [
        t async for t in run_two_agent_simulation(
            speak, {}, {}, max_turns=10, my_slots=A_SLOTS, their_slots=B_SLOTS
        )
    ]

    # 시스템 프롬프트에 자기 일정만 보인다 (정보 비대칭)
    assert "6월 13일(토) 저녁" in calls[0]["system"], "A 프롬프트에 A 일정 없음"
    assert "6월 13일" not in calls[1]["system"], "B 프롬프트에 A 일정이 새어 들어감"
    assert "6월 15일(월) 저녁" in calls[1]["system"], "B 프롬프트에 B 일정 없음"

    # B의 응답 턴(4번째 콜): A의 토 저녁 제안은 B에게 불가 → unavailable 넛지
    nudged_b = calls[3]["history"][-1]["text"]
    assert "안 되는 시간" in nudged_b, f"B 넛지가 unavailable이 아님: {nudged_b}"

    # A의 수락 턴(5번째 콜): B의 일 점심 역제안은 A도 가능 → slot-ok 넛지 + A 기준 번호(S2)
    nudged_a = calls[4]["history"][-1]["text"]
    assert "가능한 시간" in nudged_a and "S2" in nudged_a, f"A 넛지가 slot-ok가 아님: {nudged_a}"

    # 합의 슬롯 = 교집합의 일요일 점심, 수락 턴에만 실린다
    accept_turn = next(t for t in turns if t["strategy"] == "약속 수락")
    assert accept_turn["appointment_slot"] == {"date": "2026-06-14", "time": "점심"}, accept_turn
    assert all(t["appointment_slot"] is None for t in turns if t["strategy"] != "약속 수락")
    # 수락 후 상대 마무리 한 턴까지 총 6턴 종료
    assert len(turns) == 6, f"{len(turns)}턴 (기대 6)"
    print("시나리오 1 (조율 성공) 통과 — 합의: 6월 14일(일) 점심")


async def scenario_no_slots_fallback() -> None:
    script = [
        {"partner_read": "중립", "strategy": "알아가기", "text": "안녕하세요!"},
        {"partner_read": "긍정적", "strategy": "약속 제안", "text": "주말에 볼래요?"},
        {"partner_read": "긍정적", "strategy": "약속 수락", "text": "좋아요!"},
        {"partner_read": "긍정적", "strategy": "마무리", "text": "그때 봬요"},
    ]
    speak, calls = scripted_speak(script)
    turns = [
        t async for t in run_two_agent_simulation(speak, {}, {}, max_turns=10)
    ]
    assert "가능 일정 정보가 없습니다" in calls[0]["system"], "폴백 일정 안내 없음"
    nudge = calls[2]["history"][-1]["text"]
    assert "S" not in nudge.split("strategy")[0] or "appointment_slot" not in nudge, nudge
    assert all(t["appointment_slot"] is None for t in turns)
    print("시나리오 2 (일정 없음 폴백) 통과 — 의향만 합의, 슬롯 없음")


async def scenario_hallucinated_slot() -> None:
    # A가 교집합에 없는 토 저녁(S1)을 제안하고 B가 그대로 수락(자기 일정에 없는 번호) —
    # 검증에서 버려져 합의 슬롯이 없어야 한다
    script = [
        {"partner_read": "긍정적", "strategy": "약속 제안", "text": "토요일 저녁 봐요", "appointment_slot": "S1"},
        {"partner_read": "긍정적", "strategy": "약속 수락", "text": "네 좋아요!", "appointment_slot": "S9"},
        {"partner_read": "긍정적", "strategy": "마무리", "text": "그때 봬요"},
    ]
    speak, _calls = scripted_speak(script)
    turns = [
        t async for t in run_two_agent_simulation(
            speak, {}, {}, max_turns=10, my_slots=A_SLOTS, their_slots=B_SLOTS
        )
    ]
    assert all(t["appointment_slot"] is None for t in turns), turns
    print("시나리오 3 (환각 방어) 통과 — 교집합 밖 수락은 슬롯 무효")


async def main() -> int:
    await scenario_negotiation()
    await scenario_no_slots_fallback()
    await scenario_hallucinated_slot()
    print("\n일정 조율 엔진 스모크 전체 통과")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
