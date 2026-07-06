import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/user_repository.dart';

/// 소개팅 가능 일정 편집 시트 — 앞으로 2주 중 가능한 날짜·시간대를 고른다.
/// 여기서 고른 시간 안에서만 에이전트가 시뮬레이션 대화로 약속을 조율한다.
Future<void> showAvailabilitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _AvailabilitySheet(),
  );
}

class _AvailabilitySheet extends StatefulWidget {
  const _AvailabilitySheet();

  @override
  State<_AvailabilitySheet> createState() => _AvailabilitySheetState();
}

class _AvailabilitySheetState extends State<_AvailabilitySheet> {
  static const _times = ['점심', '저녁'];
  static const _days = 14;

  final UserRepository _users = UserRepository();
  final Set<String> _selected = {}; // "yyyy-MM-dd|점심"
  /// 약속으로 묶인 칸 — key("yyyy-MM-dd|점심") → 상대 이름. 잠금 표시·편집 불가.
  final Map<String, String> _booked = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final availability = await _users.fetchAvailability();
      if (!mounted) return;
      setState(() {
        _selected.addAll(availability.open.map((s) => '${s.date}|${s.time}'));
        for (final b in availability.booked) {
          _booked['${b.date}|${b.time}'] = b.partnerName ?? '상대';
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('availability: GET /users/me 실패 — 빈 일정으로 시작: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final slots = [
      for (final key in _selected)
        AvailableSlot(date: key.split('|')[0], time: key.split('|')[1]),
    ];
    try {
      await _users.saveProfile(availableSlots: slots);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('가능 일정 ${slots.length}개를 저장했어요')));
    } catch (e) {
      debugPrint('availability: 저장 실패: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장에 실패했어요. 네트워크를 확인해주세요')));
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _dateLabel(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}월 ${d.day}일(${weekdays[d.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = [
      for (var i = 1; i <= _days; i++) today.add(Duration(days: i)),
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text('소개팅 가능 일정', style: AppTypography.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  '내 AI 에이전트가 이 시간 안에서만 약속을 잡아요.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.ink500,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xs,
                        ),
                        itemCount: dates.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) => _DayRow(
                          label: _dateLabel(dates[i]),
                          selectedTimes: {
                            for (final t in _times)
                              if (_selected.contains(
                                '${_dateKey(dates[i])}|$t',
                              ))
                                t,
                          },
                          bookedWith: {
                            for (final t in _times)
                              t: ?_booked['${_dateKey(dates[i])}|$t'],
                          },
                          onToggle: (t) {
                            final key = '${_dateKey(dates[i])}|$t';
                            if (_booked.containsKey(key)) return; // 약속 칸은 잠금
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selected.contains(key)
                                  ? _selected.remove(key)
                                  : _selected.add(key);
                            });
                          },
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saving || _loading ? null : _save,
                    child: Text(
                      _saving ? '저장 중...' : '저장하기',
                      style: AppTypography.label.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.selectedTimes,
    required this.bookedWith,
    required this.onToggle,
  });

  final String label;
  final Set<String> selectedTimes;

  /// 시간대 → 약속 상대 이름. 들어있으면 그 칸은 잠금.
  final Map<String, String> bookedWith;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.ink700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final t in ['점심', '저녁']) ...[
          const SizedBox(width: 8),
          _TimeChip(
            label: bookedWith.containsKey(t) ? '$t · ${bookedWith[t]}' : t,
            selected: selectedTimes.contains(t),
            booked: bookedWith.containsKey(t),
            onTap: () => onToggle(t),
          ),
        ],
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.booked = false,
  });

  final String label;
  final bool selected;

  /// 수락한 약속이 점유한 칸 — 민트 잠금 표시, 토글 불가.
  final bool booked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = booked
        ? AppColors.mint
        : selected
        ? AppColors.primary
        : AppColors.ink100;
    final Color fg = booked
        ? AppColors.mint
        : selected
        ? AppColors.primary
        : AppColors.ink500;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: booked
              ? AppColors.mint.withValues(alpha: 0.08)
              : selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (booked) ...[
              Icon(Icons.lock_rounded, size: 11, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: fg,
                fontSize: 13,
                fontWeight: selected || booked
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
