import '../../data/models/compatibility_report.dart';
import '../api/api_client.dart';

/// 궁합 리포트 — BFF `GET /report/{match_id}` (서버 캐싱).
class ReportRepository {
  ReportRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  final ApiClient _api;

  Future<CompatibilityReport> fetch(String matchId) async {
    final json = await _api.getJson('/report/$matchId') as Map<String, dynamic>;

    List<ReportFinding> mapFindings(String key) => [
      for (final item
          in (json[key] as List? ?? const []).whereType<Map<String, dynamic>>())
        ReportFinding(
          emoji: item['emoji'] as String? ?? '✨',
          title: item['title'] as String? ?? '',
          detail: item['sub'] as String? ?? item['body'] as String? ?? '',
        ),
    ];

    return CompatibilityReport(
      score: (json['score'] as num?)?.toInt() ?? 0,
      findings: mapFindings('findings'),
      warnings: [
        for (final item in (json['warnings'] as List? ?? const [])
            .whereType<Map<String, dynamic>>())
          ReportFinding(
            emoji: item['emoji'] as String? ?? '⚠️',
            title: item['title'] as String? ?? '',
            detail: item['body'] as String? ?? '',
          ),
      ],
      recommendedPlaces: mapFindings('places'),
      conversationStarters: List<String>.from(
        json['starters'] as List? ?? const [],
      ),
      tip: json['tip'] as String? ?? '',
    );
  }
}
