import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AmoriSnackType { info, success, error }

/// 앱 전역 스낵바 스타일 통일 — floating + 둥근 모서리 + 타입별 색/아이콘.
/// 화면마다 제각각이던 raw `showSnackBar` 호출을 이 헬퍼로 모은다.
class AmoriSnackbar {
  AmoriSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    AmoriSnackType type = AmoriSnackType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final (Color bg, IconData icon) = switch (type) {
      AmoriSnackType.success => (AppColors.ink900, Icons.check_circle_rounded),
      AmoriSnackType.error => (AppColors.danger, Icons.error_rounded),
      AmoriSnackType.info => (AppColors.ink900, Icons.info_rounded),
    };
    final Color accent = switch (type) {
      AmoriSnackType.success => AppColors.secondary,
      AmoriSnackType.error => Colors.white,
      AmoriSnackType.info => AppColors.secondary,
    };

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
          elevation: 6,
          duration: duration,
          margin: const EdgeInsets.all(AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          content: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, type: AmoriSnackType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: AmoriSnackType.error);
}
