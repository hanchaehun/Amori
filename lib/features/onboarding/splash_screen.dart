import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/gradient_orb.dart';
import '../../core/widgets/gradient_text.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 3),
            const _LogoBlock(),
            AppSpacing.vXl,
            Text(
              'AI 에이전트가 먼저 만나는,\n가장 나다운 인연',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.ink500,
                height: 1.55,
              ),
            ),
            AppSpacing.vXs,
            Text(
              'Your AI meets first.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.ink300,
                fontStyle: FontStyle.italic,
              ),
            ),
            const Spacer(flex: 5),
            GradientButton(
              label: '시작하기',
              trailing: const GradientArrowTrailing(),
              onPressed: () => context.push(AppRoutes.walkthrough),
            ),
            AppSpacing.vMd,
            Center(
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.login),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: RichText(
                    text: TextSpan(
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.ink500,
                      ),
                      children: [
                        const TextSpan(text: '이미 계정이 있어요  '),
                        TextSpan(
                          text: '로그인',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.ink900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AppSpacing.vXl,
          ],
        ),
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const AmoriLogoMark(size: 56),
        AppSpacing.hMd,
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GradientText(
              'amori',
              style: AppTypography.displayLarge,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: amori.primaryGradient,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
