"""직접 채팅 + 약속 취소 풀 플로우 검증 — mock, Gemini 쿼터 0콜.

흐름: 진행 중(채팅 잠김) → 양쪽 수락(scheduled, 슬롯 예약) → 직접 채팅 양방향
→ 한쪽이 취소 → 시스템 안내문구가 상대 채팅방에 남고, 매치는 진행 중으로 회귀,
예약(파생)이 사라져 그 시간이 다시 가능한 일정이 된다(available_slots는 불변).

실행: cd backend && .venv/Scripts/python.exe -X utf8 scripts/verify_chat_cancel.py
전제: docker compose up -d db, alembic upgrade head (0004)
"""

import asyncio
import os
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ["LLM_PROVIDER"] = "mock"

import httpx
from sqlalchemy import delete, select

from app.auth.firebase import get_current_user
from app.db.session import async_session_factory
from app.main import app
from app.models.database import Match, SimulationJob
from app.services.booking import get_booked_slot_keys

UID_A, UID_B = "chat_test_a", "chat_test_b"
SLOT = {"date": (date.today() + timedelta(days=2)).isoformat(), "time": "저녁"}

CURRENT = {"uid": UID_A, "email": f"{UID_A}@t.local", "name": "A"}
app.dependency_overrides[get_current_user] = lambda: dict(CURRENT)


def switch(uid: str) -> None:
    CURRENT["uid"] = uid
    CURRENT["email"] = f"{uid}@t.local"


async def setup() -> str:
    """테스트 유저 2명 + 약속조율 완료 매치 + 에이전트 턴 2개를 깐다."""
    async with async_session_factory() as db:
        await db.execute(delete(Match).where(Match.participant_ids.any(UID_A)))
        await db.commit()

        match = Match(
            participant_ids=sorted([UID_A, UID_B]),
            status="simulated",
            appointment_ready=True,
            appointment_slot=SLOT,
        )
        db.add(match)
        await db.flush()
        # 에이전트 대화 — speaker는 잡 요청자(A) 기준. B 시점에선 뒤집혀야 한다.
        db.add(
            SimulationJob(
                match_id=match.id,
                requested_by=UID_A,
                status="completed",
                turns=[
                    {"turn_index": 0, "speaker": "me", "text": "안녕하세요!"},
                    {"turn_index": 1, "speaker": "them", "text": "반가워요 ㅎㅎ"},
                ],
            )
        )
        await db.commit()
        return str(match.id)


async def main() -> int:
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(
        transport=transport, base_url="http://t", timeout=httpx.Timeout(60.0)
    ) as client:
        for uid, name in [(UID_A, "은우"), (UID_B, "하린")]:
            switch(uid)
            r = await client.put(
                "/users/me", json={"display_name": name, "available_slots": [SLOT]}
            )
            assert r.status_code == 200, r.text
        match_id = await setup()

        # 1. 진행 중 — 방은 열리지만(에이전트 대화 읽기 전용) 채팅은 잠김
        switch(UID_A)
        r = await client.get(f"/matches/{match_id}/conversation")
        assert r.status_code == 200, r.text
        conv = r.json()
        assert conv["chat_enabled"] is False and conv["status"] == "simulated", conv
        assert [t["speaker"] for t in conv["agent_turns"]] == ["me", "them"], conv
        assert conv["partner_name"] == "하린", conv
        r = await client.post(f"/matches/{match_id}/messages", json={"text": "hi"})
        assert r.status_code == 400 and r.json()["detail"]["error_code"] == "CHAT_LOCKED", r.text
        # B 시점에선 에이전트 턴 speaker가 뒤집힌다
        switch(UID_B)
        r = await client.get(f"/matches/{match_id}/conversation")
        assert [t["speaker"] for t in r.json()["agent_turns"]] == ["them", "me"], r.text
        print("1. 진행 중: 채팅 잠김(CHAT_LOCKED) + 에이전트 턴 시점 변환 OK")

        # 2. 양쪽 수락 → scheduled, 슬롯이 예약된다
        for uid in (UID_A, UID_B):
            switch(uid)
            r = await client.post(f"/matches/{match_id}/accept", json={})
            assert r.status_code == 200, r.text
        assert r.json()["status"] == "scheduled", r.text
        async with async_session_factory() as db:
            assert await get_booked_slot_keys(db, UID_A) == {(SLOT["date"], SLOT["time"])}
        print("2. 양쪽 수락 → scheduled + 슬롯 예약 OK")

        # 3. 직접 채팅 양방향
        switch(UID_A)
        r = await client.post(
            f"/matches/{match_id}/messages", json={"text": "안녕하세요! 드디어 인사드리네요 ㅎㅎ"}
        )
        assert r.status_code == 200 and r.json()["is_me"], r.text
        switch(UID_B)
        r = await client.get(f"/matches/{match_id}/conversation")
        conv = r.json()
        assert conv["chat_enabled"] is True, conv
        assert len(conv["messages"]) == 1 and conv["messages"][0]["is_me"] is False, conv
        r = await client.post(
            f"/matches/{match_id}/messages", json={"text": "반가워요! 일요일에 봬요 :)"}
        )
        assert r.status_code == 200, r.text
        print("3. 직접 채팅 양방향 OK")

        # 4. B가 약속 취소 → 시스템 안내 + 진행 중 회귀 + 약속 상태 전부 해제
        r = await client.post(f"/matches/{match_id}/cancel", json={})
        assert r.status_code == 200, r.text
        cancel = r.json()
        assert cancel["status"] == "simulated", cancel
        assert "하린" in cancel["notice"] and "취소" in cancel["notice"], cancel
        async with async_session_factory() as db:
            m = (await db.execute(select(Match).where(Match.participant_ids.any(UID_A)))).scalar_one()
            assert not m.appointment_ready and m.appointment_slot is None and m.accepted_by == [], (
                m.appointment_ready, m.appointment_slot, m.accepted_by,
            )
            # 예약(파생)이 사라졌으니 그 시간은 자동으로 다시 가능한 일정
            assert await get_booked_slot_keys(db, UID_A) == set()
            assert await get_booked_slot_keys(db, UID_B) == set()
        print(f"4. 취소 OK — notice='{cancel['notice']}', 예약 해제(시간 풀림)")

        # 5. 상대(A) 채팅방에 안내문구가 보이고, 채팅은 다시 잠긴다
        switch(UID_A)
        r = await client.get(f"/matches/{match_id}/conversation")
        conv = r.json()
        assert conv["chat_enabled"] is False and conv["appointment_slot"] is None, conv
        last = conv["messages"][-1]
        assert last["kind"] == "system" and "취소" in last["text"], last
        r = await client.post(f"/matches/{match_id}/messages", json={"text": "..."})
        assert r.status_code == 400 and r.json()["detail"]["error_code"] == "CHAT_LOCKED", r.text
        # 재취소는 NOT_SCHEDULED
        r = await client.post(f"/matches/{match_id}/cancel", json={})
        assert r.status_code == 400 and r.json()["detail"]["error_code"] == "NOT_SCHEDULED", r.text
        print("5. 상대 방에 시스템 안내 노출 + 채팅 재잠금 + 재취소 차단 OK")

        # 6. 남의 매치 접근 차단
        switch("chat_test_stranger")
        r = await client.get(f"/matches/{match_id}/conversation")
        assert r.status_code == 404, r.text
        print("6. 비참가자 404 OK")

    print("\n직접 채팅 + 약속 취소 풀 플로우 전체 통과")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
