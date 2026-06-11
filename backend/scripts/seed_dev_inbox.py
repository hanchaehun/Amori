"""연결(inbox) 화면 개발용 시드 — mock provider, Gemini 쿼터 0콜.

DEV_UID(기본 dev_hanchaehun) 사용자와 상대 3명을 만들고 시뮬레이션을 돌려
inbox가 보여줄 세 가지 상태를 DB에 깐다:
  수아  — 약속조율 완료, 아무도 수락 안 함        → [만남 수락하기] 카드
  민준  — 약속조율 완료, 상대가 이미 수락          → 내가 수락하면 바로 scheduled
  서연  — 시뮬레이션만 완료(약속조율 미완)          → 일반 진행 중 카드

재실행 멱등 — 기존 시드 매치를 지우고 다시 깐다.

실행: .venv/Scripts/python.exe -X utf8 scripts/seed_dev_inbox.py [dev_uid]
이후: uvicorn app.main:app 띄우고 Flutter를 DEV_UID로 붙이면 된다.
"""

import asyncio
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

# settings가 임포트 시점에 .env를 읽으므로, 그 전에 환경변수로 덮어쓴다
os.environ["LLM_PROVIDER"] = "mock"
os.environ["DAILY_SIMULATION_LIMIT"] = "50"

import httpx
from sqlalchemy import delete, select

from app.db.session import async_session_factory
from app.main import app
from app.auth.firebase import get_current_user
from app.models.database import Match

DEV_UID = sys.argv[1] if len(sys.argv) > 1 else "dev_hanchaehun"

PARTNERS = [
    {"uid": "dev_partner_sua", "name": "수아"},
    {"uid": "dev_partner_minjun", "name": "민준"},
    {"uid": "dev_partner_seoyeon", "name": "서연"},
]

CURRENT = {"uid": DEV_UID, "email": f"{DEV_UID}@dev.local", "name": DEV_UID}


async def fake_user() -> dict:
    return dict(CURRENT)


app.dependency_overrides[get_current_user] = fake_user


def switch(uid: str) -> None:
    CURRENT["uid"] = uid
    CURRENT["email"] = f"{uid}@dev.local"


async def wipe_seed_matches() -> None:
    """dev 유저가 낀 매치(연쇄로 시뮬레이션 잡·리포트까지)를 지운다."""
    async with async_session_factory() as db:
        await db.execute(delete(Match).where(Match.participant_ids.any(DEV_UID)))
        await db.commit()


async def main() -> int:
    await wipe_seed_matches()
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(
        transport=transport, base_url="http://t", timeout=httpx.Timeout(120.0)
    ) as client:
        # 1. 유저 프로필 + 페르소나 (mock — 쿼터 0)
        switch(DEV_UID)
        r = await client.put("/users/me", json={"display_name": "나"})
        assert r.status_code == 200, r.text
        r = await client.post("/persona/build", json={"answers": []})
        assert r.status_code == 200, r.text
        for p in PARTNERS:
            switch(p["uid"])
            r = await client.put("/users/me", json={"display_name": p["name"]})
            assert r.status_code == 200, r.text
            r = await client.post("/persona/build", json={"answers": []})
            assert r.status_code == 200, r.text
        print(f"1. 페르소나 {1 + len(PARTNERS)}명 생성 OK")

        # 2. dev 유저로 시뮬레이션 3건 (mock 대화는 약속수락으로 끝남)
        switch(DEV_UID)
        for p in PARTNERS:
            async with client.stream(
                "POST", "/simulation/run",
                json={"target_user_id": p["uid"], "max_turns": 20},
            ) as resp:
                assert resp.status_code == 200, await resp.aread()
                async for _ in resp.aiter_lines():
                    pass
        print("2. 시뮬레이션 3건 완료 OK")

        # 3. 카드 상태 다양화 — 민준은 상대 선수락, 서연은 약속조율 미완으로 조정
        async with async_session_factory() as db:
            result = await db.execute(
                select(Match).where(Match.participant_ids.any(DEV_UID))
            )
            scores = {
                "dev_partner_sua": 91.0,
                "dev_partner_minjun": 87.0,
                "dev_partner_seoyeon": 79.0,
            }
            for m in result.scalars().all():
                partner = next(p for p in m.participant_ids if p != DEV_UID)
                m.score = scores.get(partner)
                if partner == "dev_partner_minjun":
                    m.accepted_by = [partner]
                elif partner == "dev_partner_seoyeon":
                    m.appointment_ready = False
            await db.commit()
        print("3. 카드 상태 조정 OK (수아=수락대기 / 민준=상대 선수락 / 서연=조율 미완)")

        # 4. 목록 검증 — inbox가 받을 응답 그대로 출력
        r = await client.get("/matches")
        assert r.status_code == 200, r.text
        items = r.json()
        for it in items:
            print(
                f"   · {it['partner_name']}: status={it['status']} ready={it['appointment_ready']}"
                f" you={it['you_accepted']} partner={it['partner_accepted']} turns={it['turn_count']}"
            )
        assert len(items) == len(PARTNERS), f"목록 {len(items)}건 (기대 {len(PARTNERS)})"
        print(f"\n시드 완료 — GET /matches {len(items)}건. DEV_UID={DEV_UID}")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
