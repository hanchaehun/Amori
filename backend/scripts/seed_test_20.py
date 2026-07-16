"""팀 테스트용 가짜 계정 20개 시드 — 테스트남1~10 · 테스트녀1~10.

seed_fake_users의 합성 재료(아키타입 20종 × 성향 변형 × 말투 풀)를 그대로 쓰되,
이름을 테스트남N/테스트녀N으로 고정한다(2026-07-16 사용자 지시). 20명이 서로 다른
아키타입을 하나씩 가져가므로 인격·말투가 전원 다르다. 임베딩은 실제 Gemini로 생성.

재실행 멱등 — 이미 있는 계정(seed_dev_test_*)은 건너뛴다. --force 로 재생성.

실행: .venv/Scripts/python.exe -X utf8 scripts/seed_test_20.py [--force]
필요: .env 의 GEMINI_API_KEY(임베딩), DATABASE_URL 접속 가능
"""

import argparse
import asyncio
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from seed_fake_users import compose_profiles, embed_with_retry  # noqa: E402

from sqlalchemy import delete, select  # noqa: E402

from app.config import settings  # noqa: E402
from app.db.session import async_session_factory, engine  # noqa: E402
from app.llm.embedding import GeminiEmbedder  # noqa: E402
from app.llm.prompts.persona import persona_embedding_text  # noqa: E402
from app.models.database import Base, Persona, User  # noqa: E402

TEST_PREFIX = "seed_dev_test_"


def build_profiles(rng: random.Random) -> list[dict]:
    """compose_profiles 20명을 받아 이름·uid만 테스트 규칙으로 바꾼다."""
    profiles = compose_profiles(20, rng)
    f = m = 0
    for p in profiles:
        if p["gender"] == "female":
            f += 1
            p["uid"] = f"{TEST_PREFIX}f{f:02d}"
            p["display_name"] = f"테스트녀{f}"
        else:
            m += 1
            p["uid"] = f"{TEST_PREFIX}m{m:02d}"
            p["display_name"] = f"테스트남{m}"
        # 데모 목적상 전원 이성 관심으로 고정 — 실 유저 누구와도 상호 필터가 열린다
        p["interest_gender"] = "male" if p["gender"] == "female" else "female"
    return profiles


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="기존 테스트 계정을 지우고 재생성")
    parser.add_argument("--seed", type=int, default=7, help="프로필 합성 RNG 시드(재현성)")
    args = parser.parse_args()

    if not settings.gemini_api_key:
        print("GEMINI_API_KEY 가 없습니다 — 임베딩을 만들 수 없어 중단합니다.")
        return 1

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    embedder = GeminiEmbedder(
        settings.gemini_api_key, settings.gemini_embedding_model, settings.embedding_dim
    )
    profiles = build_profiles(random.Random(args.seed))

    async with async_session_factory() as db:
        if args.force:
            await db.execute(delete(Persona).where(Persona.user_id.like(f"{TEST_PREFIX}%")))
            await db.execute(delete(User).where(User.id.like(f"{TEST_PREFIX}%")))
            await db.commit()
            print(f"--force: 기존 {TEST_PREFIX}* 계정 삭제")

        existing = set(
            (await db.execute(
                select(User.id).where(User.id.like(f"{TEST_PREFIX}%"))
            )).scalars().all()
        )

        created = skipped = 0
        for p in profiles:
            if p["uid"] in existing:
                skipped += 1
                continue
            embedding = await embed_with_retry(
                embedder, persona_embedding_text(p["persona"])
            )
            db.add(User(
                id=p["uid"],
                email=f"{p['uid']}@dev.local",
                display_name=p["display_name"],
                birth_date=p["birth_date"],
                gender=p["gender"],
                interest_gender=p["interest_gender"],
                available_slots=p["available_slots"],
            ))
            await db.flush()  # FK: personas 보다 users 먼저 (smoke_auto_sim과 동일 함정)
            db.add(Persona(
                user_id=p["uid"],
                traits=p["persona"]["traits"],
                communication_style=p["persona"]["communication_style"],
                humor_style=p["persona"]["humor_style"],
                value_keywords=p["persona"]["value_keywords"],
                speech_style=p["persona"]["speech_style"],
                sample_messages=p["persona"]["sample_messages"],
                embedding=embedding,
                answer_count=len(p["answered_codes"]),
                answered_codes=p["answered_codes"],
                persona_revision=1,
                persona_confidence="medium",
            ))
            created += 1
            await asyncio.sleep(0.3)  # 임베딩 RPM 완충
        await db.commit()
        print(f"시드 완료 — 생성 {created}, 스킵(기존) {skipped}")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
