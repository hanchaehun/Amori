"""farewell 순수함수 검증 — 실패 매치 마무리 인사."""

import random
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from app.services.farewell import (
    FAREWELL_PAIRS,
    append_farewell,
    farewell_turns,
    persona_formality,
)

SETTINGS = SimpleNamespace(
    reveal_first_delay_seconds=8.0,
    reveal_char_seconds=1.6,
    reveal_min_gap_seconds=18.0,
    reveal_max_gap_seconds=180.0,
)


def test_farewell_turns_alternate_from_last_speaker():
    turns = farewell_turns("me", rng=random.Random(1))
    assert [t["speaker"] for t in turns] == ["them", "me"]
    turns = farewell_turns("them", rng=random.Random(1))
    assert [t["speaker"] for t in turns] == ["me", "them"]


def test_farewell_turns_marked_and_from_pool():
    turns = farewell_turns("me", rng=random.Random(2))
    assert all(t["farewell"] for t in turns)
    texts = (turns[0]["text"], turns[1]["text"])
    assert any(
        texts in (pair["polite"], pair["casual"]) for pair in FAREWELL_PAIRS
    )


def test_formality_variant_per_speaker():
    rng = random.Random(3)
    pair = rng.choice(FAREWELL_PAIRS)
    # 같은 rng 시드로 다시 뽑으면 같은 pair — 첫 화자(them)=반말, 답(me)=존댓말
    turns = farewell_turns("me", me_formality="존댓말", them_formality="반말", rng=random.Random(3))
    assert turns[0]["text"] == pair["casual"][0]
    assert turns[1]["text"] == pair["polite"][1]


def test_append_farewell_idempotent():
    base = [{"speaker": "me", "text": "안녕하세요"}]
    once = append_farewell(base, SETTINGS, rng=random.Random(4))
    assert len(once) == 3
    twice = append_farewell(once, SETTINGS, rng=random.Random(4))
    assert twice == once


def test_append_farewell_skips_empty():
    assert append_farewell([], SETTINGS) == []
    assert append_farewell(None, SETTINGS) == []


def test_append_farewell_continues_reveal_schedule():
    start = datetime(2026, 7, 19, 12, 0, tzinfo=timezone.utc)
    base = [
        {"speaker": "me", "text": "안녕하세요", "visible_at": start.isoformat()},
        {
            "speaker": "them",
            "text": "안녕하세요!",
            "visible_at": (start + timedelta(seconds=60)).isoformat(),
        },
    ]
    out = append_farewell(base, SETTINGS, rng=random.Random(5))
    assert len(out) == 4
    stamps = [datetime.fromisoformat(t["visible_at"]) for t in out]
    # 마무리 인사는 기존 마지막 공개 시각 이후로, 순서대로 공개된다
    assert stamps[2] > stamps[1]
    assert stamps[3] > stamps[2]


def test_append_farewell_no_schedule_without_visible_at():
    base = [{"speaker": "me", "text": "안녕하세요"}]
    out = append_farewell(base, SETTINGS, rng=random.Random(6))
    assert "visible_at" not in out[1] and "visible_at" not in out[2]


def test_persona_formality():
    assert persona_formality(None) == ""
    assert persona_formality(SimpleNamespace(speech_style=None)) == ""
    assert (
        persona_formality(SimpleNamespace(speech_style={"formality": "반말"}))
        == "반말"
    )
