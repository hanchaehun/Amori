"""연결(inbox) 화면 개발용 시드 — mock provider, Gemini 쿼터 0콜.

DEV_UID(기본 dev_hanchaehun) 사용자와 상대들을 만들고 시뮬레이션을 돌려
inbox가 보여줄 상태를 DB에 깐다:
  수아  — 약속조율 완료(일 점심), 아무도 수락 안 함  → [만남 수락하기] 카드
  민준  — 약속조율 완료(일 점심), 상대가 이미 수락    → 내가 수락하면 바로 scheduled
          (수아·민준이 같은 시간을 잡아둠 — 하나를 수락하면 다른 쪽은 SLOT_TAKEN, 기능 데모)
  서연  — 시뮬레이션만 완료(일정 없음, 조율 미완)      → 일반 진행 중 카드
  지우  — 케미 62점 리포트(게이트 미만)              → failed=True, '닿지 않은 인연' 화면
  하은  — 케미 58점 + 리포트 4일 전(TTL 경과)        → 목록에서 자연 소멸(미노출)
  하늘  — 토 저녁 합의 + 양쪽 수락(시드가 수락 수행)  → 만남 예정 카드, 토 저녁이 예약됨
  라온  — 토 저녁만 가능, 예약 *이후* 시뮬레이션      → 토 저녁이 차감돼 약속 불성립(조율 미완)

검증: 예약 차감(라온), 일정 시트 잠금(booked_slots), 수락 충돌(SLOT_TAKEN)까지 단언.

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

# 다음 토요일 저녁·일요일 점심 — DEV의 가능 일정.
# mock 시뮬레이션은 교집합 첫 슬롯으로 약속을 잡는다.
_next_sat = date.today() + timedelta(days=((5 - date.today().weekday()) % 7) or 7)
SAT_EVENING = {"date": _next_sat.isoformat(), "time": "저녁"}
SUN_LUNCH = {"date": (_next_sat + timedelta(days=1)).isoformat(), "time": "점심"}
DEV_SLOTS = [SAT_EVENING, SUN_LUNCH]

PARTNERS = [
    {"uid": "dev_partner_sua", "name": "수아", "slots": [SUN_LUNCH]},
    {"uid": "dev_partner_minjun", "name": "민준", "slots": [SUN_LUNCH]},
    {"uid": "dev_partner_seoyeon", "name": "서연", "slots": []},
    {"uid": "dev_partner_jiwoo", "name": "지우", "slots": []},
    {"uid": "dev_partner_haeun", "name": "하은", "slots": []},
    {"uid": "dev_partner_haneul", "name": "하늘", "slots": [SAT_EVENING]},
]

# 라온은 토 저녁 예약 *이후*에 시뮬레이션 — 예약 차감 검증용
LATE_PARTNER = {"uid": "dev_partner_raon", "name": "라온", "slots": [SAT_EVENING]}

# 케미 게이트(75) 미만 리포트를 직접 깔아 '닿지 않은 인연' 분기를 만든다.
# days_ago가 TTL(3일)을 넘으면 GET /matches에서 자연 소멸해야 한다.
FAILED_REPORTS = {
    "dev_partner_jiwoo": {
        "score": 62,
        "warning": "유머 코드가 달라 대화 텐션이 자주 어긋났어요",
        "days_ago": 0,
    },
    "dev_partner_haeun": {
        "score": 58,
        "warning": "서로의 관심사가 평행선을 그렸어요",
        "days_ago": 4,
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
        # 1. 유저 프로필 + 페르소나 (mock — 쿼터 0). 파트너별 가능 일정 포함.
        switch(DEV_UID)
        r = await client.put(
            "/users/me",
            json={"display_name": "지은", "available_slots": DEV_SLOTS},
        )
        assert r.status_code == 200, r.text
        r = await client.post("/persona/build", json={"answers": []})
        assert r.status_code == 200, r.text
        for p in [*PARTNERS, LATE_PARTNER]:
            switch(p["uid"])
            r = await client.put(
                "/users/me",
                json={"display_name": p["name"], "available_slots": p["slots"]},
            )
            assert r.status_code == 200, r.text
            r = await client.post("/persona/build", json={"answers": []})
            assert r.status_code == 200, r.text
        print(f"1. 페르소나 {2 + len(PARTNERS)}명 생성 OK (파트너별 일정 포함)")

        # 2. dev 유저로 시뮬레이션 (mock 대화는 약속수락으로 끝남).
        #    라온은 토 저녁이 예약된 *뒤*(6단계)에 돌린다 — 차감 검증.
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

        # 3. 카드 상태 다양화 — 민준·하늘은 상대 선수락, 서연은 약속조율 미완,
        #    지우·하은은 게이트 미만 리포트('닿지 않은 인연')
        match_ids: dict[str, str] = {}
        async with async_session_factory() as db:
            result = await db.execute(
                select(Match).where(Match.participant_ids.any(DEV_UID))
            )
            scores = {
                "dev_partner_sua": 91.0,
                "dev_partner_minjun": 87.0,
                "dev_partner_seoyeon": 79.0,
                "dev_partner_jiwoo": 71.0,
                "dev_partner_haeun": 70.0,
                "dev_partner_haneul": 85.0,
            }
            for m in result.scalars().all():
                partner = next(p for p in m.participant_ids if p != DEV_UID)
                match_ids[partner] = str(m.id)
                m.score = scores.get(partner)
                if partner in ("dev_partner_minjun", "dev_partner_haneul"):
                    m.accepted_by = [partner]
                elif partner == "dev_partner_seoyeon":
                    m.appointment_ready = False
                elif partner in FAILED_REPORTS:
                    fr = FAILED_REPORTS[partner]
                    # 지우는 약속이 잡힌 채(appointment_ready=True)로 둔다 —
                    # 게이트 미만이면 약속째 무효 처리되는지 검증하기 위해
                    if partner == "dev_partner_haeun":
                        m.appointment_ready = False
                    db.add(
                        Report(
                            match_id=m.id,
                            score=fr["score"],
                            findings=[],
                            warnings=[fr["warning"]],
                            places=[],
                            starters=[],
                            tip=None,
                            ai_generated=True,
                            created_at=datetime.now(timezone.utc)
                            - timedelta(days=fr["days_ago"]),
                        )
                    )
            await db.commit()
        print(
            "3. 카드 상태 조정 OK (수아=수락대기 / 민준·하늘=상대 선수락 / 서연=조율 미완"
            " / 지우=실패 / 하은=실패+TTL경과)"
        )

        # 4. 하늘과의 만남 수락 → scheduled, 토 저녁이 예약된다
        r = await client.post(f"/matches/{match_ids['dev_partner_haneul']}/accept", json={})
        assert r.status_code == 200, r.text
        accept = r.json()
        assert accept["status"] == "scheduled" and accept["both_accepted"], accept
        print("4. 하늘 수락 OK → scheduled (토 저녁 예약)")

        # 4-1. 만남 확정 후 직접 채팅 — 데모용 2건 + 잠금 검증
        haneul_id = match_ids["dev_partner_haneul"]
        r = await client.post(
            f"/matches/{haneul_id}/messages", json={"text": "안녕하세요! 드디어 직접 인사드려요 ㅎㅎ"}
        )
        assert r.status_code == 200, r.text
        switch("dev_partner_haneul")
        r = await client.post(
            f"/matches/{haneul_id}/messages", json={"text": "반가워요! 토요일 저녁 기대하고 있을게요 :)"}
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

        # 5. 일정 시트 데이터 — 예약된 칸이 상대 이름과 함께 내려와야 한다
        r = await client.get("/users/me")
        assert r.status_code == 200, r.text
        booked = r.json()["booked_slots"]
        assert len(booked) == 1, booked
        assert booked[0]["time"] == "저녁" and booked[0]["partner_name"] == "하늘", booked
        print("5. booked_slots OK (토 저녁 · 하늘)")

        # 6. 수락 충돌 — 같은 토 저녁을 잡아둔 일회용 매치 수락 시 SLOT_TAKEN
        async with async_session_factory() as db:
            ghost = Match(
                participant_ids=sorted([DEV_UID, "dev_partner_ghost"]),
                status="simulated",
                appointment_ready=True,
                appointment_slot=SAT_EVENING,
            )
            db.add(ghost)
            await db.commit()
            ghost_id = str(ghost.id)
        r = await client.post(f"/matches/{ghost_id}/accept", json={})
        assert r.status_code == 400, r.text
        assert r.json()["detail"]["error_code"] == "SLOT_TAKEN", r.text
        async with async_session_factory() as db:
            await db.execute(delete(Match).where(Match.id == ghost.id))
            await db.commit()
        print("6. 수락 충돌 차단 OK (SLOT_TAKEN)")

        # 7. 라온 시뮬레이션 — 토 저녁이 예약돼 차감됐으므로 교집합이 비어
        #    약속이 성립하지 않아야 한다 (다른 에이전트 소개팅에 중복 진입 차단)
        await run_sim(LATE_PARTNER["uid"])
        print("7. 라온 시뮬레이션 OK (예약 차감 상태에서 진행)")

        # 8. 목록 검증 — inbox가 받을 응답 그대로 출력
        r = await client.get("/matches")
        assert r.status_code == 200, r.text
        items = r.json()
        for it in items:
            print(
                f"   · {it['partner_name']}: status={it['status']} ready={it['appointment_ready']}"
                f" you={it['you_accepted']} partner={it['partner_accepted']} turns={it['turn_count']}"
                f" failed={it['failed']} report={it['report_score']} slot={it['appointment_slot']}"
            )
        names = {it["partner_name"] for it in items}
        assert len(items) == 6, f"목록 {len(items)}건 (기대 6 — 하은은 TTL 소멸)"
        assert "하은" not in names, "TTL 지난 실패 건이 목록에 남아 있음"
        jiwoo = next(it for it in items if it["partner_name"] == "지우")
        assert jiwoo["failed"] and jiwoo["report_score"] == 62, jiwoo
        assert jiwoo["failure_reason"], "실패 사유가 비어 있음"
        # 게이트가 왕 — DB엔 약속이 잡혀 있어도 응답에선 약속째 무효여야 한다
        assert not jiwoo["appointment_ready"], jiwoo
        assert not jiwoo["you_accepted"] and not jiwoo["partner_accepted"], jiwoo
        r = await client.post(f"/matches/{jiwoo['match_id']}/accept", json={})
        assert r.status_code == 400 and r.json()["detail"]["error_code"] == "BELOW_GATE", r.text
        ok = [it for it in items if not it["failed"]]
        assert len(ok) == 5 and all(not it["failure_reason"] for it in ok)
        by_name = {it["partner_name"]: it for it in items}
        # 슬롯 조율 — 수아·민준은 일 점심 합의, 일정 없는 서연은 의향 폴백(라벨 없음)
        assert by_name["수아"]["appointment_slot"] and "점심" in by_name["수아"]["appointment_slot"]
        assert by_name["민준"]["appointment_slot"] and "점심" in by_name["민준"]["appointment_slot"]
        assert by_name["서연"]["appointment_slot"] is None
        # 하늘 — 양쪽 수락 완료, 만남 예정 + 토 저녁 라벨
        haneul = by_name["하늘"]
        assert haneul["status"] == "scheduled" and "저녁" in (haneul["appointment_slot"] or "")
        # 라온 — 토 저녁이 예약 차감돼 교집합이 빔 → 약속 불성립(중복 진입 차단 실증)
        raon = by_name["라온"]
        assert not raon["appointment_ready"] and raon["appointment_slot"] is None, raon
        print(f"\n시드 완료 — GET /matches {len(items)}건. DEV_UID={DEV_UID}")
        print("   더블부킹 방어 3종 검증: 시뮬 차감(라온)·시트 잠금(booked)·수락 충돌(SLOT_TAKEN)")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
