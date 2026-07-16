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
  Future<List<MatchProfile>>? _matchFuture;

  @override
  void initState() {
    super.initState();
    if (AmoriBackend().isAuthenticated) {
      _matchFuture = MatchRepository().listMatches().then((summaries) {
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
        return verified;
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
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _TopBar()),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverToBoxAdapter(child: _VerifiedBanner()),
            ),
            _MatchListSliver(future: _matchFuture, onTap: _onMatchTap),
          ],
        ),
      ),
    );
  }
}

class _MatchListSliver extends StatelessWidget {
  const _MatchListSliver({required this.future, required this.onTap});

  final Future<List<MatchProfile>>? future;
  final ValueChanged<MatchProfile> onTap;

  @override
  Widget build(BuildContext context) {
    // 미로그인 상태: 아직 매칭이 없다는 빈 상태.
    if (future == null) {
      return const _EmptySliver();
    }

    return FutureBuilder<List<MatchProfile>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _EmptySliver();
        final profiles = snapshot.data;
        if (profiles == null) {
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
        if (profiles.isEmpty) return const _EmptySliver();
        return _cards(profiles);
      },
    );
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

class _EmptySliver extends StatelessWidget {
  const _EmptySliver();

  @override
  Widget build(BuildContext context) {
    return const SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      sliver: SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 48,
                color: AppColors.ink300,
              ),
              SizedBox(height: 12),
              Text('아직 검증된 인연이 없어요', style: TextStyle(color: AppColors.ink500)),
              SizedBox(height: 4),
              Text(
                '에이전트가 소개팅을 다녀오면 여기에 나타나요',
                style: TextStyle(color: AppColors.ink300, fontSize: 12),
              ),
            ],
          ),
        ),
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
