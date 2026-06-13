"""원샷 시뮬레이션 플러밍 오프라인 스모크 — 실 Gemini 0콜.

GeminiProvider._generate를 가짜로 갈아끼워(LLM 미호출) run_simulation이:
  ① 원샷 출력(_ConversationOutput)을 다운스트림 턴 dict로 바르게 변환하는지
  ② 약속 슬롯을 '약속 수락' 턴에서만 + 교집합 실재일 때만 인정하는지(환각 방어)
  ③ 교집합에 없는 슬롯/제안 턴 슬롯은 버리는지
  ④ 프롬프트가 양쪽 정보·겹치는 일정으로 잘 빌드되는지
를 검증한다. 약속 판정(any 약속수락 + 합의 슬롯)은 라우터/auto_sim과 동일 규칙으로 재현.

실행: .venv/Scripts/python.exe -X utf8 scripts/smoke_oneshot_sim.py
"""

import asyncio
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ.setdefault("LLM_PROVIDER", "mock")  # settings 임포트용 (Gemini 미생성)

from app.llm.gemini import GeminiProvider, _ConvTurn, _ConversationOutput
from app.llm.prompts import build_oneshot_simulation_prompt

PERSONA_A = {
    "display_name": "지은",
    "communication_style": "여행 이야기로 마음을 여는 호기심형",
    "humor_style": "엉뚱한 유머",
    "value_keywords": ["새로운 경험", "자유", "사진"],
    "traits": [{"category": "데이트", "summary": "소소한 일상", "keywords": ["산책"]}],
    "speech_style": {"formality": "존댓말", "emoji_usage": "가끔", "laugh_style": "ㅎㅎ",
                     "sentence_length": "보통", "tone_keywords": ["설렘", "담백"]},
    "sample_messages": ["제주도 다녀왔어요!", "낯선 골목 걷는 거 좋아해요", "다음엔 어디 갈까 고민해요 ㅎㅎ"],
}
PERSONA_B = {
    "display_name": "유진",
    "communication_style": "맛집·요리로 친해지는 다정형",
    "humor_style": "반전 유머",
    "value_keywords": ["맛집", "집밥", "따뜻함"],
    "traits": [{"category": "데이트", "summary": "같이 먹기", "keywords": ["맛집"]}],
    "speech_style": {"formality": "존댓말", "emoji_usage": "자주", "laugh_style": "ㅋㅋ",
                     "sentence_length": "보통", "tone_keywords": ["다정", "활기"]},
    "sample_messages": ["요즘 파스타집에 빠졌어요 ㅋㅋ", "주말엔 직접 요리해요", "같이 먹으면 더 맛있죠?"],
}

SAT_EVENING = {"date": "2026-06-20", "time": "저녁"}
SUN_LUNCH = {"date": "2026-06-21", "time": "점심"}
MON_LUNCH = {"date": "2026-06-22", "time": "점심"}


def _fake_conversation(accept_slot: str) -> _ConversationOutput:
    """제안→수락(accept_slot 번호)으로 끝나는 가짜 원샷 대화."""
    turns = [
        _ConvTurn(speaker="me", text="안녕하세요! 여행 좋아하세요?", strategy="알아가기", partner_read="중립"),
        _ConvTurn(speaker="them", text="안녕하세요 ㅋㅋ 저는 맛집 탐방을 더 좋아해요!", strategy="알아가기"),
        _ConvTurn(speaker="me", text="오 저도 여행 가면 맛집부터 찾아요 ㅎㅎ", strategy="알아가기"),
        _ConvTurn(speaker="them", text="통하네요! 요즘 성수 파스타집에 빠졌어요", strategy="알아가기"),
        _ConvTurn(speaker="me", text="ㅋㅋ 같이 가실래요? 혹시 언제 시간 되세요?", strategy="약속 제안", appointment_slot="S9"),
        _ConvTurn(speaker="them", text="좋아요! 일요일 점심 어때요?", strategy="약속 수락", appointment_slot=accept_slot),
        _ConvTurn(speaker="me", text="좋아요 그때 봬요 ㅎㅎ", strategy="마무리"),
    ]
    return _ConversationOutput(turns=turns)


async def _run(my_slots, their_slots, accept_slot):
    """_generate를 가짜로 갈아끼우고 run_simulation 결과 턴을 수집."""
    prov = GeminiProvider.__new__(GeminiProvider)  # __init__(SDK) 우회
    captured = {}

    async def fake_generate(system_prompt, contents, schema, temperature=0.8):
        captured["system"] = system_prompt
        captured["user"] = contents
        return _fake_conversation(accept_slot)

    prov._generate = fake_generate
    turns = [
        t async for t in prov.run_simulation(
            PERSONA_A, PERSONA_B, max_turns=20, my_slots=my_slots, their_slots=their_slots,
        )
    ]
    return turns, captured


def _appointment(turns, my_slots, their_slots):
    """auto_sim/라우터와 동일한 약속 판정."""
    accepted = any(t.get("strategy") == "약속 수락" for t in turns)
    agreed = next((t["appointment_slot"] for t in turns if t.get("appointment_slot")), None)
    negotiating = bool(my_slots) and bool(their_slots)
    ready = accepted and (agreed is not None or not negotiating)
    return ready, agreed


async def main():
    # ① 정상 — 교집합(일 점심)이 S1, 수락이 S1 → 합의 슬롯 = 일 점심
    turns, cap = await _run([SAT_EVENING, SUN_LUNCH], [SUN_LUNCH, MON_LUNCH], "S1")
    assert len(turns) == 7 and turns[0]["speaker"] == "me"
    assert all(k in turns[0] for k in ("turn_index", "partner_read", "strategy", "appointment_slot"))
    # 제안 턴(S9, 교집합 밖+제안)은 버려지고 수락 턴만 슬롯을 가진다
    assert turns[4]["appointment_slot"] is None, "제안 턴에 슬롯이 실렸다"
    assert turns[5]["appointment_slot"] == SUN_LUNCH, f"수락 슬롯 오류: {turns[5]['appointment_slot']}"
    ready, agreed = _appointment(turns, [SAT_EVENING, SUN_LUNCH], [SUN_LUNCH, MON_LUNCH])
    assert ready and agreed == SUN_LUNCH
    # 프롬프트에 양쪽 말투/일정이 들어갔는지
    assert "이름: 지은" in cap["user"] and "이름: 유진" in cap["user"]
    assert "겹치는 시간" in cap["user"] and "6월 21일(일) 점심" in cap["user"]
    # 정직한 궁합 시뮬 + 이름 호칭 + AI 말투 금지 지시가 시스템 프롬프트에 있어야 한다
    assert "정직" in cap["system"] and "AI 말투" in cap["system"]
    assert "A님" in cap["system"]  # "A님·B님 같은 호칭은 절대 금지" 규칙
    print("① OK — 정상 합의: 수락 턴만 슬롯(일 점심), 제안 턴 슬롯 폐기, 프롬프트 구성 정상")

    # ② 환각 방어 — 수락이 교집합에 없는 S2(월 점심)를 가리키면 버려진다
    #    (common=[일 점심] 하나뿐 → S2는 인덱스 밖)
    turns, _ = await _run([SUN_LUNCH], [SUN_LUNCH], "S2")
    assert turns[5]["appointment_slot"] is None, "교집합 밖 슬롯이 통과했다"
    ready, agreed = _appointment(turns, [SUN_LUNCH], [SUN_LUNCH])
    assert ready is False and agreed is None, "환각 슬롯인데 약속이 성립했다"
    print("② OK — 환각 슬롯(교집합 밖) 폐기 → 약속 불성립")

    # ③ 일정 없음 폴백 — 한쪽 일정 없음 → 슬롯 없이 의향만, 약속은 성립(negotiating=False)
    turns, cap = await _run([], [], "S1")
    assert all(t["appointment_slot"] is None for t in turns)
    assert "구체적인 가능 시간 정보가 없습니다" in cap["user"]
    ready, agreed = _appointment(turns, [], [])
    assert ready is True and agreed is None
    print("③ OK — 일정 없음: 슬롯 None·의향 합의(negotiating=False라 약속 성립)")

    # ④ 교집합 없음 — 양쪽 일정 있으나 안 겹침 → 슬롯 인정 불가, 약속 불성립
    turns, _ = await _run([SAT_EVENING], [SUN_LUNCH], "S1")
    assert turns[5]["appointment_slot"] is None
    ready, agreed = _appointment(turns, [SAT_EVENING], [SUN_LUNCH])
    assert ready is False and agreed is None
    print("④ OK — 교집합 없음: 슬롯 폐기 → 약속 불성립")

    print("\nSMOKE PASS")


if __name__ == "__main__":
    asyncio.run(main())
