import 'package:flutter/material.dart';
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
import '../../core/widgets/page_indicator.dart';

class _WalkPage {
  const _WalkPage({
    required this.title,
    required this.body,
    required this.illustration,
  });
  final String title;
  final String body;
  final Widget illustration;
}

class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_WalkPage> _pages = [
    _WalkPage(
      title: 'AI가 먼저\n만나봅니다',
      body: '내 AI 에이전트가 다른 에이전트들과 자동 가상 소개팅을 진행해요. 앱을 닫아도 24시간 실행돼요.',
      illustration: _AgentMeetIllustration(),
    ),
    _WalkPage(
      title: '잘 맞는 인연만\n골라드려요',
      body: 'AI가 수많은 대화를 거쳐, 정말 잘 통할 사람만 리포트로 알려드립니다.',
      illustration: _MatchIllustration(),
    ),
    _WalkPage(
      title: '내가 마음을 열면\n그때 연결돼요',
      body: '리포트를 보고 만남을 신청하면 진짜 대화가 시작됩니다.',
      illustration: _ConnectIllustration(),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.push(AppRoutes.signup);
    }
  }

  void _skip() => context.push(AppRoutes.signup);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: BackAppBar(
        showBack: true,
        title: null,
        trailing: TextButton(
          onPressed: _skip,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.ink500,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Text(
            '건너뛰기',
            style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
          ),
        ),
      ),
      body: Column(
        children: [
          AppSpacing.vXs,
          PageIndicator(count: _pages.length, index: _index),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final p = _pages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSpacing.vLg,
                      Expanded(
                        child: Center(child: p.illustration),
                      ),
                      AppSpacing.vXl,
                      Text(p.title, style: AppTypography.displayMedium),
                      AppSpacing.vMd,
                      Text(
                        p.body,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.ink500,
                          height: 1.55,
                        ),
                      ),
                      AppSpacing.vXl,
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: GradientButton(
              label: _index == _pages.length - 1 ? '시작하기' : '다음',
              trailing: const GradientArrowTrailing(),
              onPressed: _next,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentMeetIllustration extends StatelessWidget {
  const _AgentMeetIllustration();

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return SizedBox(
      width: double.infinity,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 20,
            left: 30,
            child: _blurOrb(amori.primaryGradient, 160, 0.45),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: _blurOrb(amori.primaryGradient, 200, 0.35),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _agentPhone(amori, leaning: -0.06),
              const SizedBox(width: 24),
              _agentPhone(amori, leaning: 0.06),
            ],
          ),
          Positioned(
            top: 80,
            child: Container(
              width: 44,
              height: 44,
              decoration: ShapeDecoration(
                gradient: amori.primaryGradient,
                shape: const CircleBorder(),
                shadows: amori.glowShadow,
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurOrb(LinearGradient g, double size, double op) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g.colors.map((c) => c.withValues(alpha: op)).toList(),
        ),
      ),
    );
  }

  Widget _agentPhone(AmoriThemeExt amori, {required double leaning}) {
    return Transform.rotate(
      angle: leaning,
      child: Container(
        width: 110,
        height: 180,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
          shadows: amori.cardShadow,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 8,
              decoration: BoxDecoration(
                gradient: amori.primaryGradient,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 70,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.ink100,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 50,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.ink100,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 48,
                height: 22,
                decoration: BoxDecoration(
                  gradient: amori.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchIllustration extends StatelessWidget {
  const _MatchIllustration();

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return SizedBox(
      width: double.infinity,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: amori.primaryGradient.colors
                    .map((c) => c.withValues(alpha: 0.18))
                    .toList(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: ShapeDecoration(
              gradient: amori.primaryGradient,
              shape: const CircleBorder(),
              shadows: amori.glowShadow,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }
}

class _ConnectIllustration extends StatelessWidget {
  const _ConnectIllustration();

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return SizedBox(
      width: double.infinity,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240,
            height: 160,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXxl),
              shadows: amori.cardShadow,
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: amori.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                    ),
                    AppSpacing.hSm,
                    Container(
                      width: 80,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.ink100,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
                AppSpacing.vMd,
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.ink100,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                AppSpacing.vXs,
                Container(
                  height: 12,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.ink100,
                    borderRadius: BorderRadius.circular(99),
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
