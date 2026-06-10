import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/state/agent_session_store.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../data/models/compatibility_report.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/dummy/matches.dart';

class FullReportScreen extends StatefulWidget {
  const FullReportScreen({super.key, this.matchId});

  final String? matchId;

  @override
  State<FullReportScreen> createState() => _FullReportScreenState();
}

class _FullReportScreenState extends State<FullReportScreen> {
  int _tabIndex = 0;

  static const _tabs = ['요약', '대화 로그', '첫 만남 가이드'];

  MatchProfile get _match =>
      widget.matchId == null ? kMatches.first : findMatchById(widget.matchId!);

  CompatibilityReport? get _report => AgentSessionStore.instance.report;
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
      body: Column(
        children: [
          _HeroSection(match: _match, score: _score),
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
                  1 => _ChatLogTab(themInitial: _match.initial),
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
  const _HeroSection({required this.match, required this.score});
  final MatchProfile match;
  final int score;

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
          _Avatar(initial: '지'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.favorite_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          _Avatar(initial: match.initial),
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
                        color: AppColors.primary,
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
                  '지은 × ${match.name.substring(1)}',
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
  const _Avatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Text(
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
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: AppTypography.label.copyWith(
                      color: i == active ? AppColors.primary : AppColors.ink500,
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
            body: '민준님이 다소 빠른 편 — 충분히 듣고 답하는 시간을 가져보세요',
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

class _ChatLogTab extends StatelessWidget {
  const _ChatLogTab({required this.themInitial});
  final String themInitial;

  static const _fallbackMessages = [
    _PreviewMsg(true, '안녕하세요! 주말에는 보통 어떻게 보내세요?'),
    _PreviewMsg(false, '저는 주로 성수나 연남 카페에서 책 읽거나, 여행 준비해요.'),
    _PreviewMsg(true, '와 저도 이번에 오사카 다녀왔는데! 음악도 좋아하시나요?'),
    _PreviewMsg(false, '잔잔한 인디 위주로 들어요. 새소년이나 잠비나이 같은.'),
    _PreviewMsg(true, '연애에서 가장 중요하게 생각하는 게 뭐예요?'),
    _PreviewMsg(false, '서로의 일상을 존중하면서도, 함께 있을 때 편안한 거요.'),
  ];

  @override
  Widget build(BuildContext context) {
    // PersonaStore에서 최대 6개 미리보기, 없으면 폴백
    final stored = AgentSessionStore.instance.conversation
        .where((m) => !m.isSystem)
        .take(6)
        .map((m) => _PreviewMsg(m.isMe, m.text))
        .toList();
    final previewMessages = stored.isNotEmpty ? stored : _fallbackMessages;
    final total = AgentSessionStore.instance.conversation.isEmpty
        ? 24
        : AgentSessionStore.instance.conversation.length;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: AppRadius.rSm,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ink700,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(text: '$total개 메시지 중 '),
                      TextSpan(
                        text: '${previewMessages.length}개 미리보기',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.vLg,
        for (final m in previewMessages) ...[
          _PreviewBubble(message: m),
          AppSpacing.vSm,
        ],
        AppSpacing.vMd,
        Center(
          child: Text(
            '─  실제 시뮬레이션 결과 기반  ─',
            style: AppTypography.caption.copyWith(
              color: AppColors.ink300,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewMsg {
  const _PreviewMsg(this.isMe, this.text);
  final bool isMe;
  final String text;
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.message});
  final _PreviewMsg message;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    final isMe = message.isMe;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          );
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMe ? amori.primaryGradient : null,
            color: isMe ? null : AppColors.surfaceMuted,
            borderRadius: radius,
          ),
          child: Text(
            message.text,
            style: AppTypography.bodyMedium.copyWith(
              color: isMe ? Colors.white : AppColors.ink900,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ),
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
        : '민준님은 응답 속도가 빠른 편이에요. 침묵을 어색해하지 마세요 — 본인 페이스로 답해도 충분히 매력적으로 받아들여집니다.';

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
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.rSm,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
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
