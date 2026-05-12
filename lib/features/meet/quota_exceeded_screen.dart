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

class QuotaExceededScreen extends StatelessWidget {
  const QuotaExceededScreen({super.key});

  void _onClose(BuildContext context) {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _onUpgrade(BuildContext context) {
    HapticFeedback.lightImpact();
    context.go(AppRoutes.paywall);
  }

  void _onTryTomorrow(BuildContext context) => _onClose(context);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.rXl,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 48,
                    offset: const Offset(0, 16),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _HourglassIcon(),
                  AppSpacing.vMd,
                  Text(
                    '오늘의 신청 횟수를\n모두 사용했어요',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLarge.copyWith(
                      fontSize: 19,
                      height: 1.4,
                    ),
                  ),
                  AppSpacing.vSm,
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.ink500,
                        height: 1.6,
                        fontSize: 13,
                      ),
                      children: const [
                        TextSpan(text: '신중한 만남을 위해 일일 신청은\n'),
                        TextSpan(
                          text: '1건으로 제한',
                          style: TextStyle(
                            color: AppColors.ink900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: '되어 있어요.'),
                      ],
                    ),
                  ),
                  AppSpacing.vMd,
                  const _QuotaUsageCard(),
                  AppSpacing.vMd,
                  const _PremiumUpsell(),
                  AppSpacing.vMd,
                  _DarkCta(
                    label: '프리미엄으로 업그레이드 · 7일 무료',
                    onTap: () => _onUpgrade(context),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _onTryTomorrow(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.ink500,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    child: Text(
                      '내일 다시 시도하기',
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink500,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HourglassIcon extends StatelessWidget {
  const _HourglassIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.30),
          ],
        ),
      ),
      child: const Text('⏳', style: TextStyle(fontSize: 32)),
    );
  }
}

class _QuotaUsageCard extends StatelessWidget {
  const _QuotaUsageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.rSm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '오늘의 신청',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '1 / 1 사용',
                style: AppTypography.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontSize: 11,
              ),
              children: const [
                TextSpan(text: '🕐  다음 신청은 '),
                TextSpan(
                  text: '내일 오전 9:00',
                  style: TextStyle(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: '부터'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumUpsell extends StatelessWidget {
  const _PremiumUpsell();

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: ShapeDecoration(
        gradient: amori.primaryGradient,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                'PREMIUM',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '하루 3건까지 신청하기',
            style: AppTypography.titleMedium.copyWith(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '무제한 리포트 + 우선 매칭 + AI 코치 무제한',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkCta extends StatefulWidget {
  const _DarkCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_DarkCta> createState() => _DarkCtaState();
}

class _DarkCtaState extends State<_DarkCta> {
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
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: Container(
          width: double.infinity,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.ink900,
            borderRadius: AppRadius.rSm,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: AppTypography.label.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
