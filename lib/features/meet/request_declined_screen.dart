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
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/gradient_button.dart';

class RequestDeclinedScreen extends StatelessWidget {
  const RequestDeclinedScreen({super.key, this.targetName = '상대'});

  final String targetName;

  void _onClose(BuildContext context) {
    HapticFeedback.selectionClick();
    context.go(AppRoutes.home);
  }

  void _onShowMatches(BuildContext context) {
    HapticFeedback.lightImpact();
    context.go(AppRoutes.matchList);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: BackAppBar(
        title: '신청 결과',
        onBack: () => _onClose(context),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                const Center(child: _BrokenHeartIcon()),
                AppSpacing.vMd,
                Center(
                  child: Text(
                    '이번 인연은\n닿지 않았어요',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLarge.copyWith(
                      fontSize: 22,
                      height: 1.4,
                    ),
                  ),
                ),
                AppSpacing.vSm,
                Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(
                      '$targetName님이 이번 만남을 정중히 거절하셨어요.\n거절 사유는 양쪽 모두에게 비공개입니다.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.ink500,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                AppSpacing.vXl,
                const _AiCommentCard(),
                AppSpacing.vMd,
                const _StatsRow(),
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
                  label: '새로운 매칭 보러가기',
                  trailing: const GradientArrowTrailing(),
                  onPressed: () => _onShowMatches(context),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _onClose(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.ink500,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: Text(
                    '홈으로 돌아가기',
                    style: AppTypography.label.copyWith(
                      color: AppColors.ink500,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
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

class _BrokenHeartIcon extends StatelessWidget {
  const _BrokenHeartIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.heart_broken_outlined,
        size: 40,
        color: AppColors.ink500,
      ),
    );
  }
}

class _AiCommentCard extends StatelessWidget {
  const _AiCommentCard();

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  gradient: amori.primaryGradient,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                'AI 코멘트',
                style: AppTypography.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.ink900,
                height: 1.6,
                fontSize: 13,
              ),
              children: const [
                TextSpan(text: '거절은 인연이 아니라는 신호일 뿐, 매력의 부족이 아니에요. '),
                TextSpan(text: '오늘 새로 도착한 '),
                TextSpan(
                  text: '4명',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(text: '의 검증된 매칭이 기다리고 있어요.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  static const _items = [
    ('4', '오늘 새 매칭'),
    ('92%', '평균 수락률'),
    ('7일', '평균 매칭 주기'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          Expanded(child: _StatCard(value: _items[i].$1, label: _items[i].$2)),
          if (i < _items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rSm,
        border: Border.all(color: AppColors.ink100, width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.ink500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
