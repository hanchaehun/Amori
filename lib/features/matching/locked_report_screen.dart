import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/state/profile_store.dart';
import '../../core/state/purchase_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_states.dart';
import '../../core/widgets/photo_viewer.dart';
import '../../data/dummy/matches.dart';
import '../../data/repositories/match_repository.dart';

class LockedReportScreen extends StatefulWidget {
  const LockedReportScreen({super.key, this.matchId});

  final String? matchId;

  @override
  State<LockedReportScreen> createState() => _LockedReportScreenState();
}

class _LockedReportScreenState extends State<LockedReportScreen> {
  String? get matchId => widget.matchId;

  // 실데이터 — 잠금 화면이라도 케미 점수·상대 이니셜·사진은 진짜를 보여준다
  // (0점 플레이스홀더는 신뢰를 깎는다 — 2026-07-15 제품 결정).
  // 로드 전/실패엔 0을 그리지 않는다: 점수는 성공 후에만, 실패는 에러 상태로 분기.
  bool _loading = true;
  bool _hasError = false;
  int? _score; // null이면 아직 실점수 없음 → 0 대신 스켈레톤
  String _partnerInitial = '?';
  String _partnerName = '상대';
  String? _partnerPhotoUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = matchId;
    if (id == null || id.isEmpty) {
      // 매치 id 없는 데모 진입 — 실점수가 없으니 0점 대신 스켈레톤만 유지.
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }

    // 이미 구매·구독한 사용자에겐 잠금 티저·가격 CTA를 다시 보여주지 않고
    // 곧바로 전체 리포트로 보낸다(재잠금 방지).
    final canView = await PurchaseStore.instance.canViewReport(id);
    if (!mounted) return;
    if (canView) {
      context.pushReplacement('${AppRoutes.fullReport}?id=$id');
      return;
    }

    try {
      final repository = MatchRepository();
      final results = await Future.wait<Object?>([
        repository.listMatches().then<Object?>((s) => s, onError: (_) => null),
        repository
            .getPartnerProfile(id)
            .then<Object?>((p) => p, onError: (_) => null),
      ]);
      if (!mounted) return;
      final summaries = results[0] as List<MatchSummary>?;
      final partner = results[1] as PartnerProfile?;
      final match = summaries?.where((s) => s.matchId == id).firstOrNull;
      if (match == null) {
        // 케미 점수를 못 받았다 — 0점을 지어내지 않고 에러로 재시도를 유도.
        setState(() {
          _loading = false;
          _hasError = true;
        });
        return;
      }
      final name = match.partnerName ?? '';
      setState(() {
        _score = match.reportScore ?? match.score?.round();
        _partnerInitial = name.isEmpty ? '?' : name.substring(0, 1);
        if (name.isNotEmpty) _partnerName = name;
        _partnerPhotoUrl = partner?.photoUrl;
        _loading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      // 네트워크 실패 — 0점을 남기지 않고 에러 상태로 전환.
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  void _reload() {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    _load();
  }

  void _onClose(BuildContext context) {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.matchList);
    }
  }

  /// 이미 구독·단건 구매한 사용자는 페이월 없이 바로 리포트로.
  Future<void> _onUnlock(BuildContext context) async {
    HapticFeedback.lightImpact();
    final id = matchId ?? kPlaceholderMatch.id;
    final canView = await PurchaseStore.instance.canViewReport(id);
    if (!context.mounted) return;
    if (canView) {
      context.push('${AppRoutes.fullReport}?id=$id');
    } else {
      context.push('${AppRoutes.paywall}?id=$id');
    }
  }

  Future<void> _onSubscribe(BuildContext context) async {
    HapticFeedback.selectionClick();
    return _onUnlock(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.coral,
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.coral),
          child: SafeArea(
            child: Column(
              children: [
                _Header(onClose: () => _onClose(context)),
                Expanded(
                  child: _hasError
                      ? AmoriErrorState(
                          title: '리포트를 불러오지 못했어요',
                          message: '잠시 후 다시 시도해 주세요.',
                          onRetry: _reload,
                        )
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.md,
                          ),
                          children: [
                            _Hero(
                              myInitial: '나',
                              themInitial: _partnerInitial,
                              themName: _partnerName,
                              score: _score,
                              loading: _loading,
                              myPhotoUrl:
                                  ProfileStore.instance.profile?.photoUrl,
                              themPhotoUrl: _partnerPhotoUrl,
                            ),
                            AppSpacing.vXl,
                            const _SectionLabel(
                              text: '더 자세한 인사이트',
                              trailingLock: true,
                            ),
                            AppSpacing.vSm,
                            const _LockedInsightCard(
                              title: 'AI 대화 로그 요약',
                              lines: 3,
                            ),
                            AppSpacing.vSm,
                            const _LockedInsightCard(
                              title: '첫 만남 추천 가이드',
                              lines: 2,
                            ),
                            AppSpacing.vXl,
                          ],
                        ),
                ),
                if (!_hasError)
                  _BottomCta(
                    onUnlock: () => _onUnlock(context),
                    onSubscribe: () => _onSubscribe(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: onClose,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.coral,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '리포트 완성',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.coral,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.myInitial,
    required this.themInitial,
    required this.score,
    this.loading = false,
    this.themName,
    this.myPhotoUrl,
    this.themPhotoUrl,
  });

  final String myInitial;
  final String themInitial;
  final String? themName;
  final int? score; // null이면 아직 실점수 없음 → 0 대신 스켈레톤/로더
  final bool loading;
  final String? myPhotoUrl;
  final String? themPhotoUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AvatarRing(initial: myInitial, photoUrl: myPhotoUrl),
            const SizedBox(width: 16),
            const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            _AvatarRing(
              initial: themInitial,
              photoUrl: themPhotoUrl,
              caption: themName,
            ),
          ],
        ),
        AppSpacing.vMd,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (score != null)
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 88,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -3,
                ),
              )
            else
              // 로딩·데이터 없음 — 0점을 그리지 않고 로더/스켈레톤으로 대체.
              Container(
                width: 108,
                height: 62,
                margin: const EdgeInsets.only(bottom: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : null,
              ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '/100',
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        AppSpacing.vXs,
        Text(
          '케미스트리 점수',
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.initial, this.photoUrl, this.caption});
  final String initial;
  final String? photoUrl; // 있으면 사진, 없으면 이니셜
  final String? caption; // 사진 확대 뷰어의 이름 표시

  Widget _initialText() {
    return Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 22,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    // 사진은 Image.network로 그려 로드 실패 시 이니셜로 폴백한다
    // (DecorationImage는 실패해도 빈 원만 남아 신뢰를 깎았다).
    final ring = Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: hasPhoto
          ? Image.network(
              photoUrl!,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => _initialText(),
            )
          : _initialText(),
    );
    if (!hasPhoto) return ring;
    return GestureDetector(
      onTap: () => showPhotoViewer(
        context,
        photoUrl: photoUrl!,
        caption: caption,
        heroTag: 'locked-photo-$photoUrl',
      ),
      child: Hero(tag: 'locked-photo-$photoUrl', child: ring),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.trailingLock = false});
  final String text;
  final bool trailingLock;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: AppTypography.titleMedium.copyWith(
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        if (trailingLock) ...[
          const Spacer(),
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ],
      ],
    );
  }
}

class _LockedInsightCard extends StatelessWidget {
  const _LockedInsightCard({required this.title, required this.lines});

  final String title;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.rMd,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: AppRadius.rMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.label.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < lines; i++)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                          child: Container(
                            height: 8,
                            width: i.isEven ? double.infinity : 200,
                            decoration: BoxDecoration(
                              color: AppColors.ink100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: AppRadius.rMd,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 22,
                color: AppColors.coral,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCta extends StatefulWidget {
  const _BottomCta({required this.onUnlock, required this.onSubscribe});

  final VoidCallback onUnlock;
  final VoidCallback onSubscribe;

  @override
  State<_BottomCta> createState() => _BottomCtaState();
}

class _BottomCtaState extends State<_BottomCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          AnimatedScale(
            scale: _pressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onUnlock,
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.rMd,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: AppColors.coral,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '전체 리포트 열람하기',
                      style: AppTypography.button.copyWith(
                        color: AppColors.coral,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 14,
                      color: AppColors.coral.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₩1,000',
                      style: AppTypography.button.copyWith(
                        color: AppColors.coral,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSubscribe,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '또는 프리미엄 구독으로 무제한 열람',
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
