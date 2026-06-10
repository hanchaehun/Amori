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
import '../../core/widgets/dev_skip_button.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/backend/scenario_answers_store.dart';
import '../../data/dummy/scenarios.dart';

class ScenarioPlayerScreen extends StatefulWidget {
  const ScenarioPlayerScreen({super.key});

  @override
  State<ScenarioPlayerScreen> createState() => _ScenarioPlayerScreenState();
}

class _ScenarioPlayerScreenState extends State<ScenarioPlayerScreen> {
  int _index = 0;
  final Map<int, String> _answers = {};

  static const int _categoryCount = 8;

  Scenario get _current => kScenarios[_index];
  bool get _isLast => _index == kScenarios.length - 1;
  double get _progress => (_index + 1) / kScenarios.length;
  int get _categoryIndex => int.parse(_current.code.split('-').first);
  String? get _selectedLetter => _answers[_index];

  void _select(String letter) {
    HapticFeedback.selectionClick();
    setState(() => _answers[_index] = letter);
  }

  void _next() {
    if (_selectedLetter == null) return;
    HapticFeedback.lightImpact();
    if (_isLast) {
      ScenarioAnswersStore.save(
        _answers.entries.map((entry) {
          final scenario = kScenarios[entry.key];
          final choice = scenario.choices.firstWhere(
            (choice) => choice.letter == entry.value,
          );
          return ScenarioAnswer(
            code: scenario.code,
            category: scenario.category,
            question: scenario.question,
            answerLetter: choice.letter,
            answerText: choice.text,
          );
        }).toList(),
      );
      context.go(AppRoutes.personaLoading);
    } else {
      setState(() => _index += 1);
    }
  }

  void _previous() {
    HapticFeedback.selectionClick();
    setState(() => _index -= 1);
  }

  Future<void> _handleBack() async {
    if (_index > 0) {
      _previous();
    } else {
      await _exit();
    }
  }

  Future<void> _exit() async {
    if (_answers.isEmpty) {
      if (mounted) context.pop();
      return;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _ExitConfirmDialog(),
    );
    if (shouldExit == true && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    return AppScaffold(
      appBar: _ScenarioAppBar(
        categoryIndex: _categoryIndex,
        categoryTotal: _categoryCount,
        onClose: _exit,
        onSkip: () => context.go(AppRoutes.personaLoading),
      ),
      body: Column(
        children: [
          _ProgressBar(value: _progress),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(_index),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SituationCard(scenario: _current),
                    AppSpacing.vLg,
                    Text(
                      _current.question,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AppSpacing.vMd,
                    for (final c in _current.choices) ...[
                      _ChoiceCard(
                        letter: c.letter,
                        text: c.text,
                        selected: _selectedLetter == c.letter,
                        onTap: () => _select(c.letter),
                      ),
                      AppSpacing.vSm,
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: GradientButton(
              label: _isLast ? '완료' : '다음',
              trailing: _isLast ? null : const GradientArrowTrailing(),
              onPressed: _selectedLetter == null ? null : _next,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ScenarioAppBar({
    required this.categoryIndex,
    required this.categoryTotal,
    required this.onClose,
    required this.onSkip,
  });

  final int categoryIndex;
  final int categoryTotal;
  final VoidCallback onClose;
  final VoidCallback onSkip;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.ink900,
                size: 22,
              ),
              onPressed: onClose,
            ),
            const SizedBox(width: 4),
            Text(
              '$categoryIndex / $categoryTotal',
              style: AppTypography.label.copyWith(
                color: AppColors.ink700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            DevSkipButton(onPressed: onSkip),
            const Spacer(),
            const _ClonigBadge(),
          ],
        ),
      ),
    );
  }
}

class _ClonigBadge extends StatelessWidget {
  const _ClonigBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '페르소나 클로닝 중',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return SizedBox(
      height: 6,
      child: Stack(
        children: [
          Container(color: AppColors.ink100),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(gradient: amori.primaryGradient),
            ),
          ),
        ],
      ),
    );
  }
}

class _SituationCard extends StatelessWidget {
  const _SituationCard({required this.scenario});
  final Scenario scenario;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  scenario.contextLabel,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                scenario.code,
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          AppSpacing.vMd,
          Text(
            '상황',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          AppSpacing.vXs,
          Text(
            scenario.situation,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.ink900,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
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
            SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      letter,
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink500,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: selected ? 1.0 : 0.0,
                      child: Container(
                        decoration: ShapeDecoration(
                          gradient: amori.primaryGradient,
                          shape: const CircleBorder(),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          letter,
                          style: AppTypography.label.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodyMedium.copyWith(
                  color: selected ? AppColors.ink900 : AppColors.ink700,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExitConfirmDialog extends StatelessWidget {
  const _ExitConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('지금 나가시겠어요?', style: AppTypography.titleLarge),
            AppSpacing.vSm,
            Text(
              '지금까지의 답변이 사라져요.\n다시 처음부터 시작해야 합니다.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink500,
                height: 1.5,
              ),
            ),
            AppSpacing.vLg,
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surfaceMuted,
                      foregroundColor: AppColors.ink900,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rMd,
                      ),
                    ),
                    child: Text(
                      '계속하기',
                      style: AppTypography.label.copyWith(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rMd,
                      ),
                    ),
                    child: Text(
                      '나가기',
                      style: AppTypography.label.copyWith(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
