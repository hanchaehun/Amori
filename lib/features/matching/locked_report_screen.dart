import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/dummy/matches.dart';

class LockedReportScreen extends StatelessWidget {
  const LockedReportScreen({super.key, this.matchId});

  final String? matchId;

  void _onClose(BuildContext context) {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.matchList);
    }
  }

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
    final match = matchId == null ? kMatches.first : findMatchById(matchId!);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.coral,
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.coral),
          child: SafeArea(
            child: Column(
              children: [
                _Header(onClose: () => _onClose(context)),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    children: [
                      _Hero(
                        myInitial: '지',
                        themInitial: match.initial,
                        score: match.score,
                      ),
                      AppSpacing.vXl,
                      _ScoreBar(label: '가치관 일치', value: match.values),
                      AppSpacing.vMd,
                      _ScoreBar(label: '유머 코드', value: match.humor),
                      AppSpacing.vMd,
                      _ScoreBar(label: '대화 패턴', value: match.communication),
                      AppSpacing.vXl,
                      const _SectionLabel(text: '추천 대화 주제'),
                      AppSpacing.vSm,
                      _TopicChips(topics: match.recommendedTopics),
                      AppSpacing.vXl,
                      const _SectionLabel(
                          text: '더 자세한 인사이트', trailingLock: true),
                      AppSpacing.vSm,
                      const _LockedInsightCard(
                          title: 'AI 대화 로그 요약', lines: 3),
                      AppSpacing.vSm,
                      const _LockedInsightCard(
                          title: '첫 만남 추천 가이드', lines: 2),
                      AppSpacing.vXl,
                    ],
                  ),
                ),
                _BottomCta(
                  onUnlock: () => _onUnlock(context),
                  onSubscribe: () => _onSubscribe(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
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
                  color: Colors.white, size: 22),
              onPressed: onClose,
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded,
                      size: 14, color: AppColors.coral),
                  const SizedBox(width: 4),
                  Text(
                    '리포트 완성',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.coral,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.myInitial,
    required this.themInitial,
    required this.score,
  });

  final String myInitial;
  final String themInitial;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AvatarRing(initial: myInitial),
            const SizedBox(width: 16),
            const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 28),
            const SizedBox(width: 16),
            _AvatarRing(initial: themInitial),
          ],
        ),
        AppSpacing.vMd,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$score',
              style: const TextStyle(
                fontSize: 88,
                height: 1.0,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -3,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '/100',
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        AppSpacing.vXs,
        Text(
          '케미스트리 점수',
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              '$value',
              style: AppTypography.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (value / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.trailingLock = false});
  final String text;
  final bool trailingLock;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: AppTypography.titleMedium.copyWith(
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        if (trailingLock) ...[
          const Spacer(),
          Icon(Icons.lock_outline_rounded,
              size: 16, color: Colors.white.withValues(alpha: 0.85)),
        ],
      ],
    );
  }
}

class _TopicChips extends StatelessWidget {
  const _TopicChips({required this.topics});
  final List<String> topics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in topics)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              t,
              style: AppTypography.label.copyWith(
                color: AppColors.coral,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

class _LockedInsightCard extends StatelessWidget {
  const _LockedInsightCard({required this.title, required this.lines});

  final String title;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.rMd,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: AppRadius.rMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.label.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < lines; i++)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                          child: Container(
                            height: 8,
                            width: i.isEven ? double.infinity : 200,
                            decoration: BoxDecoration(
                              color: AppColors.ink100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: AppRadius.rMd,
              ),
              child: const Icon(Icons.lock_rounded,
                  size: 22, color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCta extends StatefulWidget {
  const _BottomCta({required this.onUnlock, required this.onSubscribe});

  final VoidCallback onUnlock;
  final VoidCallback onSubscribe;

  @override
  State<_BottomCta> createState() => _BottomCtaState();
}

class _BottomCtaState extends State<_BottomCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          AnimatedScale(
            scale: _pressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onUnlock,
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.rMd,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 18, color: AppColors.coral),
                    const SizedBox(width: 8),
                    Text(
                      '전체 리포트 열람하기',
                      style: AppTypography.button.copyWith(
                        color: AppColors.coral,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 14,
                      color: AppColors.coral.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₩1,000',
                      style: AppTypography.button.copyWith(
                        color: AppColors.coral,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSubscribe,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '또는 프리미엄 구독으로 무제한 열람',
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
