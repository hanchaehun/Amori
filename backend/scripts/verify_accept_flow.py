"""약속조율 감지 + 양쪽 수락 → scheduled 전환을 mock 풀스택으로 검증.

mock provider는 '약속 수락'으로 끝나는 대화를 내므로 appointment_ready가 켜진다.
인증만 모킹하고 DB·라우터는 실물.

실행(쿼터 0):
  LLM_PROVIDER=mock DAILY_SIMULATION_LIMIT=50 \
  .venv/Scripts/python.exe -X utf8 scripts/verify_accept_flow.py
"""

import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import httpx
from sqlalchemy import select

from app.db.session import async_session_factory
from app.main import app
from app.auth.firebase import get_current_user
from app.models.database import Match


async def reset_match_state() -> None:
    """재실행 멱등성 — 이전 런이 남긴 수락 상태를 초기화한다."""
    async with async_session_factory() as db:
        result = await db.execute(
            select(Match).where(
                Match.participant_ids == sorted(["mock_user_a", "mock_user_b"])
            )
        )
        match_obj = result.scalar_one_or_none()
        if match_obj:
            match_obj.accepted_by = []
            match_obj.appointment_ready = False
            match_obj.status = "candidate"
            await db.commit()

CURRENT = {"uid": "mock_user_a", "email": "ma@t.test", "name": "목A"}


async def fake_user() -> dict:
    return dict(CURRENT)


app.dependency_overrides[get_current_user] = fake_user


def switch(uid: str) -> None:
    CURRENT["uid"] = uid


async def main() -> int:
    await reset_match_state()
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(
        transport=transport, base_url="http://t", timeout=httpx.Timeout(120.0)
    ) as client:
        # personas
        for uid in ("mock_user_a", "mock_user_b"):
            switch(uid)
            r = await client.post("/persona/build", json={"answers": []})
            assert r.status_code == 200, r.text
        print("1. 페르소나 A·B 생성 OK")

        # match
        switch("mock_user_a")
        r = await client.get("/matches/find")
        assert r.status_code == 200, r.text
        target = next((m for m in r.json() if m["user_id"] == "mock_user_b"), None)
        assert target, f"B 후보 없음: {r.text}"
        mid = target["match_id"]
        print(f"2. 매칭 OK — match_id={mid}")

        # simulation → appointment_ready
        appointment_turns = 0
        async with client.stream(
            "POST", "/simulation/run",
            json={"target_user_id": "mock_user_b", "max_turns": 20},
        ) as resp:
            assert resp.status_code == 200, await resp.aread()
            async for line in resp.aiter_lines():
                if line.startswith("data:"):
                    appointment_turns += 1
        print(f"3. 시뮬레이션 SSE OK — {appointment_turns}개 이벤트 (text만 전송)")

        # accept A → 대기
        switch("mock_user_a")
        r = await client.post(f"/matches/{mid}/accept")
        assert r.status_code == 200, r.text
        a = r.json()
        print(f"4. A 수락 → appointment_ready={a['appointment_ready']} both={a['both_accepted']} status={a['status']}")
        assert a["appointment_ready"] is True, "약속조율 감지 실패"
        assert a["both_accepted"] is False

        # accept B → scheduled
        switch("mock_user_b")
        r = await client.post(f"/matches/{mid}/accept")
        assert r.status_code == 200, r.text
        b = r.json()
        print(f"5. B 수락 → both={b['both_accepted']} status={b['status']}")
        assert b["both_accepted"] is True
        assert b["status"] == "scheduled", f"scheduled 전환 실패: {b}"

        print("\n약속조율 감지 + 양쪽 수락 → scheduled 전환 검증 통과")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
