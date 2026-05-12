import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/amori_theme_ext.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

class SegmentedOption<T> {
  const SegmentedOption({required this.value, required this.label});
  final T value;
  final String label;
}

class SegmentedSelector<T> extends StatelessWidget {
  const SegmentedSelector({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentedOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          Expanded(
            child: _SegmentChip(
              label: options[i].label,
              selected: options[i].value == value,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(options[i].value);
              },
            ),
          ),
          if (i != options.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.rMd,
              ),
            ),
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                opacity: selected ? 1.0 : 0.0,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    gradient: amori.primaryGradient,
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rMd),
                    shadows: amori.glowShadow,
                  ),
                ),
              ),
            ),
            Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: AppTypography.label.copyWith(
                  color: selected ? Colors.white : AppColors.ink700,
                  fontWeight: FontWeight.w700,
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
