import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 활동 지역(시/도) 목록 — 같은 지역끼리만 매칭된다(수도권 서울·경기·인천은 상호 허용).
const kRegions = [
  '서울',
  '경기',
  '인천',
  '부산',
  '대구',
  '광주',
  '대전',
  '울산',
  '세종',
  '강원',
  '충북',
  '충남',
  '전북',
  '전남',
  '경북',
  '경남',
  '제주',
];

/// 지역 선택 바텀시트. 선택한 지역을 반환하고, "선택 안 함"은 빈 문자열, 닫으면 null.
Future<String?> showRegionSheet(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _RegionSheet(current: current),
  );
}

class _RegionSheet extends StatelessWidget {
  const _RegionSheet({this.current});
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
            Text('활동 지역', style: AppTypography.titleLarge),
            AppSpacing.vXs,
            Text(
              '주로 활동하는 지역을 선택하면 같은 지역의 상대와 매칭돼요.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
            ),
            AppSpacing.vLg,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final region in kRegions)
                  _RegionChip(
                    label: region,
                    selected: region == current,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(region);
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

class _RegionChip extends StatelessWidget {
  const _RegionChip({
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
