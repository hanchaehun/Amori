import '../../data/models/persona.dart';
import '../api/api_client.dart';
import '../backend/scenario_answers_store.dart';

class DailyPersonaStatus {
  const DailyPersonaStatus({
    required this.completedToday,
    required this.scenarioCode,
    required this.answerCount,
    required this.personaRevision,
  });

  final bool completedToday;
  final String? scenarioCode;
  final int? answerCount;
  final int personaRevision;

  factory DailyPersonaStatus.fromJson(Map<String, dynamic> json) =>
      DailyPersonaStatus(
        completedToday: json['completed_today'] as bool? ?? false,
        scenarioCode: json['scenario_code'] as String?,
        answerCount: json['answer_count'] as int?,
        personaRevision: json['persona_revision'] as int? ?? 1,
      );
}

/// 페르소나 생성/조회 — BFF `/persona/*` 경유 (클라이언트 직접 LLM 호출 제거).
class PersonaRepository {
  PersonaRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// 시나리오 답변으로 페르소나를 생성한다. (`POST /persona/build`)
  Future<PersonaProfile> buildPersona(List<ScenarioAnswer> answers) async {
    final json = await _api.postJson('/persona/build', {
      'answers': [for (final answer in answers) _forApi(answer)],
    });
    return _toProfile(json as Map<String, dynamic>);
  }

  /// 오늘의 1문항 상태. (`GET /persona/daily`)
  Future<DailyPersonaStatus> fetchDailyStatus() async {
    final json = await _api.getJson('/persona/daily');
    return DailyPersonaStatus.fromJson(json as Map<String, dynamic>);
  }

  /// 오늘의 1문항으로 기존 페르소나를 보정한다. (`POST /persona/update`)
  Future<PersonaProfile> updatePersona(ScenarioAnswer answer) async {
    final json = await _api.postJson('/persona/update', {
      'answer': _forApi(answer),
    });
    return _toProfile(json as Map<String, dynamic>);
  }

  Future<DailyPersonaStatus> advanceDayForDev() async {
    final json = await _api.postJson('/persona/dev/advance-day', const {});
    return DailyPersonaStatus.fromJson(json as Map<String, dynamic>);
  }

  /// 내 페르소나 조회. (`GET /persona/me`)
  Future<PersonaProfile> fetchMyPersona() async {
    final json = await _api.getJson('/persona/me');
    return _toProfile(json as Map<String, dynamic>);
  }

  Map<String, Object?> _forApi(ScenarioAnswer answer) => {
    'code': answer.code,
    'category': answer.category,
    'question': answer.question,
    'answer_letter': answer.answerLetter,
    'answer_text': answer.answerText,
  };

  /// shared/schemas persona 계약 → 화면용 [PersonaProfile] 매핑.
  ///
  /// UI 모델이 아직 구 형태(communicationStyle/relationshipValues...)라
  /// 8-trait 계약에서 화면 필드를 합성한다. (모델 정렬은 P2 todo)
  PersonaProfile _toProfile(Map<String, dynamic> json) {
    final traits = (json['traits'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    String traitSummary(String category) {
      for (final trait in traits) {
        if (trait['category'] == category) {
          return trait['summary'] as String? ?? '';
        }
      }
      return '';
    }

    final valueKeywords = List<String>.from(
      json['value_keywords'] as List? ?? const [],
    );
    final summaryParts = [
      for (final trait in traits.take(3)) trait['summary'] as String? ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    return PersonaProfile(
      communicationStyle: json['communication_style'] as String? ?? '',
      relationshipValues: valueKeywords.join(', '),
      humorCode: json['humor_style'] as String? ?? '',
      attachmentStyle: traitSummary('관계 속도'),
      conflictStyle: traitSummary('갈등'),
      strengths: valueKeywords.take(3).toList(),
      summary: summaryParts,
    );
  }
}
