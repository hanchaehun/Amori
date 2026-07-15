"""psych_mapping — 결정적 심리 매핑 검증 (P0-B/P0-E)."""

import pytest

from app.llm.psych_mapping import (
    collect_signals,
    compute_conversation_policy,
    compute_psych_profile,
    mbti_big_five_prior,
    measures,
    valid_mbti,
)


def _answer(code: str, letter: str) -> dict:
    return {"code": code, "answer_letter": letter}


class TestMeasures:
    def test_behavior_and_preference(self):
        assert measures("R-3") == "behavior"
        assert measures("2-1") == "preference"

    def test_unknown_code_defaults_preference(self):
        assert measures("10-1") == "preference"
        assert measures("") == "preference"


class TestSignals:
    def test_collects_only_psych_codes(self):
        signals = collect_signals(None, [_answer("R-3", "A"), _answer("R-5", "B")])
        assert signals == {"R-3": "A"}  # R-5는 심리 축 문항이 아님

    def test_merges_latest_over_existing(self):
        signals = collect_signals({"R-3": "A"}, [_answer("R-3", "D")])
        assert signals == {"R-3": "D"}

    def test_skips_free_text(self):
        assert collect_signals(None, [_answer("8-3", "주관식")]) == {}


class TestAttachment:
    def test_anxious_profile(self):
        signals = collect_signals(
            None, [_answer("R-2", "B"), _answer("8-3", "C"), _answer("1-1", "C")]
        )
        profile = compute_psych_profile(signals, None, None)
        assert profile["attachment_anxiety"] >= 0.5
        assert "확인" in profile["attachment_hint"]

    def test_avoidant_profile(self):
        signals = collect_signals(None, [_answer("R-3", "D"), _answer("8-2", "C")])
        profile = compute_psych_profile(signals, None, None)
        assert profile["attachment_avoidance"] >= 0.5
        assert "혼자" in profile["attachment_hint"]

    def test_secure_profile(self):
        signals = collect_signals(None, [_answer("R-2", "A"), _answer("8-3", "B")])
        profile = compute_psych_profile(signals, None, None)
        assert profile["attachment_hint"] == "안정형에 가까워 보여요"

    def test_no_signals_no_hint(self):
        profile = compute_psych_profile({}, None, None)
        assert profile["attachment_hint"] == ""
        assert profile["attachment_anxiety"] is None

    def test_user_visible_preserved(self):
        previous = {"user_visible": False}
        profile = compute_psych_profile({}, None, None, previous)
        assert profile["user_visible"] is False


class TestMbti:
    def test_valid_normalizes(self):
        assert valid_mbti("enfp") == "ENFP"
        assert valid_mbti("ABCD") is None
        assert valid_mbti(None) is None

    def test_prior_directions(self):
        prior = mbti_big_five_prior("ENFP")
        assert prior["E"] > 0.5 and prior["O"] > 0.5  # E, N(직관)→개방성
        assert prior["A"] > 0.5 and prior["C"] < 0.5  # F→친화, P→성실 낮음
        assert prior["N"] == 0.5  # 신경성 축 없음
        assert prior["confidence"] == 0.2

    def test_prior_only_profile(self):
        profile = compute_psych_profile({}, "ISTJ", None)
        assert profile["big_five"]["E"] < 0.5

    def test_llm_estimate_blends_with_prior(self):
        llm = {"E": 0.9, "A": 0.5, "C": 0.5, "N": 0.5, "O": 0.5, "evidence": ["R-2:B"]}
        profile = compute_psych_profile({}, "ISTJ", llm)
        blended = profile["big_five"]["E"]
        assert 0.35 < blended < 0.9  # prior(0.35)와 LLM(0.9) 사이
        assert "mbti_prior" in profile["big_five"]["evidence"]


class TestPolicy:
    def test_conflict_mode_priority(self):
        signals = {"R-3": "A", "3-3": "D"}  # 최신 문항(3-3)이 우선
        policy = compute_conversation_policy(signals, None)
        assert policy["conflict_mode"] == "회피형"

    def test_reassurance_from_anxiety(self):
        signals = collect_signals(None, [_answer("8-3", "C"), _answer("R-2", "B")])
        policy = compute_conversation_policy(signals, None)
        assert policy["reassurance_seeking"] == "높음"

    def test_amplitude_from_voice_stats(self):
        stats = {
            "sample_count": 3,
            "question_ratio": 0.4,
            "laugh": {"per_msg": 0.8},
            "emoji": {"per_msg": 0.3},
            "punct_per_msg": {"~": 0.5, "!!": 0.4},
            "interjections": ["헉"],
        }
        policy = compute_conversation_policy({}, stats)
        assert policy["reaction_amplitude"] == "큼"
        assert policy["question_ratio"] == 0.4

    def test_no_stats_no_amplitude(self):
        policy = compute_conversation_policy({}, None)
        assert policy["reaction_amplitude"] is None


class TestBehaviorBlock:
    def test_block_renders_policy_and_markers(self):
        from app.llm.prompts.simulation import _behavior_block

        persona = {
            "conversation_policy": {
                "question_ratio": 0.35,
                "reaction_amplitude": "큼",
                "conflict_mode": "지연-정리형",
                "reassurance_seeking": "높음",
                "self_disclosure_pace": "느림",
            },
            "psych_profile": {
                "big_five": {"E": 0.8, "A": 0.5, "C": 0.5, "N": 0.2, "O": 0.5,
                             "confidence": 0.4},
            },
        }
        block = _behavior_block(persona)
        assert "35%는 되묻기" in block
        assert "지연-정리형" in block
        assert "성격 마커" in block and "부정 정서 단어가 드묾" in block

    def test_empty_persona_renders_nothing(self):
        from app.llm.prompts.simulation import _behavior_block

        assert _behavior_block({}) == ""
