import '../api/api_client.dart';
import '../dummy/matches.dart';

/// BFF 매칭 결과 (`GET /matches/find`).
class MatchCandidate {
  const MatchCandidate({
    required this.matchId,
    required this.userId,
    required this.displayName,
    required this.score,
  });

  final String matchId; // 백엔드 Match UUID — report/meet 라우터와 동일 ID 체계
  final String userId;
  final String? displayName;
  final double score;

  /// 기존 화면 모델로 변환. 카테고리별 점수(가치관/유머/대화)는
  /// matching 패키지 고도화(P2) 전까지 종합 점수로 대체한다.
  MatchProfile toProfile() {
    final name = displayName ?? '익명';
    final rounded = score.round();
    return MatchProfile(
      id: matchId,
      initial: name.isEmpty ? '?' : name.substring(0, 1),
      name: name,
      age: 0,
      score: rounded,
      values: rounded,
      humor: rounded,
      communication: rounded,
    );
  }
}

/// 벡터 유사도 매칭 — BFF 경유 (Firestore 데모 시딩 대체).
class MatchRepository {
  MatchRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<MatchCandidate>> findMatches({int topK = 10}) async {
    final json = await _api.getJson(
      '/matches/find',
      query: {'top_k': '$topK'},
    );
    return [
      for (final item in (json as List).whereType<Map<String, dynamic>>())
        MatchCandidate(
          matchId: item['match_id'] as String? ?? '',
          userId: item['user_id'] as String? ?? '',
          displayName: item['display_name'] as String?,
          score: (item['score'] as num?)?.toDouble() ?? 0,
        ),
    ];
  }
}
