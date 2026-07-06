"""voice 배선(services/voice) + _speech_block v2 렌더링 테스트.

DB 없이 Persona 행을 SimpleNamespace로 대체한다 — apply_voice_profile은
속성 접근만 하므로 충분하다.
"""

from types import SimpleNamespace

from app.llm.prompts.simulation import _speech_block
from app.services.voice import (
    apply_voice_profile,
    free_text_answers,
    merge_response_preferences,
    merge_sample_bank,
)

_FREE = {
    "code": "9-1",
    "category": "말투 샘플",
    "question": "난처한 부탁을 거절해보세요",
    "answer_letter": "주관식",
    "answer_text": "헉 미안한데 이번주는 좀 어려울 것 같아 ㅠㅠ 다음에 꼭!",
}
_CHOICE = {"code": "R-1", "category": "관계 목적", "answer_letter": "C", "answer_text": "진지한 연애"}
_PREF = {
    "code": "P-1",
    "category": "정답지",
    "question": "당신이 힘들다고 했을 때 어떤 답장을 받고 싶나요?",
    "answer_letter": "정답지",
    "answer_text": "많이 힘들었겠다ㅠ 오늘은 푹 쉬어",
}


def _persona_row(**overrides):
    row = SimpleNamespace(
        sample_bank=[],
        voice_stats=None,
        voice_confidence=None,
        sample_messages=["LLM이 지어낸 문장이에요"],
        response_preferences=[],
    )
    for k, v in overrides.items():
        setattr(row, k, v)
    return row


def test_free_text_answers_filters_choices():
    assert free_text_answers([_FREE, _CHOICE]) == [
        {"code": "9-1", "text": _FREE["answer_text"]}
    ]


def test_free_text_accepts_camel_case():
    camel = {"code": "9-2", "category": "말투 샘플", "answerLetter": "주관식", "answerText": "오 저도요!"}
    assert free_text_answers([camel])[0]["text"] == "오 저도요!"


def test_merge_sample_bank_dedupes_by_text():
    bank1 = merge_sample_bank([], [_FREE])
    bank2 = merge_sample_bank(bank1, [_FREE])
    assert len(bank2) == 1
    assert bank2[0]["source"] == "user_written"
    assert bank2[0]["register"] == "9-1"


def test_apply_voice_profile_with_free_text_replaces_llm_samples():
    row = _persona_row()
    apply_voice_profile(row, [_FREE, _CHOICE])
    assert row.voice_stats["sample_count"] == 1
    assert row.voice_confidence > 0
    assert row.sample_messages == [_FREE["answer_text"]]  # 실문장이 LLM 창작을 덮는다


def test_apply_voice_profile_without_free_text_keeps_llm_samples():
    row = _persona_row()
    apply_voice_profile(row, [_CHOICE])
    assert row.voice_stats is None
    assert row.voice_confidence == 0.0
    assert row.sample_messages == ["LLM이 지어낸 문장이에요"]  # 부트스트랩 유지


def test_preference_answer_is_not_a_voice_sample():
    # 정답지는 '내가 받고 싶은 상대의 말' — 내 말투 표본·페르소나 프롬프트에서 제외
    assert free_text_answers([_PREF]) == []


def test_merge_response_preferences_dedupes():
    prefs1 = merge_response_preferences([], [_PREF, _CHOICE])
    prefs2 = merge_response_preferences(prefs1, [_PREF])
    assert len(prefs2) == 1
    assert prefs2[0]["desired_reply"] == _PREF["answer_text"]
    assert prefs2[0]["situation"] == _PREF["question"]


def test_apply_voice_profile_stores_preferences_separately():
    row = _persona_row()
    apply_voice_profile(row, [_FREE, _PREF])
    assert row.voice_stats["sample_count"] == 1  # 정답지는 말투 통계에 안 섞인다
    assert len(row.response_preferences) == 1


def test_speech_block_uses_measured_card_when_stats_present():
    row = _persona_row()
    apply_voice_profile(row, [_FREE])
    block = _speech_block(
        {
            "speech_style": {"formality": "존댓말", "tone_keywords": ["다정"]},
            "sample_messages": row.sample_messages,
            "voice_stats": row.voice_stats,
        }
    )
    assert "실측 1개 발화 통계" in block
    assert "절대 사용 금지" in block
    banned_line = next(l for l in block.splitlines() if l.startswith("절대 사용 금지"))
    assert "이모지" in banned_line  # 표본에 이모지 없음 → 금지 목록에
    assert "ㅠㅠ" not in banned_line  # 실제로 쓴 부호는 금지되지 않는다
    assert _FREE["answer_text"] in block  # few-shot 예시 유지


def test_speech_block_falls_back_to_enum_card_without_stats():
    block = _speech_block(
        {
            "speech_style": {
                "formality": "존댓말",
                "emoji_usage": "가끔",
                "laugh_style": "ㅎㅎ",
                "sentence_length": "보통",
                "tone_keywords": ["담백"],
            },
            "sample_messages": ["안녕하세요"],
        }
    )
    assert "말투(일관 유지)" in block
    assert "실측" not in block
