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

/// 페르소나 trait 카테고리 canon — 백엔드 PERSONA_TRAIT_CATEGORIES와 동일 순서.
const List<String> kPersonaTraitCategories = [
  '연락 템포',
  '유머',
  '갈등',
  '데이트',
  '돈·시간',
  '관계 속도',
  '경계선',
  '위로',
];

/// trait 한 축 — 근거 있는 카테고리만 서버가 내려준다 (P0-A).
class PersonaTraitView {
  const PersonaTraitView({
    required this.category,
    required this.summary,
    required this.keywords,
    required this.confidence,
    required this.userEdited,
  });

  final String category;
  final String summary;
  final List<String> keywords;
  final double confidence;
  final bool userEdited;

  factory PersonaTraitView.fromJson(Map<String, dynamic> json) =>
      PersonaTraitView(
        category: json['category'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        keywords: List<String>.from(json['keywords'] as List? ?? const []),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
        userEdited: json['user_edited'] as bool? ?? false,
      );
}

/// 미리보기·수정 화면용 상세 — traits 원형 + 말투 습관 + 심리 힌트.
class PersonaDetail {
  const PersonaDetail({
    required this.traits,
    required this.verbalHabits,
    required this.punctuationHabits,
    required this.voiceConfidence,
    required this.attachmentHint,
    required this.psychVisible,
  });

  final List<PersonaTraitView> traits;
  final String verbalHabits;
  final String punctuationHabits;
  final double? voiceConfidence;

  /// 애착 힌트 문구(hint 어투) — 비어 있으면 아직 근거 부족.
  final String attachmentHint;

  /// 심리 카드 표시 여부 — 사용자가 숨길 수 있다 (프라이버시 원칙).
  final bool psychVisible;
}

class PreviewUtterance {
  const PreviewUtterance({required this.register, required this.text});

  final String register;
  final String text;
}

/// 페르소나 생성/조회 — BFF `/persona/*` 경유 (클라이언트 직접 LLM 호출 제거).
class PersonaRepository {
  PersonaRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

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

  /// 미리보기·수정 화면용 상세 조회. (`GET /persona/me` 원형 파싱)
  Future<PersonaDetail> fetchMyPersonaDetail() async {
    final json = await _api.getJson('/persona/me') as Map<String, dynamic>;
    final speech = json['speech_style'] as Map<String, dynamic>? ?? const {};
    final psych = json['psych_profile'] as Map<String, dynamic>? ?? const {};
    return PersonaDetail(
      traits: (json['traits'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PersonaTraitView.fromJson)
          .toList(),
      verbalHabits: speech['verbal_habits'] as String? ?? '',
      punctuationHabits: speech['punctuation_habits'] as String? ?? '',
      voiceConfidence: (json['voice_confidence'] as num?)?.toDouble(),
      attachmentHint: psych['attachment_hint'] as String? ?? '',
      psychVisible: psych['user_visible'] as bool? ?? true,
    );
  }

  /// "이렇게 말해요" 발화 3개. (`POST /persona/preview`)
  Future<List<PreviewUtterance>> fetchPreview() async {
    final json = await _api.postJson('/persona/preview', const {})
        as Map<String, dynamic>;
    return (json['utterances'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (u) => PreviewUtterance(
            register: u['register'] as String? ?? '',
            text: u['text'] as String? ?? '',
          ),
        )
        .toList();
  }

  /// 페르소나 부분 수정. (`PATCH /persona/me`)
  ///
  /// 발화 수정문·자유입력은 sample_bank(user_written) 최고 등급 데이터로 쌓이고,
  /// 수정한 trait은 user_edited로 잠겨 이후 LLM 업데이트가 덮지 못한다.
  Future<void> patchPersona({
    List<Map<String, Object?>> traitEdits = const [],
    List<Map<String, String>> utteranceFixes = const [],
    String? verbalHabits,
    String? punctuationHabits,
    List<String> freeSamples = const [],
    bool? hidePsych,
  }) async {
    final speechEdits = <String, Object?>{
      'verbal_habits': ?verbalHabits,
      'punctuation_habits': ?punctuationHabits,
      if (freeSamples.isNotEmpty) 'free_samples': freeSamples,
    };
    await _api.patchJson('/persona/me', {
      if (traitEdits.isNotEmpty) 'trait_edits': traitEdits,
      if (utteranceFixes.isNotEmpty) 'utterance_fixes': utteranceFixes,
      if (speechEdits.isNotEmpty) 'speech_edits': speechEdits,
      if (hidePsych != null) 'psych_edits': {'hide': hidePsych},
    });
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
