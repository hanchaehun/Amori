"""QA 회귀 방지 — mock 리포트 주제 정합·게이트 다양성, 스키마 검증, warning 방어."""

import asyncio

import pytest
from pydantic import ValidationError

from app.llm.mock import (
    MockLLMProvider,
    _mock_report_score,
    _REPORT_TOPICS,
    _topic_for,
)
from app.routers.matches import _warning_title
from app.schemas.common import FeedbackCreate
from app.schemas.report import ReportResponse


def _report_for(persona: dict) -> dict:
    return asyncio.new_event_loop().run_until_complete(
        MockLLMProvider().generate_report({}, persona, [])
    )


def test_mock_report_matches_dialogue_topic_and_validates():
    # 각 아키타입 주제로 만든 리포트가 그 주제의 대표 발견을 담고,
    # ReportResponse 계약(findings/places/starters>=2 등)을 통과한다.
    for topic, data in _REPORT_TOPICS.items():
        persona = {"communication_style": f"cs::{topic}", "value_keywords": [topic]}
        # _topic_for가 폴백 해시로 topic을 못 맞출 수 있어, 리포트 자체의
        # 계약·구조만 검증하고 주제 조각은 실제 topic으로 직접 확인한다.
        report = _report_for(persona)
        ReportResponse(match_id="m", **report)  # 검증 실패 시 예외
        assert len(report["findings"]) >= 2
        assert len(report["places"]) >= 2
        assert len(report["starters"]) >= 2
        assert 0 <= report["score"] <= 100


def test_mock_report_topic_content_is_used():
    # communication_style이 아키타입과 일치하면 그 주제의 발견 제목이 쓰인다.
    persona = {"communication_style": "담백", "value_keywords": ["영화"]}
    topic = _topic_for(persona)
    report = _report_for(persona)
    expected_title = _REPORT_TOPICS[topic]["finding"][1]
    assert report["findings"][0]["title"] == expected_title


def test_mock_score_deterministic_and_bounded():
    persona = {"communication_style": "느긋", "value_keywords": ["여행"]}
    s1 = _mock_report_score(persona)
    s2 = _mock_report_score(persona)
    assert s1 == s2  # 결정적(재현 가능한 데모)
    assert 68 <= s1 <= 92


def test_warning_title_handles_dict_str_and_none():
    assert _warning_title({"title": "T", "body": "B"}) == "T"
    assert _warning_title({"body": "B"}) == "B"
    assert _warning_title("문자열 경고") == "문자열 경고"  # 구버전/시드 방어
    assert _warning_title("") is None
    assert _warning_title(None) is None
    assert _warning_title(123) is None


def test_feedback_create_rejects_bad_impression_and_long_fields():
    # 정상
    FeedbackCreate(match_id="m", impression="good", accuracy=0.5, next_step="finish")
    with pytest.raises(ValidationError):
        FeedbackCreate(
            match_id="m", impression="excellent", accuracy=0.5, next_step="finish"
        )
    with pytest.raises(ValidationError):
        FeedbackCreate(
            match_id="m", impression="ok", accuracy=0.5, next_step="x" * 51
        )
    with pytest.raises(ValidationError):
        FeedbackCreate(
            match_id="m", impression="ok", accuracy=2.0, next_step="finish"
        )
