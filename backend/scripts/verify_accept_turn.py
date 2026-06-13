"""'약속 수락' 턴 단독 검증 — 실 Gemini 1콜.

verify_nunchi.py 풀런(~10콜) 없이, 상대 제안으로 끝나는 대화 + RESPOND 넛지를
손으로 만든 history로 주고 응답 strategy가 '약속 수락'인지 확인한다.
(에스컬레이션→약속 제안까지는 2026-06-11 실 Gemini에서 검증 완료 — 남은 마지막 단계)

실행: .venv/Scripts/python.exe -X utf8 scripts/verify_accept_turn.py [user_id]
(user_id 기본 e2e_user_a — 신중형이라 거절 분기를 탈 수 있음. 수락 확인엔 e2e_user_b 권장)
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.db.session import async_session_factory
from app.llm.gemini import GeminiProvider, _SpeechOutput
from app.llm.prompts import build_agent_system_prompt
from app.config import settings
from app.models.database import Persona
from app.services.simulation import RESPOND_TO_PROPOSAL_NUDGE

HISTORY = [
    {"role": "model", "text": "안녕하세요! 오늘 하루는 어떠셨어요? ㅎㅎ"},
    {"role": "user", "text": "안녕하세요! 좋은 하루였어요 ㅎㅎ 퇴근하고 뭐 하면서 쉬세요?"},
    {"role": "model", "text": "저는 주로 책 읽거나 음악 들으면서 쉬어요. 잔잔한 재즈 좋아하거든요 ㅎㅎ"},
    {
        "role": "user",
        "text": "재즈 좋아하시는구나! 그럼 이번 주말에 같이 재즈바 가서 분위기 즐겨보는 건 어때요? "
        "제가 괜찮은 곳 아는데! ㅎㅎ\n" + RESPOND_TO_PROPOSAL_NUDGE,
    },
]


async def main() -> int:
    user_id = sys.argv[1] if len(sys.argv) > 1 else "e2e_user_a"
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
        build_agent_system_prompt(persona),
        provider._to_contents(HISTORY),
        _SpeechOutput,
        temperature=0.9,
    )
    print(f"읽기={out.partner_read} 전략={out.strategy}")
    print(f"«{out.text}»")
    print("약속 수락 검증 통과" if out.strategy == "약속 수락" else "WARN: '약속 수락'이 아님 — 넛지/프롬프트 보강 필요")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
