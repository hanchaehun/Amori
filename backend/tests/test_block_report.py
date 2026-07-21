"""UGC 안전(신고·차단, App Store 1.2) — DB 없이 검증 가능한 순수 로직 회귀."""

import pytest
from pydantic import ValidationError

from app.models.database import AbuseReport, Match, UserBlock
from app.routers.matches import _partner_uid, _REPORT_REASONS, ReportRequest


def test_partner_uid_returns_the_other_participant():
    match = Match(participant_ids=["alice", "bob"])
    assert _partner_uid(match, "alice") == "bob"
    assert _partner_uid(match, "bob") == "alice"


def test_partner_uid_self_fallback_when_alone():
    # 방어적: 참가자 목록에 나밖에 없으면 나를 돌려준다(크래시 대신).
    match = Match(participant_ids=["solo"])
    assert _partner_uid(match, "solo") == "solo"


def test_report_reasons_are_the_canonical_set():
    assert _REPORT_REASONS == {
        "inappropriate",
        "harassment",
        "spam",
        "fake",
        "other",
    }


def test_report_request_defaults_and_limits():
    assert ReportRequest().reason == "other"
    assert ReportRequest().detail is None
    # detail 1000자 초과는 거부(과도한 페이로드 방어).
    with pytest.raises(ValidationError):
        ReportRequest(detail="가" * 1001)
    # reason 20자 초과도 거부.
    with pytest.raises(ValidationError):
        ReportRequest(reason="x" * 21)


def test_block_and_report_models_construct():
    # 모델이 임포트·인스턴스화되는지(테이블 스키마 정의 스모크).
    block = UserBlock(blocker_id="a", blocked_id="b")
    assert block.blocker_id == "a" and block.blocked_id == "b"
    report = AbuseReport(reporter_id="a", reported_id="b", reason="spam")
    assert report.reason == "spam"
