"""라이브 타이핑 UX 데모 — 실 유저 ↔ 테스트 계정 소개팅 1건을 쏜다.

실 유저(시드가 아닌 계정)를 찾아 run_auto_simulation을 실행한다. 턴에는
plan_reveal_schedule이 visible_at을 심으므로, 폰(Render API)에서 홈 라이브
관전·대화방을 열면 턴이 하나씩 도착하며 타이핑 인디케이터가 움직인다.

시차 간격은 데모용으로 짧게 덮어쓴다(턴당 대략 10~40초) — 서빙(Render)이
아니라 생성 시점 설정이 visible_at을 정하므로 로컬 env 덮어쓰기로 충분하다.

실행: .venv/Scripts/python.exe -X utf8 scripts/demo_typing_ux.py [--uid UID] [--target UID] [--count N]
"""

import argparse
import asyncio
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.chdir(Path(__file__).resolve().parents[1])

# settings가 임포트 시점에 .env를 읽으므로 그 전에 데모 간격을 덮어쓴다.
# 턴당 5분 고정(2026-07-16 사용자 지시) — min=max로 클램프해 지터를 없앤다.
os.environ.setdefault("REVEAL_FIRST_DELAY_SECONDS", "5")
os.environ.setdefault("REVEAL_CHAR_SECONDS", "0")
os.environ.setdefault("REVEAL_MIN_GAP_SECONDS", "300")
os.environ.setdefault("REVEAL_MAX_GAP_SECONDS", "300")

from sqlalchemy import select  # noqa: E402

from app.config import settings  # noqa: E402
from app.db.session import async_session_factory  # noqa: E402
from app.dependencies import get_llm_provider  # noqa: E402
from app.models.database import Persona, SimulationJob, User  # noqa: E402
from app.services.auto_sim import run_auto_simulation  # noqa: E402

SEED_LIKE = ("seed_dev_%", "dev_%", "auto_smoke_%")


async def _find_real_user(db) -> User | None:
    """시드·dev 계정이 아닌, 페르소나 있는 유저 1명(가장 최근 가입)."""
    result = await db.execute(
        select(User).join(Persona, Persona.user_id == User.id)
        .order_by(User.created_at.desc())
    )
    for u in result.scalars().all():
        if not any(u.id.startswith(p[:-1]) for p in SEED_LIKE):
            return u
    return None


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--uid", help="시뮬을 요청할 유저(기본: 최근 가입한 실 유저)")
    parser.add_argument("--target", help="상대 uid(기본: 매칭 자동 선택)")
    parser.add_argument("--count", type=int, default=1, help="연속으로 쏠 소개팅 수")
    args = parser.parse_args()

    print(f"LLM provider = {settings.llm_provider}")
    llm = get_llm_provider()
    async with async_session_factory() as db:
        if args.uid:
            me = (await db.execute(select(User).where(User.id == args.uid))).scalar_one_or_none()
        else:
            me = await _find_real_user(db)
        if me is None:
            print("실 유저를 못 찾았습니다 — 폰에서 가입+페르소나 생성이 먼저입니다.")
            return 1
        print(f"요청자: {me.display_name} ({me.id})")

        for i in range(args.count):
            summary = await run_auto_simulation(
                db, llm, me.id, target_user_id=args.target
            )
            if summary is None:
                print("스킵됨 — 후보 없음 또는 일일 한도. 종료합니다.")
                return 1

            job = (await db.execute(
                select(SimulationJob)
                .where(SimulationJob.match_id == summary["match_id"])
                .order_by(SimulationJob.created_at.desc()).limit(1)
            )).scalar_one()
            turns = job.turns or []
            first = turns[0].get("visible_at") if turns else None
            last = turns[-1].get("visible_at") if turns else None
            target = (await db.execute(
                select(User).where(User.id == summary["target_user_id"])
            )).scalar_one_or_none()
            now = datetime.now(timezone.utc).isoformat(timespec="seconds")
            print(
                f"[{i + 1}/{args.count}] 상대={target.display_name if target else '?'} "
                f"턴={summary['total_turns']} 점수={summary['report_score']}\n"
                f"  now={now}\n  첫 턴 공개={first}\n  마지막 턴 공개={last}"
            )
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
