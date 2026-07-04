"""스타일 게이트 테스트 — 실측에 없는 습관 누출을 결정적으로 제거하는지."""

from app.llm.voice_features import extract_voice_stats
from app.services.style_gate import gate_turn, sanitize_text

# "이모지·~·ㅠㅠ 안 쓰고 ㅋ로 웃는 존댓말" 사용자
_STATS = extract_voice_stats(
    ["안녕하세요 ㅋㅋ 주말에 뭐 하세요?", "저는 등산 갔다왔어요 ㅋㅋㅋ", "오 좋네요!"]
)


def test_removes_emoji_user_never_uses():
    fixed, violations = sanitize_text("등산 좋아하세요? 😊", _STATS)
    assert fixed == "등산 좋아하세요?"
    assert "emoji" in violations


def test_converts_wrong_laugh_token():
    fixed, violations = sanitize_text("네 ㅎㅎㅎ 맞아요", _STATS)
    assert fixed == "네 ㅋㅋㅋ 맞아요"  # 길이 보존, 토큰만 교정
    assert "laugh" in violations


def test_removes_unused_punct_but_keeps_used():
    fixed, violations = sanitize_text("좋아요~~ 진짜!!", _STATS)
    assert "~" not in fixed
    assert fixed.endswith("!")  # !!은 !로 축약 (단일 !는 습관이 아니라 문장부호)
    assert "punct:~" in violations


def test_preserves_habits_user_actually_has():
    # ㅋㅋ는 실측에 있는 습관 — 건드리지 않는다
    fixed, violations = sanitize_text("재밌네요 ㅋㅋ", _STATS)
    assert fixed == "재밌네요 ㅋㅋ"
    assert violations == []


def test_flags_formality_violation_without_editing():
    fixed, violations = sanitize_text("야 뭐해", _STATS)
    assert fixed == "야 뭐해"  # 격식은 결정적 교정 불가 — 기록만
    assert any(v.startswith("formality:") for v in violations)


def test_gate_turn_passthrough_without_stats():
    turn = {"turn_index": 0, "speaker": "me", "text": "안녕~ 😊"}
    assert gate_turn(turn, None) is turn
    assert gate_turn(turn, {"sample_count": 0}) is turn


def test_gate_turn_edits_text_only():
    turn = {
        "turn_index": 3,
        "speaker": "them",
        "text": "저도요 ㅎㅎ 다음에 봬요~ 😊",
        "partner_read": "긍정적",
        "strategy": "마무리",
    }
    gated = gate_turn(turn, _STATS)
    assert gated["text"] == "저도요 ㅋㅋ 다음에 봬요"
    assert gated["strategy"] == "마무리"  # 다른 필드는 보존
    assert turn["text"].endswith("😊")  # 원본 불변


def test_tears_removed_when_not_a_habit():
    fixed, violations = sanitize_text("아쉽네요 ㅠㅠ", _STATS)
    assert fixed == "아쉽네요"
    assert "punct:ㅠㅠ" in violations
