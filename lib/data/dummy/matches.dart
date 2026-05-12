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

const List<MatchProfile> kMatches = [
  MatchProfile(
    id: 'minjun',
    initial: '민',
    name: '서민준',
    age: 28,
    score: 88,
    values: 92,
    humor: 85,
    communication: 88,
    recommendedTopics: ['여행', '영화', '일상 루틴'],
  ),
  MatchProfile(
    id: 'jihyun',
    initial: '지',
    name: '김지현',
    age: 27,
    score: 82,
    values: 86,
    humor: 78,
    communication: 82,
    recommendedTopics: ['카페', '독서', '여행'],
  ),
  MatchProfile(
    id: 'hyunwoo',
    initial: '현',
    name: '박현우',
    age: 29,
    score: 79,
    values: 81,
    humor: 76,
    communication: 80,
    recommendedTopics: ['음악', '운동', '맛집'],
  ),
  MatchProfile(
    id: 'sumin',
    initial: '수',
    name: '이수민',
    age: 26,
    score: 91,
    values: 94,
    humor: 88,
    communication: 91,
    recommendedTopics: ['전시', '여행', '와인'],
  ),
];

MatchProfile findMatchById(String id) =>
    kMatches.firstWhere((m) => m.id == id, orElse: () => kMatches.first);
