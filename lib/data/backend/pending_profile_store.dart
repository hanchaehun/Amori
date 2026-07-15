import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 가입 폼 프로필의 임시 보관소 (2026-07-15 정책).
///
/// 본인인증(KYC)을 통과하기 전에는 users DB에 프로필을 저장하지 않는다 —
/// 인증 이탈·실패 계정이 DB에 쌓이는 것을 막는다. 가입 시 여기(로컬)에만
/// 보관했다가, 인증 통과 후 첫 화면(페르소나 인트로)에서 PUT /users/me로
/// 커밋하고 지운다. 커밋이 실패하면 남겨둬 다음 진입 때 자동 재시도된다
/// (앱을 껐다 켜도 유지 — SharedPreferences).
///
/// KYC가 흐름에서 임시 제외된 현재(팀 테스트)도 커밋 지점이 같은 화면이라
/// 실연동 복원 시 코드 변경 없이 "인증 후 저장"이 성립한다.
class PendingProfileStore {
  PendingProfileStore._();

  static const _key = 'signup.pending_profile';

  static Future<void> save({
    required String displayName,
    String? birthDate, // yyyy-MM-dd
    String? gender,
    String? interestGender,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'display_name': displayName,
        'birth_date': birthDate,
        'gender': gender,
        'interest_gender': interestGender,
      }),
    );
  }

  /// 커밋 대기 중인 프로필. 없으면 null.
  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
