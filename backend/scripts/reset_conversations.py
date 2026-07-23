"""대화만 초기화 — 계정·페르소나는 유지하고 매칭·시뮬레이션·대화 산출물만 지운다.

reset_accounts.py(전체 wipe)와 달리 users·personas·안전기록(user_blocks·abuse_reports·
blocked_contacts)은 보존한다. auto-sim이 남은 계정끼리 '처음부터' 다시 매칭·시뮬레이션
하도록(새 프롬프트로) 초기화하는 용도.

TRUNCATE가 아니라 DELETE를 쓴다 — matches를 TRUNCATE ... CASCADE 하면 match_id를
SET NULL로 참조하는 user_blocks·abuse_reports(안전 기록)까지 통째로 잘린다. DELETE라야
ondelete='SET NULL'이 작동해 안전 기록이 보존된다.

기본은 **미리보기**(SELECT count만). 실제 삭제는 `--wipe`.

    .venv/Scripts/python.exe -X utf8 scripts/reset_conversations.py          # 미리보기
    .venv/Scripts/python.exe -X utf8 scripts/reset_conversations.py --wipe   # 실제 삭제

주의: 팀 공용 Neon DB다. 실행 전 팀(손지민)과 타이밍을 맞출 것. 서버가 새 프롬프트로
재배포된 뒤에 실행해야 재생성이 새 프롬프트로 나온다(재배포 전이면 옛 프롬프트로 재생성될 수 있음).
"""

import asyncio
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

import asyncpg  # noqa: E402

# 자식 → 부모 순. matches를 마지막에 지우면 CASCADE 자식은 이미 비었고,
# user_blocks·abuse_reports의 match_id는 SET NULL 로 정리된다.
DELETE_TABLES = [
    "llm_call_logs",
    "feedback",
    "meet_requests",
    "reports",
    "chat_messages",
    "simulation_jobs",
    "matches",
]

# 보존 확인용 — 삭제 후에도 행 수가 그대로여야 한다.
KEEP_TABLES = ["users", "personas", "blocked_contacts", "user_blocks", "abuse_reports"]


def _dsn() -> str:
    raw = os.environ["DATABASE_URL"]
    return re.sub(r"^postgresql\+asyncpg", "postgresql", raw)


async def _counts(conn: asyncpg.Connection, tables: list[str]) -> dict[str, int | None]:
    """행 수. 테이블이 없으면(마이그레이션 미적용) None — 크래시 대신 '(없음)'으로 표시."""
    out: dict[str, int | None] = {}
    for t in tables:
        exists = await conn.fetchval("SELECT to_regclass($1)", t)
        out[t] = await conn.fetchval(f"SELECT count(*) FROM {t}") if exists else None
    return out


def _fmt(c: int | None) -> str:
    return "(테이블 없음)" if c is None else f"{c}행"


async def preview(conn: asyncpg.Connection) -> None:
    print("=== 삭제 대상 (대화 산출물) ===")
    for t, c in (await _counts(conn, DELETE_TABLES)).items():
        print(f"  {t:20s} {_fmt(c)}")
    print("\n=== 보존 (계정·페르소나·안전기록) ===")
    for t, c in (await _counts(conn, KEEP_TABLES)).items():
        print(f"  {t:20s} {_fmt(c)}")
    print("\n실제 삭제하려면 --wipe 플래그를 붙여 다시 실행하세요.")


async def wipe(conn: asyncpg.Connection) -> None:
    keep_before = await _counts(conn, KEEP_TABLES)
    async with conn.transaction():
        for t in DELETE_TABLES:
            status = await conn.execute(f"DELETE FROM {t}")
            print(f"  DELETE {t:20s} {status}")
    for t in DELETE_TABLES:
        remaining = await conn.fetchval(f"SELECT count(*) FROM {t}")
        assert remaining == 0, f"{t}에 {remaining}행 잔존"
    keep_after = await _counts(conn, KEEP_TABLES)
    assert keep_after == keep_before, f"보존 테이블 행 수 변동: {keep_before} -> {keep_after}"
    print("\n대화 테이블 0행 확인. 계정·페르소나·안전기록 보존됨:")
    for t, c in keep_after.items():
        print(f"  {t:20s} {_fmt(c)}")


async def main() -> None:
    conn = await asyncpg.connect(_dsn())
    try:
        if "--wipe" in sys.argv:
            await wipe(conn)
        else:
            await preview(conn)
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
