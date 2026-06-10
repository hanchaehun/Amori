import '../api/api_client.dart';

/// 사용자 프로필 — Firestore users 컬렉션 대신 Postgres 단일 원천 (`/users/me`).
class UserRepository {
  UserRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<void> saveProfile({
    String? displayName,
    String? birthDate, // yyyy-MM-dd
    String? gender,
    String? interestGender,
    String? photoUrl,
    String? fcmToken,
  }) async {
    await _api.putJson('/users/me', {
      'display_name': ?displayName,
      'birth_date': ?birthDate,
      'gender': ?gender,
      'interest_gender': ?interestGender,
      'photo_url': ?photoUrl,
      'fcm_token': ?fcmToken,
    });
  }
}
