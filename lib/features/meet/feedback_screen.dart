import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/gradient_button.dart';

enum _Impression { good, ok, bad }

extension on _Impression {
  String get emoji => switch (this) {
        _Impression.good => '😊',
        _Impression.ok => '😐',
        _Impression.bad => '😞',
      };

  String get label => switch (this) {
        _Impression.good => '좋았어요',
        _Impression.ok => '보통이에요',
        _Impression.bad => '별로였어요',
      };
}

enum _NextStep { keepDating, friends, finish }

extension on _NextStep {
  String get label => switch (this) {
        _NextStep.keepDating => '💞  계속 만나고 싶어요',
        _NextStep.friends => '🤝  친구로 지내요',
        _NextStep.finish => '🙏  정중히 마무리할게요',
      };
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  _Impression? _impression;
  double _accuracy = 0.75;
  _NextStep? _nextStep;

  bool get _canSubmit => _impression != null && _nextStep != null;

  void _onClose() {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _onSubmit() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('소중한 피드백 감사해요. AI가 더 정확해질 수 있어요.')),
    );
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: BackAppBar(
        title: '만남 피드백',
        onBack: _onClose,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                const _Hero(name: '민준', initial: '민', date: '11월 12일 · 성수 카페'),
                AppSpacing.vXl,
                _QuestionLabel(n: 1, text: '실제 인상은 어땠나요?'),
                AppSpacing.vSm,
                _ImpressionRow(
                  value: _impression,
                  onChanged: (v) => setState(() => _impression = v),
                ),
                AppSpacing.vXl,
                _QuestionLabel(n: 2, text: 'AI 리포트가 실제와 얼마나 일치했나요?'),
                AppSpacing.vXxs,
                Text(
                  '이 답변은 AI 정확도 향상에 사용됩니다',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                AppSpacing.vMd,
                _AccuracySlider(
                  value: _accuracy,
                  onChanged: (v) => setState(() => _accuracy = v),
                ),
                AppSpacing.vSm,
                _SliderLabels(value: _accuracy),
                AppSpacing.vXl,
                _QuestionLabel(n: 3, text: '민준님과 계속 연락하실 건가요?'),
                AppSpacing.vSm,
                _NextStepList(
                  value: _nextStep,
                  onChanged: (v) => setState(() => _nextStep = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                GradientButton(
                  label: '피드백 보내기',
                  onPressed: _canSubmit ? _onSubmit : null,
                ),
                const SizedBox(height: 8),
                Text(
                  '피드백은 익명 처리되며 상대방에게 공개되지 않습니다',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.ink500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.initial, required this.date});
  final String name;
  final String initial;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.ink700,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.vSm,
        Text(
          '$name님과의 만남\n어땠어요?',
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(
            fontSize: 22,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          date,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.ink500,
          ),
        ),
      ],
    );
  }
}

class _QuestionLabel extends StatelessWidget {
  const _QuestionLabel({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$n.  ',
            style: AppTypography.titleMedium.copyWith(
              fontSize: 15,
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: text,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 15,
              color: AppColors.ink900,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpressionRow extends StatelessWidget {
  const _ImpressionRow({required this.value, required this.onChanged});
  final _Impression? value;
  final ValueChanged<_Impression> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _Impression.values.length; i++) ...[
          Expanded(
            child: _ImpressionCard(
              option: _Impression.values[i],
              selected: _Impression.values[i] == value,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(_Impression.values[i]);
              },
            ),
          ),
          if (i < _Impression.values.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ImpressionCard extends StatelessWidget {
  const _ImpressionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final _Impression option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 96,
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceSoft : Colors.white,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.ink100,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 6),
            Text(
              option.label,
              style: AppTypography.caption.copyWith(
                color: selected ? AppColors.primary : AppColors.ink700,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccuracySlider extends StatelessWidget {
  const _AccuracySlider({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        const thumbSize = 28.0;
        final fillWidth = (width * value).clamp(0.0, width);
        final thumbLeft =
            (width * value - thumbSize / 2).clamp(0.0, width - thumbSize);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            HapticFeedback.selectionClick();
            onChanged((d.localPosition.dx / width).clamp(0.0, 1.0));
          },
          onHorizontalDragUpdate: (d) {
            onChanged((d.localPosition.dx / width).clamp(0.0, 1.0));
          },
          child: SizedBox(
            height: thumbSize,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 11,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.ink100,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 11,
                  width: fillWidth,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: amori.primaryGradient,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Positioned(
                  left: thumbLeft,
                  top: 0,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SliderLabels extends StatelessWidget {
  const _SliderLabels({required this.value});
  final double value;

  String get _activeBucket {
    if (value < 0.34) return 'low';
    if (value < 0.67) return 'mid';
    return 'high';
  }

  @override
  Widget build(BuildContext context) {
    final bucket = _activeBucket;
    TextStyle base(bool active) => AppTypography.caption.copyWith(
          color: active ? AppColors.primary : AppColors.ink500,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          fontSize: 11,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('전혀 달랐어요', style: base(bucket == 'low')),
        Text('비슷했어요', style: base(bucket == 'mid')),
        Text('정확했어요', style: base(bucket == 'high')),
      ],
    );
  }
}

class _NextStepList extends StatelessWidget {
  const _NextStepList({required this.value, required this.onChanged});
  final _NextStep? value;
  final ValueChanged<_NextStep> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final s in _NextStep.values) ...[
          _NextStepRow(
            option: s,
            selected: s == value,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(s);
            },
          ),
          if (s != _NextStep.values.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _NextStepRow extends StatelessWidget {
  const _NextStepRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final _NextStep option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceSoft : Colors.white,
          borderRadius: AppRadius.rSm,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.ink100,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.label,
                style: AppTypography.bodyLarge.copyWith(
                  color: selected ? AppColors.primary : AppColors.ink900,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
