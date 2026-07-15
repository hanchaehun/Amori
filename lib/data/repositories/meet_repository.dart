import '../api/api_client.dart';

/// 만남 신청 — BFF `/meet/*` (Firestore 직접 쓰기 대체, 일일 쿼터는 서버가 강제).
class MeetRepository {
  MeetRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  final ApiClient _api;

  Future<String> createRequest({
    required String matchId,
    required String receiverId,
    String message = '',
  }) async {
    final json = await _api.postJson('/meet/request', {
      'match_id': matchId,
      'receiver_id': receiverId,
      'message': message,
    }) as Map<String, dynamic>;
    return json['id'] as String? ?? '';
  }

  Future<void> respond({
    required String meetRequestId,
    required bool accept,
  }) async {
    await _api.postJson('/meet/request/$meetRequestId/respond', {
      'action': accept ? 'accept' : 'decline',
    });
  }
}
