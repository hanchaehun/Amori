class MatchProfile {
  const MatchProfile({
    required this.id,
    required this.initial,
    required this.name,
    required this.age,
    required this.score,
    required this.values,
    required this.humor,
    required this.communication,
    this.recommendedTopics = const [],
  });

  final String id;
  final String initial;
  final String name;
  final int age;
  final int score;
  final int values;
  final int humor;
  final int communication;
  final List<String> recommendedTopics;
}

/// 실제 매칭 데이터가 아직 배선되지 않은 화면(잠금 리포트·만남 신청 등)이
/// 참조하는 중립 플레이스홀더. 예시 인물(가짜 이름)을 제거하고 역할 라벨만 노출한다.
const MatchProfile kPlaceholderMatch = MatchProfile(
  id: 'placeholder',
  initial: '상',
  name: '상대',
  age: 0,
  score: 0,
  values: 0,
  humor: 0,
  communication: 0,
  recommendedTopics: [],
);

MatchProfile findMatchById(String id) => kPlaceholderMatch;
