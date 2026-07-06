"""연결(inbox) 화면 개발용 시드 — mock provider, Gemini 쿼터 0콜.

DEV_UID(기본 dev_hanchaehun) 사용자와 상대들을 만들고 시뮬레이션을 돌려
inbox가 보여줄 상태를 DB에 깐다. 시뮬은 약속을 잡지 않는다(2026-07-04 결정) —
수락 가능(ready) 조건은 '리포트 생성 + 케미 게이트(75) 통과'다:
  수아  — 리포트 91점(통과), 아무도 수락 안 함     → [만남 수락하기] 카드
  민준  — 리포트 87점(통과), 상대가 이미 수락       → 내가 수락하면 바로 scheduled
  서연  — 시뮬만 완료, 리포트 없음                → 수락 불가(NOT_READY) 일반 카드
  지우  — 케미 62점 리포트(게이트 미만)            → failed=True, '닿지 않은 인연' 화면
  하은  — 케미 58점 + 리포트 4일 전(TTL 경과)      → 목록에서 자연 소멸(미노출)
  하늘  — 리포트 85점 + 양쪽 수락(시드가 수락 수행) → 만남 예정 카드 + 직접 채팅
약속(날짜·시간)은 scheduled 이후 두 사용자가 직접 채팅에서 잡는다.

재실행 멱등 — 기존 시드 매치를 지우고 다시 깐다.

실행: .venv/Scripts/python.exe -X utf8 scripts/seed_dev_inbox.py [dev_uid]
이후: uvicorn app.main:app 띄우고 Flutter를 DEV_UID로 붙이면 된다.
"""

import asyncio
import os
import sys
from datetime import date, datetime, timedelta, timezone
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
from app.models.database import Match, Report

DEV_UID = sys.argv[1] if len(sys.argv) > 1 else "dev_hanchaehun"

# DEV의 가능 일정 — 프로필 일정 시트 데모용 (시뮬·약속과는 무관해졌다)
_next_sat = date.today() + timedelta(days=((5 - date.today().weekday()) % 7) or 7)
DEV_SLOTS = [
    {"date": _next_sat.isoformat(), "time": "저녁"},
    {"date": (_next_sat + timedelta(days=1)).isoformat(), "time": "점심"},
]

PARTNERS = [
    {"uid": "dev_partner_sua", "name": "수아"},
    {"uid": "dev_partner_minjun", "name": "민준"},
    {"uid": "dev_partner_seoyeon", "name": "서연"},
    {"uid": "dev_partner_jiwoo", "name": "지우"},
    {"uid": "dev_partner_haeun", "name": "하은"},
    {"uid": "dev_partner_haneul", "name": "하늘"},
]

# 수락 가능 조건 = 리포트 게이트 통과. 상태별 리포트를 직접 깐다 —
# 서연은 일부러 리포트를 만들지 않는다(NOT_READY 분기 검증).
REPORTS = {
    "dev_partner_sua": {"score": 91, "warning": None, "days_ago": 0},
    "dev_partner_minjun": {"score": 87, "warning": None, "days_ago": 0},
    "dev_partner_haneul": {"score": 85, "warning": None, "days_ago": 0},
    "dev_partner_jiwoo": {
        "score": 62,
        "warning": "유머 코드가 달라 대화 텐션이 자주 어긋났어요",
        "days_ago": 0,
    },
    "dev_partner_haeun": {
        "score": 58,
        "warning": "서로의 관심사가 평행선을 그렸어요",
        "days_ago": 4,  # TTL(3일) 경과 → 목록 자연 소멸
    },
}

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
        r = await client.put(
            "/users/me",
            json={"display_name": "지은", "available_slots": DEV_SLOTS},
        )
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

        # 2. dev 유저로 시뮬레이션
        switch(DEV_UID)

        async def run_sim(target_uid: str) -> None:
            async with client.stream(
                "POST", "/simulation/run",
                json={"target_user_id": target_uid, "max_turns": 20},
            ) as resp:
                assert resp.status_code == 200, await resp.aread()
                async for _ in resp.aiter_lines():
                    pass

        for p in PARTNERS:
            await run_sim(p["uid"])
        print(f"2. 시뮬레이션 {len(PARTNERS)}건 완료 OK")

        # 3. 카드 상태 다양화 — 리포트 직접 시드(서연 제외) + 민준·하늘 상대 선수락
        match_ids: dict[str, str] = {}
        async with async_session_factory() as db:
            result = await db.execute(
                select(Match).where(Match.participant_ids.any(DEV_UID))
            )
            for m in result.scalars().all():
                partner = next(p for p in m.participant_ids if p != DEV_UID)
                match_ids[partner] = str(m.id)
                if partner in REPORTS:
                    rep = REPORTS[partner]
                    m.score = float(rep["score"])
                    db.add(
                        Report(
                            match_id=m.id,
                            score=rep["score"],
                            findings=[],
                            warnings=[rep["warning"]] if rep["warning"] else [],
                            places=[],
                            starters=[],
                            tip=None,
                            ai_generated=True,
                            created_at=datetime.now(timezone.utc)
                            - timedelta(days=rep["days_ago"]),
                        )
                    )
                if partner in ("dev_partner_minjun", "dev_partner_haneul"):
                    m.accepted_by = [partner]
            await db.commit()
        print(
            "3. 카드 상태 조정 OK (수아=수락대기 / 민준·하늘=상대 선수락"
            " / 서연=리포트 없음 / 지우=실패 / 하은=실패+TTL경과)"
        )

        # 4. 하늘과의 만남 수락 → scheduled (약속은 이후 직접 채팅에서)
        r = await client.post(f"/matches/{match_ids['dev_partner_haneul']}/accept", json={})
        assert r.status_code == 200, r.text
        accept = r.json()
        assert accept["status"] == "scheduled" and accept["both_accepted"], accept
        print("4. 하늘 수락 OK → scheduled")

        # 4-1. 만남 확정 후 직접 채팅 — 데모용 2건 + 잠금 검증
        haneul_id = match_ids["dev_partner_haneul"]
        r = await client.post(
            f"/matches/{haneul_id}/messages", json={"text": "안녕하세요! 드디어 직접 인사드려요 ㅎㅎ"}
        )
        assert r.status_code == 200, r.text
        switch("dev_partner_haneul")
        r = await client.post(
            f"/matches/{haneul_id}/messages",
            json={"text": "반가워요! 언제 만날지는 여기서 정해봐요 :)"},
        )
        assert r.status_code == 200, r.text
        switch(DEV_UID)
        r = await client.get(f"/matches/{haneul_id}/conversation")
        assert r.status_code == 200, r.text
        conv = r.json()
        assert conv["chat_enabled"] and len(conv["messages"]) == 2, conv
        assert conv["agent_turns"], "에이전트 대화가 비어 있음"
        # 진행 중(수아)은 채팅 잠김 — 서버 차단 확인
        r = await client.post(
            f"/matches/{match_ids['dev_partner_sua']}/messages", json={"text": "x"}
        )
        assert r.status_code == 400 and r.json()["detail"]["error_code"] == "CHAT_LOCKED", r.text
        print("4-1. 하늘 직접 채팅 2건 시드 OK + 진행 중 채팅 잠금(CHAT_LOCKED) OK")

        # 4-2. 직접 약속 확정 — 사용자가 채팅에서 합의한 시간을 기록한다
        #      (시뮬 약속 폐지 — 약속의 주체는 사용자. 일정 시트 잠금의 근거가 된다)
        r = await client.post(
            f"/matches/{haneul_id}/appointment",
            json={"date": DEV_SLOTS[0]["date"], "time": DEV_SLOTS[0]["time"]},
        )
        assert r.status_code == 200, r.text
        assert "저녁" in r.json()["appointment_slot"], r.json()
        r = await client.get("/users/me")
        booked = r.json()["booked_slots"]
        assert len(booked) == 1 and booked[0]["partner_name"] == "하늘", booked
        # 진행 중(수아) 매치엔 약속을 걸 수 없다
        r = await client.post(
            f"/matches/{match_ids['dev_partner_sua']}/appointment",
            json={"date": DEV_SLOTS[1]["date"], "time": DEV_SLOTS[1]["time"]},
        )
        assert r.status_code == 400 and r.json()["detail"]["error_code"] == "NOT_SCHEDULED", r.text
        print("4-2. 직접 약속 확정 OK (토 저녁 · booked_slots 잠금 · NOT_SCHEDULED 차단)")

        # 5. 수락 게이트 검증 — 서연(리포트 없음)은 NOT_READY, 지우(게이트 미만)는 BELOW_GATE
        r = await client.post(f"/matches/{match_ids['dev_partner_seoyeon']}/accept", json={})
        assert r.status_code == 400 and r.json()["detail"]["error_code"] == "NOT_READY", r.text
        r = await client.post(f"/matches/{match_ids['dev_partner_jiwoo']}/accept", json={})
        assert r.status_code == 400 and r.json()["detail"]["error_code"] == "BELOW_GATE", r.text
        print("5. 수락 게이트 OK (리포트 없음=NOT_READY, 게이트 미만=BELOW_GATE)")

        # 6. 목록 검증 — inbox가 받을 응답 그대로 출력
        r = await client.get("/matches")
        assert r.status_code == 200, r.text
        items = r.json()
        for it in items:
            print(
                f"   · {it['partner_name']}: status={it['status']} ready={it['appointment_ready']}"
                f" you={it['you_accepted']} partner={it['partner_accepted']} turns={it['turn_count']}"
                f" failed={it['failed']} report={it['report_score']}"
            )
        names = {it["partner_name"] for it in items}
        assert len(items) == 5, f"목록 {len(items)}건 (기대 5 — 하은은 TTL 소멸)"
        assert "하은" not in names, "TTL 지난 실패 건이 목록에 남아 있음"
        by_name = {it["partner_name"]: it for it in items}
        # ready = 리포트 게이트 통과
        assert by_name["수아"]["appointment_ready"] is True
        assert by_name["민준"]["appointment_ready"] is True and by_name["민준"]["partner_accepted"]
        assert by_name["서연"]["appointment_ready"] is False  # 리포트 없음
        jiwoo = by_name["지우"]
        assert jiwoo["failed"] and jiwoo["report_score"] == 62, jiwoo
        assert jiwoo["failure_reason"], "실패 사유가 비어 있음"
        assert not jiwoo["appointment_ready"], jiwoo
        haneul = by_name["하늘"]
        assert haneul["status"] == "scheduled", haneul
        assert "저녁" in (haneul["appointment_slot"] or ""), haneul  # 직접 확정한 약속 라벨
        ok = [it for it in items if not it["failed"]]
        assert len(ok) == 4 and all(not it["failure_reason"] for it in ok)
        print(f"\n시드 완료 — GET /matches {len(items)}건. DEV_UID={DEV_UID}")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
