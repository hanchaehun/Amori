import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 프로필 사진을 크게 보는 뷰어 — 전체화면이 아니라 배경을 블러 처리한 위에
/// 둥근 카드로 사진을 크게 띄운다. 사진을 탭하거나 배경을 누르면 닫힌다.
/// (리포트·잠금 리포트의 상대 사진 확대용, 2026-07-15)
Future<void> showPhotoViewer(
  BuildContext context, {
  required String photoUrl,
  String? caption,
  Object? heroTag,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '사진 닫기',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, _) => _PhotoViewer(
      photoUrl: photoUrl,
      caption: caption,
      heroTag: heroTag,
    ),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({
    required this.photoUrl,
    this.caption,
    this.heroTag,
  });

  final String photoUrl;
  final String? caption;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final side = size.width * 0.82;

    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.network(
        photoUrl,
        width: side,
        height: side,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: side,
            height: side,
            color: AppColors.surfaceMuted,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: AppColors.coral),
          );
        },
        errorBuilder: (context, _, _) => Container(
          width: side,
          height: side,
          color: AppColors.surfaceMuted,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.ink300,
            size: 40,
          ),
        ),
      ),
    );
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.coral.withValues(alpha: 0.28),
                        blurRadius: 40,
                        spreadRadius: -4,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  // 사진 탭이 배경 탭(닫기)으로 새지 않게 자체 탭을 흡수한다.
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: image,
                  ),
                ),
                if (caption != null && caption!.isNotEmpty) ...[
                  AppSpacing.vMd,
                  Text(
                    caption!,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                AppSpacing.vSm,
                Text(
                  '탭하면 닫혀요',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
