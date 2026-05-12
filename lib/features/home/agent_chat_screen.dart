import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';

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

const _meName = '지은-AI';
const _meInitial = '지';
const _themName = '민준-AI';
const _themInitial = '민';

const List<_ChatMessage> _messages = [
  _ChatMessage(
    sender: _Sender.me,
    name: _meName,
    avatarInitial: _meInitial,
    text: '안녕하세요! 주말에는 보통 어떻게 보내세요?',
    signal: '여행 시그널',
  ),
  _ChatMessage(
    sender: _Sender.them,
    name: _themName,
    avatarInitial: _themInitial,
    text: '저는 주로 성수나 연남 카페에서 책 읽거나, 여행 준비해요. 최근엔 후쿠오카 다녀왔어요 ✈️',
    signal: '여행+카페 매치',
  ),
  _ChatMessage(
    sender: _Sender.me,
    name: _meName,
    avatarInitial: _meInitial,
    text: '와 저도 이번에 오사카 다녀왔는데! 음악도 좋아하시나요?',
    signal: '취향 일치',
  ),
  _ChatMessage(
    sender: _Sender.them,
    name: _themName,
    avatarInitial: _themInitial,
    text: '잔잔한 인디 위주로 들어요. 새소년이나 잠비나이 같은.',
    signal: '음악 취향 +18%',
  ),
  _ChatMessage(
    sender: _Sender.system,
    text: '🔍 가치관 분석: 둘 다 "느린 일상 · 진심" 키워드 상위',
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
    name: _themName,
    avatarInitial: _themInitial,
    text: '서로의 일상을 존중하면서도, 함께 있을 때 편안한 거요.',
    signal: '가치관 매치',
  ),
];

class AgentChatScreen extends StatefulWidget {
  const AgentChatScreen({super.key});

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _typing;

  @override
  void initState() {
    super.initState();
    _typing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  void _showMoreMenu() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('시뮬레이션 옵션 (일시정지 · 종료) — 다음 턴 작업 예정')),
    );
  }

  void _onNotifyMe() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('시뮬레이션 완료 시 알림으로 알려드릴게요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: _ChatTopBar(onMore: _showMoreMenu),
      bottomBar: _BottomNotice(onNotify: _onNotifyMe),
      body: Column(
        children: [
          const _ChemistryBanner(score: 88),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                const _StartMarker(time: '14:32'),
                AppSpacing.vSm,
                for (var i = 0; i < _messages.length; i++) ...[
                  _MessageRow(message: _messages[i]),
                  AppSpacing.vSm,
                ],
                _TypingIndicator(controller: _typing),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatTopBar({required this.onMore});

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
                      '$_meName ↔ $_themName',
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
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '실시간 시뮬레이션 · 메시지 7/24',
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

  final int score;

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
                  '예상 케미스트리',
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
                        text: '$score',
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.6,
                        ),
                      ),
                      TextSpan(
                        text: ' /100 (계산 중)',
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
  const _StartMarker({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '── 시뮬레이션 시작 · $time ──',
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
  const _TypingIndicator({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const _MiniAvatar(initial: _themInitial),
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
          '$_themName 응답 생성 중...',
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
  const _BottomNotice({required this.onNotify});
  final VoidCallback onNotify;

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
                  '시뮬레이션 완료 후 알림 받기',
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
