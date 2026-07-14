class ChoiceOption {
  const ChoiceOption(this.letter, this.text);
  final String letter;
  final String text;
}

class Scenario {
  const Scenario({
    required this.category,
    required this.code,
    required this.title,
    required this.contextLabel,
    required this.situation,
    required this.question,
    this.choices = const [],
    this.isFreeText = false,
    this.hint,
  });

  final String category;
  final String code;
  final String title;
  final String contextLabel;
  final String situation;
  final String question;
  final List<ChoiceOption> choices;

  /// 주관식(말투 샘플) 문항 — 사용자가 평소 말투 그대로 메시지를 직접 쓴다.
  /// 객관식은 성향(매칭)을 잡지만 말투는 못 잡는다는 게 실 Gemini E2E에서
  /// 실증되어, 이 답변이 에이전트 voice의 원천이 된다 (voice 2차).
  final bool isFreeText;

  /// 주관식 입력칸 placeholder.
  final String? hint;
}

// 온보딩 = 객관식 R-1~5(성향/매칭) + 주관식 9-1·9-2(실발화 → voice 원천).
// 가입 직후부터 sample_messages가 LLM 창작이 아닌 실문장으로 시작한다
// (persona_fidelity_design.md §3-1, 2026-07-13 적용). 9-3은 데일리 첫 질문.
const List<String> kInitialScenarioCodes = [
  'R-1',
  'R-2',
  'R-3',
  'R-4',
  'R-5',
  '9-1',
  '9-2',
];

const List<String> kDailyScenarioCodes = [
  '9-1',
  '9-2',
  '9-3',
  '2-1',
  '7-3',
  '5-2',
  '4-2',
  '8-3',
  '6-2',
  '6-3',
  '7-1',
  '4-1',
  '5-1',
  '2-2',
  '8-2',
  '3-2',
  '3-3',
  '6-1',
  '5-3',
  '4-3',
  '1-2',
  '1-3',
  '2-3',
  '7-2',
];

Scenario? scenarioByCode(String code) {
  for (final scenario in kScenarios) {
    if (scenario.code == code) return scenario;
  }
  return null;
}

List<Scenario> scenariosByCodes(List<String> codes) {
  final scenarios = <Scenario>[];
  for (final code in codes) {
    final scenario = scenarioByCode(code);
    if (scenario != null) scenarios.add(scenario);
  }
  return scenarios;
}

const List<Scenario> kScenarios = [
  // R. 대표 질문
  Scenario(
    category: '관계 목적 / 진지함',
    code: 'R-1',
    title: '원하는 관계',
    contextLabel: '새로운 만남',
    situation: '새로운 사람을 만난다면, 지금 원하는 관계에 가장 가까운 것은 무엇인가요?',
    question: '당신의 선택은?',
    choices: [
      ChoiceOption('A', '부담 없이 알아가고 싶다'),
      ChoiceOption('B', '천천히 연애 가능성을 확인하고 싶다'),
      ChoiceOption('C', '진지한 연애를 원한다'),
      ChoiceOption('D', '결혼 가능성까지 고려하고 싶다'),
      ChoiceOption('E', '아직 명확하게 정하지 않았다'),
    ],
  ),
  Scenario(
    category: '연락 / 관계 확인',
    code: 'R-2',
    title: '연락 스타일',
    contextLabel: '소개팅 이후',
    situation: '첫 만남의 분위기는 좋았지만, 상대는 하루에 한두 번 정도만 답장합니다. 답장이 성의 없지는 않습니다.',
    question: '당신의 생각에 가장 가까운 것은 무엇인가요?',
    choices: [
      ChoiceOption('A', '하루에 한두 번이면 충분하다'),
      ChoiceOption('B', '짧게라도 자주 연락하고 싶다'),
      ChoiceOption('C', '횟수보다 꾸준히 연락하는 것이 중요하다'),
      ChoiceOption('D', '연락보다 직접 만났을 때의 대화가 중요하다'),
    ],
  ),
  Scenario(
    category: '감정 표현 / 갈등 대처',
    code: 'R-3',
    title: '서운함을 다루는 방식',
    contextLabel: '썸 또는 연애 중',
    situation: '상대의 말 때문에 조금 서운했습니다. 큰 문제는 아니지만 그냥 넘기면 계속 마음에 남을 것 같습니다.',
    question: '당신은 보통 어떻게 하나요?',
    choices: [
      ChoiceOption('A', '그 자리에서 바로 이야기한다'),
      ChoiceOption('B', '감정을 정리한 뒤 이야기한다'),
      ChoiceOption('C', '상대가 먼저 알아차리는지 기다린다'),
      ChoiceOption('D', '혼자 정리하고 넘어간다'),
    ],
  ),
  Scenario(
    category: '위로 / 정서적 욕구',
    code: 'R-4',
    title: '원하는 위로 방식',
    contextLabel: '연애 중',
    situation: '힘든 하루를 보낸 뒤 상대에게 “오늘 많이 지쳤어”라고 말했습니다.',
    question: '상대가 어떻게 해주면 가장 좋나요?',
    choices: [
      ChoiceOption('A', '내 이야기를 들어주고 공감해준다'),
      ChoiceOption('B', '해결 방법을 함께 찾아준다'),
      ChoiceOption('C', '맛있는 음식이나 데이트로 기분을 전환해준다'),
      ChoiceOption('D', '혼자 쉴 수 있도록 기다려준다'),
    ],
  ),
  Scenario(
    category: '핵심 가치관 / 매칭 우선순위',
    code: 'R-5',
    title: '관계에서 가장 중요한 것',
    contextLabel: '장기 관계',
    situation: '상대와 잘 지내더라도, 다음 중 하나가 부족하면 장기적으로 가장 힘들 것 같은 것은 무엇인가요?',
    question: '당신에게 가장 중요한 것은 무엇인가요?',
    choices: [
      ChoiceOption('A', '대화가 잘 통하는 것'),
      ChoiceOption('B', '신뢰할 수 있고 행동이 일관적인 것'),
      ChoiceOption('C', '애정과 관심을 표현하는 것'),
      ChoiceOption('D', '생활 방식과 데이트 취향이 잘 맞는 것'),
      ChoiceOption('E', '서로의 시간과 선택을 존중하는 것'),
    ],
  ),

  // 1. 연락 / 대화 템포
  Scenario(
    category: '연락 / 대화 템포',
    code: '1-1',
    title: '답장 간격',
    contextLabel: '소개팅 전',
    situation:
        '소개팅 날짜는 잡혔고, 아직 만나기 전입니다. 상대가 하루에 한두 번 정도만 답장합니다. 답장이 성의 없지는 않지만 텀이 긴 편입니다.',
    question: '당신은 이 연락 템포를 어떻게 느끼나요?',
    choices: [
      ChoiceOption('A', '만나기 전이라 이 정도면 괜찮다'),
      ChoiceOption('B', '조금 더 자주 연락하면 좋겠다'),
      ChoiceOption('C', '관심이 낮아 보여서 신경 쓰인다'),
      ChoiceOption('D', '직접 만나보기 전까지 판단하지 않는다'),
    ],
  ),
  Scenario(
    category: '연락 / 대화 템포',
    code: '1-2',
    title: '대화 주도권',
    contextLabel: '썸',
    situation:
        '상대가 답장은 잘하지만 먼저 질문을 거의 하지 않습니다. 대화는 이어지지만 대부분 당신이 주제를 꺼내고 있습니다.',
    question: '당신의 반응에 가장 가까운 것은?',
    choices: [
      ChoiceOption('A', '내가 주도하는 것도 괜찮다'),
      ChoiceOption('B', '몇 번은 이어가 보지만 오래가면 지친다'),
      ChoiceOption('C', '나에게 관심이 없는 것처럼 느껴진다'),
      ChoiceOption('D', '직접 만나면 다를 수 있다고 생각한다'),
    ],
  ),
  Scenario(
    category: '연락 / 대화 템포',
    code: '1-3',
    title: '연락 스타일 차이',
    contextLabel: '연애 초반',
    situation:
        '당신은 틈날 때 답장하는 편인데, 상대는 빠른 답장을 중요하게 생각합니다. 상대가 "연락이 조금 느린 것 같아"라고 말합니다.',
    question: '당신은 어떻게 반응하나요?',
    choices: [
      ChoiceOption('A', '상대가 불안하지 않게 조금 더 신경 쓴다'),
      ChoiceOption('B', '내 연락 스타일을 설명하고 조율한다'),
      ChoiceOption('C', '연락 빈도로 마음을 판단하지 않았으면 한다'),
      ChoiceOption('D', '부담이 커지면 관계가 어려울 것 같다'),
    ],
  ),

  // 2. 유머 / 대화 코드
  Scenario(
    category: '유머 / 대화 코드',
    code: '2-1',
    title: '농담 코드',
    contextLabel: '첫 만남',
    situation: '상대가 농담을 자주 합니다. 분위기를 풀려는 의도는 보이지만, 당신에게는 조금 과하게 느껴집니다.',
    question: '당신은 어떻게 느끼나요?',
    choices: [
      ChoiceOption('A', '분위기를 편하게 만들려는 점이 좋다'),
      ChoiceOption('B', '적당하면 좋지만 계속되면 피곤하다'),
      ChoiceOption('C', '진지한 대화도 함께 있어야 호감이 간다'),
      ChoiceOption('D', '유머 코드가 맞지 않으면 호감이 떨어진다'),
    ],
  ),
  Scenario(
    category: '유머 / 대화 코드',
    code: '2-2',
    title: '장난의 선',
    contextLabel: '썸',
    situation: '상대가 가벼운 놀림을 자주 합니다. 예를 들어 "너 은근 허당이네" 같은 말을 웃으면서 합니다.',
    question: '당신에게 가장 가까운 반응은?',
    choices: [
      ChoiceOption('A', '친근하게 느껴져서 괜찮다'),
      ChoiceOption('B', '말투와 분위기에 따라 다르다'),
      ChoiceOption('C', '반복되면 불편하다고 말한다'),
      ChoiceOption('D', '초반에는 그런 장난이 조심스러웠으면 한다'),
    ],
  ),
  Scenario(
    category: '유머 / 대화 코드',
    code: '2-3',
    title: '밈과 트렌드 코드',
    contextLabel: '소개팅 전',
    situation: '상대가 대화 중 밈이나 유행어를 자주 씁니다. 대화가 가볍고 빠르게 이어지는 편입니다.',
    question: '당신은 이런 대화 방식을 어떻게 느끼나요?',
    choices: [
      ChoiceOption('A', '코드가 맞으면 재미있다'),
      ChoiceOption('B', '가끔은 좋지만 계속되면 가벼워 보인다'),
      ChoiceOption('C', '잘 몰라도 분위기에 맞춰간다'),
      ChoiceOption('D', '나와는 대화 방식이 다를 수 있다고 느낀다'),
    ],
  ),

  // 3. 갈등 / 감정 표현
  Scenario(
    category: '갈등 / 감정 표현',
    code: '3-1',
    title: '서운함 표현',
    contextLabel: '썸',
    situation: '상대의 말이나 행동 때문에 조금 서운했습니다. 큰일은 아니지만 그냥 넘기면 계속 마음에 남을 것 같습니다.',
    question: '당신은 보통 어떻게 하나요?',
    choices: [
      ChoiceOption('A', '바로 말한다'),
      ChoiceOption('B', '분위기를 봐서 나중에 말한다'),
      ChoiceOption('C', '상대가 먼저 알아차리길 기다린다'),
      ChoiceOption('D', '큰일이 아니면 혼자 정리한다'),
    ],
  ),
  Scenario(
    category: '갈등 / 감정 표현',
    code: '3-2',
    title: '사과의 기준',
    contextLabel: '연애 초반',
    situation:
        '상대가 약속을 깼고, 나중에 "미안, 다음엔 조심할게"라고 말했습니다. 다만 이유 설명은 짧고, 대수롭지 않게 넘기는 분위기입니다.',
    question: '당신은 어떻게 받아들이나요?',
    choices: [
      ChoiceOption('A', '사과했으면 일단 넘어간다'),
      ChoiceOption('B', '이유와 재발 방지가 중요하다'),
      ChoiceOption('C', '태도가 가벼우면 사과로 느껴지지 않는다'),
      ChoiceOption('D', '같은 일이 반복되는지 지켜본다'),
    ],
  ),
  Scenario(
    category: '갈등 / 감정 표현',
    code: '3-3',
    title: '감정이 격해졌을 때',
    contextLabel: '연애 중',
    situation: '대화 중 감정이 올라와서 지금 계속 말하면 더 싸울 것 같습니다. 상대는 당장 결론을 내고 싶어 합니다.',
    question: '당신은 어떻게 하는 편인가요?',
    choices: [
      ChoiceOption('A', '그 자리에서 끝까지 이야기한다'),
      ChoiceOption('B', '잠깐 쉬었다가 다시 이야기하자고 한다'),
      ChoiceOption('C', '감정이 정리될 때까지 시간을 갖는다'),
      ChoiceOption('D', '상대가 압박하면 더 말하기 어려워진다'),
    ],
  ),

  // 4. 데이트 취향 / 라이프스타일
  Scenario(
    category: '데이트 취향 / 라이프스타일',
    code: '4-1',
    title: '데이트 에너지',
    contextLabel: '첫 만남',
    situation: '상대가 첫 데이트 코스로 맛집, 전시, 카페, 산책까지 하루 일정을 꽉 채워 왔습니다.',
    question: '당신은 어떤 쪽에 가깝나요?',
    choices: [
      ChoiceOption('A', '알차게 준비한 느낌이라 좋다'),
      ChoiceOption('B', '좋지만 중간에 쉬는 시간이 필요하다'),
      ChoiceOption('C', '첫 만남은 짧고 편한 쪽이 좋다'),
      ChoiceOption('D', '일정이 많으면 부담스럽다'),
    ],
  ),
  Scenario(
    category: '데이트 취향 / 라이프스타일',
    code: '4-2',
    title: '즉흥 제안',
    contextLabel: '썸',
    situation: '금요일 밤, 상대가 갑자기 "내일 근교로 놀러 갈래?"라고 제안합니다. 미리 정해진 계획은 없습니다.',
    question: '당신의 반응은?',
    choices: [
      ChoiceOption('A', '즉흥적인 제안이 설렌다'),
      ChoiceOption('B', '좋지만 대략적인 계획은 필요하다'),
      ChoiceOption('C', '갑작스러운 일정은 부담스럽다'),
      ChoiceOption('D', '가까운 만남 정도면 괜찮다'),
    ],
  ),
  Scenario(
    category: '데이트 취향 / 라이프스타일',
    code: '4-3',
    title: '휴식형 데이트',
    contextLabel: '연애 초반',
    situation:
        '상대가 주말에 밖에 나가기보다 집이나 조용한 공간에서 쉬고 싶어 합니다. 활동적인 데이트는 가끔만 하고 싶다고 말합니다.',
    question: '당신은 어떻게 느끼나요?',
    choices: [
      ChoiceOption('A', '나도 편한 데이트를 좋아한다'),
      ChoiceOption('B', '가끔은 좋지만 밖에서도 만나고 싶다'),
      ChoiceOption('C', '데이트는 새로운 경험이 있어야 좋다'),
      ChoiceOption('D', '생활 패턴이 맞는지 고민될 것 같다'),
    ],
  ),

  // 5. 돈 / 시간 / 약속 가치관
  Scenario(
    category: '돈 / 시간 / 약속 가치관',
    code: '5-1',
    title: '계산 방식',
    contextLabel: '첫 만남',
    situation: '첫 데이트가 끝나고 계산할 시간이 됐습니다. 상대가 계산 방식에 대해 먼저 말하지 않고 있습니다.',
    question: '당신은 보통 어떻게 하나요?',
    choices: [
      ChoiceOption('A', '자연스럽게 반반하자고 한다'),
      ChoiceOption('B', '내가 먼저 내고 다음을 기대한다'),
      ChoiceOption('C', '상대가 어떻게 하는지 먼저 본다'),
      ChoiceOption('D', '상황과 금액에 따라 다르게 한다'),
    ],
  ),
  Scenario(
    category: '돈 / 시간 / 약속 가치관',
    code: '5-2',
    title: '반복 지각',
    contextLabel: '썸',
    situation: '상대가 약속마다 10분 정도 늦습니다. 사과는 하지만 크게 문제라고 생각하지 않는 듯합니다.',
    question: '당신에게 가장 가까운 반응은?',
    choices: [
      ChoiceOption('A', '10분 정도는 괜찮다'),
      ChoiceOption('B', '반복되면 신경 쓰인다'),
      ChoiceOption('C', '시간 약속은 기본이라 불편하다'),
      ChoiceOption('D', '이유와 태도에 따라 다르다'),
    ],
  ),
  Scenario(
    category: '돈 / 시간 / 약속 가치관',
    code: '5-3',
    title: '기념일 기대치',
    contextLabel: '연애 중',
    situation: '당신은 기념일을 어느 정도 챙기고 싶은 편입니다. 상대는 "기념일을 꼭 챙겨야 하나?"라는 입장입니다.',
    question: '당신은 어떻게 생각하나요?',
    choices: [
      ChoiceOption('A', '크게 중요하지 않다'),
      ChoiceOption('B', '작게라도 챙기면 좋다'),
      ChoiceOption('C', '기념일을 대하는 태도가 중요하다'),
      ChoiceOption('D', '서로 기대치를 미리 맞춰야 한다'),
    ],
  ),

  // 6. 관계 속도 / 호감 표현
  Scenario(
    category: '관계 속도 / 호감 표현',
    code: '6-1',
    title: '빠른 호감 표현',
    contextLabel: '첫 만남 이후',
    situation: '첫 만남 후 상대가 바로 "나는 너에게 호감이 있어"라고 말합니다.',
    question: '당신은 어떻게 느끼나요?',
    choices: [
      ChoiceOption('A', '솔직해서 좋다'),
      ChoiceOption('B', '좋지만 조금 더 알아가고 싶다'),
      ChoiceOption('C', '빠른 표현은 부담스럽다'),
      ChoiceOption('D', '말보다 이후 행동을 보고 싶다'),
    ],
  ),
  Scenario(
    category: '관계 속도 / 호감 표현',
    code: '6-2',
    title: '애정표현 방식',
    contextLabel: '연애 초반',
    situation: '상대는 말로 애정을 자주 표현하지는 않지만, 약속을 지키고 행동으로 챙겨주는 편입니다.',
    question: '당신에게 가장 가까운 생각은?',
    choices: [
      ChoiceOption('A', '행동이 더 중요해서 괜찮다'),
      ChoiceOption('B', '행동도 좋지만 말도 가끔 필요하다'),
      ChoiceOption('C', '표현이 적으면 마음이 헷갈린다'),
      ChoiceOption('D', '내 표현 방식과 맞는지 지켜본다'),
    ],
  ),
  Scenario(
    category: '관계 속도 / 호감 표현',
    code: '6-3',
    title: '관계 정의',
    contextLabel: '썸',
    situation: '몇 번 만났고 분위기도 좋습니다. 하지만 상대가 관계를 명확히 말하지 않은 채 계속 만나자고만 합니다.',
    question: '당신은 어떻게 하나요?',
    choices: [
      ChoiceOption('A', '자연스럽게 흐름을 본다'),
      ChoiceOption('B', '조금 더 만나보고 판단한다'),
      ChoiceOption('C', '어느 시점에는 관계를 확인하고 싶다'),
      ChoiceOption('D', '불명확한 관계가 오래가면 힘들다'),
    ],
  ),

  // 7. 경계선 / 질투 / 프라이버시
  Scenario(
    category: '경계선 / 질투 / 프라이버시',
    code: '7-1',
    title: '이성 친구',
    contextLabel: '연애 초반',
    situation: '상대에게 오래 알고 지낸 이성 친구가 있습니다. 가끔 단둘이 밥을 먹는다고 합니다.',
    question: '당신은 어떻게 받아들이나요?',
    choices: [
      ChoiceOption('A', '신뢰가 있으면 괜찮다'),
      ChoiceOption('B', '미리 말해주면 괜찮다'),
      ChoiceOption('C', '단둘이 만나는 건 신경 쓰인다'),
      ChoiceOption('D', '관계의 선을 분명히 했으면 한다'),
    ],
  ),
  Scenario(
    category: '경계선 / 질투 / 프라이버시',
    code: '7-2',
    title: 'SNS 공개',
    contextLabel: '연애 중',
    situation: '상대가 당신과 찍은 사진을 SNS에 올리고 싶어 합니다. 당신을 태그하는 것도 자연스럽게 생각합니다.',
    question: '당신은 어떤 편인가요?',
    choices: [
      ChoiceOption('A', '공개해도 괜찮다'),
      ChoiceOption('B', '얼굴이 잘 안 나온 사진은 괜찮다'),
      ChoiceOption('C', '연애는 공개하지 않는 편이 좋다'),
      ChoiceOption('D', '서로 동의한 범위에서만 가능하다'),
    ],
  ),
  Scenario(
    category: '경계선 / 질투 / 프라이버시',
    code: '7-3',
    title: '휴대폰 확인',
    contextLabel: '연애 중',
    situation: '상대가 장난처럼 "폰 한번 봐도 돼?"라고 말합니다. 가볍게 말했지만 확인하고 싶은 마음도 있어 보입니다.',
    question: '당신의 생각에 가까운 것은?',
    choices: [
      ChoiceOption('A', '숨길 건 없지만 굳이 볼 필요는 없다'),
      ChoiceOption('B', '장난으로 한 번은 괜찮다'),
      ChoiceOption('C', '사생활이라 불편하다'),
      ChoiceOption('D', '신뢰 문제로 이어질 수 있다고 본다'),
    ],
  ),

  // 8. 위로 / 안정감 / 애착
  Scenario(
    category: '위로 / 안정감 / 애착',
    code: '8-1',
    title: '힘든 날의 위로',
    contextLabel: '연애 초반',
    situation: '당신이 힘든 하루를 보냈고, 상대에게 "오늘 좀 지쳤어"라고 말했습니다.',
    question: '상대가 어떻게 해주면 가장 좋나요?',
    choices: [
      ChoiceOption('A', '먼저 공감해주면 좋다'),
      ChoiceOption('B', '해결책을 함께 찾아주면 좋다'),
      ChoiceOption('C', '가볍게 기분 전환을 시켜주면 좋다'),
      ChoiceOption('D', '혼자 쉴 시간을 존중해주면 좋다'),
    ],
  ),
  Scenario(
    category: '위로 / 안정감 / 애착',
    code: '8-2',
    title: '혼자 있고 싶은 날',
    contextLabel: '연애 중',
    situation: '당신은 혼자 쉬고 싶은데, 상대는 걱정돼서 계속 연락하고 싶어 합니다.',
    question: '당신에게 가장 가까운 반응은?',
    choices: [
      ChoiceOption('A', '관심받는 느낌이라 고맙다'),
      ChoiceOption('B', '마음은 고맙지만 시간을 조금 줬으면 한다'),
      ChoiceOption('C', '혼자 회복하는 시간이 꼭 필요하다'),
      ChoiceOption('D', '계속 연락하면 더 지칠 수 있다'),
    ],
  ),
  Scenario(
    category: '위로 / 안정감 / 애착',
    code: '8-3',
    title: '관계 불안',
    contextLabel: '썸 / 연애 초반',
    situation: '상대의 답장이 전보다 짧아졌고, 만날 때도 조금 피곤해 보입니다. 큰 변화는 아니지만 당신은 신경이 쓰입니다.',
    question: '당신은 보통 어떻게 하나요?',
    choices: [
      ChoiceOption('A', '일단 상황을 지켜본다'),
      ChoiceOption('B', '요즘 괜찮은지 가볍게 물어본다'),
      ChoiceOption('C', '나에 대한 마음이 달라졌는지 확인하고 싶다'),
      ChoiceOption('D', '혼자 생각이 많아지는 편이다'),
    ],
  ),

  // 9. 말투 샘플 (주관식) — 사용자가 직접 쓴 문장이 에이전트 voice의 원천.
  // 세 상황은 각각 다른 말투 단면을 트리거한다:
  // 9-1 난처함 대처(부정 상황 톤앤매너), 9-2 취향 티키타카(말수·되묻기),
  // 9-3 칭찬 반응(리액션 크기·수줍음·유머).
  Scenario(
    category: '말투 샘플',
    code: '9-1',
    title: '난처한 상황 메시지',
    contextLabel: '소개팅 당일',
    situation: '오늘 만나기로 한 카페가 하필 정기 휴무라는 걸 방금 알았습니다. 약속 시간은 한 시간 뒤입니다.',
    question: '상대에게 보낼 메시지를 평소 말투 그대로 써보세요.',
    isFreeText: true,
    hint: '평소 카톡 보내듯 편하게 써주세요. 이모지·ㅋㅋ·말버릇 모두 그대로!',
  ),
  Scenario(
    category: '말투 샘플',
    code: '9-2',
    title: '취향 질문에 답하기',
    contextLabel: '썸',
    situation: '상대가 이렇게 물어봤습니다: "스트레스 풀 때 보통 뭐 하세요? 밖에서 활동하는 파예요, 집에서 쉬는 파예요?"',
    question: '평소 말투 그대로 답장을 써보세요.',
    isFreeText: true,
    hint: '단답이든 길게든, 실제로 보낼 답장 그대로면 됩니다.',
  ),
  Scenario(
    category: '말투 샘플',
    code: '9-3',
    title: '칭찬에 답하기',
    contextLabel: '소개팅 후',
    situation: '소개팅이 끝나고 상대에게 메시지가 왔습니다: "오늘 대화 진짜 즐거웠어요. 되게 다정하신 것 같아요 ㅎㅎ"',
    question: '평소 말투 그대로 답장을 써보세요.',
    isFreeText: true,
    hint: '칭찬받았을 때 평소 반응 그대로 — 쑥스러우면 쑥스러운 대로!',
  ),
];
