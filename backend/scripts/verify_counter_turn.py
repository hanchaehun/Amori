"""'거절+역제안' 턴 단독 검증 — 실 Gemini 1콜.

풀런에서는 상대가 우연히 교집합 슬롯을 바로 제안하면 역제안 경로가 안 밟힌다
(2026-06-12 verify_slot_negotiation_gemini.py 런이 그랬음). verify_accept_turn.py와
같은 방식으로, 상대가 '내 일정에 없는 시간'을 제안한 history + unavailable 넛지를
손으로 만들어 1콜로 확인한다:
  - strategy = '약속 제안' (거절 후 역제안)
  - appointment_slot = 자기 [가능한 일정]의 번호
  - 발화가 미안함 표시 + 자기 일정 내 시간 역제안, 내부 번호(S1) 비노출

실행: .venv/Scripts/python.exe -X utf8 scripts/verify_counter_turn.py [user_id]
(기본 e2e_user_b — B 일정 기준: 일 점심·월 저녁, 상대가 토 저녁을 제안한 상황)
"""

import asyncio
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.config import settings
from app.db.session import async_session_factory
from app.llm.gemini import GeminiProvider, _SpeechOutput
from app.llm.prompts import build_agent_system_prompt
from app.models.database import Persona
from app.services.simulation import respond_nudge_slot_unavailable

SLOT_LABELS = ["S1) 6월 14일(일) 점심", "S2) 6월 15일(월) 저녁"]

HISTORY = [
    {"role": "model", "text": "안녕하세요! 좋은 인연이 되었으면 좋겠습니다 ㅎㅎ"},
    {"role": "user", "text": "안녕하세요! 저도요 ㅎㅎ 대화 나눠보니 잘 맞는 것 같아요."},
    {"role": "model", "text": "저도 그렇게 느꼈어요! 이야기가 잘 통하는 것 같아요 ㅎㅎ"},
    {
        "role": "user",
        "text": "그럼 우리 6월 13일 토요일 저녁에 만나서 이야기 더 나눠볼까요?\n"
        + respond_nudge_slot_unavailable(),
    },
]


async def main() -> int:
    user_id = sys.argv[1] if len(sys.argv) > 1 else "e2e_user_b"
    async with async_session_factory() as db:
        p = (await db.execute(select(Persona).where(Persona.user_id == user_id))).scalar_one_or_none()
    if not p:
        print(f"FAIL: {user_id} 페르소나가 DB에 없음 — 먼저 e2e_gemini.py로 생성하세요")
        return 1
    persona = {
        "traits": p.traits,
        "communication_style": p.communication_style,
        "humor_style": p.humor_style,
        "value_keywords": p.value_keywords,
        "speech_style": p.speech_style,
        "sample_messages": p.sample_messages,
    }

    provider = GeminiProvider(api_key=settings.gemini_api_key, chat_model=settings.gemini_chat_model)
    out = await provider._generate(
        build_agent_system_prompt(persona, slot_labels=SLOT_LABELS),
        provider._to_contents(HISTORY),
        _SpeechOutput,
        temperature=0.9,
    )

    print(f"읽기={out.partner_read} 전략={out.strategy} 슬롯={out.appointment_slot!r}")
    print(f"발화: {out.text}")

    failures = []
    if out.strategy != "약속 제안":
        failures.append(f"전략이 '약속 제안'이 아님: {out.strategy}")
    if out.appointment_slot.strip().upper() not in {"S1", "S2"}:
        failures.append(f"역제안 슬롯 번호가 일정 밖: {out.appointment_slot!r}")
    if re.search(r"\bS\d+\b", out.text):
        failures.append("내부 슬롯 번호가 발화에 노출됨")
    if "토요일" in out.text and not any(k in out.text for k in ("일요일", "월요일", "14일", "15일")):
        failures.append("거절만 있고 역제안 시간이 없음")

    if failures:
        print("FAIL: " + "; ".join(failures))
        return 1
    print("PASS — 불가 시간 거절 + 자기 일정 내 역제안 (실 Gemini)")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
