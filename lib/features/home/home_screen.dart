import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_tab_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/gradient_text.dart';

enum _StageState { done, active, locked }

class _StageItem {
  const _StageItem(this.icon, this.label, this.state);
  final IconData icon;
  final String label;
  final _StageState state;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bottomBar: const AmoriTabBar(active: AmoriTab.home),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _TopBar()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _Greeting(name: '지은'),
                AppSpacing.vLg,
                _HeroAICard(
                  onTap: () => context.push(AppRoutes.agentChat),
                ),
                AppSpacing.vXl,
                const _StatusTracker(stages: [
                  _StageItem(
                      Icons.check_rounded, '페르소나 생성', _StageState.done),
                  _StageItem(
                      Icons.sync_rounded, 'Pre-Dating', _StageState.active),
                  _StageItem(Icons.description_outlined, '리포트 발행',
                      _StageState.locked),
                  _StageItem(Icons.favorite_outline_rounded, '만남 연결',
                      _StageState.locked),
                ]),
                AppSpacing.vXl,
                _ReportSection(
                  onHeaderTap: () => context.push(AppRoutes.matchList),
                  onCardTap: () => context.push(AppRoutes.lockedReport),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: 56,
        child: Align(
          alignment: Alignment.centerLeft,
          child: GradientText(
            'amori',
            style: AppTypography.titleLarge.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '안녕하세요, $name님 👋',
          style: AppTypography.titleXl.copyWith(fontSize: 24),
        ),
        AppSpacing.vXxs,
        Text(
          '오늘도 AI가 열심히 일하고 있어요',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.ink500),
        ),
      ],
    );
  }
}

class _HeroAICard extends StatefulWidget {
  const _HeroAICard({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_HeroAICard> createState() => _HeroAICardState();
}

class _HeroAICardState extends State<_HeroAICard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return AnimatedScale(
      scale: _pressed ? 0.99 : 1.0,
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.rXl,
            boxShadow: amori.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LiveBadge(),
              AppSpacing.vMd,
              Text(
                '소개팅 시뮬레이션\n진행 중',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.ink900,
                  fontSize: 22,
                  height: 1.3,
                ),
              ),
              AppSpacing.vXs,
              Text(
                '오늘 오전 2시에 완료 예정',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.ink500),
              ),
              AppSpacing.vMd,
              const _HeroProgress(value: 0.65),
              AppSpacing.vXs,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '자세히 보기',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.ink500,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
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
          const SizedBox(width: 6),
          Text(
            'AI 활동 중',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroProgress extends StatelessWidget {
  const _HeroProgress({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusTracker extends StatelessWidget {
  const _StatusTracker({required this.stages});
  final List<_StageItem> stages;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stages.length; i++) ...[
            _StageColumn(stage: stages[i]),
            if (i < stages.length - 1)
              Expanded(
                child: _Connector(
                  filled: stages[i].state == _StageState.done &&
                      stages[i + 1].state != _StageState.locked,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({required this.stage});
  final _StageItem stage;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    final isLocked = stage.state == _StageState.locked;
    final isActive = stage.state == _StageState.active;

    Color labelColor;
    FontWeight labelWeight;
    if (isActive) {
      labelColor = AppColors.primary;
      labelWeight = FontWeight.w800;
    } else if (isLocked) {
      labelColor = AppColors.ink300;
      labelWeight = FontWeight.w500;
    } else {
      labelColor = AppColors.ink900;
      labelWeight = FontWeight.w800;
    }

    return SizedBox(
      width: 56,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isLocked ? null : amori.primaryGradient,
              color: isLocked ? Colors.white : null,
              border: isLocked
                  ? Border.all(color: AppColors.ink100, width: 1.5)
                  : null,
              boxShadow: isActive ? amori.glowShadow : const [],
            ),
            child: Icon(
              stage.icon,
              size: 18,
              color: isLocked ? AppColors.ink300 : Colors.white,
            ),
          ),
          AppSpacing.vXs,
          Text(
            stage.label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: labelColor,
              fontWeight: labelWeight,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 17),
      child: filled
          ? Container(height: 2, color: AppColors.primary)
          : CustomPaint(
              size: const Size(double.infinity, 2),
              painter: _DashedLinePainter(),
            ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink100
      ..strokeWidth = 1.5;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1), Offset(x + dashWidth, 1), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.onHeaderTap,
    required this.onCardTap,
  });

  final VoidCallback onHeaderTap;
  final VoidCallback onCardTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onHeaderTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  '리포트 준비 중',
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.ink500, size: 22),
              ],
            ),
          ),
        ),
        AppSpacing.vSm,
        _LockedMatchCard(onTap: onCardTap),
      ],
    );
  }
}

class _LockedMatchCard extends StatefulWidget {
  const _LockedMatchCard({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_LockedMatchCard> createState() => _LockedMatchCardState();
}

class _LockedMatchCardState extends State<_LockedMatchCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.99 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.rMd,
            border: Border.all(color: AppColors.ink100, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '민',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.ink700,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '서민준',
                      style: AppTypography.titleMedium.copyWith(fontSize: 15),
                    ),
                    AppSpacing.vXxs,
                    Text(
                      '케미스트리 점수 확인 대기 중',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.lock_rounded,
                  color: AppColors.ink300, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
