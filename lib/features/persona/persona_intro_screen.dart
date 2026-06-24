import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/outline_button.dart';
import '../../core/widgets/soft_card.dart';

class PersonaIntroScreen extends StatefulWidget {
  const PersonaIntroScreen({super.key});

  @override
  State<PersonaIntroScreen> createState() => _PersonaIntroScreenState();
}

class _PersonaIntroScreenState extends State<PersonaIntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.scenarioPlayer);
  }

  void _connectExternal() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('S05-Import · 외부 데이터 연동 — 다음 턴 작업 예정')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const BackAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSpacing.vXs,
                  _HeroIllustrationCard(controller: _pulse),
                  AppSpacing.vLg,
                  Text(
                    '내 AI 에이전트를\n만들어볼까요?',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleXl,
                  ),
                  AppSpacing.vSm,
                  Text(
                    '대표 질문 5개로 AI 에이전트 초안을 만들고\n'
                    '매일 1문항으로 더 정교하게 업데이트합니다.\n'
                    '약 2분 소요',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink500,
                      height: 1.55,
                    ),
                  ),
                  AppSpacing.vXl,
                  const _LearningCategoryRow(
                    emoji: '💬',
                    title: '대화 스타일',
                    sub: '당신만의 소통 방식을 반영',
                  ),
                  AppSpacing.vSm,
                  const _LearningCategoryRow(
                    emoji: '❤️',
                    title: '관계 가치관',
                    sub: '중요하게 여기는 것들을 파악',
                  ),
                  AppSpacing.vSm,
                  const _LearningCategoryRow(
                    emoji: '😄',
                    title: '유머 코드',
                    sub: '웃음 포인트와 분위기를 분석',
                  ),
                  AppSpacing.vMd,
                ],
              ),
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
                  label: '시작하기',
                  trailing: const GradientArrowTrailing(),
                  onPressed: _start,
                ),
                AppSpacing.vSm,
                OutlineCtaButton(
                  label: 'Spotify · Strava · Instagram 연동하기',
                  onPressed: _connectExternal,
                ),
                AppSpacing.vSm,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: AppColors.ink500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '답변 데이터는 암호화되어 안전하게 보관됩니다',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
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

class _HeroIllustrationCard extends StatelessWidget {
  const _HeroIllustrationCard({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      useLowShadow: true,
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.coralHalo),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _MiniPhoneCard(),
                  const SizedBox(width: 18),
                  _CoralOrb(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPhoneCard extends StatelessWidget {
  const _MiniPhoneCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink100,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppGradients.coral,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '안녕!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '...',
              style: TextStyle(color: AppColors.ink700, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoralOrb extends StatelessWidget {
  const _CoralOrb({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, _) {
          final t = Curves.easeInOut.transform(controller.value);
          final scale = 1.0 + t * 0.06;
          final glow = 0.35 + t * 0.25;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppGradients.coral,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7AA2).withValues(alpha: glow),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LearningCategoryRow extends StatelessWidget {
  const _LearningCategoryRow({
    required this.emoji,
    required this.title,
    required this.sub,
  });

  final String emoji;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: AppTypography.label.copyWith(fontSize: 15)),
                AppSpacing.vXxs,
                Text(
                  sub,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.ink500,
                    fontSize: 12,
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
