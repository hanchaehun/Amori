enum ConversationStatus { active, scheduling, scheduled, completed }

extension ConversationStatusX on ConversationStatus {
  String get label => switch (this) {
        ConversationStatus.active => '🟢 대화 중',
        ConversationStatus.scheduling => '📅 약속 조율 완료',
        ConversationStatus.scheduled => '📍 만남 예정',
        ConversationStatus.completed => '✓ 만남 완료',
      };
}

class Conversation {
  const Conversation({
    required this.id,
    required this.name,
    required this.initial,
    required this.score,
    required this.lastMessage,
    required this.time,
    required this.status,
    required this.unread,
    this.appointmentReady = false,
    this.partnerAccepted = false,
    this.youAccepted = false,
  });

  final String id;
  final String name;
  final String initial;
  final int score;
  final String lastMessage;
  final String time;
  final ConversationStatus status;
  final bool unread;

  /// 시뮬레이션 중 두 에이전트가 약속을 잡았는가(백엔드 눈치 strategy="약속 수락").
  /// true면 '진행 중'에서 맨 위로 올라오고 테두리가 강조된다.
  final bool appointmentReady;

  /// 상대가 이미 만남을 수락했는가. 내가 수락하면 곧바로 '만남 예정'으로 넘어간다.
  final bool partnerAccepted;

  /// 내가 만남을 수락했는가.
  final bool youAccepted;

  bool get bothAccepted => partnerAccepted && youAccepted;

  Conversation copyWith({
    ConversationStatus? status,
    String? lastMessage,
    String? time,
    bool? unread,
    bool? appointmentReady,
    bool? partnerAccepted,
    bool? youAccepted,
  }) {
    return Conversation(
      id: id,
      name: name,
      initial: initial,
      score: score,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      status: status ?? this.status,
      unread: unread ?? this.unread,
      appointmentReady: appointmentReady ?? this.appointmentReady,
      partnerAccepted: partnerAccepted ?? this.partnerAccepted,
      youAccepted: youAccepted ?? this.youAccepted,
    );
  }
}

const List<Conversation> kActiveConversations = [
  // 약속 조율 완료 — 상대가 이미 수락한 상태라, 사용자가 수락만 누르면 '만남 예정'으로.
  Conversation(
    id: 'c2',
    name: '김현우',
    initial: '현',
    score: 91,
    lastMessage: '토요일 저녁 좋아요! 그럼 그때 봬요 ㅎㅎ',
    time: '오후 1:10',
    status: ConversationStatus.scheduling,
    unread: true,
    appointmentReady: true,
    partnerAccepted: true,
  ),
  Conversation(
    id: 'c1',
    name: '서민준',
    initial: '민',
    score: 88,
    lastMessage: '네, 그 카페 좋을 것 같아요!',
    time: '오후 3:24',
    status: ConversationStatus.active,
    unread: true,
  ),
  Conversation(
    id: 'c3',
    name: '박지수',
    initial: '지',
    score: 79,
    lastMessage: '안녕하세요! AI 추천대로 영화 얘기...',
    time: '오전 11:42',
    status: ConversationStatus.active,
    unread: false,
  ),
];

const List<Conversation> kScheduledConversations = [
  Conversation(
    id: 'c4',
    name: '이도윤',
    initial: '도',
    score: 86,
    lastMessage: '토요일 오후 3시 성수에서 만나요!',
    time: '어제',
    status: ConversationStatus.scheduled,
    unread: false,
    appointmentReady: true,
    partnerAccepted: true,
    youAccepted: true,
  ),
];

const List<Conversation> kCompletedConversations = [
  Conversation(
    id: 'c5',
    name: '정수아',
    initial: '수',
    score: 84,
    lastMessage: '오늘 즐거웠어요. 잘 들어가세요!',
    time: '3일 전',
    status: ConversationStatus.completed,
    unread: false,
  ),
];
