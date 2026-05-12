import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/gradient_button.dart';

enum _Step { when, where, confirm }

enum _TimeSlot { morning, lunch, afternoon, evening, night }

extension on _TimeSlot {
  String get label => switch (this) {
        _TimeSlot.morning => '🌅 오전',
        _TimeSlot.lunch => '🍽 점심',
        _TimeSlot.afternoon => '☀️ 오후',
        _TimeSlot.evening => '🌆 저녁',
        _TimeSlot.night => '🌙 밤',
      };
}

class _Place {
  const _Place(this.emoji, this.title, this.area);
  final String emoji;
  final String title;
  final String area;
}

class SchedulingScreen extends StatefulWidget {
  const SchedulingScreen({super.key});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  _Step _step = _Step.when;
  final Set<int> _selectedDays = {};
  _TimeSlot _timeSlot = _TimeSlot.lunch;
  _Place? _selectedPlace;

  static const _places = [
    _Place('🍵', '오늘의 카페 성수점', '성수동 · 1.2km'),
    _Place('🌳', '연남동 산책 코스', '연남동 · 4km'),
    _Place('🖼', '소소한 갤러리', '한남동 · 3km'),
  ];

  static const _today = 5;
  static const _daysInMonth = 30;
  static const _firstDayWeekday = 0; // 0 = Sun

  void _onClose() {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    }
  }

  void _onNext() {
    HapticFeedback.lightImpact();
    setState(() {
      _step = switch (_step) {
        _Step.when => _Step.where,
        _Step.where => _Step.confirm,
        _Step.confirm => _Step.confirm,
      };
    });
  }

  void _onBack() {
    HapticFeedback.selectionClick();
    setState(() {
      _step = switch (_step) {
        _Step.when => _Step.when,
        _Step.where => _Step.when,
        _Step.confirm => _Step.where,
      };
    });
  }

  void _onSend() {
    HapticFeedback.mediumImpact();
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('약속 신청을 보냈어요. 상대방의 응답을 기다려주세요.')),
    );
  }

  void _toggleDay(int day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else if (_selectedDays.length < 3) {
        _selectedDays.add(day);
      }
    });
  }

  bool get _canProceed => switch (_step) {
        _Step.when => _selectedDays.isNotEmpty,
        _Step.where => _selectedPlace != null,
        _Step.confirm => true,
      };

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        children: [
          const _Handle(),
          _Header(
            title: '약속 잡기',
            onClose: _onClose,
            showBack: _step != _Step.when,
            onBack: _onBack,
          ),
          _Stepper(current: _step),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  _Step.when => _WhenStep(
                      today: _today,
                      daysInMonth: _daysInMonth,
                      firstDayWeekday: _firstDayWeekday,
                      selectedDays: _selectedDays,
                      onToggleDay: _toggleDay,
                      timeSlot: _timeSlot,
                      onTimeSlot: (s) => setState(() => _timeSlot = s),
                    ),
                  _Step.where => _WhereStep(
                      places: _places,
                      selected: _selectedPlace,
                      onSelect: (p) => setState(() => _selectedPlace = p),
                    ),
                  _Step.confirm => _ConfirmStep(
                      days: _selectedDays.toList()..sort(),
                      timeSlot: _timeSlot,
                      place: _selectedPlace,
                    ),
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: GradientButton(
              label: _step == _Step.confirm ? '약속 신청 보내기' : '다음 단계',
              trailing: _step == _Step.confirm
                  ? const Icon(Icons.send_rounded,
                      size: 18, color: Colors.white)
                  : const GradientArrowTrailing(),
              onPressed: _canProceed
                  ? (_step == _Step.confirm ? _onSend : _onNext)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.ink100,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onClose,
    required this.showBack,
    required this.onBack,
  });

  final String title;
  final VoidCallback onClose;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              title,
              style: AppTypography.titleLarge.copyWith(fontSize: 20),
            ),
          ),
          if (showBack)
            Positioned(
              left: 8,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: AppColors.ink900),
                onPressed: onBack,
              ),
            ),
          Positioned(
            right: 8,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.close_rounded,
                  size: 22, color: AppColors.ink900),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.current});
  final _Step current;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (1, '언제', _Step.when),
      (2, '어디서', _Step.where),
      (3, '확인', _Step.confirm),
    ];
    final currentIdx = _Step.values.indexOf(current);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _StepNode(
              n: steps[i].$1,
              label: steps[i].$2,
              isActive: i == currentIdx,
              isDone: i < currentIdx,
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 16),
                  color: i < currentIdx
                      ? AppColors.primary
                      : AppColors.ink100,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.n,
    required this.label,
    required this.isActive,
    required this.isDone,
  });
  final int n;
  final String label;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final filled = isActive || isDone;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.10),
          ),
          child: isDone
              ? const Icon(Icons.check_rounded,
                  size: 14, color: Colors.white)
              : Text(
                  '$n',
                  style: AppTypography.caption.copyWith(
                    color: filled ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isActive ? AppColors.primary : AppColors.ink500,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _WhenStep extends StatelessWidget {
  const _WhenStep({
    required this.today,
    required this.daysInMonth,
    required this.firstDayWeekday,
    required this.selectedDays,
    required this.onToggleDay,
    required this.timeSlot,
    required this.onTimeSlot,
  });

  final int today;
  final int daysInMonth;
  final int firstDayWeekday;
  final Set<int> selectedDays;
  final ValueChanged<int> onToggleDay;
  final _TimeSlot timeSlot;
  final ValueChanged<_TimeSlot> onTimeSlot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      children: [
        Text('언제 만날까요?',
            style: AppTypography.titleMedium.copyWith(fontSize: 17)),
        AppSpacing.vMd,
        _CalendarCard(
          today: today,
          daysInMonth: daysInMonth,
          firstDayWeekday: firstDayWeekday,
          selectedDays: selectedDays,
          onToggleDay: onToggleDay,
        ),
        const SizedBox(height: 8),
        Text(
          '최대 3개 후보를 선택해주세요  (${selectedDays.length}/3)',
          style: AppTypography.caption.copyWith(color: AppColors.ink500),
        ),
        AppSpacing.vXl,
        Text('선호 시간대',
            style: AppTypography.titleMedium.copyWith(fontSize: 15)),
        AppSpacing.vSm,
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              for (final s in _TimeSlot.values) ...[
                _TimeChip(
                  label: s.label,
                  selected: s == timeSlot,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTimeSlot(s);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.today,
    required this.daysInMonth,
    required this.firstDayWeekday,
    required this.selectedDays,
    required this.onToggleDay,
  });

  final int today;
  final int daysInMonth;
  final int firstDayWeekday;
  final Set<int> selectedDays;
  final ValueChanged<int> onToggleDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.ink100, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '11월 2026',
                style: AppTypography.titleMedium.copyWith(fontSize: 16),
              ),
              const Spacer(),
              const Icon(Icons.chevron_left_rounded,
                  size: 22, color: AppColors.ink500),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded,
                  size: 22, color: AppColors.ink500),
            ],
          ),
          AppSpacing.vSm,
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 32,
            ),
            itemCount: 7,
            itemBuilder: (_, i) {
              const labels = ['일', '월', '화', '수', '목', '금', '토'];
              return Center(
                child: Text(
                  labels[i],
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 36,
            ),
            itemCount: 35,
            itemBuilder: (_, i) {
              final day = i - firstDayWeekday + 1;
              final inMonth = day > 0 && day <= daysInMonth;
              if (!inMonth) return const SizedBox.shrink();
              final isPast = day < today;
              final isToday = day == today;
              final isSelected = selectedDays.contains(day);

              return Center(
                child: GestureDetector(
                  onTap: isPast ? null : () => onToggleDay(day),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primary : null,
                      border: !isSelected && isToday
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : null,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : isPast
                                ? AppColors.ink300
                                : AppColors.ink900,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: selected ? Colors.white : AppColors.ink700,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _WhereStep extends StatelessWidget {
  const _WhereStep({
    required this.places,
    required this.selected,
    required this.onSelect,
  });

  final List<_Place> places;
  final _Place? selected;
  final ValueChanged<_Place> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      children: [
        Text('어디서 만날까요?',
            style: AppTypography.titleMedium.copyWith(fontSize: 17)),
        AppSpacing.vXs,
        Text(
          'AI가 두 분의 취향에 맞춰 추천한 장소예요',
          style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
        ),
        AppSpacing.vMd,
        for (final p in places) ...[
          _PlaceCard(
            place: p,
            selected: p == selected,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(p);
            },
          ),
          AppSpacing.vSm,
        ],
        AppSpacing.vXs,
        Text(
          '나중에 채팅에서 다른 장소도 제안할 수 있어요',
          style: AppTypography.caption.copyWith(color: AppColors.ink500),
        ),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.selected,
    required this.onTap,
  });
  final _Place place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceSoft : Colors.white,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.ink100,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(place.emoji, style: const TextStyle(fontSize: 26)),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.title,
                    style: AppTypography.label.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.area,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ink500,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  size: 22, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.days,
    required this.timeSlot,
    required this.place,
  });

  final List<int> days;
  final _TimeSlot timeSlot;
  final _Place? place;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      children: [
        Text('이렇게 신청할게요',
            style: AppTypography.titleMedium.copyWith(fontSize: 17)),
        AppSpacing.vMd,
        _SummaryRow(
          icon: Icons.event_rounded,
          label: '후보 날짜',
          value: days.isEmpty
              ? '선택 안 됨'
              : days.map((d) => '11월 $d일').join(', '),
        ),
        AppSpacing.vSm,
        _SummaryRow(
          icon: Icons.schedule_rounded,
          label: '시간대',
          value: timeSlot.label,
        ),
        AppSpacing.vSm,
        _SummaryRow(
          icon: Icons.place_rounded,
          label: '장소',
          value: place == null
              ? '선택 안 됨'
              : '${place!.title} · ${place!.area}',
        ),
        AppSpacing.vXl,
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: AppRadius.rMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.primary),
              AppSpacing.hSm,
              Expanded(
                child: Text(
                  '상대방이 후보 중 가능한 날짜를 골라 확정하면 채팅에 알림이 가요.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.ink700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.ink100, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
