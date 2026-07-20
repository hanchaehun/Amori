import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_states.dart';
import '../../core/widgets/amori_tab_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/exit_guard.dart';
import '../../data/backend/amori_backend.dart';
import '../../data/dummy/matches.dart';
import '../../data/repositories/match_repository.dart';

/// 케미 게이트(백엔드 report_pass_score=75) 통과 매치만 이 탭에 띄운다.
/// 후보 검색(/matches/find)이 아니라 시뮬 대화·리포트가 끝난 결과(/matches)가
/// 원천 — "AI가 먼저 만나보고 검증된 인연"이라는 제품 약속과 배너 문구의 구현.
const int kVerifiedScoreThreshold = 75;

class MatchListScreen extends StatefulWidget {
  const MatchListScreen({super.key});

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  bool _loading = true;
  bool _error = false;
  List<MatchProfile> _matches = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AmoriBackend().isAuthenticated) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = false;
          _matches = const [];
        });
      }
      return;
    }
    if (mounted) setState(() => _error = false);
    try {
      final summaries = await MatchRepository().listMatches();
      final verified = [
        for (final s in summaries)
          // 송출 중(reportScore null)·게이트 미만(failed)은 제외 —
          // 진행 중은 연결 탭, 미달은 닿지 않은 인연의 몫.
          if (!s.failed && (s.reportScore ?? 0) >= kVerifiedScoreThreshold)
            MatchProfile(
              id: s.matchId,
              initial: (s.partnerName?.isNotEmpty ?? false)
                  ? s.partnerName!.substring(0, 1)
                  : '?',
              name: s.partnerName ?? '상대',
              age: 0,
              score: s.reportScore!,
              values: 0,
              humor: 0,
              communication: 0,
              photoUrl: s.partnerPhotoUrl,
            ),
      ];
      verified.sort((a, b) => b.score.compareTo(a.score));
      if (!mounted) return;
      setState(() {
        _matches = verified;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      // 네트워크/서버 오류는 "매칭 0건"으로 위장하지 않고 에러 상태로 노출한다.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _onMatchTap(MatchProfile match) {
    HapticFeedback.lightImpact();
    context.push('${AppRoutes.lockedReport}?id=${match.id}');
  }

  @override
  Widget build(BuildContext context) {
    return ExitGuard(
      child: AppScaffold(
        bottomBar: const AmoriTabBar(active: AmoriTab.match),
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              const SliverToBoxAdapter(child: _TopBar()),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(child: _VerifiedBanner()),
              ),
              _buildContentSliver(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentSliver() {
    if (_loading) {
      return const SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.mega,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        sliver: SliverToBoxAdapter(child: AmoriLoader()),
      );
    }
    if (_error) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AmoriErrorState(
          title: '매칭을 불러오지 못했어요',
          message: '네트워크 상태를 확인하고 다시 시도해 주세요.',
          onRetry: _load,
        ),
      );
    }
    if (_matches.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AmoriEmptyState(
          icon: Icons.favorite_border_rounded,
          title: '아직 검증된 인연이 없어요',
          message: '에이전트가 소개팅을 다녀오면 여기에 나타나요',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      sliver: SliverList.separated(
        itemCount: _matches.length,
        separatorBuilder: (_, _) => AppSpacing.vMd,
        itemBuilder: (_, i) =>
            _MatchCard(match: _matches[i], onTap: () => _onMatchTap(_matches[i])),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: 56,
        child: Row(children: [Text('검증된 인연', style: AppTypography.titleLarge)]),
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
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                      image: (m.photoUrl?.isNotEmpty ?? false)
                          ? DecorationImage(
                              image: NetworkImage(m.photoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (m.photoUrl?.isNotEmpty ?? false)
                        ? null
                        : Text(
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
                      m.name,
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
