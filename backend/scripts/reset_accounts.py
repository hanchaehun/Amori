"""계정 DB 초기화 — 릴리스 전 공용 Neon의 테스트 잔여물 일괄 정리.

기본 실행은 **미리보기**: 지워질 내용(테이블별 행 수 + 유저 목록)만 보여준다.
실제 삭제는 `--wipe` 플래그를 붙였을 때만 수행한다.

    .venv/Scripts/python scripts/reset_accounts.py          # 미리보기
    .venv/Scripts/python scripts/reset_accounts.py --wipe   # 실제 삭제

주의: 팀 공용 DB다. 실행 전 팀(손지민)과 타이밍을 맞출 것.
Firebase Auth 계정은 별도(콘솔 또는 Admin SDK)로 지워야 한다 — 여기선 DB만.
"""

import asyncio
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

import asyncpg  # noqa: E402

# FK 역순 정리 — TRUNCATE ... CASCADE가 걸러주지만 목록은 명시가 안전하다.
TABLES = [
    "llm_call_logs",
    "feedback",
    "meet_requests",
    "reports",
    "chat_messages",
    "simulation_jobs",
    "matches",
    "personas",
    "users",
]


def _dsn() -> str:
    raw = os.environ["DATABASE_URL"]
    return re.sub(r"^postgresql\+asyncpg", "postgresql", raw)


async def preview(conn: asyncpg.Connection) -> None:
    print("=== 삭제 대상 미리보기 ===")
    for table in TABLES:
        count = await conn.fetchval(f"SELECT count(*) FROM {table}")
        print(f"  {table:20s} {count}행")
    print("\n=== users 목록 ===")
    rows = await conn.fetch(
        "SELECT id, email, display_name, created_at::date AS joined FROM users"
        " ORDER BY created_at"
    )
    for r in rows:
        print(f"  {r['email'] or '(email 없음)':40s} {r['display_name'] or '-':10s} {r['joined']}")
    print("\n실제 삭제하려면 --wipe 플래그를 붙여 다시 실행하세요.")


async def wipe(conn: asyncpg.Connection) -> None:
    joined = ", ".join(TABLES)
    await conn.execute(f"TRUNCATE {joined} CASCADE")
    print(f"TRUNCATE 완료: {joined}")
    for table in TABLES:
        count = await conn.fetchval(f"SELECT count(*) FROM {table}")
        assert count == 0, f"{table}에 {count}행 잔존"
    print("모든 테이블 0행 확인. Firebase Auth 계정은 콘솔에서 별도 삭제하세요.")


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
