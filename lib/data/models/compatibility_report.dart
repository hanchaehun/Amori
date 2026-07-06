class ReportFinding {
  const ReportFinding({
    required this.emoji,
    required this.title,
    required this.detail,
  });

  final String emoji;
  final String title;
  final String detail;

  factory ReportFinding.fromJson(Map<String, dynamic> json) {
    return ReportFinding(
      emoji: json['emoji'] as String? ?? '✨',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }
}

class CompatibilityReport {
  const CompatibilityReport({
    required this.score,
    required this.findings,
    required this.warnings,
    required this.recommendedPlaces,
    required this.conversationStarters,
    required this.tip,
  });

  final int score;
  final List<ReportFinding> findings;
  final List<ReportFinding> warnings;
  final List<ReportFinding> recommendedPlaces;
  final List<String> conversationStarters;
  final String tip;

  factory CompatibilityReport.fromJson(Map<String, dynamic> json) {
    List<ReportFinding> toFindings(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ReportFinding.fromJson)
          .toList();
    }

    List<String> toStrings(dynamic raw) {
      if (raw is! List) return [];
      return raw.whereType<String>().toList();
    }

    return CompatibilityReport(
      score: json['score'] as int? ?? 70,
      findings: toFindings(json['findings']),
      warnings: toFindings(json['warnings']),
      recommendedPlaces: toFindings(json['recommendedPlaces']),
      conversationStarters: toStrings(json['conversationStarters']),
      tip: json['tip'] as String? ?? '',
    );
  }
}
