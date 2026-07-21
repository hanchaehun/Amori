import 'package:flutter/material.dart';

import '../theme/amori_theme_ext.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'gradient_button.dart';

/// 브랜드 색을 쓰는 공용 로딩 스피너. Material 기본 파랑 스피너가 화면마다
/// 섞이던 문제를 없애기 위해 모든 로딩은 이 위젯을 쓴다.
class AmoriLoader extends StatelessWidget {
  const AmoriLoader({
    super.key,
    this.size = 26,
    this.strokeWidth = 2.6,
    this.color,
    this.message,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  /// 있으면 스피너 아래에 안내 문구를 표시한다(무설명 스피너 방지).
  final String? message;

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
      ),
    );
    if (message == null) return Center(child: spinner);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          spinner,
          AppSpacing.vMd,
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
          ),
        ],
      ),
    );
  }
}

/// 리스트/화면의 "내용 없음" 상태. 아이콘 + 제목 + 설명 + (선택)CTA.
/// 화면마다 중복 정의되던 `_EmptyState`를 대체한다.
class AmoriEmptyState extends StatelessWidget {
  const AmoriEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: amori.softGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: iconColor ?? AppColors.primary),
            ),
            AppSpacing.vLg,
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium,
            ),
            if (message != null) ...[
              AppSpacing.vXs,
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.ink500,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              AppSpacing.vLg,
              GradientButton(
                label: actionLabel!,
                onPressed: onAction,
                size: GradientButtonSize.regular,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 네트워크/서버 오류 상태 — "내용 없음"과 반드시 구분해서 보여준다.
/// (에러를 빈 상태로 위장하면 사용자가 장애와 데이터 없음을 구분 못 함.)
class AmoriErrorState extends StatelessWidget {
  const AmoriErrorState({
    super.key,
    this.title = '불러오지 못했어요',
    this.message = '네트워크 상태를 확인하고 다시 시도해 주세요.',
    this.onRetry,
    this.retryLabel = '다시 시도',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.ink100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 30,
                color: AppColors.ink500,
              ),
            ),
            AppSpacing.vLg,
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium,
            ),
            AppSpacing.vXs,
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
            ),
            if (onRetry != null) ...[
              AppSpacing.vLg,
              GradientButton(
                label: retryLabel,
                onPressed: onRetry,
                size: GradientButtonSize.regular,
                expand: false,
                icon: Icons.refresh_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
