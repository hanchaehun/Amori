"""voice_features 단위테스트 — 순수 함수라 DB·LLM 없이 완결된다."""

import pytest

from app.llm.voice_features import extract_voice_stats, voice_confidence


def test_empty_input_returns_none():
    assert extract_voice_stats([]) is None
    assert extract_voice_stats(["", "   "]) is None
    assert extract_voice_stats(None) is None


def test_polite_formality():
    stats = extract_voice_stats(["내일 봬요!", "감사합니다", "좋아요 ㅎㅎ"])
    assert stats["formality_ratio"] == {"존댓말": 1.0, "반말": 0.0}


def test_banmal_formality():
    stats = extract_voice_stats(["뭐해", "밥 먹었어", "나 지금 감"])
    assert stats["formality_ratio"] == {"존댓말": 0.0, "반말": 1.0}


def test_mixed_formality_ignores_unjudgeable():
    # "커피" — 어미 표지 없음 → 분모에서 제외돼 1:1이 유지된다
    stats = extract_voice_stats(["좋아요", "뭐해", "커피"])
    assert stats["formality_ratio"] == {"존댓말": 0.5, "반말": 0.5}


def test_no_formality_evidence_yields_zeros():
    stats = extract_voice_stats(["커피", "치킨!!"])
    assert stats["formality_ratio"] == {"존댓말": 0.0, "반말": 0.0}


def test_short_token_lexicon():
    stats = extract_voice_stats(["넵", "ㅇㅇ"])
    assert stats["formality_ratio"] == {"존댓말": 0.5, "반말": 0.5}


def test_trailing_laugh_and_punct_stripped_before_formality():
    # 문미 ㅋㅋ·부호를 벗겨야 '먹었어'의 반말 표지가 보인다
    stats = extract_voice_stats(["밥 먹었어 ㅋㅋㅋ~~"])
    assert stats["formality_ratio"]["반말"] == 1.0


def test_nida_is_not_banmal_da():
    stats = extract_voice_stats(["확인했습니다"])
    assert stats["formality_ratio"]["존댓말"] == 1.0


def test_laugh_stats():
    stats = extract_voice_stats(["ㅋㅋㅋ 진짜요?", "네 ㅋㅋ", "그렇군요"])
    assert stats["laugh"]["token"] == "ㅋ"
    assert stats["laugh"]["avg_run"] == 2.5  # (3+2)/2
    assert stats["laugh"]["per_msg"] == round(2 / 3, 2)


def test_laugh_absent():
    stats = extract_voice_stats(["안녕하세요", "반가워요"])
    assert stats["laugh"] == {"token": "", "avg_run": 0.0, "per_msg": 0.0}


def test_emoji_counted_but_text_emotes_are_not():
    stats = extract_voice_stats(["좋아요 😊😊", "슬퍼요 ㅠㅠ"])
    assert stats["emoji"]["per_msg"] == 1.0  # 이모지 2개 / 메시지 2개
    assert stats["emoji"]["inventory"] == ["😊"]
    assert stats["punct_per_msg"]["ㅠㅠ"] == 0.5  # ㅠㅠ는 부호 습관으로


def test_punct_habits():
    stats = extract_voice_stats(["오늘 어때~~", "진짜?! 대박!!", "글쎄…"])
    assert stats["punct_per_msg"]["~"] == round(2 / 3, 2)
    assert stats["punct_per_msg"]["!!"] == round(1 / 3, 2)
    assert stats["punct_per_msg"]["…"] == round(1 / 3, 2)
    assert "^^" not in stats["punct_per_msg"]  # 0인 키는 넣지 않는다


def test_ellipsis_dots_variant():
    stats = extract_voice_stats(["음..."])
    assert stats["punct_per_msg"]["…"] == 1.0


def test_question_ratio():
    stats = extract_voice_stats(
        ["뭐 먹을까", "내일 시간 되세요?", "그러니까 말이야", "좋네요"]
    )
    # '을까' 어미 + '?' 두 개가 질문. '그러니까'는 질문 어미로 오탐하지 않는다.
    assert stats["question_ratio"] == 0.5


def test_len_percentiles_single_message():
    stats = extract_voice_stats(["안녕하세요"])
    assert stats["len_chars"] == {"p25": 5, "p50": 5, "p75": 5}


def test_len_percentiles_ordering():
    stats = extract_voice_stats(["아 배고파", "오늘 뭐 먹지 고민되네", "굿"])
    lc = stats["len_chars"]
    assert lc["p25"] <= lc["p50"] <= lc["p75"]


def test_interjections_token_match_only():
    # '헉' 단독 토큰은 잡고, '대박이야'처럼 어절 일부일 때 '대박'도 스트립 후 잡히지만
    # 사전에 없는 감탄사는 나오지 않는다
    stats = extract_voice_stats(["헉 진짜?", "아 맞다 나 내일 약속 있어", "헉!!"])
    assert stats["interjections"][0] == "헉"
    assert "아 맞다" in stats["interjections"]


def test_sample_count():
    stats = extract_voice_stats(["하나", "둘", " ", ""])
    assert stats["sample_count"] == 2


def test_voice_confidence_curve():
    assert voice_confidence(None) == 0.0
    assert voice_confidence({"sample_count": 0}) == 0.0
    c3 = voice_confidence({"sample_count": 3})
    c10 = voice_confidence({"sample_count": 10})
    c100 = voice_confidence({"sample_count": 100})
    assert 0.3 <= c3 <= 0.4  # 설계 사다리: 3개 = 격식·웃음 잡힘
    assert 0.7 <= c10 <= 0.8  # 10개 = 통계 안정
    assert c100 == 0.9  # 상한 — 나머지는 카톡/레지스터 커버리지 몫
    assert c3 < c10


def test_full_shape_keys():
    stats = extract_voice_stats(["안녕하세요 ㅎㅎ 주말에 뭐 하세요?"])
    assert set(stats.keys()) == {
        "sample_count",
        "formality_ratio",
        "len_chars",
        "laugh",
        "emoji",
        "punct_per_msg",
        "question_ratio",
        "interjections",
    }
