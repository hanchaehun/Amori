import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 지인 필터 식별자 정규화+해시 — 백엔드와 동일 규칙 계약.
///
/// backend/app/services/contact_hash.py 와 반드시 같은 결과를 내야 한다
/// (동일 입력 → 동일 SHA-256이 매칭 제외의 전제). 규칙:
/// - 전화번호: 숫자만 남기고, 국가번호 82로 시작하면 0으로 치환
///   ("+82 10-1234-5678" → "01012345678"). 7자리 미만 무효.
/// - 이메일: 앞뒤 공백 제거 + 소문자. '@' 없으면 무효.
/// - 해시: SHA-256 hex 소문자 64자.
///
/// 연락처 원문은 이 파일 밖(서버·저장소)으로 나가지 않는다 — 해시만 전송.
class ContactHash {
  ContactHash._();

  /// 전화번호 정규화. 무효면 null.
  static String? normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('82') && digits.length >= 10) {
      digits = '0${digits.substring(2)}';
    }
    return digits.length < 7 ? null : digits;
  }

  /// 이메일 정규화. 무효면 null.
  static String? normalizeEmail(String raw) {
    final email = raw.trim().toLowerCase();
    return (!email.contains('@') || email.length < 3) ? null : email;
  }

  static String _sha256Hex(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  /// 전화번호 해시. 무효 입력이면 null.
  static String? phone(String raw) {
    final normalized = normalizePhone(raw);
    return normalized == null ? null : _sha256Hex(normalized);
  }

  /// 이메일 해시. 무효 입력이면 null.
  static String? email(String raw) {
    final normalized = normalizeEmail(raw);
    return normalized == null ? null : _sha256Hex(normalized);
  }

  /// 수동 등록 목록 표시용 마스킹 — 원문 대신 서버로 보내는 라벨.
  /// "01012345678" → "010-****-5678"
  static String maskPhone(String raw) {
    final digits = normalizePhone(raw);
    if (digits == null) return '번호';
    if (digits.length < 8) return '${digits.substring(0, 3)}****';
    final head = digits.substring(0, 3);
    final tail = digits.substring(digits.length - 4);
    return '$head-****-$tail';
  }

  /// "kim@example.com" → "k***@example.com"
  static String maskEmail(String raw) {
    final email = normalizeEmail(raw);
    if (email == null) return '이메일';
    final at = email.indexOf('@');
    final local = email.substring(0, at);
    final domain = email.substring(at);
    final head = local.isEmpty ? '*' : local.substring(0, 1);
    return '$head***$domain';
  }
}
