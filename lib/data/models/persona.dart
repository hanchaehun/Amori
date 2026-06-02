class PersonaProfile {
  const PersonaProfile({
    required this.communicationStyle,
    required this.relationshipValues,
    required this.humorCode,
    required this.attachmentStyle,
    required this.conflictStyle,
    required this.strengths,
    required this.summary,
  });

  final String communicationStyle;
  final String relationshipValues;
  final String humorCode;
  final String attachmentStyle;
  final String conflictStyle;
  final List<String> strengths;
  final String summary;

  factory PersonaProfile.fromJson(Map<String, dynamic> json) {
    return PersonaProfile(
      communicationStyle: json['communicationStyle'] as String? ?? '',
      relationshipValues: json['relationshipValues'] as String? ?? '',
      humorCode: json['humorCode'] as String? ?? '',
      attachmentStyle: json['attachmentStyle'] as String? ?? '',
      conflictStyle: json['conflictStyle'] as String? ?? '',
      strengths: (json['strengths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      summary: json['summary'] as String? ?? '',
    );
  }
}
