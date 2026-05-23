import 'dart:math';

import '../dummy/matches.dart';
import 'models.dart';
import 'scenario_answers_store.dart';

class MockBackendEngine {
  const MockBackendEngine();

  static const _categories = [
    '연락 템포',
    '유머',
    '갈등',
    '데이트',
    '돈·시간',
    '관계 속도',
    '경계선',
    '위로',
  ];

  PersonaCard buildPersona({
    required String userId,
    required List<ScenarioAnswer> answers,
  }) {
    final answerText = answers.map((answer) => answer.answerLetter).join();
    final seed = _stableSeed('$userId:$answerText');

    return PersonaCard(
      userId: userId,
      traits: [
        for (var i = 0; i < _categories.length; i++)
          PersonaTrait(
            category: _categories[i],
            summary: i.isEven
                ? '관계를 천천히 확인하면서도 진심을 중요하게 봅니다.'
                : '상대의 리듬을 존중하되 선명한 표현도 필요로 합니다.',
            keywords: [i.isEven ? '안정감' : '표현', i % 3 == 0 ? '존중' : '균형'],
          ),
      ],
      communicationStyle: '느린 일상·진심형',
      humorStyle: '잔잔한 유머·드라이톤',
      valueKeywords: const ['존중', '일상 공유', '정서적 안정', '성장'],
      embedding: _embedding(seed),
      aiGenerated: true,
      source: 'mock',
    );
  }

  List<Map<String, Object?>> demoMatchesFor(String uid) => [
    for (var i = 0; i < kMatches.length; i++)
      {
        'participantIds': [uid, 'demo-${kMatches[i].id}'],
        'name': kMatches[i].name,
        'initial': kMatches[i].initial,
        'age': kMatches[i].age,
        'score': kMatches[i].score,
        'values': kMatches[i].values,
        'humor': kMatches[i].humor,
        'communication': kMatches[i].communication,
        'status': 'candidate',
        'recommendedTopics': kMatches[i].recommendedTopics,
      },
  ];

  ChemistryReport reportFor(MatchProfile match) => ChemistryReport(
    matchId: match.id,
    score: match.score,
    findings: const [
      {
        'emoji': '💬',
        'title': '대화 템포가 잘 맞아요',
        'sub': '서로 재촉하지 않고 자연스럽게 깊어지는 흐름입니다.',
      },
      {
        'emoji': '🌿',
        'title': '안정감을 중요하게 봐요',
        'sub': '각자의 경계와 회복 시간을 존중하는 공통점이 있습니다.',
      },
      {
        'emoji': '✨',
        'title': '잔잔한 유머 코드',
        'sub': '큰 리액션보다 작은 농담과 관찰을 편안하게 받아들입니다.',
      },
    ],
    warnings: const [
      {'title': '초반 속도 조절', 'body': '둘 다 신중한 편이라 첫 약속은 구체적인 선택지를 주면 좋아요.'},
    ],
    places: const [
      {'emoji': '☕', 'title': '조용한 로스터리 카페', 'sub': '서로의 이야기에 집중하기 좋은 곳'},
      {'emoji': '🎧', 'title': '작은 음악 바', 'sub': '취향 이야기를 자연스럽게 꺼낼 수 있는 곳'},
    ],
    starters: const [
      '요즘 제일 자주 듣는 노래가 뭐예요?',
      '쉬는 날에 회복되는 루틴이 있어요?',
      '최근에 오래 기억난 대화가 있었나요?',
    ],
    tip: '처음부터 깊은 질문을 몰아가기보다 일상 루틴에서 천천히 가치관으로 넘어가면 좋아요.',
  );

  int _stableSeed(String input) =>
      input.codeUnits.fold(17, (acc, code) => (acc * 31 + code) & 0x7fffffff);

  List<double> _embedding(int seed) {
    final random = Random(seed);
    return List<double>.generate(
      1024,
      (_) => double.parse((random.nextDouble() * 2 - 1).toStringAsFixed(6)),
    );
  }
}
