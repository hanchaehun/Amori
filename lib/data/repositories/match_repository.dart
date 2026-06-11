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

/// 연결(inbox) 화면의 대화 카드 한 장 (`GET /matches`).
class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.partnerId,
    required this.partnerName,
    required this.status,
    required this.score,
    required this.appointmentReady,
    required this.youAccepted,
    required this.partnerAccepted,
    required this.lastMessage,
    required this.turnCount,
    required this.updatedAt,
  });

  final String matchId;
  final String partnerId;
  final String? partnerName;
  final String status; // simulated | scheduled | met
  final double? score;
  final bool appointmentReady;
  final bool youAccepted;
  final bool partnerAccepted;
  final String? lastMessage;
  final int turnCount;
  final DateTime? updatedAt;

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
        matchId: json['match_id'] as String? ?? '',
        partnerId: json['partner_id'] as String? ?? '',
        partnerName: json['partner_name'] as String?,
        status: json['status'] as String? ?? 'simulated',
        score: (json['score'] as num?)?.toDouble(),
        appointmentReady: json['appointment_ready'] as bool? ?? false,
        youAccepted: json['you_accepted'] as bool? ?? false,
        partnerAccepted: json['partner_accepted'] as bool? ?? false,
        lastMessage: json['last_message'] as String?,
        turnCount: json['turn_count'] as int? ?? 0,
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );
}

/// 수락 결과 (`POST /matches/{id}/accept`).
class MatchAcceptResult {
  const MatchAcceptResult({
    required this.status,
    required this.bothAccepted,
  });

  final String status; // simulated | scheduled
  final bool bothAccepted;
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

  /// 내 대화 목록 — 시뮬레이션이 있었던 매치만 (연결 화면).
  Future<List<MatchSummary>> listMatches() async {
    final json = await _api.getJson('/matches');
    return [
      for (final item in (json as List).whereType<Map<String, dynamic>>())
        MatchSummary.fromJson(item),
    ];
  }

  /// 만남 수락 — 양쪽 모두 수락하면 status가 'scheduled'로 올라온다.
  Future<MatchAcceptResult> acceptMatch(String matchId) async {
    final json = await _api.postJson('/matches/$matchId/accept', const {})
        as Map<String, dynamic>;
    return MatchAcceptResult(
      status: json['status'] as String? ?? 'simulated',
      bothAccepted: json['both_accepted'] as bool? ?? false,
    );
  }
}
