import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_states.dart';
import '../../data/repositories/persona_repository.dart';

/// 페르소나 미리보기·수정 — "당신의 에이전트는 이렇게 말해요" (refatodo P0-C).
///
/// 사용자가 발화·성향·말투 습관을 직접 고치는 화면. 수정문은 최고 등급
/// (user_written) 말투 데이터로 쌓이고, 수정한 성향은 user_edited로 잠긴다.
/// 설계 근거: docs/persona_science_rationale.md (수정권 = 충실도 루프).
class PersonaPreviewScreen extends StatefulWidget {
  const PersonaPreviewScreen({super.key, this.fromOnboarding = false});

  /// 온보딩 직후 진입이면 저장/건너뛰기가 홈으로 이어진다.
  final bool fromOnboarding;

  @override
  State<PersonaPreviewScreen> createState() => _PersonaPreviewScreenState();
}

class _PersonaPreviewScreenState extends State<PersonaPreviewScreen> {
  final _repository = PersonaRepository();

  bool _loading = true;
  String? _loadError;

  List<PreviewUtterance> _utterances = const [];
  PersonaDetail? _detail;

  // 수정 상태 — 저장 시 바뀐 것만 PATCH로 보낸다.
  final Map<int, String> _utteranceFixes = {}; // index → 수정문
  final Map<String, String> _traitSummaryEdits = {}; // category → summary
  final Set<String> _traitDeletes = {};
  final List<String> _freeSamples = [];
  String? _verbalHabitsEdit;
  bool? _hidePsychEdit; // true=숨기기 예약, null=변경 없음
  bool _saving = false;

  bool get _dirty =>
      _utteranceFixes.isNotEmpty ||
      _traitSummaryEdits.isNotEmpty ||
      _traitDeletes.isNotEmpty ||
      _freeSamples.isNotEmpty ||
      _verbalHabitsEdit != null ||
      _hidePsychEdit != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _repository.fetchPreview(),
        _repository.fetchMyPersonaDetail(),
      ]);
      if (!mounted) return;
      setState(() {
        _utterances = results[0] as List<PreviewUtterance>;
        _detail = results[1] as PersonaDetail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '미리보기를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _save() async {
    if (!_dirty || _saving) {
      _leave();
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.patchPersona(
        traitEdits: [
          for (final category in _traitDeletes)
            {'category': category, 'delete': true},
          for (final entry in _traitSummaryEdits.entries)
            if (!_traitDeletes.contains(entry.key))
              {'category': entry.key, 'summary': entry.value},
        ],
        utteranceFixes: [
          for (final entry in _utteranceFixes.entries)
            {
              'register': _utterances[entry.key].register,
              'text': entry.value,
            },
        ],
        verbalHabits: _verbalHabitsEdit,
        freeSamples: _freeSamples,
        hidePsych: _hidePsychEdit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반영했어요. 에이전트가 더 나다워졌어요!')),
      );
      _leave();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  void _leave() {
    if (!mounted) return;
    if (widget.fromOnboarding) {
      context.go(AppRoutes.home);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _editUtterance(int index) async {
    final current = _utteranceFixes[index] ?? _utterances[index].text;
    final edited = await _showTextEditorSheet(
      title: '내 말투로 고쳐 주세요',
      initial: current,
      hint: '실제로 보낼 문장 그대로 — 오타·ㅋㅋ·이모지도 습관이면 그대로!',
    );
    if (edited == null || edited == _utterances[index].text) return;
    setState(() {
      HapticFeedback.selectionClick();
      if (edited.trim().isEmpty) {
        _utteranceFixes.remove(index);
      } else {
        _utteranceFixes[index] = edited.trim();
      }
    });
  }

  Future<void> _editTrait(PersonaTraitView trait) async {
    final current = _traitSummaryEdits[trait.category] ?? trait.summary;
    final edited = await _showTextEditorSheet(
      title: '${trait.category} — 나는 이래요',
      initial: current,
      hint: '한 문장으로, 예: 서운하면 바로 말하는 편이에요',
    );
    if (edited == null || edited.trim().isEmpty || edited == trait.summary) {
      return;
    }
    setState(() {
      HapticFeedback.selectionClick();
      _traitSummaryEdits[trait.category] = edited.trim();
      _traitDeletes.remove(trait.category);
    });
  }

  Future<void> _addFreeSample() async {
    final sample = await _showTextEditorSheet(
      title: '평소에 이렇게 써요',
      initial: '',
      hint: '오타도 습관이면 그대로! 예: 마쟈마쟈 / 넹넹 / 구캥?',
    );
    if (sample == null || sample.trim().isEmpty) return;
    setState(() {
      HapticFeedback.selectionClick();
      _freeSamples.add(sample.trim());
    });
  }

  Future<String?> _showTextEditorSheet({
    required String title,
    required String initial,
    required String hint,
  }) {
    final controller = TextEditingController(text: initial);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleMedium),
            AppSpacing.vMd,
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.ink300,
                ),
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            AppSpacing.vMd,
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
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text),
                child: Text('확인', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: widget.fromOnboarding
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.ink900),
                onPressed: _leave,
              ),
        automaticallyImplyLeading: !widget.fromOnboarding,
        title: Text(
          '내 에이전트 미리보기',
          style: AppTypography.titleMedium.copyWith(color: AppColors.ink900),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const AmoriLoader(message: '에이전트가 말할 준비를 하고 있어요…')
          : _loadError != null
          ? _ErrorBody(message: _loadError!, onRetry: _load, onSkip: _leave)
          : _body(),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    if (!_dirty)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _leave,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            side: const BorderSide(color: AppColors.ink300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            '이대로 좋아요',
                            style: AppTypography.button.copyWith(
                              color: AppColors.ink700,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text('반영하기', style: AppTypography.button),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _body() {
    final detail = _detail!;
    final traitsByCategory = {
      for (final trait in detail.traits) trait.category: trait,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        Text(
          '당신의 에이전트는 이렇게 말해요',
          style: AppTypography.titleLarge.copyWith(color: AppColors.ink900),
        ),
        AppSpacing.vXs,
        Text(
          '내 말투가 아니면 눌러서 직접 고쳐 주세요.\n고칠수록 에이전트가 나다워져요.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.ink500),
        ),
        AppSpacing.vLg,
        for (var i = 0; i < _utterances.length; i++) ...[
          _UtteranceCard(
            register: _utterances[i].register,
            text: _utteranceFixes[i] ?? _utterances[i].text,
            edited: _utteranceFixes.containsKey(i),
            onTap: () => _editUtterance(i),
          ),
          AppSpacing.vSm,
        ],
        AppSpacing.vLg,
        Text(
          '성향 카드',
          style: AppTypography.titleMedium.copyWith(color: AppColors.ink900),
        ),
        AppSpacing.vXs,
        Text(
          '답변에서 확인된 성향만 보여드려요. 빈 칸은 매일 질문으로 채워져요.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
        ),
        AppSpacing.vMd,
        for (final category in kPersonaTraitCategories) ...[
          if (_traitDeletes.contains(category))
            _DeletedTraitCard(
              category: category,
              onRestore: () => setState(() => _traitDeletes.remove(category)),
            )
          else if (traitsByCategory.containsKey(category))
            _TraitCard(
              trait: traitsByCategory[category]!,
              summaryOverride: _traitSummaryEdits[category],
              onEdit: () => _editTrait(traitsByCategory[category]!),
              onDelete: () => setState(() {
                HapticFeedback.selectionClick();
                _traitDeletes.add(category);
              }),
            )
          else
            _UnknownTraitCard(category: category),
          AppSpacing.vSm,
        ],
        if (detail.attachmentHint.isNotEmpty &&
            detail.psychVisible &&
            _hidePsychEdit != true) ...[
          AppSpacing.vLg,
          _PsychCard(
            hint: detail.attachmentHint,
            onHide: () => setState(() {
              HapticFeedback.selectionClick();
              _hidePsychEdit = true;
            }),
          ),
        ],
        AppSpacing.vLg,
        Text(
          '말투 습관',
          style: AppTypography.titleMedium.copyWith(color: AppColors.ink900),
        ),
        AppSpacing.vXs,
        Text(
          '자주 쓰는 말버릇이나 표기가 있다면 알려 주세요. 의도적인 오타도 좋아요.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
        ),
        if (detail.voiceStats?.hasData ?? false) ...[
          AppSpacing.vMd,
          _VoiceStatsCard(
            stats: detail.voiceStats!,
            confidence: detail.voiceConfidence,
          ),
        ],
        AppSpacing.vMd,
        _HabitTile(
          label: '말버릇·감탄사',
          value: _verbalHabitsEdit ?? detail.verbalHabits,
          placeholder: '예: 헐 / 아 맞다 / 그니까',
          onTap: () async {
            final edited = await _showTextEditorSheet(
              title: '말버릇·감탄사',
              initial: _verbalHabitsEdit ?? detail.verbalHabits,
              hint: '예: 헐 / 아 맞다 / 그니까',
            );
            if (edited == null) return;
            setState(() => _verbalHabitsEdit = edited.trim());
          },
        ),
        AppSpacing.vSm,
        for (final sample in _freeSamples) ...[
          _FreeSampleChip(
            text: sample,
            onRemove: () => setState(() => _freeSamples.remove(sample)),
          ),
          AppSpacing.vXs,
        ],
        OutlinedButton.icon(
          onPressed: _addFreeSample,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            side: const BorderSide(color: AppColors.ink300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
          label: Text(
            '평소에 이렇게 써요 — 문장 추가',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.ink700),
          ),
        ),
      ],
    );
  }
}

class _UtteranceCard extends StatelessWidget {
  const _UtteranceCard({
    required this.register,
    required this.text,
    required this.edited,
    required this.onTap,
  });

  final String register;
  final String text;
  final bool edited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: edited ? AppColors.primary : AppColors.ink100,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    register,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (edited)
                  Text(
                    '수정함',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  )
                else
                  const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.ink300,
                  ),
              ],
            ),
            AppSpacing.vSm,
            Text(
              text,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.ink900,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TraitCard extends StatelessWidget {
  const _TraitCard({
    required this.trait,
    required this.onEdit,
    required this.onDelete,
    this.summaryOverride,
  });

  final PersonaTraitView trait;
  final String? summaryOverride;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final edited = summaryOverride != null || trait.userEdited;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: edited ? AppColors.primary : AppColors.ink100,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trait.category,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vXxs,
                  Text(
                    summaryOverride ?? trait.summary,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink900,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.ink300,
              ),
              tooltip: '이건 내가 아니에요',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnknownTraitCard extends StatelessWidget {
  const _UnknownTraitCard({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.vXxs,
                Text(
                  '아직 알아가는 중이에요 — 매일 질문에 답하면 채워져요',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: AppColors.ink300),
        ],
      ),
    );
  }
}

class _DeletedTraitCard extends StatelessWidget {
  const _DeletedTraitCard({required this.category, required this.onRestore});

  final String category;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$category — 삭제할게요',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.ink500,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
          TextButton(
            onPressed: onRestore,
            child: Text(
              '되돌리기',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 코드가 실측한 말투 통계의 읽기 전용 요약 카드 — LLM 추측이 아니라 실제
/// 답변에서 뽑은 값이라 "에이전트가 내 말투를 얼마나 아는지"의 근거가 된다.
class _VoiceStatsCard extends StatelessWidget {
  const _VoiceStatsCard({required this.stats, required this.confidence});

  final VoiceStatsView stats;
  final double? confidence;

  (String, Color) get _confidenceLabel {
    final c = confidence ?? 0;
    if (c >= 0.6) return ('높음', AppColors.success);
    if (c >= 0.35) return ('보통', AppColors.primary);
    return ('알아가는 중', AppColors.warning);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _confidenceLabel;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: AppRadius.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'AI가 측정한 내 말투',
                style: AppTypography.label.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '정확도 $label',
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '실제 답변 ${stats.sampleCount}개에서 뽑았어요 — 답할수록 더 정확해져요',
            style: AppTypography.caption.copyWith(color: AppColors.ink500),
          ),
          AppSpacing.vSm,
          for (final line in stats.summaryLines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle,
                      size: 4, color: AppColors.ink300),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ink700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ink100),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vXxs,
                  Text(
                    value.isEmpty ? placeholder : value,
                    style: AppTypography.bodyMedium.copyWith(
                      color: value.isEmpty
                          ? AppColors.ink300
                          : AppColors.ink900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 16, color: AppColors.ink300),
          ],
        ),
      ),
    );
  }
}

class _FreeSampleChip extends StatelessWidget {
  const _FreeSampleChip({required this.text, required this.onRemove});

  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink900,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16, color: AppColors.ink500),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _PsychCard extends StatelessWidget {
  const _PsychCard({required this.hint, required this.onHide});

  final String hint;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '관계에서의 마음 습관',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onHide,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  '숨기기',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
              ),
            ],
          ),
          Text(
            hint,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.ink900),
          ),
          AppSpacing.vXxs,
          Text(
            '답변에서 조심스럽게 읽은 힌트예요 — 진단이 아니에요.',
            style: AppTypography.caption.copyWith(color: AppColors.ink500),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.onSkip,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink500,
              ),
            ),
            AppSpacing.vMd,
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text('다시 시도', style: AppTypography.button),
            ),
            TextButton(
              onPressed: onSkip,
              child: Text(
                '다음에 할게요',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.ink500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
