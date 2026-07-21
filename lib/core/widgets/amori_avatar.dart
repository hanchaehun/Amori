import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// 프로필 원형 아바타 — 사진이 있으면 로드하고, 로딩/실패 시 이니셜로 폴백한다.
/// (DecorationImage(NetworkImage)는 로드 실패 시 빈 회색 원만 남던 문제를 없앤다.)
class AmoriAvatar extends StatelessWidget {
  const AmoriAvatar({
    super.key,
    required this.initial,
    this.photoUrl,
    this.size = 48,
    this.backgroundColor,
    this.initialColor,
    this.initialStyle,
  });

  final String initial;
  final String? photoUrl;
  final double size;
  final Color? backgroundColor;
  final Color? initialColor;
  final TextStyle? initialStyle;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: hasPhoto
          ? Image.network(
              photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Center(
                      child: SizedBox(
                        width: size * 0.4,
                        height: size * 0.4,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.ink300),
                        ),
                      ),
                    ),
              errorBuilder: (context, _, _) => _initial(),
            )
          : _initial(),
    );
  }

  Widget _initial() {
    return Text(
      initial,
      style: initialStyle ??
          AppTypography.titleMedium.copyWith(
            color: initialColor ?? AppColors.ink700,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}
