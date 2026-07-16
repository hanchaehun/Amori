import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 매칭 허용 나이 — 서버 미설정(null) 시 기본값. ranker.DEFAULT_AGE_GAP과 동일.
const kDefaultAgeGap = 5;

/// 법적 성인 하한(만 나이) — 매칭 쿼리도 서버에서 같은 값으로 자른다.
const kAdultAge = 19;

const _kGapMax = 20;

/// 매칭 선호(허용 나이) 결과 — 나보다 위로/아래로 몇 살까지.
typedef MatchAgePref = ({int older, int younger});

/// 매칭 선호 설정 바텀시트. 저장을 누르면 선택값을 반환하고, 닫으면 null.
Future<MatchAgePref?> showMatchPrefSheet(
  BuildContext context, {
  int? currentOlder,
  int? currentYounger,
  int? myAge,
}) {
  return showModalBottomSheet<MatchAgePref>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _MatchPrefSheet(
      initialOlder: currentOlder ?? kDefaultAgeGap,
      initialYounger: currentYounger ?? kDefaultAgeGap,
      myAge: myAge,
    ),
  );
}

class _MatchPrefSheet extends StatefulWidget {
  const _MatchPrefSheet({
    required this.initialOlder,
    required this.initialYounger,
    this.myAge,
  });

  final int initialOlder;
  final int initialYounger;
  final int? myAge;

  @override
  State<_MatchPrefSheet> createState() => _MatchPrefSheetState();
}

class _MatchPrefSheetState extends State<_MatchPrefSheet> {
  late int _older = widget.initialOlder;
  late int _younger = widget.initialYounger;

  /// "만 27세 ~ 37세와 매칭돼요" — 내 나이를 알 때만. 하한은 만 19세에서 잘린다.
  String? get _rangePreview {
    final age = widget.myAge;
    if (age == null) return null;
    final low = (age - _younger).clamp(kAdultAge, age);
    final high = age + _older;
    return '만 $low세 ~ $high세와 매칭돼요';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _rangePreview;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.ink300,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            Text('매칭 선호 설정', style: AppTypography.titleLarge),
            AppSpacing.vXs,
            Text(
              '나이 차이를 얼마나 허용할지 정해 주세요. 서로의 허용 범위에 드는 상대만 매칭돼요.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
            ),
            AppSpacing.vLg,
            _GapSlider(
              label: '연상 (나보다 위로)',
              value: _older,
              onChanged: (v) => setState(() => _older = v),
            ),
            AppSpacing.vMd,
            _GapSlider(
              label: '연하 (나보다 아래로)',
              value: _younger,
              onChanged: (v) => setState(() => _younger = v),
            ),
            AppSpacing.vMd,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview != null)
                    Text(
                      preview,
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (preview != null) const SizedBox(height: 2),
                  Text(
                    '만 $kAdultAge세 미만과는 매칭되지 않아요.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.vLg,
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(
                    context,
                  ).pop((older: _older, younger: _younger));
                },
                child: Text('저장', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GapSlider extends StatelessWidget {
  const _GapSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.label.copyWith(color: AppColors.ink700),
            ),
            const Spacer(),
            Text(
              value == 0 ? '동갑까지' : '$value살까지',
              style: AppTypography.label.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.surfaceMuted,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: _kGapMax.toDouble(),
            divisions: _kGapMax,
            onChanged: (v) {
              if (v.round() != value) HapticFeedback.selectionClick();
              onChanged(v.round());
            },
          ),
        ),
      ],
    );
  }
}
