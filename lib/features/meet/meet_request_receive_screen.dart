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
import '../../core/widgets/gradient_button.dart';

class MeetRequestReceiveScreen extends StatelessWidget {
  const MeetRequestReceiveScreen({super.key});

  static const _name = '이지은';
  static const _age = 26;
  static const _location = '서울 · 1.2km 거리';
  static const _initial = '지';
  static const _score = 88;
  static const _values = 92;
  static const _humor = 85;
  static const _comm = 88;
  static const _aiNote =
      'AI 대화에서 두 분 모두 여행과 인디 음악에 대해 깊이 있게 대화했어요. 가치관 정렬도가 매우 높습니다.';
  static const _message =
      '안녕하세요! AI가 추천해준 여행 얘기로 시작해보고 싶어요 😊';

  void _onClose(BuildContext context) {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _onAccept(BuildContext context) {
    HapticFeedback.mediumImpact();
    context.go('${AppRoutes.chat}?id=new');
  }

  Future<void> _onDecline(BuildContext context) async {
    HapticFeedback.selectionClick();
    final shouldDecline = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _DeclineConfirmDialog(),
    );
    if (shouldDecline == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정중히 거절했어요. 상대방에게는 전달되지 않습니다.')),
      );
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        children: [
          _CloseBar(onClose: () => _onClose(context)),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: const [
                _NoticeBanner(),
                AppSpacing.vXl,
                Center(child: _AvatarHero(initial: _initial)),
                AppSpacing.vMd,
                Center(
                  child: Text('$_name, $_age',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: AppColors.ink900,
                      )),
                ),
                SizedBox(height: 4),
                Center(
                  child: Text(_location,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.ink500,
                      )),
                ),
                AppSpacing.vXl,
                _ChemistryCard(
                  score: _score,
                  values: _values,
                  humor: _humor,
                  comm: _comm,
                  note: _aiNote,
                ),
                AppSpacing.vXl,
                _MessagePreview(name: _name, text: _message),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                GradientButton(
                  label: '수락하기',
                  icon: Icons.check_rounded,
                  onPressed: () => _onAccept(context),
                ),
                AppSpacing.vSm,
                _OutlineCta(
                  label: '정중히 거절',
                  onTap: () => _onDecline(context),
                ),
                const SizedBox(height: 8),
                Text(
                  '거절 사유는 상대에게 전달되지 않습니다',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseBar extends StatelessWidget {
  const _CloseBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.close_rounded,
                  size: 22, color: AppColors.ink900),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.rSm,
      ),
      child: Row(
        children: [
          const Text('💌', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '새로운 만남 신청이 도착했어요',
              style: AppTypography.label.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarHero extends StatelessWidget {
  const _AvatarHero({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              gradient: amori.softGradient,
              shape: const CircleBorder(),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChemistryCard extends StatelessWidget {
  const _ChemistryCard({
    required this.score,
    required this.values,
    required this.humor,
    required this.comm,
    required this.note,
  });

  final int score;
  final int values;
  final int humor;
  final int comm;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.rLg,
      ),
      child: Column(
        children: [
          Text(
            'AI가 측정한 우리의 케미스트리',
            style: AppTypography.caption.copyWith(
              color: AppColors.ink500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1.0,
                  letterSpacing: -2.0,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '/100',
                  style: AppTypography.label.copyWith(
                    color: AppColors.ink300,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vMd,
          Row(
            children: [
              Expanded(child: _Bar(label: '가치관', value: values)),
              AppSpacing.hMd,
              Expanded(child: _Bar(label: '유머', value: humor)),
              AppSpacing.hMd,
              Expanded(child: _Bar(label: '대화', value: comm)),
            ],
          ),
          AppSpacing.vMd,
          Text(
            note,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.ink700,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.caption
                .copyWith(color: AppColors.ink500, fontSize: 11)),
        const SizedBox(height: 2),
        Text('$value',
            style: AppTypography.label.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.ink900,
            )),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (value / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({required this.name, required this.text});
  final String name;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${name.substring(1)}님의 메시지',
          style: AppTypography.caption
              .copyWith(color: AppColors.ink500, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.ink900,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlineCta extends StatefulWidget {
  const _OutlineCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_OutlineCta> createState() => _OutlineCtaState();
}

class _OutlineCtaState extends State<_OutlineCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.rXl,
            border: Border.all(color: AppColors.ink100, width: 1.5),
          ),
          child: Text(
            widget.label,
            style: AppTypography.label.copyWith(
              color: AppColors.ink500,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeclineConfirmDialog extends StatelessWidget {
  const _DeclineConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('정중히 거절할까요?', style: AppTypography.titleLarge),
            AppSpacing.vSm,
            Text(
              '거절 사유는 상대에게 전달되지 않으며,\n다시 매칭에 노출되지 않아요.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink500,
                height: 1.5,
              ),
            ),
            AppSpacing.vLg,
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surfaceMuted,
                      foregroundColor: AppColors.ink900,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.rMd),
                    ),
                    child: Text('다시 보기',
                        style: AppTypography.label.copyWith(fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.rMd),
                    ),
                    child: Text(
                      '거절',
                      style: AppTypography.label.copyWith(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
