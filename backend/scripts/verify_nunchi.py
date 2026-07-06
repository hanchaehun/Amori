"""실 Gemini로 눈치(partner_read·strategy) 작동 검증.

DB의 기존 A/B 페르소나를 직접 GeminiProvider에 넣어 시뮬레이션하고,
사용자에겐 안 보이는 내부 필드(partner_read·strategy)와 약속조율 감지를 출력한다.
HTTP 스택 없이 provider만 직접 호출 — 쿼터 절약.

실행: .venv/Scripts/python.exe -X utf8 scripts/verify_nunchi.py
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.config import settings
from app.db.session import async_session_factory
from app.dependencies import get_llm_provider
from app.models.database import Persona


async def main() -> int:
    print(f"provider={settings.llm_provider} chat_model={settings.gemini_chat_model}")
    async with async_session_factory() as db:
        a = (await db.execute(select(Persona).where(Persona.user_id == "e2e_user_a"))).scalar_one_or_none()
        b = (await db.execute(select(Persona).where(Persona.user_id == "e2e_user_b"))).scalar_one_or_none()
    if not a or not b:
        print("FAIL: e2e_user_a/b 페르소나가 DB에 없음 — 먼저 e2e_gemini.py로 생성하세요")
        return 1

    def to_dict(p: Persona) -> dict:
        return {
            "traits": p.traits,
            "communication_style": p.communication_style,
            "humor_style": p.humor_style,
            "value_keywords": p.value_keywords,
            "speech_style": p.speech_style,
            "sample_messages": p.sample_messages,
        }

    llm = get_llm_provider()
    turns = []
    async for t in llm.run_simulation(to_dict(a), to_dict(b), max_turns=10):
        turns.append(t)
        who = "A(지우)" if t["speaker"] == "me" else "B(하준)"
        print(f"[{t['turn_index']}] {who} | 읽기={t['partner_read']} 전략={t['strategy']}")
        print(f"      «{t['text']}»")

    appt = any(t.get("strategy") == "약속 수락" for t in turns)
    print(f"\n총 {len(turns)}턴 | appointment_ready={appt} | 마지막 전략={turns[-1]['strategy']}")
    print("눈치 검증 통과" if all(t.get("partner_read") and t.get("strategy") for t in turns) else "FAIL: 눈치 필드 누락")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
