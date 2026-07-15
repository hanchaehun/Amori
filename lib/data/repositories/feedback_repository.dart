import '../api/api_client.dart';

/// 만남 후 피드백 — BFF `POST /feedback` (매칭 품질 개선 신호).
class FeedbackRepository {
  FeedbackRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  final ApiClient _api;

  Future<void> submit({
    required String matchId,
    required String impression,
    required double accuracy,
    required String nextStep,
    String? note,
  }) async {
    await _api.postJson('/feedback', {
      'match_id': matchId,
      'impression': impression,
      'accuracy': accuracy,
      'next_step': nextStep,
      'note': note,
    });
  }
}
