import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class DevSkipButton extends StatelessWidget {
  const DevSkipButton({
    super.key,
    required this.onPressed,
    this.label = 'SKIP',
    this.dark = false,
  });

  final VoidCallback onPressed;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final tint = dark ? Colors.white : AppColors.warning;
    final textColor = dark ? Colors.white : const Color(0xFFB5780A);
    final bgAlpha = dark ? 0.18 : 0.12;
    final borderAlpha = dark ? 0.45 : 0.45;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: tint.withValues(alpha: borderAlpha),
            width: 1,
          ),
        ),
        child: Text(
          '(개발용) $label',
          style: AppTypography.caption.copyWith(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
