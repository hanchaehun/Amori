import 'package:amori/core/utils/contact_hash.dart';
import 'package:flutter_test/flutter_test.dart';

/// backend/tests/test_contact_hash.py 와 동일 케이스 — 규칙 계약 검증.
/// 여기 기대값이 바뀌면 백엔드 구현도 같이 바뀌어야 한다.
void main() {
  group('normalizePhone', () {
    test('포맷 문자를 제거한다', () {
      expect(ContactHash.normalizePhone('010-1234-5678'), '01012345678');
      expect(ContactHash.normalizePhone('(010) 1234.5678'), '01012345678');
    });

    test('국가번호 82를 0으로 치환한다', () {
      expect(ContactHash.normalizePhone('+82 10-1234-5678'), '01012345678');
      expect(ContactHash.normalizePhone('+821012345678'), '01012345678');
      expect(ContactHash.normalizePhone('82-2-123-4567'), '021234567');
    });

    test('7자리 미만은 무효', () {
      expect(ContactHash.normalizePhone('1234'), isNull);
      expect(ContactHash.normalizePhone(''), isNull);
    });
  });

  group('normalizeEmail', () {
    test('공백 제거 + 소문자', () {
      expect(ContactHash.normalizeEmail('  Kim@Example.COM '), 'kim@example.com');
    });
    test('@ 없으면 무효', () {
      expect(ContactHash.normalizeEmail('no-at-sign'), isNull);
    });
  });

  group('해시 — 백엔드와 동일 SHA-256', () {
    test('같은 번호의 다른 표기는 같은 해시', () {
      // sha256("01012345678") — 백엔드 hashlib으로 산출한 고정 기대값
      const expected =
          'e60124f2fe2045215abda1ae912aa80bb66dab5fc231a758387682c9c0e70c01';
      expect(ContactHash.phone('+82 10-1234-5678'), expected);
      expect(ContactHash.phone('010.1234.5678'), expected);
    });
    test('무효 입력은 null', () {
      expect(ContactHash.phone('123'), isNull);
      expect(ContactHash.email('nope'), isNull);
    });
  });

  group('마스킹 라벨', () {
    test('전화번호는 가운데를 가린다', () {
      expect(ContactHash.maskPhone('010-1234-5678'), '010-****-5678');
    });
    test('이메일은 로컬 파트를 가린다', () {
      expect(ContactHash.maskEmail('kim@example.com'), 'k***@example.com');
    });
  });
}
