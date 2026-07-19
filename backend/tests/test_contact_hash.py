"""contact_hash 정규화·해시 규칙 검증 — Flutter 구현과 계약 공유.

여기 케이스의 기대 해시가 바뀌면 lib/core/utils/contact_hash.dart 도
같이 바뀌어야 한다 (동일 입력 → 동일 해시가 지인 필터의 전제).
"""

import hashlib

from app.services.contact_hash import (
    email_hash,
    is_valid_hash,
    normalize_email,
    normalize_phone,
    phone_hash,
)


def test_normalize_phone_strips_formatting():
    assert normalize_phone("010-1234-5678") == "01012345678"
    assert normalize_phone("010 1234 5678") == "01012345678"
    assert normalize_phone("(010) 1234.5678") == "01012345678"


def test_normalize_phone_country_code():
    # +82 10 → 010 (한국 국가번호)
    assert normalize_phone("+82 10-1234-5678") == "01012345678"
    assert normalize_phone("+821012345678") == "01012345678"
    assert normalize_phone("82-2-123-4567") == "021234567"


def test_normalize_phone_rejects_short():
    assert normalize_phone("1234") is None
    assert normalize_phone("") is None
    assert normalize_phone("abc") is None


def test_normalize_email():
    assert normalize_email("  Kim@Example.COM ") == "kim@example.com"
    assert normalize_email("no-at-sign") is None
    assert normalize_email("") is None


def test_hashes_are_sha256_of_normalized():
    expected = hashlib.sha256(b"01012345678").hexdigest()
    assert phone_hash("+82 10-1234-5678") == expected
    assert phone_hash("010.1234.5678") == expected
    expected_email = hashlib.sha256(b"kim@example.com").hexdigest()
    assert email_hash(" Kim@Example.com ") == expected_email


def test_invalid_inputs_hash_to_none():
    assert phone_hash("123") is None
    assert email_hash("nope") is None


def test_is_valid_hash():
    assert is_valid_hash("a" * 64)
    assert is_valid_hash(hashlib.sha256(b"x").hexdigest())
    assert not is_valid_hash("A" * 64)  # 대문자 금지 (소문자 hex 계약)
    assert not is_valid_hash("a" * 63)
    assert not is_valid_hash("")
