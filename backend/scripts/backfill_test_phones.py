"""기존 계정 테스트 전화번호 백필 — 지인 필터 실효화 (2026-07-19 사용자 지시).

가입 폼 전화번호 수집 도입 전에 만들어진 계정에 테스트 번호를 채운다:
- 시드 계정(seed_dev_test_fNN/mNN): seed_test_20.py와 동일 체계
  (여 01099900NN, 남 01099910NN) — 재시드해도 번호가 안 바뀐다.
- 실계정: 010555000NN 순번 — 실번호 대역과 충돌하지 않는 테스트 값.
이미 phone_number가 있는 행은 건너뛴다(멱등). email_hash도 함께 백필한다.

실행: .venv/Scripts/python.exe -X utf8 scripts/backfill_test_phones.py
"""

import asyncio
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select  # noqa: E402

from app.db.session import async_session_factory  # noqa: E402
from app.models.database import User  # noqa: E402
from app.services import contact_hash  # noqa: E402

SEED_RE = re.compile(r"^seed_dev_test_([fm])(\d{2})$")


async def main() -> int:
    async with async_session_factory() as db:
        users = (
            (await db.execute(select(User).order_by(User.created_at))).scalars().all()
        )
        real_seq = 0
        filled = skipped = 0
        for u in users:
            if u.email and not u.email_hash:
                u.email_hash = contact_hash.email_hash(u.email)
            if u.phone_number:
                skipped += 1
                continue
            m = SEED_RE.match(u.id)
            if m:
                # seed_test_20.py 체계와 일치: f01→0109990001, m01→0109991001
                prefix = "01099900" if m.group(1) == "f" else "01099910"
                phone = f"{prefix}{int(m.group(2)):02d}"
            else:
                real_seq += 1
                phone = f"010555000{real_seq:02d}"
            u.phone_number = phone
            u.phone_hash = contact_hash.sha256_hex(phone)
            filled += 1
            print(f"  {u.id[:24]:26} {u.display_name!r:16} → {phone}")
        await db.commit()
        print(f"백필 완료 — 채움 {filled}, 스킵(이미 있음) {skipped}")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
