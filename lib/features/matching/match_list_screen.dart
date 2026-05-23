import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_tab_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/backend/amori_backend.dart';
import '../../data/backend/models.dart';
import '../../data/dummy/matches.dart';

enum _MatchFilter { all, valueAlignment, humor, conversation }

extension _MatchFilterX on _MatchFilter {
  String get label => switch (this) {
    _MatchFilter.all => '전체',
    _MatchFilter.valueAlignment => '가치관',
    _MatchFilter.humor => '유머',
    _MatchFilter.conversation => '대화 패턴',
  };
}

class MatchListScreen extends StatefulWidget {
  const MatchListScreen({super.key});

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  _MatchFilter _filter = _MatchFilter.all;
  late final AmoriBackend _backend = AmoriBackend();
  Stream<List<MatchDocument>>? _matchStream;

  @override
  void initState() {
    super.initState();
    if (_backend.currentUser != null) {
      _backend.ensureDemoMatches();
      _matchStream = _backend.watchMatches();
    }
  }

  void _onFilterTrailing() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('필터 옵션 — 다음 턴 작업 예정')));
  }

  void _onMatchTap(MatchProfile match) {
    HapticFeedback.lightImpact();
    context.push('${AppRoutes.lockedReport}?id=${match.id}');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bottomBar: const AmoriTabBar(active: AmoriTab.match),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _TopBar(onTrailing: _onFilterTrailing)),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(child: _VerifiedBanner()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: _FilterRow(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
          ),
          _MatchListSliver(
            stream: _matchStream,
            filter: _filter,
            onTap: _onMatchTap,
          ),
        ],
      ),
    );
  }
}

class _MatchListSliver extends StatelessWidget {
  const _MatchListSliver({
    required this.stream,
    required this.filter,
    required this.onTap,
  });

  final Stream<List<MatchDocument>>? stream;
  final _MatchFilter filter;
  final ValueChanged<MatchProfile> onTap;

  @override
  Widget build(BuildContext context) {
    if (stream == null) {
      return _cards(kMatches);
    }

    return StreamBuilder<List<MatchDocument>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _cards(kMatches);
        final docs = snapshot.data;
        if (docs == null) {
          return const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final profiles = docs.map((doc) => doc.profile).toList();
        return _cards(_filtered(profiles));
      },
    );
  }

  List<MatchProfile> _filtered(List<MatchProfile> matches) {
    final sorted = [...matches];
    switch (filter) {
      case _MatchFilter.all:
        sorted.sort((a, b) => b.score.compareTo(a.score));
      case _MatchFilter.valueAlignment:
        sorted.sort((a, b) => b.values.compareTo(a.values));
      case _MatchFilter.humor:
        sorted.sort((a, b) => b.humor.compareTo(a.humor));
      case _MatchFilter.conversation:
        sorted.sort((a, b) => b.communication.compareTo(a.communication));
    }
    return sorted;
  }

  Widget _cards(List<MatchProfile> matches) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      sliver: SliverList.separated(
        itemCount: matches.length,
        separatorBuilder: (_, _) => AppSpacing.vMd,
        itemBuilder: (_, i) =>
            _MatchCard(match: matches[i], onTap: () => onTap(matches[i])),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onTrailing});

  final VoidCallback onTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Text('검증된 인연', style: AppTypography.titleLarge),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(
                Icons.tune_rounded,
                size: 22,
                color: AppColors.ink900,
              ),
              onPressed: onTrailing,
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedBanner extends StatelessWidget {
  const _VerifiedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.06),
        borderRadius: AppRadius.rSm,
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, size: 16, color: AppColors.coral),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '75점 이상 검증된 매칭만 표시됩니다',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.ink700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.value, required this.onChanged});

  final _MatchFilter value;
  final ValueChanged<_MatchFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final f in _MatchFilter.values) ...[
            _FilterChip(
              label: f.label,
              selected: f == value,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(f);
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.coral : AppColors.surfaceMuted,
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

class _MatchCard extends StatefulWidget {
  const _MatchCard({required this.match, required this.onTap});

  final MatchProfile match;
  final VoidCallback onTap;

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    return AnimatedScale(
      scale: _pressed ? 0.99 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.rMd,
            border: Border.all(color: AppColors.ink100, width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      m.initial,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.ink700,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: Text(
                      '${m.name}, ${m.age}',
                      style: AppTypography.titleMedium.copyWith(fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${m.score}점',
                      style: AppTypography.label.copyWith(
                        color: AppColors.coral,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.vMd,
              Row(
                children: [
                  Expanded(
                    child: _MiniBar(label: '가치관', value: m.values),
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: _MiniBar(label: '유머', value: m.humor),
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: _MiniBar(label: '대화', value: m.communication),
                  ),
                ],
              ),
              AppSpacing.vMd,
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.coral, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '리포트 보기',
                        style: AppTypography.label.copyWith(
                          color: AppColors.coral,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: AppColors.coral,
                      ),
                    ],
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

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          '$value',
          style: AppTypography.label.copyWith(
            color: AppColors.ink900,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.ink100,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (value / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.coral,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
