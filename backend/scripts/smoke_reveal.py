"""시차 송출(라이브 관전) 오프라인 스모크 — mock provider, Gemini 쿼터 0콜.

검증:
  ① plan_reveal_schedule — 모든 턴에 visible_at, 단조 증가, 첫 턴=start+도입딜레이,
     원본 필드(strategy 등) 보존
  ② revealed_turns / reveal_complete — 시작 직후엔 미공개·미완, 먼 미래엔 전부 공개·완료,
     visible_at 없는 턴은 공개로 간주(하위호환)
  ③ auto_sim 통합 — reveal_enabled로 한 사이클 후 job.turns에 visible_at이 박히고,
     생성 직후 now로는 송출 미완(스포일러 게이트 닫힘), 먼 미래 now로는 완료

끝나면 스모크 유저/매치를 지워 DB를 원복한다.

실행: .venv/Scripts/python.exe -X utf8 scripts/smoke_reveal.py
"""

import asyncio
import os
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from random import Random

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ["LLM_PROVIDER"] = "mock"

from sqlalchemy import delete, select

from app.config import settings
from app.db.session import async_session_factory
from app.dependencies import get_llm_provider
from app.models.database import Match, Persona, Report, SimulationJob, User
from app.services.auto_sim import run_auto_simulation
from app.services.reveal import (
    plan_reveal_schedule,
    reveal_complete,
    revealed_turns,
)

UID_A = "reveal_smoke_a"
UID_B = "reveal_smoke_b"
ALL_UIDS = [UID_A, UID_B]

_next_sat = date.today() + timedelta(days=((5 - date.today().weekday()) % 7) or 7)
SAT_EVENING = {"date": _next_sat.isoformat(), "time": "저녁"}
SUN_LUNCH = {"date": (_next_sat + timedelta(days=1)).isoformat(), "time": "점심"}

SPEECH = {
    "formality": "존댓말", "emoji": "가끔", "laugh": "ㅎㅎ",
    "sentence_length": "중간", "tone": "다정함", "habits": "",
    "punctuation_habits": "", "reaction_style": "공감형",
}


def _unit_tests():
    """① plan_reveal_schedule · ② revealed_turns/reveal_complete — 순수 함수."""
    start = datetime(2026, 6, 13, 12, 0, 0, tzinfo=timezone.utc)
    turns = [
        {"turn_index": 0, "speaker": "me", "text": "안녕하세요!", "strategy": "알아가기"},
        {"turn_index": 1, "speaker": "them", "text": "반가워요 ㅎㅎ 오늘 날씨 좋네요", "strategy": "알아가기"},
        {"turn_index": 2, "speaker": "me", "text": "그쵸 산책하기 좋아요", "strategy": "마무리"},
    ]
    planned = plan_reveal_schedule(turns, start, settings, rng=Random(7))

    assert all("visible_at" in t for t in planned), "visible_at 누락"
    times = [datetime.fromisoformat(t["visible_at"]) for t in planned]
    assert times == sorted(times) and len(set(times)) == 3, "단조 증가 위반"
    expected_first = start + timedelta(seconds=settings.reveal_first_delay_seconds)
    assert times[0] == expected_first, f"첫 턴 시각 불일치: {times[0]} != {expected_first}"
    assert planned[2]["strategy"] == "마무리", "원본 필드(strategy) 유실"
    assert planned[0]["text"] == "안녕하세요!", "원본 필드(text) 유실"
    print("① OK — plan_reveal_schedule: visible_at·단조증가·도입딜레이·필드보존")

    # ② 공개 필터 — 시작 직후(첫 턴도 아직)·중간·먼 미래
    just_before = expected_first - timedelta(seconds=1)
    assert revealed_turns(planned, just_before) == [], "도입 전인데 공개됨"
    assert not reveal_complete(planned, just_before), "도입 전인데 완료 판정"

    mid = times[1]  # 둘째 턴 공개 시각 정각 → 0,1번 공개
    shown = revealed_turns(planned, mid)
    assert len(shown) == 2, f"중간 공개 수 불일치: {len(shown)}"
    assert not reveal_complete(planned, mid), "중간인데 완료 판정"

    future = times[-1] + timedelta(hours=1)
    assert len(revealed_turns(planned, future)) == 3, "먼 미래에 전부 공개 안 됨"
    assert reveal_complete(planned, future), "먼 미래인데 미완 판정"

    # 하위호환: visible_at 없는 턴은 공개로 간주
    legacy = [{"text": "구버전"}, {"text": "행", "visible_at": future.isoformat()}]
    assert len(revealed_turns(legacy, just_before)) == 1, "구버전 턴이 안 보임"
    assert not reveal_complete(legacy, just_before), "미래 턴이 있는데 완료"
    assert reveal_complete([], just_before), "빈 리스트는 완료여야 함"
    print("② OK — revealed_turns/reveal_complete: 경계·하위호환·빈 리스트")


async def _seed(db):
    await _cleanup(db)
    for uid, name, slots, gender, interest in [
        (UID_A, "리빌A", [SAT_EVENING, SUN_LUNCH], "male", "female"),
        (UID_B, "리빌B", [SUN_LUNCH], "female", "male"),
    ]:
        db.add(User(
            id=uid, display_name=name, available_slots=slots,
            gender=gender, interest_gender=interest,
        ))
    await db.flush()
    for uid in ALL_UIDS:
        db.add(Persona(
            user_id=uid, traits={"warmth": 4},
            communication_style="다정한 경청형", humor_style="잔잔한 유머",
            value_keywords=["진심"], speech_style=SPEECH,
            sample_messages=["주말에 카페 가요 ㅎㅎ"], embedding=[0.1] * 1024,
        ))
    await db.commit()


async def _cleanup(db):
    result = await db.execute(
        select(Match).where(Match.participant_ids.contains([UID_A]))
    )
    for m in result.scalars().all():
        await db.execute(delete(Report).where(Report.match_id == m.id))
        await db.execute(delete(SimulationJob).where(SimulationJob.match_id == m.id))
        await db.execute(delete(Match).where(Match.id == m.id))
    await db.execute(delete(Persona).where(Persona.user_id.in_(ALL_UIDS)))
    await db.execute(delete(User).where(User.id.in_(ALL_UIDS)))
    await db.commit()


async def main():
    _unit_tests()

    assert settings.reveal_enabled, "reveal_enabled가 꺼져 있어 통합 검증 불가"
    llm = get_llm_provider()
    async with async_session_factory() as db:
        await _seed(db)
        try:
            before = datetime.now(timezone.utc)
            summary = await run_auto_simulation(db, llm, UID_A, target_user_id=UID_B)
            assert summary is not None and summary["total_turns"] > 1

            job = (await db.execute(
                select(SimulationJob).where(SimulationJob.requested_by == UID_A)
            )).scalar_one()
            assert job.status == "completed" and job.turns
            assert all("visible_at" in t for t in job.turns), "auto_sim이 visible_at 안 박음"

            # 생성 직후 now로는 송출 미완 — 스포일러 게이트가 닫혀 있어야 한다
            now = datetime.now(timezone.utc)
            shown = revealed_turns(job.turns, now)
            assert len(shown) < len(job.turns), (
                f"생성 직후 전부 공개됨(게이트 무력): {len(shown)}/{len(job.turns)}"
            )
            assert not reveal_complete(job.turns, now), "생성 직후 송출 완료 판정"

            # 첫 visible_at은 사이클 시작 이후
            first_at = min(datetime.fromisoformat(t["visible_at"]) for t in job.turns)
            assert first_at >= before, "visible_at이 과거"

            # 먼 미래엔 전부 공개 + 완료 (수락 게이트도 열린다)
            far = now + timedelta(days=1)
            assert len(revealed_turns(job.turns, far)) == len(job.turns)
            assert reveal_complete(job.turns, far), "먼 미래인데 미완"

            print(f"③ OK — auto_sim 통합: {len(job.turns)}턴 송출 계획, "
                  f"직후 {len(shown)}턴 공개·게이트 닫힘, 미래 전부 공개·게이트 열림")
            print("\nSMOKE PASS")
        finally:
            await _cleanup(db)
            print("스모크 유저/매치 원복 완료")


if __name__ == "__main__":
    asyncio.run(main())
