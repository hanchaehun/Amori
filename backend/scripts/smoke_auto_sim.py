"""자동 소개팅(auto_sim) 오프라인 스모크 — mock provider, Gemini 쿼터 0콜.

전용 스모크 유저 3명을 만들어 run_auto_simulation 한 사이클을 검증한다:
  ⓪ 관심 성별 상호 필터 — A(남·관심 여)에게 B(여·관심 남)는 후보, C(여·관심 여)는 제외
  ① 매칭 후보 선택(시뮬 없던 상대 우선) ② 시뮬레이션 완료 + 턴 저장
  ③ 리포트 생성 + 게이트 규칙 ④ 일일 한도 스킵
  (시뮬은 약속을 잡지 않는다 — 2026-07-04 결정. 약속 관련 단언은 제거됨)

끝나면 스모크 유저·매치를 지워 DB를 원복한다 (다른 시드/실데이터 불변).

실행: .venv/Scripts/python.exe -X utf8 scripts/smoke_auto_sim.py
"""

import asyncio
import os
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

# settings가 임포트 시점에 .env를 읽으므로, 그 전에 환경변수로 덮어쓴다
os.environ["LLM_PROVIDER"] = "mock"
os.environ["DAILY_SIMULATION_LIMIT"] = "2"  # ⑤ 한도 스킵 검증용

from sqlalchemy import delete, select

from app.db.session import async_session_factory
from app.dependencies import get_llm_provider
from app.matching import find_candidates
from app.models.database import Match, Persona, Report, SimulationJob, User
from app.services.auto_sim import run_auto_simulation

UID_A = "auto_smoke_a"
UID_B = "auto_smoke_b"
UID_C = "auto_smoke_c"
ALL_UIDS = [UID_A, UID_B, UID_C]

_next_sat = date.today() + timedelta(days=((5 - date.today().weekday()) % 7) or 7)
SAT_EVENING = {"date": _next_sat.isoformat(), "time": "저녁"}
SUN_LUNCH = {"date": (_next_sat + timedelta(days=1)).isoformat(), "time": "점심"}

SPEECH = {
    "formality": "존댓말", "emoji": "가끔", "laugh": "ㅎㅎ",
    "sentence_length": "중간", "tone": "다정함", "habits": "",
    "punctuation_habits": "", "reaction_style": "공감형",
}


async def _seed(db):
    await _cleanup(db)
    # 값은 가입 화면(signup_screen) 기준 — gender: female/male/other,
    # interest_gender: female/male/both
    for uid, name, slots, gender, interest in [
        (UID_A, "스모크A", [SAT_EVENING, SUN_LUNCH], "male", "female"),
        (UID_B, "스모크B", [SUN_LUNCH], "female", "male"),
        (UID_C, "스모크C", [], "female", "female"),  # A의 관심엔 맞지만 상호는 아님
    ]:
        db.add(User(
            id=uid, display_name=name, available_slots=slots,
            gender=gender, interest_gender=interest,
        ))
    await db.flush()  # FK: personas 보다 users 먼저
    for uid in ALL_UIDS:
        db.add(
            Persona(
                user_id=uid,
                traits={"warmth": 4},
                communication_style="다정한 경청형",
                humor_style="잔잔한 유머",
                value_keywords=["진심", "느린 일상"],
                speech_style=SPEECH,
                sample_messages=["주말에 카페 가는 거 좋아해요 ㅎㅎ"],
                embedding=[0.1] * 1024,
            )
        )
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
    llm = get_llm_provider()
    async with async_session_factory() as db:
        await _seed(db)
        try:
            # ⓪ 관심 성별 상호 필터 — B·C 모두 A와 동일 임베딩(거리 0)이라
            #    필터 없으면 둘 다 최상위. 상호 필터로 C(여·관심 여)만 빠져야 한다.
            cands = await find_candidates(
                db, [0.1] * 1024, UID_A, top_k=50,
                my_gender="male", my_interest_gender="female",
            )
            cand_ids = {c.user_id for c in cands}
            assert UID_B in cand_ids, "상호 매칭(B)이 후보에 없다"
            assert UID_C not in cand_ids, "비상호(C)가 필터를 뚫었다"
            # 관심 'both'는 모든 성별 허용 — C(여·관심 여) 입장에서 보면
            # 후보 B(여)는 관심 여성에 맞고 B의 관심(남)에 C(여)가 없어 제외돼야 한다
            cands_c = await find_candidates(
                db, [0.1] * 1024, UID_C, top_k=50,
                my_gender="female", my_interest_gender="female",
            )
            assert UID_B not in {c.user_id for c in cands_c}, "B의 관심 성별을 무시했다"
            print("⓪ OK — 관심 성별 상호 필터 (B 포함, C 제외, 역방향도 차단)")

            # ①~④ 한 사이클 — 후보 자동 선택은 임베딩 최근접이므로 명시 타깃으로 고정
            summary = await run_auto_simulation(db, llm, UID_A, target_user_id=UID_B)
            assert summary is not None, "auto-sim 사이클이 None"
            assert summary["total_turns"] > 0, "턴이 비었다"
            assert summary["target_user_id"] == UID_B

            result = await db.execute(
                select(SimulationJob).where(SimulationJob.requested_by == UID_A)
            )
            jobs = result.scalars().all()
            assert len(jobs) == 1 and jobs[0].status == "completed"
            assert jobs[0].turns, "턴 미저장"

            match = (await db.execute(
                select(Match).where(Match.id == jobs[0].match_id)
            )).scalar_one()
            assert match.status == "simulated"

            report = (await db.execute(
                select(Report).where(Report.match_id == match.id)
            )).scalar_one_or_none()
            assert report is not None, "리포트 미생성"
            assert summary["report_score"] == report.score
            # 게이트 규칙: 75 미만이면 수락 진행분이 리셋됐어야 한다
            if report.score < 75:
                assert match.accepted_by == []
            print(f"①~③ OK — {summary['total_turns']}턴, 점수={report.score}")

            # ④ 일일 한도(2로 설정): 2회째 실행 후 3회째는 스킵돼야 한다
            second = await run_auto_simulation(db, llm, UID_A, target_user_id=UID_B)
            assert second is not None, "2회째가 한도에 막힘 (한도=2)"
            third = await run_auto_simulation(db, llm, UID_A, target_user_id=UID_B)
            assert third is None, "3회째가 한도를 뚫었다"
            print("④ OK — 일일 한도 스킵 동작")

            print("\nSMOKE PASS")
        finally:
            await _cleanup(db)
            print("스모크 유저/매치 원복 완료")


if __name__ == "__main__":
    asyncio.run(main())
