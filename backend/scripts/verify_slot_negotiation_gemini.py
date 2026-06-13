"""실 Gemini 일정 조율 검증 — 시뮬레이션만 (~10콜, 리포트 생략).

refatodo ▶다음 작업 1번. 교집합이 1개뿐인 어긋난 일정을 e2e 유저에 세팅하고
실 Gemini 시뮬레이션을 돌려 확인한다:
  ① 제안이 자기 일정 안에서 나오는가 (턴 텍스트 + 일정 출력으로 육안 확인)
  ② 안 되는 시간 거절 + 역제안이 자연스러운가 (육안 확인)
  ③ 합의 슬롯 = 교집합 (자동 단언)
  ④ Match.appointment_slot 저장 + appointment_ready (자동 단언)
  ⑤ 대화 텍스트에 S1 같은 내부 번호가 새지 않는가 (자동 단언)

리포트는 일부러 안 돈다 — 쿼터 절약 + 75점 게이트가 appointment를 되돌리면
저장 검증(④)이 가려진다. 인증만 dependency_overrides, LLM·DB는 실물.

실행: cd backend && .venv/Scripts/python.exe -X utf8 scripts/verify_slot_negotiation_gemini.py
전제: docker compose up -d db (api 컨테이너는 정지), .env LLM_PROVIDER=gemini
"""

import asyncio
import json
import re
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import httpx
from sqlalchemy import select

from app.auth.firebase import get_current_user
from app.db.session import async_session_factory
from app.main import app
from app.models.database import Match, SimulationJob, User
from app.services.booking import get_booked_slot_keys
from app.services.simulation import slot_label

RESULT_PATH = Path(__file__).parent / "slot_negotiation_result.md"

UID_A, UID_B = "e2e_user_a", "e2e_user_b"

# 교집합이 일요일 점심 하나뿐 — A가 토 저녁(자기 S1)부터 제안하면 역제안 경로가 보인다
SLOTS_A = [
    {"date": "2026-06-13", "time": "저녁"},
    {"date": "2026-06-14", "time": "점심"},
]
SLOTS_B = [
    {"date": "2026-06-14", "time": "점심"},
    {"date": "2026-06-15", "time": "저녁"},
]
EXPECTED_AGREED = {"date": "2026-06-14", "time": "점심"}

app.dependency_overrides[get_current_user] = lambda: {
    "uid": UID_A, "email": f"{UID_A}@e2e.test", "name": "지우"
}

out_lines: list[str] = []


def emit(line: str = "") -> None:
    print(line, flush=True)
    out_lines.append(line)


async def setup() -> str | None:
    """일정 세팅 + 기존 매치의 약속 상태 초기화. 매치 id 반환."""
    async with async_session_factory() as db:
        users = (
            await db.execute(select(User).where(User.id.in_([UID_A, UID_B])))
        ).scalars().all()
        by_id = {u.id: u for u in users}
        if set(by_id) != {UID_A, UID_B}:
            emit(f"FAIL: e2e 유저가 DB에 없음 ({sorted(by_id)}) — 먼저 e2e_gemini.py로 생성하세요")
            return None
        by_id[UID_A].available_slots = SLOTS_A
        by_id[UID_B].available_slots = SLOTS_B

        match = (
            await db.execute(
                select(Match).where(Match.participant_ids == sorted([UID_A, UID_B]))
            )
        ).scalar_one_or_none()
        if not match:
            emit("FAIL: e2e 매치가 DB에 없음 — 먼저 e2e_gemini.py로 생성하세요")
            return None
        # 이전 런의 약속 상태를 지워 이번 저장(④)을 깨끗하게 검증한다
        match.appointment_ready = False
        match.appointment_slot = None
        match.accepted_by = []
        await db.commit()
        match_id = str(match.id)

        # 다른 매치의 예약이 슬롯을 차감하면 교집합 설계가 깨진다 — 사전 확인
        for uid in (UID_A, UID_B):
            booked = await get_booked_slot_keys(db, uid)
            if booked:
                emit(f"FAIL: {uid}에 기존 예약이 있어 슬롯이 차감됨: {booked}")
                return None

    emit("## 세팅")
    emit(f"- A(지우) 일정: {', '.join(slot_label(s) for s in SLOTS_A)}")
    emit(f"- B(하준) 일정: {', '.join(slot_label(s) for s in SLOTS_B)}")
    emit(f"- 교집합: {slot_label(EXPECTED_AGREED)} (1개) — 역제안 경로 기대")
    emit(f"- match_id={match_id}, 약속 상태 초기화 완료, 기존 예약 없음")
    emit()
    return match_id


async def run_simulation() -> bool:
    emit("## 시뮬레이션 (실 Gemini, SSE)")
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(
        transport=transport, base_url="http://verify", timeout=httpx.Timeout(600.0)
    ) as client:
        event_name = None
        turn_count = 0
        async with client.stream(
            "POST", "/simulation/run",
            json={"target_user_id": UID_B, "max_turns": 10},
        ) as resp:
            if resp.status_code != 200:
                body = await resp.aread()
                emit(f"FAIL {resp.status_code}: {body.decode('utf-8', 'replace')[:500]}")
                return False
            async for line in resp.aiter_lines():
                if line.startswith("event:"):
                    event_name = line.split(":", 1)[1].strip()
                elif line.startswith("data:"):
                    data = json.loads(line.split(":", 1)[1].strip())
                    if event_name == "turn":
                        turn_count += 1
                        speaker = {"me": "A(지우)", "them": "B(하준)"}[data["speaker"]]
                        emit(f"- [{data['turn_index']}] **{speaker}**: {data['text']}")
                    elif event_name == "done":
                        emit(f"- done: {data}")
                    elif event_name == "error":
                        emit(f"FAIL SSE error: {data}")
                        return False
    emit()
    return turn_count > 0


async def inspect(match_id: str) -> int:
    """내부 턴(눈치·슬롯)과 매치 저장 상태를 DB에서 직접 단언한다."""
    async with async_session_factory() as db:
        mid = uuid.UUID(match_id)
        job = (
            await db.execute(
                select(SimulationJob)
                .where(SimulationJob.match_id == mid)
                .order_by(SimulationJob.created_at.desc())
                .limit(1)
            )
        ).scalar_one()
        match = (
            await db.execute(select(Match).where(Match.id == mid))
        ).scalar_one()

    turns = job.turns or []
    emit("## 내부 턴 (DB — 눈치·슬롯)")
    for t in turns:
        slot = f" → 합의 {slot_label(t['appointment_slot'])}" if t.get("appointment_slot") else ""
        emit(f"- [{t['turn_index']}] {t['speaker']} 읽기={t['partner_read']} 전략={t['strategy']}{slot}")
    emit()

    emit("## 판정")
    failures: list[str] = []

    # ⑤ 내부 슬롯 번호 누출 — 대화 텍스트에 S1/S2가 보이면 안 된다
    leaks = [t["turn_index"] for t in turns if re.search(r"\bS\d+\b", t["text"])]
    emit(f"- ⑤ 내부 번호(S1 등) 누출: {'없음 ✅' if not leaks else f'턴 {leaks}에서 발견 ❌'}")
    if leaks:
        failures.append("내부 슬롯 번호가 대화에 노출됨")

    # ③ 합의 슬롯 = 교집합
    agreed = [t["appointment_slot"] for t in turns if t.get("appointment_slot")]
    if not agreed:
        emit("- ③ 합의 슬롯: 없음 ❌ (수락 턴 미발생 또는 검증에서 버려짐)")
        failures.append("합의 슬롯 없음")
    elif agreed[0] != EXPECTED_AGREED:
        emit(f"- ③ 합의 슬롯: {agreed[0]} ❌ (기대: 교집합 {EXPECTED_AGREED})")
        failures.append("합의 슬롯이 교집합이 아님")
    else:
        emit(f"- ③ 합의 슬롯 = 교집합 {slot_label(EXPECTED_AGREED)} ✅")

    # ④ Match 저장
    ok4 = match.appointment_ready and match.appointment_slot == EXPECTED_AGREED
    emit(
        f"- ④ Match 저장: appointment_ready={match.appointment_ready}, "
        f"appointment_slot={match.appointment_slot} {'✅' if ok4 else '❌'}"
    )
    if not ok4:
        failures.append("Match.appointment_slot/ready 저장 불일치")

    # ①② 는 위 대화 텍스트·일정 대조로 육안 확인 (자동 판정 불가)
    emit("- ①(제안이 자기 일정 안) ②(거절+역제안 자연스러움): 위 대화·일정 대조로 확인")
    emit()

    proposal_turns = [t for t in turns if t["strategy"] == "약속 제안"]
    emit(f"- 참고: 약속 제안 턴 {len(proposal_turns)}회 — 2회 이상이면 역제안 경로를 탄 것")
    emit()

    if failures:
        emit(f"**FAIL**: {'; '.join(failures)}")
        return 1
    emit("**PASS** — 실 Gemini 일정 조율: 합의=교집합, Match 저장, 내부 번호 비노출")
    return 0


async def main() -> int:
    match_id = await setup()
    if not match_id:
        return 1
    if not await run_simulation():
        return 1
    return await inspect(match_id)


if __name__ == "__main__":
    code = asyncio.run(main())
    RESULT_PATH.write_text("\n".join(out_lines), encoding="utf-8")
    print(f"\n결과 저장: {RESULT_PATH}")
    sys.exit(code)
