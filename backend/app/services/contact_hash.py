"""지인 필터 식별자 정규화+해시 — 클라이언트(Flutter)와 동일 규칙 계약.

제품 설계 (2026-07-19, 한채훈): 주소록의 지인과 매칭되지 않게 한다.
제3자 연락처 원문을 서버로 보내지 않기 위해 클라이언트가 이 규칙으로
정규화+SHA-256 해시해 올리고, 서버는 사용자 본인의 phone/email도 같은
규칙으로 해시해 users.phone_hash/email_hash 에 유지한다. 매칭 제외는
해시 대 해시 비교만으로 이뤄진다.

정규화 규칙 (Flutter lib/core/utils/contact_hash.dart 와 반드시 동일):
- 전화번호: 숫자만 남긴다 → 국가번호 82로 시작하면 0으로 치환
  ("+82 10-1234-5678" → "01012345678"). 7자리 미만이면 무효.
- 이메일: 앞뒤 공백 제거 + 소문자. '@' 없으면 무효.
- 해시: SHA-256 hex (소문자 64자).
"""

import hashlib
import re

_HEX64 = re.compile(r"^[0-9a-f]{64}$")


def normalize_phone(raw: str) -> str | None:
    """전화번호 정규화. 무효(숫자 7자리 미만)면 None."""
    digits = re.sub(r"\D", "", raw or "")
    if digits.startswith("82") and len(digits) >= 10:
        digits = "0" + digits[2:]
    if len(digits) < 7:
        return None
    return digits


def normalize_email(raw: str) -> str | None:
    """이메일 정규화. 무효('@' 없음)면 None."""
    email = (raw or "").strip().lower()
    if "@" not in email or len(email) < 3:
        return None
    return email


def sha256_hex(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def phone_hash(raw: str) -> str | None:
    normalized = normalize_phone(raw)
    return sha256_hex(normalized) if normalized else None


def email_hash(raw: str) -> str | None:
    normalized = normalize_email(raw)
    return sha256_hex(normalized) if normalized else None


def is_valid_hash(value: str) -> bool:
    """클라이언트가 올린 해시 형식 검증 — SHA-256 hex 소문자 64자."""
    return bool(_HEX64.match(value or ""))
