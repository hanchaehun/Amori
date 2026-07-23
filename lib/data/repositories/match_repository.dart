import '../api/api_client.dart';
import '../dummy/matches.dart';

/// BFF 매칭 결과 (`GET /matches/find`).
class MatchCandidate {
  const MatchCandidate({
    required this.matchId,
    required this.userId,
    required this.displayName,
    required this.score,
  });

  final String matchId; // 백엔드 Match UUID — report/meet 라우터와 동일 ID 체계
  final String userId;
  final String? displayName;
  final double score;

  /// 기존 화면 모델로 변환. 카테고리별 점수(가치관/유머/대화)는
  /// matching 패키지 고도화(P2) 전까지 종합 점수로 대체한다.
  MatchProfile toProfile() {
    final name = displayName ?? '익명';
    final rounded = score.round();
    return MatchProfile(
      id: matchId,
      initial: name.isEmpty ? '?' : name.substring(0, 1),
      name: name,
      age: 0,
      score: rounded,
      values: rounded,
      humor: rounded,
      communication: rounded,
    );
  }
}

/// 연결(inbox) 화면의 대화 카드 한 장 (`GET /matches`).
class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.partnerId,
    required this.partnerName,
    this.partnerPhotoUrl,
    required this.status,
    required this.score,
    required this.appointmentReady,
    required this.youAccepted,
    required this.partnerAccepted,
    required this.lastMessage,
    required this.turnCount,
    required this.updatedAt,
    this.appointmentSlot,
    this.reportScore,
    this.failed = false,
    this.failureReason,
    this.failedExpiresAt,
    this.agentLive = false,
  });

  final String matchId;
  final String partnerId;
  final String? partnerName;
  final String? partnerPhotoUrl;
  final String status; // simulated | scheduled | met
  final double? score;
  final bool appointmentReady;
  final bool youAccepted;
  final bool partnerAccepted;
  final String? lastMessage;
  final int turnCount;
  final DateTime? updatedAt;

  /// 에이전트 대화가 시차 송출 중 — 카드는 "에이전트 대화 중"으로 표시하고
  /// 약속·점수 정보는 송출이 끝날 때까지 백엔드가 가린다(라이브 관전).
  final bool agentLive;

  /// 사용자들이 직접 채팅에서 확정한 약속 라벨 ("6월 14일(토) 저녁").
  /// 시뮬은 약속을 잡지 않는다(07-04 결정) — 약속의 주체는 사용자.
  final String? appointmentSlot;

  /// 케미 점수(리포트). [score]는 벡터 매칭 점수.
  final int? reportScore;

  /// 케미 점수가 게이트(80) 미만 — '닿지 않은 인연' 화면으로 분리된다.
  final bool failed;
  final String? failureReason;

  /// 이 시각이 지나면 백엔드 목록에서 자연 소멸한다 (TTL 3일).
  final DateTime? failedExpiresAt;

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
    matchId: json['match_id'] as String? ?? '',
    partnerId: json['partner_id'] as String? ?? '',
    partnerName: json['partner_name'] as String?,
    partnerPhotoUrl: json['partner_photo_url'] as String?,
    status: json['status'] as String? ?? 'simulated',
    score: (json['score'] as num?)?.toDouble(),
    appointmentReady: json['appointment_ready'] as bool? ?? false,
    youAccepted: json['you_accepted'] as bool? ?? false,
    partnerAccepted: json['partner_accepted'] as bool? ?? false,
    lastMessage: json['last_message'] as String?,
    turnCount: json['turn_count'] as int? ?? 0,
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    appointmentSlot: json['appointment_slot'] as String?,
    reportScore: json['report_score'] as int?,
    failed: json['failed'] as bool? ?? false,
    failureReason: json['failure_reason'] as String?,
    failedExpiresAt: DateTime.tryParse(
      json['failed_expires_at'] as String? ?? '',
    ),
    agentLive: json['agent_live'] as bool? ?? false,
  );
}

/// 수락 결과 (`POST /matches/{id}/accept`).
class MatchAcceptResult {
  const MatchAcceptResult({required this.status, required this.bothAccepted});

  final String status; // simulated | scheduled
  final bool bothAccepted;
}

/// 에이전트 시뮬레이션 발화 한 턴 — 내 시점의 speaker(me|them)와 text.
class AgentTurn {
  const AgentTurn({required this.isMe, required this.text});

  final bool isMe;
  final String text;
}

/// 직접 채팅 메시지 한 건. [kind]가 'system'이면 약속 취소 같은 안내문구.
/// 직접 채팅 메시지의 전송 상태 — 낙관적 UI(전송 중/실패 재시도)용.
enum DirectMessageStatus { sent, sending, failed }

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.kind,
    required this.isMe,
    required this.text,
    this.createdAt,
    this.status = DirectMessageStatus.sent,
  });

  final String id;
  final String kind; // user | system
  final bool isMe;
  final String text;
  final DateTime? createdAt;

  /// 서버에서 온 메시지는 항상 sent. 낙관적으로 삽입한 로컬 메시지만
  /// sending/failed 상태를 가진다.
  final DirectMessageStatus status;

  bool get isSystem => kind == 'system';

  DirectMessage copyWith({String? id, DirectMessageStatus? status}) =>
      DirectMessage(
        id: id ?? this.id,
        kind: kind,
        isMe: isMe,
        text: text,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
    id: json['id'] as String? ?? '',
    kind: json['kind'] as String? ?? 'user',
    isMe: json['is_me'] as bool? ?? false,
    text: json['text'] as String? ?? '',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
  );
}

/// 대화방 화면 데이터 (`GET /matches/{id}/conversation`) —
/// 에이전트 대화 + 직접 채팅 + 입력 가능 여부를 한 번에.
class MatchConversation {
  const MatchConversation({
    required this.matchId,
    required this.partnerName,
    required this.status,
    required this.chatEnabled,
    required this.agentTurns,
    required this.messages,
    this.appointmentSlot,
    this.agentLive = false,
    this.agentNextSpeaker,
  });

  final String matchId;
  final String? partnerName;
  final String status; // simulated | scheduled | met

  /// 양쪽이 만남을 수락(scheduled)했을 때만 직접 채팅이 열린다.
  final bool chatEnabled;

  /// 에이전트 대화가 시차 송출 중 — True면 다음 턴이 곧 도착한다(라이브 관전).
  final bool agentLive;

  /// 다음에 공개될 턴의 화자('me'|'them', 내 시점) — 타이핑 인디케이터를
  /// 상대 말풍선에 붙일지 내 입력창에 붙일지 정한다. 송출 끝이면 null.
  final String? agentNextSpeaker;

  /// [agentNextSpeaker]에 구버전 서버 폴백을 얹은 값 — 필드가 없으면
  /// 마지막 공개 턴의 반대편으로 추정한다(시뮬 발화는 교대로 진행).
  String? get effectiveNextSpeaker {
    if (!agentLive) return null;
    if (agentNextSpeaker != null) return agentNextSpeaker;
    if (agentTurns.isEmpty) return 'me'; // 첫 턴은 요청자(내 AI)부터
    return agentTurns.last.isMe ? 'them' : 'me';
  }
  final List<AgentTurn> agentTurns;
  final List<DirectMessage> messages;

  /// 사용자들이 직접 확정한 약속 라벨 ("6월 13일(토) 저녁"). 아직 안 잡았거나 취소되면 null.
  final String? appointmentSlot;

  factory MatchConversation.fromJson(Map<String, dynamic> json) =>
      MatchConversation(
        matchId: json['match_id'] as String? ?? '',
        partnerName: json['partner_name'] as String?,
        status: json['status'] as String? ?? 'simulated',
        chatEnabled: json['chat_enabled'] as bool? ?? false,
        agentLive: json['agent_live'] as bool? ?? false,
        agentNextSpeaker: json['agent_next_speaker'] as String?,
        agentTurns: [
          for (final t
              in (json['agent_turns'] as List? ?? [])
                  .whereType<Map<String, dynamic>>())
            AgentTurn(
              isMe: t['speaker'] == 'me',
              text: t['text'] as String? ?? '',
            ),
        ],
        messages: [
          for (final m
              in (json['messages'] as List? ?? [])
                  .whereType<Map<String, dynamic>>())
            DirectMessage.fromJson(m),
        ],
        appointmentSlot: json['appointment_slot'] as String?,
      );
}

/// 매치 상대의 공개 프로필 (`GET /matches/{id}/partner-profile`) —
/// 리포트 내 '상대 프로필 보기'. 매칭된 쌍에게만 서버가 공개한다.
class PartnerProfile {
  const PartnerProfile({
    required this.displayName,
    this.age,
    this.region,
    this.mbti,
    this.bio,
    this.photoUrl,
  });

  final String displayName;
  final int? age;
  final String? region;
  final String? mbti;
  final String? bio;
  final String? photoUrl;

  factory PartnerProfile.fromJson(Map<String, dynamic> json) => PartnerProfile(
    displayName: json['display_name'] as String? ?? '상대',
    age: json['age'] as int?,
    region: json['region'] as String?,
    mbti: json['mbti'] as String?,
    bio: json['bio'] as String?,
    photoUrl: json['photo_url'] as String?,
  );
}

/// 약속 취소 결과 (`POST /matches/{id}/cancel`).
class MatchCancelResult {
  const MatchCancelResult({required this.status, required this.notice});

  final String status; // 취소 후 simulated
  final String notice; // 채팅방에 남은 시스템 안내문구
}

/// 벡터 유사도 매칭 — BFF 경유 (Firestore 데모 시딩 대체).
class MatchRepository {
  MatchRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  final ApiClient _api;

  Future<List<MatchCandidate>> findMatches({int topK = 10}) async {
    final json = await _api.getJson('/matches/find', query: {'top_k': '$topK'});
    return [
      for (final item in (json as List).whereType<Map<String, dynamic>>())
        MatchCandidate(
          matchId: item['match_id'] as String? ?? '',
          userId: item['user_id'] as String? ?? '',
          displayName: item['display_name'] as String?,
          score: (item['score'] as num?)?.toDouble() ?? 0,
        ),
    ];
  }

  /// 내 대화 목록 — 시뮬레이션이 있었던 매치만 (연결 화면).
  Future<List<MatchSummary>> listMatches() async {
    final json = await _api.getJson('/matches');
    return [
      for (final item in (json as List).whereType<Map<String, dynamic>>())
        MatchSummary.fromJson(item),
    ];
  }

  /// 만남 수락 — 양쪽 모두 수락하면 status가 'scheduled'로 올라온다.
  Future<MatchAcceptResult> acceptMatch(String matchId) async {
    final json =
        await _api.postJson('/matches/$matchId/accept', const {})
            as Map<String, dynamic>;
    return MatchAcceptResult(
      status: json['status'] as String? ?? 'simulated',
      bothAccepted: json['both_accepted'] as bool? ?? false,
    );
  }

  /// 대화방 — 에이전트 대화 + 직접 채팅. 진행 중이면 읽기 전용으로 내려온다.
  Future<PartnerProfile> getPartnerProfile(String matchId) async {
    final json = await _api.getJson('/matches/$matchId/partner-profile')
        as Map<String, dynamic>;
    return PartnerProfile.fromJson(json);
  }

  Future<MatchConversation> getConversation(String matchId) async {
    final json =
        await _api.getJson('/matches/$matchId/conversation')
            as Map<String, dynamic>;
    return MatchConversation.fromJson(json);
  }

  /// 직접 채팅 전송 — scheduled가 아니면 400 CHAT_LOCKED.
  Future<DirectMessage> sendMessage(String matchId, String text) async {
    final json =
        await _api.postJson('/matches/$matchId/messages', {'text': text})
            as Map<String, dynamic>;
    return DirectMessage.fromJson(json);
  }

  /// 직접 채팅에서 합의한 약속을 확정 기록 — scheduled 매치에서만.
  /// 반환값은 약속 라벨("6월 14일(토) 저녁"). 채팅방에 시스템 안내가 남는다.
  Future<String> setAppointment(
    String matchId, {
    required String date, // YYYY-MM-DD
    required String time, // 점심 | 저녁
  }) async {
    final json =
        await _api.postJson('/matches/$matchId/appointment', {
              'date': date,
              'time': time,
            })
            as Map<String, dynamic>;
    return json['appointment_slot'] as String? ?? '';
  }

  /// 약속 취소 — 매치가 '진행 중'으로 돌아가고 예약된 시간이 풀린다.
  /// 상대 채팅방에는 시스템 안내문구가 남는다.
  Future<MatchCancelResult> cancelAppointment(String matchId) async {
    final json =
        await _api.postJson('/matches/$matchId/cancel', const {})
            as Map<String, dynamic>;
    return MatchCancelResult(
      status: json['status'] as String? ?? 'simulated',
      notice: json['notice'] as String? ?? '약속이 취소됐어요.',
    );
  }

  /// 상대 신고 — 검토 큐(abuse_reports)에 접수된다. [reason]은 고정 목록
  /// (inappropriate·harassment·spam·fake·other) 중 하나.
  Future<void> reportPartner(
    String matchId, {
    String reason = 'other',
    String? detail,
  }) async {
    await _api.postJson('/matches/$matchId/report', {
      'reason': reason,
      if (detail != null && detail.isNotEmpty) 'detail': detail,
    });
  }

  /// 상대 차단 — 이후 매칭 후보·대화 목록에서 상호 제외된다. 멱등.
  Future<void> blockPartner(String matchId) async {
    await _api.postJson('/matches/$matchId/block', const {});
  }
}
