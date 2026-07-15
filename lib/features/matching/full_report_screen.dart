import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/state/agent_session_store.dart';
import '../../core/state/profile_store.dart';
import '../../data/models/compatibility_report.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/photo_viewer.dart';
import '../../data/dummy/matches.dart';
import '../../data/repositories/match_repository.dart';
import '../../data/repositories/report_repository.dart';

class FullReportScreen extends StatefulWidget {
  const FullReportScreen({super.key, this.matchId});

  final String? matchId;

  @override
  State<FullReportScreen> createState() => _FullReportScreenState();
}

class _FullReportScreenState extends State<FullReportScreen> {
  int _tabIndex = 0;

  // 대화 로그 탭은 제거(2026-07-15 제품 결정) — 대화는 연결 탭에서 이미 보고 오고,
  // 리포트는 '요약 → 상대가 누구인지 → 만나면 뭘 할지'로 결정을 돕는 화면이다.
  static const _tabs = ['요약', '상대 프로필', '첫 만남 가이드'];

  bool _loading = true;
  CompatibilityReport? _fetched;
  PartnerProfile? _partner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 리포트·상대 프로필을 백엔드에서 병렬 로드 (실데이터 배선).
  /// 개별 실패는 폴백(세션 스토어·기본 문구)으로 흡수한다.
  Future<void> _load() async {
    final id = widget.matchId;
    if (id == null || id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final results = await Future.wait<Object?>([
      ReportRepository().fetch(id).then<Object?>((r) => r, onError: (_) => null),
      MatchRepository()
          .getPartnerProfile(id)
          .then<Object?>((p) => p, onError: (_) => null),
    ]);
    if (!mounted) return;
    setState(() {
      _fetched = results[0] as CompatibilityReport?;
      _partner = results[1] as PartnerProfile?;
      _loading = false;
    });
  }

  CompatibilityReport? get _report =>
      _fetched ?? AgentSessionStore.instance.report;

  String get _partnerName => _partner?.displayName ?? '상대';

  MatchProfile get _match => widget.matchId == null
      ? kPlaceholderMatch
      : MatchProfile(
          id: widget.matchId!,
          initial: _partnerName.isEmpty ? '?' : _partnerName.substring(0, 1),
          name: _partnerName,
          age: _partner?.age ?? 0,
          score: _report?.score ?? 0,
          values: 0,
          humor: 0,
          communication: 0,
        );

  int get _score => _report?.score ?? _match.score;

  void _onShare() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('리포트 공유 — 다음 턴 작업 예정')));
  }

  void _onRequestMeet() {
    HapticFeedback.lightImpact();
    context.push('${AppRoutes.meetRequestSend}?id=${_match.id}');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: BackAppBar(
        title: '리포트',
        trailing: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(
            Icons.ios_share_rounded,
            size: 20,
            color: AppColors.ink900,
          ),
          onPressed: _onShare,
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            )
          : Column(
        children: [
          _HeroSection(
            match: _match,
            score: _score,
            myPhotoUrl: ProfileStore.instance.profile?.photoUrl,
            partnerPhotoUrl: _partner?.photoUrl,
          ),
          _TabBar(
            active: _tabIndex,
            tabs: _tabs,
            onChange: (i) => setState(() => _tabIndex = i),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey(_tabIndex),
                child: switch (_tabIndex) {
                  0 => _SummaryTab(match: _match, report: _report),
                  1 => _PartnerProfileTab(partner: _partner),
                  _ => _GuideTab(match: _match, report: _report),
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
              label: '오프라인 만남 신청하기',
              trailing: const GradientArrowTrailing(),
              onPressed: _onRequestMeet,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.match,
    required this.score,
    this.myPhotoUrl,
    this.partnerPhotoUrl,
  });
  final MatchProfile match;
  final int score;
  final String? myPhotoUrl;
  final String? partnerPhotoUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          _Avatar(initial: '나', photoUrl: myPhotoUrl),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.favorite_rounded,
              size: 16,
              color: AppColors.coral,
            ),
          ),
          _Avatar(initial: match.initial, photoUrl: partnerPhotoUrl),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$score점',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.coral,
                        height: 1.0,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        '/100',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.ink300,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '나 × ${match.name}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_open_rounded,
                  size: 12,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  '잠금 해제됨',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, this.photoUrl});
  final String initial;
  final String? photoUrl; // 있으면 사진, 없으면 이니셜

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(photoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasPhoto
          ? null
          : Text(
              initial,
              style: AppTypography.label.copyWith(
                color: AppColors.ink700,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.active,
    required this.tabs,
    required this.onChange,
  });

  final int active;
  final List<String> tabs;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink100, width: 1)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChange(i);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == active
                            ? AppColors.coral
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: AppTypography.label.copyWith(
                      color: i == active ? AppColors.coral : AppColors.ink500,
                      fontWeight: i == active
                          ? FontWeight.w800
                          : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.match, this.report});
  final MatchProfile match;
  final CompatibilityReport? report;

  static const _fallbackFindings = [
    _Finding('🎵', '둘 다 인디 음악을 즐겨 들음', '취향 키워드: 잔잔한 멜로디, 어쿠스틱 기반'),
    _Finding('📚', '비슷한 독서 취향', '에세이·소설을 주로 읽고, 자기계발서엔 거리감 있음'),
    _Finding('🌱', '가치관: 안정성과 자유로움 균형 추구', '둘 다 큰 변화보다는 점진적 성장을 선호'),
  ];

  @override
  Widget build(BuildContext context) {
    final findings = report != null
        ? report!.findings
            .map((f) => _Finding(f.emoji, f.title, f.detail))
            .toList()
        : _fallbackFindings;

    final warnings = report?.warnings ?? [];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      children: [
        Text(
          'AI가 발견한 공통점',
          style: AppTypography.titleMedium.copyWith(fontSize: 17),
        ),
        AppSpacing.vMd,
        for (final f in findings) ...[
          _FindingCard(finding: f),
          AppSpacing.vSm,
        ],
        AppSpacing.vMd,
        Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              '주의할 점',
              style: AppTypography.titleMedium.copyWith(fontSize: 17),
            ),
          ],
        ),
        AppSpacing.vMd,
        if (warnings.isNotEmpty)
          for (final w in warnings) ...[
            _WarningCard(title: w.title, body: w.detail),
            AppSpacing.vSm,
          ]
        else
          const _WarningCard(
            title: '대화 페이스 차이',
            body: '상대가 다소 빠른 편 — 충분히 듣고 답하는 시간을 가져보세요',
          ),
      ],
    );
  }
}

class _Finding {
  const _Finding(this.emoji, this.title, this.sub);
  final String emoji;
  final String title;
  final String sub;
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});
  final _Finding finding;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(finding.emoji, style: const TextStyle(fontSize: 26)),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: AppTypography.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  finding.sub,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.ink500,
                    height: 1.5,
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

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 22)),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.ink700,
                    height: 1.5,
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

class _PartnerProfileTab extends StatelessWidget {
  const _PartnerProfileTab({required this.partner});

  /// 매칭된 쌍에게만 서버가 공개하는 최소 프로필 — 사진·나이·지역·MBTI·한줄 소개.
  final PartnerProfile? partner;

  @override
  Widget build(BuildContext context) {
    final p = partner;
    if (p == null) {
      return Center(
        child: Text(
          '상대 프로필을 불러오지 못했어요',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.ink500),
        ),
      );
    }
    final photo = p.photoUrl;
    final chips = <String>[
      if (p.region != null && p.region!.isNotEmpty) '📍 ${p.region}',
      if (p.mbti != null && p.mbti!.isNotEmpty) p.mbti!,
    ];
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      children: [
        Center(
          child: GestureDetector(
            onTap: (photo != null && photo.isNotEmpty)
                ? () => showPhotoViewer(
                    context,
                    photoUrl: photo,
                    caption: p.age != null
                        ? '${p.displayName}, ${p.age}'
                        : p.displayName,
                    heroTag: 'partner-photo-$photo',
                  )
                : null,
            child: Hero(
              tag: 'partner-photo-${photo ?? p.displayName}',
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  image: (photo != null && photo.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(photo),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (photo == null || photo.isEmpty)
                    ? Text(
                        p.displayName.isEmpty
                            ? '?'
                            : p.displayName.substring(0, 1),
                        style: AppTypography.titleXl.copyWith(
                          color: AppColors.coral,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        AppSpacing.vMd,
        Center(
          child: Text(
            p.age != null ? '${p.displayName}, ${p.age}' : p.displayName,
            style: AppTypography.titleLarge,
          ),
        ),
        if (chips.isNotEmpty) ...[
          AppSpacing.vSm,
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final chip in chips)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    chip,
                    style: AppTypography.label.copyWith(
                      color: AppColors.ink700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (p.bio != null && p.bio!.isNotEmpty) ...[
          AppSpacing.vLg,
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '"${p.bio}"',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink700,
                height: 1.5,
              ),
            ),
          ),
        ],
        AppSpacing.vLg,
        Center(
          child: Text(
            '사진과 프로필은 매칭된 상대에게만 공개돼요',
            style: AppTypography.caption.copyWith(color: AppColors.ink300),
          ),
        ),
      ],
    );
  }
}

class _GuideTab extends StatelessWidget {
  const _GuideTab({required this.match, this.report});
  final MatchProfile match;
  final CompatibilityReport? report;

  static const _fallbackPlaces = [
    _GuideItem('🍵', '조용한 동네 카페', '대화 페이스에 맞는 차분한 분위기'),
    _GuideItem('🌳', '연남동 산책 코스', '걸으며 자연스럽게 대화 — 첫 만남 부담 ↓'),
    _GuideItem('🖼', '작은 독립 전시', '취향 공통분모(독서·예술)를 자연스럽게 공유'),
  ];

  static const _fallbackStarters = [
    '"최근에 본 전시 중에 가장 기억에 남는 거 있어요?"',
    '"인디 추천해주실 만한 거 있나요? 요즘 새로 듣고 싶은데요."',
    '"여행 가서 꼭 들르는 카페 같은 거 있어요?"',
  ];

  @override
  Widget build(BuildContext context) {
    final places = report != null
        ? report!.recommendedPlaces
            .map((p) => _GuideItem(p.emoji, p.title, p.detail))
            .toList()
        : _fallbackPlaces;

    final starters = report?.conversationStarters.isNotEmpty == true
        ? report!.conversationStarters
        : _fallbackStarters;

    final tip = report?.tip.isNotEmpty == true
        ? report!.tip
        : '상대는 응답 속도가 빠른 편이에요. 침묵을 어색해하지 마세요 — 본인 페이스로 답해도 충분히 매력적으로 받아들여집니다.';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      children: [
        Text('추천 장소', style: AppTypography.titleMedium.copyWith(fontSize: 17)),
        AppSpacing.vMd,
        for (final p in places) ...[_GuideCard(item: p), AppSpacing.vSm],
        AppSpacing.vLg,
        Text('대화 시작법', style: AppTypography.titleMedium.copyWith(fontSize: 17)),
        AppSpacing.vMd,
        for (final s in starters) ...[
          _StarterCard(text: s),
          AppSpacing.vSm,
        ],
        AppSpacing.vLg,
        _TipCard(title: '한 가지 팁', body:
              tip),
      ],
    );
  }
}

class _GuideItem {
  const _GuideItem(this.emoji, this.title, this.sub);
  final String emoji;
  final String title;
  final String sub;
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.item});
  final _GuideItem item;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 24)),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.sub,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.ink500,
                    height: 1.5,
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

class _StarterCard extends StatelessWidget {
  const _StarterCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.06),
        borderRadius: AppRadius.rSm,
        border: Border.all(
          color: AppColors.coral.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.ink900,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 22)),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.ink700,
                    height: 1.5,
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
