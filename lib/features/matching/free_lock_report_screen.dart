import 'dart:ui';

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
import '../../core/widgets/outline_button.dart';

class FreeLockReportScreen extends StatelessWidget {
  const FreeLockReportScreen({super.key});

  void _onUnlock(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.paywall);
  }

  void _onSubscribe(BuildContext context) {
    HapticFeedback.selectionClick();
    context.push(AppRoutes.paywall);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const BackAppBar(title: '케미스트리 리포트'),
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
              children: const [
                Center(child: _AvatarPair()),
                AppSpacing.vMd,
                Center(child: _BlurredScore()),
                SizedBox(height: 6),
                Center(
                  child: Text(
                    '케미스트리 점수',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.ink500,
                    ),
                  ),
                ),
                AppSpacing.vXl,
                _LockedNotice(),
                AppSpacing.vLg,
                _UnlockBenefits(),
                AppSpacing.vLg,
                _MoreMatchesNote(),
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
                  label: '1회 열람하기 · ₩1,000',
                  icon: Icons.lock_open_rounded,
                  onPressed: () => _onUnlock(context),
                ),
                AppSpacing.vSm,
                OutlineCtaButton(
                  label: '프리미엄 구독으로 무제한 열람',
                  onPressed: () => _onSubscribe(context),
                ),
                const SizedBox(height: 8),
                Text(
                  '첫 7일 무료 체험',
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

class _AvatarPair extends StatelessWidget {
  const _AvatarPair();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _Avatar(initial: '지'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Icon(Icons.favorite_rounded,
              color: AppColors.primary, size: 26),
        ),
        _Avatar(initial: '민'),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: AppTypography.titleLarge.copyWith(
          color: AppColors.ink700,
          fontWeight: FontWeight.w900,
          fontSize: 24,
        ),
      ),
    );
  }
}

class _BlurredScore extends StatelessWidget {
  const _BlurredScore();

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return SizedBox(
      width: 140,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: amori.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}

class _LockedNotice extends StatelessWidget {
  const _LockedNotice();

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
          const Icon(Icons.lock_rounded, size: 28, color: AppColors.ink700),
          AppSpacing.vSm,
          Text(
            '이 리포트는 잠겨있어요',
            style: AppTypography.titleMedium.copyWith(fontSize: 17),
          ),
          AppSpacing.vSm,
          Text(
            'AI가 검증한 매칭이지만,\n점수와 상세 내용은 결제 후 확인할 수 있어요.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.ink500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockBenefits extends StatelessWidget {
  const _UnlockBenefits();

  static const _benefits = [
    '정확한 케미스트리 점수',
    '가치관 · 유머 · 대화 패턴 세부 분석',
    'AI 가상 소개팅 대화 로그 요약',
    '첫 만남 추천 가이드 (장소 · 주제)',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('잠금 해제 시 받게 되는 정보',
            style: AppTypography.titleMedium.copyWith(fontSize: 14)),
        AppSpacing.vSm,
        for (final text in _benefits) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MoreMatchesNote extends StatelessWidget {
  const _MoreMatchesNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: AppRadius.rSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '오늘 검증된 매칭 4명이 더 있어요. 무제한 열람은 프리미엄에서.',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
