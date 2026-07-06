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

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, this.matchId});

  final String? matchId;

  void _onClose(BuildContext context) {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.matchList);
    }
  }

  void _onSelectPerUse(BuildContext context) {
    HapticFeedback.lightImpact();
    context.go('${AppRoutes.fullReport}?id=${matchId ?? ''}');
  }

  void _onSubscribe(BuildContext context) {
    HapticFeedback.mediumImpact();
    context.go('${AppRoutes.fullReport}?id=${matchId ?? ''}');
  }

  void _onLegal(BuildContext context, String label) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label — 외부 페이지 (다음 턴 작업 예정)')));
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
                AppSpacing.md,
              ),
              children: [
                const _Hero(),
                AppSpacing.vXl,
                _PerUseCard(onSelect: () => _onSelectPerUse(context)),
                AppSpacing.vMd,
                _PremiumCard(onSubscribe: () => _onSubscribe(context)),
              ],
            ),
          ),
          _LegalFooter(
            onTerms: () => _onLegal(context, '이용약관'),
            onRefund: () => _onLegal(context, '환불 정책'),
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
              icon: const Icon(
                Icons.close_rounded,
                size: 22,
                color: AppColors.ink900,
              ),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: ShapeDecoration(
            gradient: amori.primaryGradient,
            shape: const CircleBorder(),
            shadows: amori.glowShadow,
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
        AppSpacing.vLg,
        Text(
          '진짜 인연을 확인해보세요',
          textAlign: TextAlign.center,
          style: AppTypography.titleXl.copyWith(fontSize: 26),
        ),
        AppSpacing.vSm,
        Text(
          'AI가 검증한 케미스트리,\n이제 직접 확인할 차례입니다',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.ink500,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _PerUseCard extends StatelessWidget {
  const _PerUseCard({required this.onSelect});
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.ink100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '리포트 1회 열람',
            style: AppTypography.titleMedium.copyWith(fontSize: 17),
          ),
          AppSpacing.vXs,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₩1,000',
                style: AppTypography.titleXl.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink900,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '1회',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vMd,
          const _BulletRow(text: '선택한 1명의 리포트만 열람'),
          AppSpacing.vMd,
          _OutlineCta(label: '선택', onTap: onSelect),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.onSubscribe});
  final VoidCallback onSubscribe;

  static const List<String> _features = [
    '무제한 리포트 열람',
    '우선 매칭 (3배 빠른 매칭)',
    '페르소나 심화 학습',
    '광고 제거',
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.rLg,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'amori 프리미엄',
                style: AppTypography.titleMedium.copyWith(fontSize: 17),
              ),
              AppSpacing.vXs,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₩9,900',
                    style: AppTypography.titleXl.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '/ 월',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '첫 7일 무료',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              AppSpacing.vMd,
              for (final f in _features) ...[
                _BulletRow(text: f),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 6),
              _GradientCta(label: '구독 시작하기', onTap: onSubscribe),
            ],
          ),
        ),
        Positioned(
          top: -12,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '추천',
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
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
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.rSm,
            border: Border.all(color: AppColors.ink900, width: 1.5),
          ),
          child: Text(
            widget.label,
            style: AppTypography.label.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientCta extends StatefulWidget {
  const _GradientCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_GradientCta> createState() => _GradientCtaState();
}

class _GradientCtaState extends State<_GradientCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
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
          height: 48,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            gradient: amori.primaryGradient,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.rSm),
            shadows: _pressed ? const [] : amori.glowShadow,
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

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.onTerms, required this.onRefund});
  final VoidCallback onTerms;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          Text(
            '언제든 해지 가능 · 자동 결제 사전 알림',
            style: AppTypography.caption.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTerms,
                child: Text(
                  '이용약관',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text(
                '  ·  ',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink300,
                  fontSize: 11,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRefund,
                child: Text(
                  '환불 정책',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
