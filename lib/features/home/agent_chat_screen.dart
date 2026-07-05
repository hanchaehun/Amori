import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/repositories/match_repository.dart';

enum _Sender { me, them, system }

class _ChatMessage {
  const _ChatMessage({
    required this.sender,
    this.name,
    this.avatarInitial,
    required this.text,
    this.signal,
  });

  final _Sender sender;
  final String? name;
  final String? avatarInitial;
  final String text;
  final String? signal;
}

const _meName = '내 AI';
const _meInitial = '나';
const _fallbackThemName = '상대 AI';
const _fallbackThemInitial = '상';

// 백엔드에 닿지 못할 때(오프라인 / dev 미설정)만 보여줄 폴백 더미 대화.
const List<_ChatMessage> _fallbackMessages = [
  _ChatMessage(
    sender: _Sender.me,
    name: _meName,
    avatarInitial: _meInitial,
    text: '안녕하세요! 주말에는 보통 어떻게 보내세요?',
    signal: '여행 시그널',
  ),
  _ChatMessage(
    sender: _Sender.them,
    name: _fallbackThemName,
    avatarInitial: _fallbackThemInitial,
    text: '저는 주로 성수나 연남 카페에서 책 읽거나, 여행 준비해요. 최근엔 후쿠오카 다녀왔어요 ✈️',
    signal: '여행+카페 매치',
  ),
  _ChatMessage(
    sender: _Sender.me,
    name: _meName,
    avatarInitial: _meInitial,
    text: '연애에서 가장 중요하게 생각하는 게 뭐예요?',
    signal: '핵심 질문',
  ),
  _ChatMessage(
    sender: _Sender.them,
    name: _fallbackThemName,
    avatarInitial: _fallbackThemInitial,
    text: '서로의 일상을 존중하면서도, 함께 있을 때 편안한 거요.',
    signal: '가치관 매치',
  ),
];

List<_ChatMessage> _fromTurns(
  List<AgentTurn> turns, {
  required String themName,
  required String themInitial,
}) {
  return turns
      .map(
        (t) => _ChatMessage(
          sender: t.isMe ? _Sender.me : _Sender.them,
          name: t.isMe ? _meName : themName,
          avatarInitial: t.isMe ? _meInitial : themInitial,
          text: t.text,
        ),
      )
      .toList();
}

/// 화면이 표시하는 현재 상태.
/// - [loading]: 첫 로드 중
/// - [live]: 시차 송출 중 — 다음 턴이 곧 도착(폴링 + 타이핑 인디케이터)
/// - [completed]: 송출 끝 — 케미 점수·리포트 노출
/// - [empty]: 백엔드는 닿았으나 아직 다녀온 소개팅이 없음
/// - [fallback]: 백엔드 미연결 — 더미 데모
enum _Mode { loading, live, completed, empty, fallback }

class AgentChatScreen extends StatefulWidget {
  const AgentChatScreen({
    super.key,
    this.repository,
    this.pollInterval = const Duration(seconds: 5),
  });

  /// 테스트에서 가짜 리포지토리를 주입한다. 기본은 실 BFF.
  final MatchRepository? repository;

  /// 라이브 송출 폴링 간격.
  final Duration pollInterval;

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen>
    with SingleTickerProviderStateMixin {
  late final MatchRepository _repo;
  late final AnimationController _typing;
  final ScrollController _scroll = ScrollController();

  Timer? _poll;
  bool _polling = false; // 폴 중복 방지 (느린 응답이 겹치지 않도록)

  _Mode _mode = _Mode.loading;
  MatchSummary? _match; // 관전 중인 매치(카드 정보: 점수·이름)
  MatchConversation? _conv; // 지금까지 공개된 대화
  int _lastTurnCount = 0;

  bool get _isLive => _mode == _Mode.live;
  bool get _isFallback => _mode == _Mode.fallback;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MatchRepository();
    _typing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bootstrap();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _typing.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final matches = await _repo.listMatches();
      if (!mounted) return;
      final selected = _pickMatch(matches);
      if (selected == null) {
        setState(() => _mode = _Mode.empty);
        _syncTyping();
        return;
      }
      _match = selected;
      await _refreshConversation();
      if (!mounted) return;
      if (_conv?.agentLive ?? false) _startPolling();
    } catch (error) {
      if (!mounted) return;
      debugPrint('AgentChat 라이브 로드 실패 — 더미 폴백: $error');
      setState(() => _mode = _Mode.fallback);
      _syncTyping();
    }
  }

  /// 라이브 송출 중인 매치를 우선, 없으면 가장 최근(목록 맨 앞) 매치.
  MatchSummary? _pickMatch(List<MatchSummary> matches) {
    if (matches.isEmpty) return null;
    for (final m in matches) {
      if (m.agentLive) return m;
    }
    return matches.first; // 백엔드가 updated_at desc로 정렬해 보낸다
  }

  Future<void> _refreshConversation() async {
    final id = _match?.matchId;
    if (id == null) return;
    final conv = await _repo.getConversation(id);
    if (!mounted) return;
    setState(() {
      _conv = conv;
      _mode = conv.agentLive ? _Mode.live : _Mode.completed;
    });
    _syncTyping();
    if (conv.agentTurns.length > _lastTurnCount) _scrollToBottom();
    _lastTurnCount = conv.agentTurns.length;
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(widget.pollInterval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final wasLive = _conv?.agentLive ?? false;
      await _refreshConversation();
      if (!mounted) return;
      final live = _conv?.agentLive ?? false;
      if (wasLive && !live) {
        // 송출 종료 — 점수·약속이 이제 노출되니 카드 정보를 한 번 더 받고 폴링 중단.
        await _refreshSummary();
        _poll?.cancel();
        _poll = null;
      }
    } catch (error) {
      // 일시적 오류는 다음 틱에 재시도 — 폴링을 죽이지 않는다.
      debugPrint('AgentChat 폴링 실패: $error');
    } finally {
      _polling = false;
    }
  }

  Future<void> _refreshSummary() async {
    try {
      final matches = await _repo.listMatches();
      if (!mounted) return;
      final id = _match?.matchId;
      for (final m in matches) {
        if (m.matchId == id) {
          setState(() => _match = m);
          return;
        }
      }
    } catch (error) {
      debugPrint('AgentChat 요약 갱신 실패: $error');
    }
  }

  void _syncTyping() {
    if (_typingVisible) {
      if (!_typing.isAnimating) _typing.repeat();
    } else {
      _typing.stop();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String get _themName {
    if (_isFallback) return _fallbackThemName;
    final p = _conv?.partnerName ?? _match?.partnerName;
    return (p == null || p.isEmpty) ? _fallbackThemName : '$p-AI';
  }

  String get _themInitial => _themName.substring(0, 1);

  List<_ChatMessage> get _messages {
    if (_isFallback) return _fallbackMessages;
    return _fromTurns(
      _conv?.agentTurns ?? const [],
      themName: _themName,
      themInitial: _themInitial,
    );
  }

  /// 타이핑 인디케이터: 라이브 송출 중이거나 더미 데모일 때.
  bool get _typingVisible => _isLive || _isFallback;

  int? get _score => _isFallback ? 88 : _match?.reportScore;

  bool get _reportReady =>
      _mode == _Mode.completed && _match?.reportScore != null;

  void _showMoreMenu() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('에이전트가 하루 중 자동으로 소개팅을 다녀와요')),
    );
  }

  void _onNotifyMe() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('소개팅이 끝나면 알림으로 알려드릴게요')),
    );
  }

  void _openReport() {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.lockedReport);
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    return AppScaffold(
      appBar: _ChatTopBar(
        onMore: _showMoreMenu,
        meName: _meName,
        themName: _themName,
        messageCount: messages.length,
        live: _isLive || _isFallback,
        done: _mode == _Mode.completed,
      ),
      bottomBar: _BottomNotice(
        reportReady: _reportReady,
        onNotify: _reportReady ? _openReport : _onNotifyMe,
      ),
      body: _buildBody(messages),
    );
  }

  Widget _buildBody(List<_ChatMessage> messages) {
    if (_mode == _Mode.loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_mode == _Mode.empty) return const _EmptyState();

    return Column(
      children: [
        _ChemistryBanner(score: _score),
        Expanded(
          child: ListView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: [
              const _StartMarker(),
              AppSpacing.vSm,
              for (var i = 0; i < messages.length; i++) ...[
                _MessageRow(message: messages[i]),
                AppSpacing.vSm,
              ],
              if (_typingVisible)
                _TypingIndicator(
                  controller: _typing,
                  initial: _themInitial,
                  label: '$_themName 응답 생성 중...',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            AppSpacing.vMd,
            Text(
              '아직 다녀온 소개팅이 없어요',
              style: AppTypography.titleMedium.copyWith(fontSize: 16),
            ),
            AppSpacing.vXs,
            Text(
              '에이전트가 하루 중 알아서 소개팅을 다녀와요.\n끝나면 여기에서 대화를 볼 수 있어요.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatTopBar({
    required this.onMore,
    required this.meName,
    required this.themName,
    required this.messageCount,
    required this.live,
    required this.done,
  });

  final VoidCallback onMore;
  final String meName;
  final String themName;
  final int messageCount;
  final bool live;
  final bool done;

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
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: AppColors.ink900),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$meName ↔ $themName',
                      style: AppTypography.label.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: live
                                ? AppColors.danger
                                : (done ? AppColors.mint : AppColors.ink300),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          done
                              ? '소개팅 완료 · 메시지 $messageCount'
                              : '실시간 소개팅 · 메시지 $messageCount',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded,
                    size: 24, color: AppColors.ink900),
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChemistryBanner extends StatelessWidget {
  const _ChemistryBanner({required this.score});

  /// 리포트의 케미 점수. null 이면 아직 송출 중(계산 결과 비공개).
  final int? score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        border: const Border(
          bottom: BorderSide(color: AppColors.ink100, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score == null ? '예상 케미스트리' : '케미스트리',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: score == null ? '—' : '$score',
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.6,
                        ),
                      ),
                      TextSpan(
                        text: score == null ? ' /100 (계산 중)' : ' /100',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.ink500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '🤖 AI 자동 진행',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartMarker extends StatelessWidget {
  const _StartMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '── AI 에이전트 소개팅 ──',
        style: AppTypography.caption.copyWith(
          color: AppColors.ink300,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.sender == _Sender.system) {
      return _SystemMessage(text: message.text);
    }
    final isMe = message.sender == _Sender.me;
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        _SenderLabel(
          name: message.name!,
          initial: message.avatarInitial!,
          rightAligned: isMe,
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: _Bubble(text: message.text, isMe: isMe),
        ),
        if (message.signal != null) ...[
          const SizedBox(height: 4),
          _SignalChip(text: message.signal!),
        ],
      ],
    );
  }
}

class _SenderLabel extends StatelessWidget {
  const _SenderLabel({
    required this.name,
    required this.initial,
    required this.rightAligned,
  });

  final String name;
  final String initial;
  final bool rightAligned;

  @override
  Widget build(BuildContext context) {
    final avatar = _MiniAvatar(initial: initial);
    final label = Text(
      name,
      style: AppTypography.caption.copyWith(
        color: AppColors.ink500,
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: rightAligned
          ? [label, const SizedBox(width: 4), avatar]
          : [avatar, const SizedBox(width: 4), label],
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: AppTypography.caption.copyWith(
          color: AppColors.ink700,
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isMe});

  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isMe ? amori.primaryGradient : null,
        color: isMe ? null : AppColors.surfaceMuted,
        borderRadius: radius,
      ),
      child: Text(
        text,
        style: AppTypography.bodyMedium.copyWith(
          color: isMe ? Colors.white : AppColors.ink900,
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: AppColors.ink500,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({
    required this.controller,
    required this.initial,
    required this.label,
  });

  final AnimationController controller;
  final String initial;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _MiniAvatar(initial: initial),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    _Dot(phase: i / 3, t: controller.value),
                    if (i < 2) const SizedBox(width: 4),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.ink500,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.phase, required this.t});

  final double phase;
  final double t;

  @override
  Widget build(BuildContext context) {
    final adjusted = (t + phase) % 1.0;
    final wave = 0.5 - 0.5 * (1 - 2 * adjusted).abs();
    final opacity = 0.3 + wave * 0.7;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.ink500.withValues(alpha: opacity.clamp(0.0, 1.0)),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BottomNotice extends StatelessWidget {
  const _BottomNotice({required this.onNotify, this.reportReady = false});

  final VoidCallback onNotify;

  /// 리포트가 준비되면 알림 버튼이 리포트 진입 버튼으로 바뀐다.
  final bool reportReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.ink100, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        12,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 12, color: AppColors.ink500),
                const SizedBox(width: 5),
                Text(
                  '이 대화는 AI끼리만 진행돼요 · 상대방은 볼 수 없어요',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNotify,
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: AppRadius.rPill,
                ),
                child: Text(
                  reportReady ? '궁합 리포트 확인하기' : '소개팅 완료 후 알림 받기',
                  style: AppTypography.label.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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
