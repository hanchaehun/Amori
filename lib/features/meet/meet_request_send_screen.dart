import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/dummy/matches.dart';

class _StarterChip {
  const _StarterChip({
    required this.label,
    required this.message,
  });

  final String label;
  final String message;
}

class MeetRequestSendScreen extends StatefulWidget {
  const MeetRequestSendScreen({super.key, this.matchId});

  final String? matchId;

  @override
  State<MeetRequestSendScreen> createState() => _MeetRequestSendScreenState();
}

class _MeetRequestSendScreenState extends State<MeetRequestSendScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const List<_StarterChip> _starters = [
    _StarterChip(
      label: '💬 여행 얘기로 시작',
      message: '여행 얘기 좀 듣고 싶어요. 최근에 다녀오신 곳 중에 가장 좋았던 데가 어디예요?',
    ),
    _StarterChip(
      label: '🎬 영화 추천 묻기',
      message: '요즘 인상 깊게 본 영화 있으세요? 추천받고 싶어요.',
    ),
    _StarterChip(
      label: '☕ 일상 루틴 공유',
      message: '주말에는 보통 어떻게 보내세요? 비슷할 것 같은데 궁금하네요.',
    ),
  ];

  MatchProfile get _match => widget.matchId == null
      ? kMatches.first
      : findMatchById(widget.matchId!);

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applyStarter(_StarterChip chip) {
    HapticFeedback.selectionClick();
    setState(() {
      _controller.text = chip.message;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  void _send() {
    HapticFeedback.mediumImpact();
    context.go(AppRoutes.requestStatus);
  }

  String _shortName(String fullName) =>
      fullName.length <= 1 ? fullName : fullName.substring(1);

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AppScaffold(
      appBar: const BackAppBar(title: '만남 신청'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _MatchSummaryCard(match: _match),
                AppSpacing.vXl,
                _MessageLabel(name: '${_shortName(_match.name)}님'),
                AppSpacing.vSm,
                _MessageInput(
                  controller: _controller,
                  focusNode: _focusNode,
                ),
                AppSpacing.vSm,
                _StarterRow(
                  starters: _starters,
                  onTap: _applyStarter,
                ),
                AppSpacing.vXxs,
                Text(
                  '탭하면 시작 문장이 자동 입력됩니다',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontSize: 11,
                  ),
                ),
                AppSpacing.vXl,
                _InfoCard(name: '${_shortName(_match.name)}님'),
              ],
            ),
          ),
          if (!keyboardOpen) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: GradientButton(
                label: '만남 신청 보내기',
                trailing: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
                onPressed: _send,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                '오늘 신청 가능: 1 / 3건 (프리미엄)',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MatchSummaryCard extends StatelessWidget {
  const _MatchSummaryCard({required this.match});
  final MatchProfile match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Avatar(initial: '지'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.favorite_rounded,
                    size: 16, color: AppColors.primary),
              ),
              _Avatar(initial: match.initial),
            ],
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.score}점',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'AI 가상 소개팅 검증 완료',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: AppTypography.label.copyWith(
          color: AppColors.ink700,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _MessageLabel extends StatelessWidget {
  const _MessageLabel({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$name에게 보낼 메시지',
            style: AppTypography.label.copyWith(fontSize: 14),
          ),
          TextSpan(
            text: '  (선택)',
            style: AppTypography.caption.copyWith(
              color: AppColors.ink500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  const _MessageInput({required this.controller, required this.focusNode});
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.rMd,
        border: Border.all(
          color: _focused ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        minLines: 4,
        maxLines: 6,
        maxLength: 300,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.ink900,
          height: 1.5,
        ),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: 'AI 리포트가 추천한 대화 주제로 시작해보세요',
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.ink500,
            height: 1.5,
          ),
          contentPadding: const EdgeInsets.all(AppSpacing.md),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          counterText: '',
          filled: false,
        ),
      ),
    );
  }
}

class _StarterRow extends StatelessWidget {
  const _StarterRow({required this.starters, required this.onTap});

  final List<_StarterChip> starters;
  final ValueChanged<_StarterChip> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final s in starters) ...[
            _StarterChipButton(label: s.label, onTap: () => onTap(s)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StarterChipButton extends StatefulWidget {
  const _StarterChipButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_StarterChipButton> createState() => _StarterChipButtonState();
}

class _StarterChipButtonState extends State<_StarterChipButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.primary, width: 1),
          ),
          child: Text(
            widget.label,
            style: AppTypography.label.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          AppSpacing.hMd,
          Expanded(
            child: Text(
              '$name이 수락하면 실시간 채팅이 열립니다.\n거절 시 메시지는 전달되지 않습니다.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.ink700,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
