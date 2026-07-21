import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/state/agent_session_store.dart';

import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_snackbar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/backend/scenario_answers_store.dart';
import '../../data/dummy/scenarios.dart';
import '../../data/repositories/persona_repository.dart';

enum ScenarioPlayerMode { initial, daily }

class ScenarioPlayerScreen extends StatefulWidget {
  const ScenarioPlayerScreen({
    super.key,
    this.mode = ScenarioPlayerMode.initial,
    this.scenarioCodes,
    this.personaRepository,
  });

  final ScenarioPlayerMode mode;
  final List<String>? scenarioCodes;
  final PersonaRepository? personaRepository;

  @override
  State<ScenarioPlayerScreen> createState() => _ScenarioPlayerScreenState();
}

class _ScenarioPlayerScreenState extends State<ScenarioPlayerScreen> {
  int _index = 0;
  // 객관식: 선택지 letter / 주관식: 사용자가 쓴 메시지 원문
  final Map<int, String> _answers = {};
  final TextEditingController _freeTextController = TextEditingController();
  late final PersonaRepository _personaRepository;

  // 주관식은 "평소 말투"가 드러날 최소 길이만 요구 (한 마디면 충분)
  static const int _minFreeTextLength = 5;

  List<Scenario> get _scenarios {
    final codes =
        widget.scenarioCodes ??
        (widget.mode == ScenarioPlayerMode.initial
            ? kInitialScenarioCodes
            : kDailyScenarioCodes.take(1).toList());
    final scenarios = scenariosByCodes(codes);
    return scenarios.isEmpty
        ? scenariosByCodes(kInitialScenarioCodes)
        : scenarios;
  }

  Scenario get _current => _scenarios[_index];
  bool get _isLast => _index == _scenarios.length - 1;
  double get _progress => (_index + 1) / _scenarios.length;
  String? get _selectedLetter => _answers[_index];

  bool get _canProceed {
    final answer = _answers[_index];
    if (answer == null) return false;
    if (_current.isFreeText) return answer.trim().length >= _minFreeTextLength;
    return true;
  }

  /// 주관식에 뭔가 쓰긴 했는데 최소 길이 미달 — 왜 못 넘어가는지 안내한다.
  bool get _freeTextTooShort {
    if (!_current.isFreeText) return false;
    final answer = (_answers[_index] ?? '').trim();
    return answer.isNotEmpty && answer.length < _minFreeTextLength;
  }

  @override
  void initState() {
    super.initState();
    _personaRepository = widget.personaRepository ?? PersonaRepository();
  }

  @override
  void dispose() {
    _freeTextController.dispose();
    super.dispose();
  }

  void _select(String letter) {
    HapticFeedback.selectionClick();
    setState(() => _answers[_index] = letter);
  }

  void _onFreeTextChanged(String text) {
    setState(() => _answers[_index] = text);
  }

  /// 문항 이동 시 주관식 컨트롤러를 해당 문항의 저장값으로 동기화한다.
  void _syncFreeTextController() {
    if (_current.isFreeText) {
      _freeTextController.text = _answers[_index] ?? '';
    }
  }

  Future<void> _next() async {
    if (!_canProceed) return;
    HapticFeedback.lightImpact();
    if (_isLast) {
      final answers = _toScenarioAnswers();
      if (widget.mode == ScenarioPlayerMode.daily) {
        _submitDailyAnswer(answers.first);
      } else {
        ScenarioAnswersStore.save(answers);
        if (mounted) context.go(AppRoutes.personaLoading);
      }
    } else {
      setState(() => _index += 1);
      _syncFreeTextController();
    }
  }

  List<ScenarioAnswer> _toScenarioAnswers() {
    final entries = _answers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) {
      final scenario = _scenarios[entry.key];
      if (scenario.isFreeText) {
        return ScenarioAnswer(
          code: scenario.code,
          category: scenario.category,
          question: scenario.question,
          answerLetter: '주관식',
          answerText: entry.value.trim(),
        );
      }
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
    }).toList();
  }

  /// 낙관적 저장 (2026-07-15) — 데일리 보정은 LLM 호출이라 ~20초 걸린다.
  /// 사용자를 붙잡지 않고 즉시 완료 처리 후 홈으로 보내고, 저장은 백그라운드.
  /// 실패하면 완료 표시를 되돌려 오늘 다시 답할 수 있게 한다(답변 유실 방지).
  void _submitDailyAnswer(ScenarioAnswer answer) {
    final store = AgentSessionStore.instance;
    final previousCode = store.dailyScenarioCode;
    store.markDailyPersonaCompleted(DateTime.now());
    context.go(AppRoutes.home);
    unawaited(
      _personaRepository
          .updatePersona(answer)
          .then((profile) {
            store.profile = profile;
          })
          .catchError((Object _) {
            store.setDailyPersonaStatus(
              scenarioCode: previousCode,
              completedDate: null,
            );
            // 홈으로 이동한 뒤이므로 전역 스낵바로 실패를 알린다(무통지 방지).
            AmoriSnackbar.showGlobal(
              '오늘 질문을 저장하지 못했어요. 다시 시도해 주세요.',
              type: AmoriSnackType.error,
            );
          }),
    );
  }

  void _previous() {
    HapticFeedback.selectionClick();
    setState(() => _index -= 1);
    _syncFreeTextController();
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
      if (!mounted) return;
      if (widget.mode == ScenarioPlayerMode.daily) {
        context.go(AppRoutes.home);
      } else {
        context.pop();
      }
      return;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _ExitConfirmDialog(),
    );
    if (shouldExit == true && mounted) {
      if (widget.mode == ScenarioPlayerMode.daily) {
        context.go(AppRoutes.home);
      } else {
        context.pop();
      }
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
        stepIndex: _index + 1,
        stepTotal: _scenarios.length,
        onClose: _exit,
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
                    if (_current.isFreeText) ...[
                      _FreeTextCard(
                        controller: _freeTextController,
                        hint: _current.hint ?? '평소 말투 그대로 써주세요',
                        onChanged: _onFreeTextChanged,
                      ),
                      if (_freeTextTooShort) ...[
                        AppSpacing.vXs,
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 14, color: AppColors.ink500),
                            const SizedBox(width: 4),
                            Text(
                              '조금만 더 써주세요 (최소 $_minFreeTextLength자)',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.ink500),
                            ),
                          ],
                        ),
                      ],
                    ] else
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
              label: _isLast
                  ? (widget.mode == ScenarioPlayerMode.daily ? '답변 저장' : '완료')
                  : '다음',
              trailing: _isLast ? null : const GradientArrowTrailing(),
              onPressed: _canProceed ? () => _next() : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ScenarioAppBar({
    required this.stepIndex,
    required this.stepTotal,
    required this.onClose,
  });

  final int stepIndex;
  final int stepTotal;
  final VoidCallback onClose;

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
              '$stepIndex / $stepTotal',
              style: AppTypography.label.copyWith(
                color: AppColors.ink700,
                fontWeight: FontWeight.w700,
              ),
            ),
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
            '에이전트 설정 중',
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

class _FreeTextCard extends StatelessWidget {
  const _FreeTextCard({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.rMd,
            border: Border.all(color: AppColors.ink100, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: 3,
            maxLines: 6,
            maxLength: 200,
            cursorColor: AppColors.primary,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.ink900,
              fontSize: 15,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink300,
                fontSize: 14,
                height: 1.5,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              counterStyle: AppTypography.caption.copyWith(
                color: AppColors.ink300,
                fontSize: 11,
              ),
            ),
          ),
        ),
        AppSpacing.vSm,
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '내 AI 에이전트의 말투를 조정해요',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
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
