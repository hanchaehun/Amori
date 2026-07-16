import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 앱 최상위(탭 루트) 화면을 감싸 휴대폰 뒤로가기를 처리한다.
///
/// 탭 루트는 `context.go()`로 진입해 네비게이션 스택이 비어 있어서,
/// 하드웨어/제스처 뒤로가기를 그대로 두면 pop 할 화면이 없어 OS가 앱을
/// 백그라운드로 보내 버린다(바탕화면으로 나가짐). 이를 가로채:
///   - 하위 스택이 있으면 → 일반 뒤로가기(pop)
///   - 홈이 아닌 루트 탭이면 → 홈으로 이동
///   - 홈이면 → 종료 확인 다이얼로그 → 확인 시에만 앱 종료
class ExitGuard extends StatelessWidget {
  const ExitGuard({super.key, required this.child, this.isHome = false});

  /// 감쌀 화면.
  final Widget child;

  /// 홈 화면이면 true. 홈에서만 종료 확인을 띄운다.
  final bool isHome;

  Future<void> _handleBack(BuildContext context) async {
    // 하위 스택이 있으면 평범하게 뒤로 간다.
    if (context.canPop()) {
      context.pop();
      return;
    }
    // 홈이 아닌 루트 탭이면 홈으로 돌아간다.
    if (!isHome) {
      context.go(AppRoutes.home);
      return;
    }
    // 홈이면 종료 확인을 거친다.
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _ExitConfirmDialog(),
    );
    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: child,
    );
  }
}

class _ExitConfirmDialog extends StatelessWidget {
  const _ExitConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('앱을 종료할까요?', style: AppTypography.titleLarge),
            AppSpacing.vSm,
            Text(
              'amori를 종료하시겠어요?',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink500,
                height: 1.5,
              ),
            ),
            AppSpacing.vLg,
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surfaceMuted,
                      foregroundColor: AppColors.ink900,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rMd,
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: AppTypography.label.copyWith(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rMd,
                      ),
                    ),
                    child: Text(
                      '종료',
                      style: AppTypography.label.copyWith(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
