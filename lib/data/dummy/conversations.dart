enum ConversationStatus { active, scheduling, scheduled, completed }

extension ConversationStatusX on ConversationStatus {
  String get label => switch (this) {
        ConversationStatus.active => '🟢 대화 중',
        ConversationStatus.scheduling => '📅 약속 조율 중',
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
  });

  final String id;
  final String name;
  final String initial;
  final int score;
  final String lastMessage;
  final String time;
  final ConversationStatus status;
  final bool unread;
}

const List<Conversation> kActiveConversations = [
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
    id: 'c2',
    name: '김현우',
    initial: '현',
    score: 91,
    lastMessage: '주말 일정 확인하고 알려드릴게요',
    time: '오후 1:10',
    status: ConversationStatus.scheduling,
    unread: false,
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
