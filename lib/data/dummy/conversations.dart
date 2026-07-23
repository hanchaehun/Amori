enum ConversationStatus { active, scheduling, scheduled, completed }

extension ConversationStatusX on ConversationStatus {
  String get label => switch (this) {
    ConversationStatus.active => '🟢 대화 중',
    ConversationStatus.scheduling => '💌 만남 수락 대기',
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
    this.photoUrl,
    this.appointmentReady = false,
    this.appointmentLabel,
    this.partnerAccepted = false,
    this.youAccepted = false,
  });

  final String id;
  final String name;
  final String initial;
  final String? photoUrl;
  final int score;
  final String lastMessage;
  final String time;
  final ConversationStatus status;
  final bool unread;

  /// 수락 가능 — 케미 리포트가 게이트(80점)를 통과했는가.
  /// (시뮬은 약속을 잡지 않는다 — 07-04 결정. 필드명은 백엔드 하위호환.)
  /// true면 '진행 중'에서 맨 위로 올라오고 테두리가 강조된다.
  final bool appointmentReady;

  /// 사용자들이 직접 채팅에서 확정한 약속 시간 ("6월 14일(토) 저녁").
  /// 아직 안 잡았으면 null.
  final String? appointmentLabel;

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
      photoUrl: photoUrl,
      score: score,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      status: status ?? this.status,
      unread: unread ?? this.unread,
      appointmentReady: appointmentReady ?? this.appointmentReady,
      appointmentLabel: appointmentLabel,
      partnerAccepted: partnerAccepted ?? this.partnerAccepted,
      youAccepted: youAccepted ?? this.youAccepted,
    );
  }
}

/// 케미 점수가 게이트(80점)를 넘지 못해 이어지지 않은 대화 — '닿지 않은 인연'.
/// 백엔드 TTL(3일)이 지나면 목록에서 자연 소멸한다.
class FailedMatch {
  const FailedMatch({
    required this.id,
    required this.name,
    required this.initial,
    required this.score,
    required this.reason,
    this.expiresAt,
  });

  final String id;
  final String name;
  final String initial;
  final int score; // 케미 점수 (리포트)
  final String reason; // 리포트 warnings 첫 항목
  final DateTime? expiresAt;

  /// 소멸까지 남은 일수(올림). 0이면 오늘 사라진다.
  int get daysLeft {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return (diff.inHours / 24).ceil();
  }
}
