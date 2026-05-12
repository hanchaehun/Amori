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

class RequestTimeoutScreen extends StatelessWidget {
  const RequestTimeoutScreen({
    super.key,
    this.targetName = '서민준',
    this.targetInitial = '민',
    this.targetAge = 28,
    this.requestDate = '5/3',
    this.expiryDate = '5/4',
  });

  final String targetName;
  final String targetInitial;
  final int targetAge;
  final String requestDate;
  final String expiryDate;

  void _onBack(BuildContext context) {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _onShowMatches(BuildContext context) {
    HapticFeedback.lightImpact();
    context.go(AppRoutes.matchList);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: BackAppBar(
        title: '신청 만료',
        onBack: () => _onBack(context),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                const Center(child: _ExpiredHourglass()),
                AppSpacing.vMd,
                Center(
                  child: Text(
                    '응답 시간이 지났어요',
                    style: AppTypography.titleLarge.copyWith(
                      fontSize: 22,
                      height: 1.4,
                    ),
                  ),
                ),
                AppSpacing.vSm,
                Center(
                  child: Text(
                    '24시간 동안 응답이 없어\n신청이 자동으로 만료되었습니다.\n상대가 바빴거나, 인연이 닿지 않은 것일 수 있어요.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink500,
                      height: 1.6,
                    ),
                  ),
                ),
                AppSpacing.vXl,
                _ExpiredMatchCard(
                  initial: targetInitial,
                  name: targetName,
                  age: targetAge,
                  requestDate: requestDate,
                  expiryDate: expiryDate,
                ),
                AppSpacing.vMd,
                const _TipCard(),
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
            child: GradientButton(
              label: '다른 매칭 둘러보기',
              trailing: const GradientArrowTrailing(),
              onPressed: () => _onShowMatches(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiredHourglass extends StatelessWidget {
  const _ExpiredHourglass();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.4, 0.4, 0.4, 0, 0,
          0.4, 0.4, 0.4, 0, 0,
          0.4, 0.4, 0.4, 0, 0,
          0, 0, 0, 0.6, 0,
        ]),
        child: const Text('⌛', style: TextStyle(fontSize: 40)),
      ),
    );
  }
}

class _ExpiredMatchCard extends StatelessWidget {
  const _ExpiredMatchCard({
    required this.initial,
    required this.name,
    required this.age,
    required this.requestDate,
    required this.expiryDate,
  });

  final String initial;
  final String name;
  final int age;
  final String requestDate;
  final String expiryDate;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.75,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: AppColors.ink100, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.ink500,
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
                    '$name · $age',
                    style: AppTypography.titleMedium.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '신청일 $requestDate · 만료 $expiryDate',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.ink100,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '만료됨',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          AppSpacing.hSm,
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.ink900,
                  height: 1.6,
                  fontSize: 12,
                ),
                children: const [
                  TextSpan(
                    text: 'Tip. ',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text:
                        'AI 분석에 따르면 신청 메시지를 30자 이상 작성하면 응답률이 ',
                  ),
                  TextSpan(
                    text: '2.4배',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(text: ' 높아져요.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
