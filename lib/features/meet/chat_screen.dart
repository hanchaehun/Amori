import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/dummy/conversations.dart';

class _ChatMsg {
  _ChatMsg({
    required this.isMe,
    required this.text,
    required this.time,
    this.read = false,
  });

  final bool isMe;
  final String text;
  final String time;
  final bool read;
}

class _Starter {
  const _Starter({required this.label, required this.message});
  final String label;
  final String message;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.conversationId});

  final String? conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _typing;

  static const _starters = [
    _Starter(
      label: '💬 여행 얘기',
      message: '최근에 다녀온 여행지 중에 가장 좋았던 데가 어디예요?',
    ),
    _Starter(
      label: '🎬 영화 추천',
      message: '요즘 인상 깊게 본 영화 있으세요?',
    ),
    _Starter(
      label: '☕ 일상 루틴',
      message: '주말에는 보통 어떻게 보내세요?',
    ),
  ];

  late List<_ChatMsg> _messages;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _typing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _messages = [
      _ChatMsg(
        isMe: false,
        text: '안녕하세요 지은님! 비슷한 음악 취향이신 것 같아요 🎵',
        time: '오후 3:20',
      ),
      _ChatMsg(
        isMe: true,
        text: '맞아요! 요즘 잔잔한 인디 자주 듣고 있어요',
        time: '오후 3:22',
        read: true,
      ),
      _ChatMsg(
        isMe: false,
        text: '혹시 이번 주말에 시간 괜찮으시면, 성수에 좋은 카페 알아요. 같이 가볼래요?',
        time: '오후 3:24',
      ),
    ];
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _typing.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Conversation get _peer {
    if (widget.conversationId == null || widget.conversationId == 'new') {
      return kActiveConversations.first;
    }
    return kActiveConversations.firstWhere(
      (c) => c.id == widget.conversationId,
      orElse: () => kActiveConversations.first,
    );
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

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(
        _ChatMsg(isMe: true, text: text, time: '방금', read: false),
      );
      _controller.clear();
    });
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

  void _onCamera() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('사진 첨부 — 다음 턴 작업 예정')),
    );
  }

  void _onMore() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('대화 옵션 (차단·신고 등) — 다음 턴 작업 예정')),
    );
  }

  void _onScheduleMeet() {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.scheduling);
  }

  @override
  Widget build(BuildContext context) {
    final peer = _peer;
    return AppScaffold(
      appBar: _ChatAppBar(peer: peer, onMore: _onMore),
      body: Column(
        children: [
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
                const _DateDivider(label: '오늘'),
                AppSpacing.vSm,
                for (final m in _messages) ...[
                  _MessageBubble(msg: m),
                  AppSpacing.vSm,
                ],
                _TypingIndicator(controller: _typing, peerName: peer.name),
              ],
            ),
          ),
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            hasText: _hasText,
            onSend: _send,
            onCamera: _onCamera,
            onScheduleMeet: _onScheduleMeet,
          ),
        ],
      ),
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({required this.peer, required this.onMore});
  final Conversation peer;
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
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: AppColors.ink900),
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
                          peer.initial,
                          style: AppTypography.label.copyWith(
                            color: AppColors.ink700,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        peer.name,
                        style: AppTypography.titleMedium
                            .copyWith(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${peer.score}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: const Icon(Icons.more_horiz_rounded,
                      size: 24, color: AppColors.ink900),
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

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '─── $label ───',
        style: AppTypography.caption.copyWith(
          color: AppColors.ink300,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg});
  final _ChatMsg msg;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    final isMe = msg.isMe;
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
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: isMe ? amori.primaryGradient : null,
                color: isMe ? null : AppColors.surfaceMuted,
                borderRadius: radius,
              ),
              child: Text(
                msg.text,
                style: AppTypography.bodyMedium.copyWith(
                  color: isMe ? Colors.white : AppColors.ink900,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isMe && msg.read ? '${msg.time} · 읽음' : msg.time,
            style: AppTypography.caption.copyWith(
              color: AppColors.ink300,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.controller, required this.peerName});
  final AnimationController controller;
  final String peerName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  _Dot(phase: i / 3, t: controller.value),
                  if (i < 2) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$peerName님이 입력 중...',
          style: AppTypography.caption.copyWith(
            color: AppColors.ink500,
            fontSize: 11,
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

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onSend,
    required this.onCamera,
    required this.onScheduleMeet,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  final VoidCallback onScheduleMeet;

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
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.camera_alt_rounded,
                  size: 22, color: AppColors.ink500),
              onPressed: onCamera,
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
              onTap: onScheduleMeet,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '약속',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: hasText ? onSend : null,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
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
          ],
        ),
      ),
    );
  }
}
