import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_snackbar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/typing_dots.dart';
import '../../data/api/api_exception.dart';
import '../../data/dummy/conversations.dart';
import '../../data/repositories/match_repository.dart';

class _Starter {
  const _Starter({required this.label, required this.message});
  final String label;
  final String message;
}

/// 대화방 — 에이전트들이 먼저 나눈 대화 뒤에 두 사용자의 직접 채팅이 이어진다.
///
/// 직접 채팅은 양쪽이 만남을 수락해 status='scheduled'일 때만 열린다.
/// '진행 중'에서는 에이전트 대화를 읽기 전용으로 보여주고 입력이 잠긴다.
/// 만남 예정 상태에선 약속 배너에서 취소할 수 있고, 취소하면 상대 방에
/// 시스템 안내문구가 남으며 잡혀 있던 시간이 다시 가능한 일정으로 풀린다.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.conversationId, this.peer});

  final String? conversationId;

  /// 목록 카드에서 넘어온 상대 정보 — 로딩 중 헤더 표시용. 없어도 동작한다.
  final Conversation? peer;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final MatchRepository _matches = MatchRepository();

  static const _starters = [
    _Starter(label: '💬 여행 얘기', message: '최근에 다녀온 여행지 중에 가장 좋았던 데가 어디예요?'),
    _Starter(label: '🎬 영화 추천', message: '요즘 인상 깊게 본 영화 있으세요?'),
    _Starter(label: '☕ 일상 루틴', message: '주말에는 보통 어떻게 보내세요?'),
  ];

  bool _loading = true;

  /// 백엔드 대화방을 받아왔는가. false면 더미 폴백 — 전송·취소도 로컬 처리.
  bool _fromBackend = false;

  String? _partnerName;
  String _status = 'simulated';
  bool _chatEnabled = false;
  String? _appointmentSlot;
  List<AgentTurn> _agentTurns = [];
  List<DirectMessage> _messages = [];

  /// 에이전트 대화 시차 송출 중 — 다음 턴이 곧 도착한다(라이브 관전).
  bool _agentLive = false;

  /// 다음에 공개될 턴의 화자('me'|'them') — 타이핑 인디케이터 위치를 정한다.
  String? _agentNextSpeaker;

  bool _hasText = false;
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.conversationId;
    if (id != null && id != 'new') {
      try {
        final conv = await _matches.getConversation(id);
        if (!mounted) return;
        setState(() {
          _fromBackend = true;
          _loading = false;
          _apply(conv);
        });
        _scrollToEnd();
        // 상대 메시지·취소 안내를 주기적으로 받아온다 (SSE 없는 단순 폴링)
        _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
        return;
      } catch (e) {
        debugPrint('chat: GET /conversation 실패 — 더미 폴백으로 전환: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _fromBackend = false;
      _loading = false;
      _partnerName = widget.peer?.name;
      _status = widget.peer?.status == ConversationStatus.scheduled
          ? 'scheduled'
          : 'simulated';
      _chatEnabled = _status == 'scheduled';
      _appointmentSlot = widget.peer?.appointmentLabel;
      _agentTurns = kDummyAgentTurns;
      _messages = _chatEnabled ? [...kDummyDirectMessages] : [];
    });
    _scrollToEnd();
  }

  void _apply(MatchConversation conv) {
    _partnerName = conv.partnerName ?? widget.peer?.name;
    _status = conv.status;
    _chatEnabled = conv.chatEnabled;
    _appointmentSlot = conv.appointmentSlot;
    _agentTurns = conv.agentTurns;
    _messages = conv.messages;
    _agentLive = conv.agentLive;
    _agentNextSpeaker = conv.effectiveNextSpeaker;
  }

  Future<void> _refresh() async {
    final id = widget.conversationId;
    if (!_fromBackend || id == null) return;
    try {
      final conv = await _matches.getConversation(id);
      if (!mounted) return;
      final grew = conv.messages.length > _messages.length ||
          conv.agentTurns.length > _agentTurns.length;
      setState(() => _apply(conv));
      if (grew) _scrollToEnd();
    } catch (_) {
      // 일시 오류는 다음 폴링에서 회복
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _applyStarter(_Starter s) {
    HapticFeedback.selectionClick();
    setState(() {
      _controller.text = s.message;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
    _focusNode.requestFocus();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.lightImpact();

    if (!_fromBackend) {
      setState(() {
        _messages = [
          ..._messages,
          DirectMessage(
            id: 'local_${_messages.length}',
            kind: 'user',
            isMe: true,
            text: text,
            createdAt: DateTime.now(),
          ),
        ];
        _controller.clear();
      });
      _scrollToEnd();
      return;
    }

    setState(() => _sending = true);
    try {
      final sent = await _matches.sendMessage(widget.conversationId!, text);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _controller.clear();
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      if (e.errorCode == 'CHAT_LOCKED') _refresh(); // 상대가 취소했을 수 있다
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 약속 취소 — 확인 팝업 후 진행. 상대 방에는 시스템 안내문구가 남고,
  /// 잡혀 있던 시간은 다시 가능한 일정으로 풀린다.
  Future<void> _onCancelAppointment() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('정말 취소하시겠습니까?', style: AppTypography.titleMedium),
        content: Text(
          '${_appointmentSlot != null ? '$_appointmentSlot 약속이' : '약속이'} 취소되고 '
          '상대에게 안내가 전달돼요. 잡혀 있던 시간은 다시 가능한 일정이 돼요.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.ink700,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.ink500),
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('네, 취소할게요'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (!_fromBackend) {
      setState(() {
        _status = 'simulated';
        _chatEnabled = false;
        _messages = [
          ..._messages,
          DirectMessage(
            id: 'local_cancel',
            kind: 'system',
            isMe: false,
            text:
                '약속을 취소했어요.'
                '${_appointmentSlot != null ? ' 그 시간은 다시 비어 있는 일정이 됐어요.' : ''}',
            createdAt: DateTime.now(),
          ),
        ];
        _appointmentSlot = null;
      });
      _scrollToEnd();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _matches.cancelAppointment(widget.conversationId!);
      if (!mounted) return;
      setState(() {
        _status = result.status;
        _chatEnabled = false;
        _appointmentSlot = null;
        _messages = [
          ..._messages,
          DirectMessage(
            id: 'cancel_${_messages.length}',
            kind: 'system',
            isMe: false,
            text: result.notice,
            createdAt: DateTime.now(),
          ),
        ];
      });
      _scrollToEnd();
      messenger.showSnackBar(
        const SnackBar(content: Text('약속을 취소했어요. 그 시간은 다시 가능한 일정이 됐어요')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// 직접 약속 확정 — 채팅으로 합의한 시간을 기록한다.
  /// 시뮬은 약속을 잡지 않으므로(07-04 결정) 약속의 주체는 사용자다.
  Future<void> _onSetAppointment() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final days = [for (var i = 1; i <= 14; i++) now.add(Duration(days: i))];
    DateTime? day;
    String time = '저녁';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('약속 잡기', style: AppTypography.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '채팅으로 합의한 시간을 확정해요. 확정하면 상대에게도 표시돼요.',
                  style: AppTypography.caption.copyWith(color: AppColors.ink500),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: days.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final d = days[i];
                      final selected = day == d;
                      final weekday = '월화수목금토일'[d.weekday - 1];
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheet(() => day = d);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.mint.withValues(alpha: 0.12)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? AppColors.mint : AppColors.ink100,
                            ),
                          ),
                          child: Text(
                            '${d.month}/${d.day} ($weekday)',
                            style: AppTypography.caption.copyWith(
                              color: selected ? AppColors.ink900 : AppColors.ink700,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final t in const ['점심', '저녁']) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setSheet(() => time = t);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: time == t
                                  ? AppColors.mint.withValues(alpha: 0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    time == t ? AppColors.mint : AppColors.ink100,
                              ),
                            ),
                            child: Text(
                              t == '점심' ? '🍽 점심' : '🌆 저녁',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: time == t
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (t == '점심') const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.ink500,
                      ),
                      child: const Text('다음에'),
                    ),
                    TextButton(
                      onPressed: day == null
                          ? null
                          : () => Navigator.of(ctx).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.mint,
                      ),
                      child: const Text(
                        '이 시간으로 확정',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final picked = day;
    if (confirmed != true || picked == null || !mounted) return;

    final dateIso =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    final weekday = '월화수목금토일'[picked.weekday - 1];
    final localLabel = '${picked.month}월 ${picked.day}일($weekday) $time';

    if (!_fromBackend) {
      setState(() {
        _appointmentSlot = localLabel;
        _messages = [
          ..._messages,
          DirectMessage(
            id: 'local_appointment',
            kind: 'system',
            isMe: false,
            text: '📅 $localLabel에 만나기로 약속했어요',
            createdAt: DateTime.now(),
          ),
        ];
      });
      _scrollToEnd();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final label = await _matches.setAppointment(
        widget.conversationId!,
        date: dateIso,
        time: time,
      );
      if (!mounted) return;
      setState(() => _appointmentSlot = label.isEmpty ? localLabel : label);
      await _refresh(); // 시스템 안내 메시지를 받아온다
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _onMore() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink100,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 8),
            _MoreOption(
              icon: Icons.flag_outlined,
              label: '신고하기',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _onReport();
              },
            ),
            _MoreOption(
              icon: Icons.block_rounded,
              label: '차단하기',
              danger: true,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _onBlock();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        title: Text(title, style: AppTypography.titleMedium),
        content: Text(
          body,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.ink500,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.ink500),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: danger ? AppColors.danger : AppColors.primary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _onReport() async {
    final ok = await _confirm(
      title: '이 대화를 신고할까요?',
      body: '부적절한 행동이 있었다면 알려주세요. 접수 후 검토합니다.',
      confirmLabel: '신고하기',
      danger: true,
    );
    if (ok && mounted) {
      AmoriSnackbar.success(context, '신고가 접수되었어요. 검토 후 조치할게요.');
    }
  }

  Future<void> _onBlock() async {
    final ok = await _confirm(
      title: '$_displayName님을 차단할까요?',
      body: '차단하면 서로의 대화가 더 이상 표시되지 않아요.',
      confirmLabel: '차단하기',
      danger: true,
    );
    if (ok && mounted) {
      AmoriSnackbar.show(context, '차단했어요.');
      if (context.canPop()) context.pop();
    }
  }

  String get _displayName =>
      _partnerName ?? widget.peer?.name ?? '상대';

  @override
  Widget build(BuildContext context) {
    final hasDirectSection = _chatEnabled || _messages.isNotEmpty;
    return AppScaffold(
      appBar: _ChatAppBar(
        name: _displayName,
        score: widget.peer?.score ?? 0,
        onMore: _onMore,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_chatEnabled)
                  _AppointmentBanner(
                    label: _appointmentSlot,
                    onCancel: _onCancelAppointment,
                    onSet: _onSetAppointment,
                  ),
                if (_chatEnabled)
                  _StarterRow(starters: _starters, onTap: _applyStarter),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    children: [
                      if (_agentTurns.isNotEmpty || _agentLive) ...[
                        const _SectionDivider(
                          label: 'AI 에이전트가 먼저 나눈 대화',
                          accent: true,
                        ),
                        AppSpacing.vSm,
                        for (final t in _agentTurns) ...[
                          _Bubble(isMe: t.isMe, text: t.text, isAgent: true),
                          AppSpacing.vSm,
                        ],
                        // 상대 에이전트가 다음 발화를 준비 중 — 상대 말풍선 자리에
                        // 점(1→2→3)이 차오른다. 내 차례면 아래 입력창에 표시된다.
                        if (_agentLive && _agentNextSpeaker == 'them') ...[
                          const _TypingBubble(),
                          AppSpacing.vSm,
                        ],
                      ],
                      if (hasDirectSection) ...[
                        AppSpacing.vSm,
                        const _SectionDivider(label: '여기서부터 두 분의 대화'),
                        AppSpacing.vSm,
                        for (final m in _messages) ...[
                          if (m.isSystem)
                            _SystemNotice(text: m.text)
                          else
                            _Bubble(
                              isMe: m.isMe,
                              text: m.text,
                              time: _formatTime(m.createdAt),
                            ),
                          AppSpacing.vSm,
                        ],
                      ],
                    ],
                  ),
                ),
                if (_chatEnabled)
                  _InputBar(
                    controller: _controller,
                    focusNode: _focusNode,
                    hasText: _hasText && !_sending,
                    onSend: _send,
                  )
                else if (_agentLive && _agentNextSpeaker == 'me')
                  const _AgentTypingBar()
                else
                  const _LockedBar(),
              ],
            ),
    );
  }

  static String _formatTime(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.hour < 12 ? '오전' : '오후'} $h12:$mm';
  }
}

/// 더미 폴백용 에이전트 대화 — 백엔드 없이 화면 구조를 보여주기 위한 것.
const kDummyAgentTurns = [
  AgentTurn(isMe: true, text: '안녕하세요! 좋은 인연이 되었으면 좋겠어요 ㅎㅎ'),
  AgentTurn(isMe: false, text: '안녕하세요! 저도요. 주말엔 보통 뭐 하면서 보내세요?'),
  AgentTurn(isMe: true, text: '조용한 카페에서 책 읽는 걸 좋아해요. 혹시 토요일 저녁 어떠세요?'),
  AgentTurn(isMe: false, text: '좋아요! 토요일 저녁에 봬요 :)'),
];

const kDummyDirectMessages = [
  DirectMessage(
    id: 'd1',
    kind: 'user',
    isMe: false,
    text: '안녕하세요! 에이전트들이 약속까지 잡아줬네요 ㅎㅎ',
  ),
  DirectMessage(
    id: 'd2',
    kind: 'user',
    isMe: true,
    text: '그러니까요! 직접 인사드리니 반가워요 :)',
  ),
];

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.name,
    required this.score,
    required this.onMore,
  });
  final String name;
  final int score;
  final VoidCallback onMore;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.ink100, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: AppColors.ink900,
                  ),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceMuted,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          name.isEmpty ? '?' : name.substring(0, 1),
                          style: AppTypography.label.copyWith(
                            color: AppColors.ink700,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: AppTypography.titleMedium.copyWith(fontSize: 16),
                      ),
                      if (score > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '$score',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 24,
                    color: AppColors.ink900,
                  ),
                  onPressed: onMore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 만남 예정 배너 — 합의된 약속 시간과 [약속 취소] 진입점.
class _AppointmentBanner extends StatelessWidget {
  /// 약속 배너 — 아직 안 잡았으면 [약속 잡기], 잡혔으면 라벨 + [약속 취소].
  /// 약속의 주체는 사용자다 (시뮬은 약속을 잡지 않는다 — 07-04 결정).
  const _AppointmentBanner({
    required this.label,
    required this.onCancel,
    required this.onSet,
  });

  final String? label;
  final VoidCallback onCancel;
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    final hasAppointment = label != null;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.06),
        border: const Border(
          bottom: BorderSide(color: AppColors.ink100, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasAppointment
                ? Icons.event_available_rounded
                : Icons.event_rounded,
            size: 16,
            color: AppColors.mint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hasAppointment ? '$label 만남 예정' : '채팅으로 정한 시간을 확정해보세요',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink900,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: hasAppointment ? onCancel : onSet,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                hasAppointment ? '약속 취소' : '약속 잡기',
                style: AppTypography.caption.copyWith(
                  color: hasAppointment ? AppColors.danger : AppColors.mint,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarterRow extends StatelessWidget {
  const _StarterRow({required this.starters, required this.onTap});
  final List<_Starter> starters;
  final ValueChanged<_Starter> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.ink100, width: 1)),
      ),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            for (final s in starters) ...[
              _StarterChip(label: s.label, onTap: () => onTap(s)),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _StarterChip extends StatelessWidget {
  const _StarterChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.primary, width: 1),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label, this.accent = false});
  final String label;

  /// true면 보라 틴트 알약 — 에이전트 대화 섹션의 정체성 표시.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(99),
        border: accent
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.22))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accent) ...[
            const Icon(
              Icons.auto_awesome_rounded,
              size: 11,
              color: AppColors.primary,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: accent ? AppColors.primary : AppColors.ink500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.ink100, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: pill,
        ),
        const Expanded(child: Divider(color: AppColors.ink100, height: 1)),
      ],
    );
  }
}

/// 시스템 안내문구 — 약속 취소 등. 가운데 회색 알약으로 표시한다.
class _SystemNotice extends StatelessWidget {
  const _SystemNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: AppColors.ink700,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// 말풍선. 내 직접 메시지만 그라데이션 테두리 — 에이전트 발화는 [isAgent]로
/// 평평한 테두리를 써서 '진짜 나'와 시각적으로 구분한다.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.isMe,
    required this.text,
    this.time = '',
    this.isAgent = false,
  });
  final bool isMe;
  final String text;
  final String time;
  final bool isAgent;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    const border = 1.6;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          );
    const innerRadius = BorderRadius.only(
      topLeft: Radius.circular(18 - border),
      topRight: Radius.circular(18 - border),
      bottomLeft: Radius.circular(18 - border),
      bottomRight: Radius.circular(6 - border),
    );
    final textWidget = Text(
      text,
      style: AppTypography.bodyMedium.copyWith(
        color: AppColors.ink900,
        fontSize: 15,
        height: 1.4,
      ),
    );
    final Widget bubble;
    if (isMe && !isAgent) {
      // 그라데이션 테두리: 바깥은 그라데이션, 안쪽은 흰 칸 → 텍스트가 또렷하게.
      bubble = Container(
        decoration: BoxDecoration(
          gradient: amori.primaryGradient,
          borderRadius: radius,
        ),
        padding: const EdgeInsets.all(border),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: innerRadius,
          ),
          child: textWidget,
        ),
      );
    } else if (isMe) {
      // 내 에이전트 발화 — 보라 기운으로 '내 쪽'임을 보여주되,
      // 그라데이션('진짜 나')보다는 한 단계 차분하게.
      bubble = Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: radius,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.28),
            width: 1.2,
          ),
        ),
        child: textWidget,
      );
    } else {
      bubble = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: radius,
          border: Border.all(color: AppColors.ink100, width: 1),
        ),
        child: textWidget,
      );
    }
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: bubble,
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              time,
              style: AppTypography.caption.copyWith(
                color: AppColors.ink300,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 상대 에이전트가 입력 중 — 상대 말풍선 모양 안에서 점이 1→2→3으로 차오른다.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: AppColors.ink100, width: 1),
        ),
        child: const TypingDots(),
      ),
    );
  }
}

/// 내 에이전트 차례 — 입력창 자리에서 점이 차오른다. 내 AI가 내 폰으로
/// 답장을 치고 있는 듯한 연출이라, 입력창 모양은 유지하되 조작은 막는다.
class _AgentTypingBar extends StatelessWidget {
  const _AgentTypingBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.ink100, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const TypingDots(),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const ShapeDecoration(
                color: AppColors.ink100,
                shape: CircleBorder(),
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                size: 20,
                color: AppColors.ink300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// '진행 중' 잠금 안내 — 에이전트 단계라 직접 채팅이 닫혀 있다.
class _LockedBar extends StatelessWidget {
  const _LockedBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.ink100, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: AppColors.ink500,
              ),
              const SizedBox(width: 6),
              Text(
                '서로 만남을 수락하면 직접 대화할 수 있어요',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.ink100, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 40,
                  maxHeight: 120,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.ink900,
                    fontSize: 14,
                  ),
                  cursorColor: AppColors.primary,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: '메시지 입력...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink500,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: hasText ? onSend : null,
              behavior: HitTestBehavior.opaque,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Container(
                  key: ValueKey(hasText),
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    gradient: hasText ? amori.primaryGradient : null,
                    color: hasText ? null : AppColors.ink100,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 20,
                    color: hasText ? Colors.white : AppColors.ink300,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreOption extends StatelessWidget {
  const _MoreOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink900;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            AppSpacing.hMd,
            Text(
              label,
              style: AppTypography.bodyLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
