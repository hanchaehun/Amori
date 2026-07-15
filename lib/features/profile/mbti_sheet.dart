import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// MBTI 16유형 — 프로필 표시 + 성격 추정의 약한 초기값 전용.
/// 매칭 점수·유형 궁합 규칙에는 절대 쓰지 않는다
/// (docs/persona_science_rationale.md §9 금지선 — 문구도 "매칭해준다"로 쓰지 말 것).
const List<String> kMbtiTypes = [
  'ISTJ', 'ISFJ', 'INFJ', 'INTJ',
  'ISTP', 'ISFP', 'INFP', 'INTP',
  'ESTP', 'ESFP', 'ENFP', 'ENTP',
  'ESTJ', 'ESFJ', 'ENFJ', 'ENTJ',
];

/// MBTI 선택 바텀시트. 선택한 유형을 반환하고, "선택 안 함"은 빈 문자열, 닫으면 null.
Future<String?> showMbtiSheet(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _MbtiSheet(current: current),
  );
}

class _MbtiSheet extends StatelessWidget {
  const _MbtiSheet({this.current});
  final String? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.ink300,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
            Text('MBTI', style: AppTypography.titleLarge),
            AppSpacing.vXs,
            Text(
              '프로필에 보여지고, 에이전트가 당신을 이해하는 힌트로만 써요.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
            ),
            AppSpacing.vLg,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in kMbtiTypes)
                  _MbtiChip(
                    label: type,
                    selected: type == current,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(type);
                    },
                  ),
              ],
            ),
            if (current != null && current!.isNotEmpty) ...[
              AppSpacing.vMd,
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop('');
                },
                child: Text(
                  '선택 안 함',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MbtiChip extends StatelessWidget {
  const _MbtiChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: ShapeDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceMuted,
          shape: selected
              ? const StadiumBorder()
              : StadiumBorder(
                  side: BorderSide(
                    color: AppColors.ink300.withValues(alpha: 0.4),
                  ),
                ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: selected ? Colors.white : AppColors.ink700,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
