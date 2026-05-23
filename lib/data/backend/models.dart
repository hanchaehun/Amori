import 'package:cloud_firestore/cloud_firestore.dart';

import '../dummy/matches.dart';

DateTime? _dateFromTimestamp(Object? value) =>
    value is Timestamp ? value.toDate() : null;

class AmoriUserProfile {
  const AmoriUserProfile({
    required this.uid,
    required this.displayName,
    required this.birthDate,
    required this.gender,
    required this.interestGender,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String birthDate;
  final String gender;
  final String interestGender;
  final String? photoUrl;

  Map<String, Object?> toCreateJson() => {
    'displayName': displayName,
    'birthDate': birthDate,
    'gender': gender,
    'interestGender': interestGender,
    'photoUrl': photoUrl,
    'kycStatus': 'pending',
    'entitlements': {'plan': 'free', 'reportUnlocks': <String>[]},
    'dailyQuota': {'meetRequests': 1, 'simulations': 5},
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class PersonaTrait {
  const PersonaTrait({
    required this.category,
    required this.summary,
    required this.keywords,
  });

  final String category;
  final String summary;
  final List<String> keywords;

  Map<String, Object?> toJson() => {
    'category': category,
    'summary': summary,
    'keywords': keywords,
  };

  factory PersonaTrait.fromJson(Map<String, dynamic> json) => PersonaTrait(
    category: json['category'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    keywords: List<String>.from(json['keywords'] as List? ?? const []),
  );
}

class PersonaCard {
  const PersonaCard({
    required this.userId,
    required this.traits,
    required this.communicationStyle,
    required this.humorStyle,
    required this.valueKeywords,
    required this.embedding,
    required this.aiGenerated,
    required this.source,
  });

  final String userId;
  final List<PersonaTrait> traits;
  final String communicationStyle;
  final String humorStyle;
  final List<String> valueKeywords;
  final List<double> embedding;
  final bool aiGenerated;
  final String source;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'traits': traits.map((trait) => trait.toJson()).toList(),
    'communicationStyle': communicationStyle,
    'humorStyle': humorStyle,
    'valueKeywords': valueKeywords,
    'embedding': embedding,
    'aiGenerated': aiGenerated,
    'source': source,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory PersonaCard.fromJson(Map<String, dynamic> json) => PersonaCard(
    userId: json['userId'] as String? ?? '',
    traits: (json['traits'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => PersonaTrait.fromJson(Map<String, dynamic>.from(raw)))
        .toList(),
    communicationStyle: json['communicationStyle'] as String? ?? '',
    humorStyle: json['humorStyle'] as String? ?? '',
    valueKeywords: List<String>.from(
      json['valueKeywords'] as List? ?? const [],
    ),
    embedding: (json['embedding'] as List? ?? const [])
        .map((value) => (value as num).toDouble())
        .toList(),
    aiGenerated: json['aiGenerated'] as bool? ?? true,
    source: json['source'] as String? ?? 'mock',
  );
}

class MatchDocument {
  const MatchDocument({
    required this.id,
    required this.participantIds,
    required this.profile,
    required this.status,
    this.createdAt,
  });

  final String id;
  final List<String> participantIds;
  final MatchProfile profile;
  final String status;
  final DateTime? createdAt;

  factory MatchDocument.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MatchDocument(
      id: doc.id,
      participantIds: List<String>.from(
        data['participantIds'] as List? ?? const [],
      ),
      profile: MatchProfile(
        id: doc.id,
        initial: data['initial'] as String? ?? '?',
        name: data['name'] as String? ?? '이름 없음',
        age: (data['age'] as num?)?.toInt() ?? 0,
        score: (data['score'] as num?)?.toInt() ?? 0,
        values: (data['values'] as num?)?.toInt() ?? 0,
        humor: (data['humor'] as num?)?.toInt() ?? 0,
        communication: (data['communication'] as num?)?.toInt() ?? 0,
        recommendedTopics: List<String>.from(
          data['recommendedTopics'] as List? ?? const <String>[],
        ),
      ),
      status: data['status'] as String? ?? 'candidate',
      createdAt: _dateFromTimestamp(data['createdAt']),
    );
  }
}

class ChemistryReport {
  const ChemistryReport({
    required this.matchId,
    required this.score,
    required this.findings,
    required this.warnings,
    required this.places,
    required this.starters,
    this.tip,
  });

  final String matchId;
  final int score;
  final List<Map<String, String>> findings;
  final List<Map<String, String>> warnings;
  final List<Map<String, String>> places;
  final List<String> starters;
  final String? tip;

  Map<String, Object?> toJson() => {
    'matchId': matchId,
    'score': score,
    'findings': findings,
    'warnings': warnings,
    'places': places,
    'starters': starters,
    'tip': tip,
    'aiGenerated': true,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class MeetRequestDraft {
  const MeetRequestDraft({
    required this.matchId,
    required this.receiverId,
    this.message,
  });

  final String matchId;
  final String receiverId;
  final String? message;
}
