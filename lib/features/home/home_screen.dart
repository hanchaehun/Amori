import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_routes.dart';
import '../../core/state/notification_store.dart';
import '../../core/state/profile_store.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_tab_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/gradient_text.dart';
import '../../data/backend/local_notifications.dart';
import '../../data/repositories/match_repository.dart';
import '../../data/repositories/persona_repository.dart';

enum _StageState { done, active, locked }

/// 홈 히어로 카드의 상태 — listMatches 실데이터에서 도출한다.
enum _HeroMode { loading, live, completed, idle, offline }

class _HeroData {
  const _HeroData(
    this.mode, {
    this.partnerName,
    this.liveCount = 0,
    this.turnCount = 0,
    this.completedCount = 0,
  });

  final _HeroMode mode;
  final String? partnerName; // 라이브 중인 상대
  final int liveCount; // 동시에 송출 중인 소개팅 수
  final int turnCount; // 라이브 매치의 지금까지 공개된 턴 수
  final int completedCount; // 오늘 다녀온(완료) 소개팅 수
}

class _StageItem {
  const _StageItem(this.icon, this.label, this.state);
  final IconData icon;
  final String label;
  final _StageState state;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository, this.personaRepository});

  /// 테스트에서 가짜 리포지토리를 주입한다. 기본은 실 BFF.
  final MatchRepository? repository;
  final PersonaRepository? personaRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MatchRepository _repo;
  late final PersonaRepository _personaRepo;
  _HeroData _hero = const _HeroData(_HeroMode.loading);
  DailyPersonaStatus? _dailyStatus;
  bool _advancingDay = false;

  bool get _showDailyQuestion =>
      _dailyStatus != null &&
      !_dailyStatus!.completedToday &&
      _dailyStatus!.scenarioCode != null;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MatchRepository();
    _personaRepo = widget.personaRepository ?? PersonaRepository();
    _load();
  }

  Future<void> _load() async {
    final dailyStatusFuture = _personaRepo
        .fetchDailyStatus()
        .then<DailyPersonaStatus?>((status) => status)
        .catchError((_) => null);
    try {
      final matches = await _repo.listMatches();
      if (!mounted) return;
      setState(() => _hero = _summarize(matches));
    } catch (error) {
      if (!mounted) return;
      // 백엔드 미연결(오프라인/dev 미설정) — 데모용 정적 상태로.
      setState(() => _hero = const _HeroData(_HeroMode.offline));
    }
    final dailyStatus = await dailyStatusFuture;
    if (mounted) {
      setState(() => _dailyStatus = dailyStatus);
    }
    await _refreshNotifications(dailyStatus);
  }

  /// 알림 배지 계산 + 프로필 미완성 시 하루 1회 폰 알림 예약.
  Future<void> _refreshNotifications(DailyPersonaStatus? dailyStatus) async {
    await ProfileStore.instance.refresh();
    final profile = ProfileStore.instance.profile;
    final dailyCode =
        (dailyStatus != null && !dailyStatus.completedToday)
        ? dailyStatus.scenarioCode
        : null;
    await NotificationStore.instance.refresh(
      profile: profile,
      dailyScenarioCode: dailyCode,
    );

    // 폰 알림 — 프로필 넛지(데일리 제외)가 남아 있으면 하루 1회 리마인드.
    final nudges = NotificationStore.instance.items
        .where((n) => n.id != 'daily')
        .toList();
    await LocalNotifications.instance.requestPermission();
    if (nudges.isNotEmpty) {
      await LocalNotifications.instance.scheduleProfileNudge(
        title: nudges.first.title,
        body: '프로필이 완성될수록 매칭이 정확해져요',
      );
    } else {
      await LocalNotifications.instance.cancelProfileNudge();
    }
  }

  /// 라이브 송출 중인 매치가 있으면 그걸, 없으면 완료 건수/대기 상태.
  _HeroData _summarize(List<MatchSummary> matches) {
    final live = matches.where((m) => m.agentLive).toList();
    if (live.isNotEmpty) {
      final m = live.first;
      return _HeroData(
        _HeroMode.live,
        partnerName: m.partnerName,
        liveCount: live.length,
        turnCount: m.turnCount,
      );
    }
    final completed = matches.where((m) => !m.failed).length;
    if (completed > 0) {
      return _HeroData(_HeroMode.completed, completedCount: completed);
    }
    return const _HeroData(_HeroMode.idle);
  }

  void _openConnect() {
    // 히어로 카드는 별도 화면을 띄우지 않고 '연결'(진행 중) 탭으로 넘어간다 —
    // 하단 탭바에서 연결을 누른 것과 동일하게 동작한다(inbox 기본 탭=진행 중).
    context.go(AppRoutes.inbox);
  }

  void _openDailyQuestion() {
    final code = _dailyStatus?.scenarioCode;
    if (code == null) return;
    context.push(AppRoutes.dailyScenario(code));
  }

  Future<void> _advanceDayForDev() async {
    if (_advancingDay) return;
    setState(() => _advancingDay = true);
    try {
      final status = await _personaRepo.advanceDayForDev();
      if (!mounted) return;
      setState(() {
        _dailyStatus = status;
        _advancingDay = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('개발 날짜를 하루 넘겼어요.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _advancingDay = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('개발 날짜 변경 실패: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bottomBar: const AmoriTabBar(active: AmoriTab.home),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _TopBar()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _Greeting(name: '회원'),
                AppSpacing.vLg,
                _HeroAICard(data: _hero, onTap: _openConnect),
                if (_showDailyQuestion) ...[
                  AppSpacing.vMd,
                  _DailyQuestionCard(
                    answerCount: _dailyStatus!.answerCount,
                    onTap: _openDailyQuestion,
                  ),
                ],
                if (AppConfig.devUid != null) ...[
                  AppSpacing.vSm,
                  _DevAdvanceDayButton(
                    isLoading: _advancingDay,
                    onPressed: _advanceDayForDev,
                  ),
                ],
                AppSpacing.vXl,
                const _StatusTracker(
                  stages: [
                    _StageItem(
                      Icons.check_rounded,
                      '페르소나 생성',
                      _StageState.done,
                    ),
                    _StageItem(
                      Icons.sync_rounded,
                      'Pre-Dating',
                      _StageState.active,
                    ),
                    _StageItem(
                      Icons.description_outlined,
                      '리포트 발행',
                      _StageState.locked,
                    ),
                    _StageItem(
                      Icons.favorite_outline_rounded,
                      '만남 연결',
                      _StageState.locked,
                    ),
                  ],
                ),
                AppSpacing.vXl,
                _ReportSection(
                  onHeaderTap: () => context.push(AppRoutes.matchList),
                  onCardTap: () => context.push(AppRoutes.lockedReport),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  Future<void> _openNotifications(BuildContext context) async {
    HapticFeedback.selectionClick();
    final store = NotificationStore.instance;
    await store.markSeen();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _NotificationSheet(items: store.items),
    );
  }

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
            GradientText(
              'amori',
              style: AppTypography.titleLarge.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const Spacer(),
            ListenableBuilder(
              listenable: NotificationStore.instance,
              builder: (context, _) => _BellButton(
                count: NotificationStore.instance.unseenCount,
                onTap: () => _openNotifications(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 24,
              color: AppColors.ink900,
            ),
            if (count > 0)
              Positioned(
                top: 6,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 15),
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({required this.items});

  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.ink300,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            Text('알림', style: AppTypography.titleLarge),
            AppSpacing.vMd,
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: Text(
                    '새 알림이 없어요',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink500,
                    ),
                  ),
                ),
              )
            else
              for (final item in items) ...[
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                    context.push(item.route);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
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
                        Text(item.emoji, style: const TextStyle(fontSize: 22)),
                        AppSpacing.hMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.ink900,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.body,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.ink500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.ink300,
                        ),
                      ],
                    ),
                  ),
                ),
                AppSpacing.vXs,
              ],
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '안녕하세요, $name님 👋',
          style: AppTypography.titleXl.copyWith(fontSize: 24),
        ),
        AppSpacing.vXxs,
        Text(
          '오늘도 AI가 열심히 일하고 있어요',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.ink500),
        ),
      ],
    );
  }
}

class _HeroAICard extends StatefulWidget {
  const _HeroAICard({required this.data, required this.onTap});
  final _HeroData data;
  final VoidCallback onTap;

  @override
  State<_HeroAICard> createState() => _HeroAICardState();
}

class _HeroAICardState extends State<_HeroAICard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    final c = _content(widget.data);
    return AnimatedScale(
      scale: _pressed ? 0.99 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.rXl,
            boxShadow: amori.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LiveBadge(label: c.badgeLabel, dotColor: c.badgeColor),
              AppSpacing.vMd,
              Text(
                c.title,
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.ink900,
                  fontSize: 22,
                  height: 1.3,
                ),
              ),
              AppSpacing.vXs,
              Text(
                c.subtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.ink500,
                ),
              ),
              AppSpacing.vMd,
              _HeroProgress(value: c.progress),
              AppSpacing.vXs,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '자세히 보기',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.ink500,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _HeroContent _content(_HeroData d) {
    switch (d.mode) {
      case _HeroMode.live:
        final name = (d.partnerName == null || d.partnerName!.isEmpty)
            ? '상대'
            : d.partnerName!;
        final sub = d.liveCount > 1
            ? '지금 ${d.liveCount}건의 소개팅이 오가고 있어요'
            : (d.turnCount > 0
                  ? '지금 ${d.turnCount}번째 대화가 오가고 있어요'
                  : '에이전트가 막 대화를 시작했어요');
        return _HeroContent(
          title: '$name-AI와\n소개팅 중',
          subtitle: sub,
          badgeLabel: '실시간 진행 중',
          badgeColor: AppColors.danger,
          progress: (d.turnCount / 8).clamp(0.12, 0.92),
        );
      case _HeroMode.completed:
        return _HeroContent(
          title: '오늘의 소개팅\n${d.completedCount}건 완료',
          subtitle: '케미 리포트를 확인해 보세요',
          badgeLabel: '완료',
          badgeColor: AppColors.mint,
          progress: 1.0,
        );
      case _HeroMode.idle:
        return const _HeroContent(
          title: '곧 소개팅을\n다녀올게요',
          subtitle: '에이전트가 하루 중 알아서 진행해요',
          badgeLabel: '대기 중',
          badgeColor: AppColors.ink300,
          progress: 0.06,
        );
      case _HeroMode.offline:
        return const _HeroContent(
          title: '소개팅 시뮬레이션\n진행 중',
          subtitle: '에이전트가 열심히 일하고 있어요',
          badgeLabel: 'AI 활동 중',
          badgeColor: AppColors.danger,
          progress: 0.65,
        );
      case _HeroMode.loading:
        return const _HeroContent(
          title: '소개팅 현황\n불러오는 중',
          subtitle: '잠시만요...',
          badgeLabel: 'AI 활동 중',
          badgeColor: AppColors.ink300,
          progress: 0.2,
        );
    }
  }
}

class _HeroContent {
  const _HeroContent({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    required this.progress,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final double progress;
}

class _DevAdvanceDayButton extends StatelessWidget {
  const _DevAdvanceDayButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.fast_forward_rounded, size: 18),
        label: Text(isLoading ? '넘기는 중' : '개발: 다음날로 넘기기'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB5780A),
          side: BorderSide(color: AppColors.warning.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DailyQuestionCard extends StatelessWidget {
  const _DailyQuestionCard({required this.answerCount, required this.onTap});

  final int? answerCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final countLabel = answerCount == null ? '답변 보완' : '누적 $answerCount문항';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 1문항',
                    style: AppTypography.label.copyWith(
                      color: AppColors.ink900,
                      fontSize: 15,
                    ),
                  ),
                  AppSpacing.vXxs,
                  Text(
                    '$countLabel · 에이전트 업데이트',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ink500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.ink500,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label, required this.dotColor});

  final String label;
  final Color dotColor;

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
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroProgress extends StatelessWidget {
  const _HeroProgress({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusTracker extends StatelessWidget {
  const _StatusTracker({required this.stages});
  final List<_StageItem> stages;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stages.length; i++) ...[
            _StageColumn(stage: stages[i]),
            if (i < stages.length - 1)
              Expanded(
                child: _Connector(
                  filled:
                      stages[i].state == _StageState.done &&
                      stages[i + 1].state != _StageState.locked,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({required this.stage});
  final _StageItem stage;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    final isLocked = stage.state == _StageState.locked;
    final isActive = stage.state == _StageState.active;

    Color labelColor;
    FontWeight labelWeight;
    if (isActive) {
      labelColor = AppColors.primary;
      labelWeight = FontWeight.w800;
    } else if (isLocked) {
      labelColor = AppColors.ink300;
      labelWeight = FontWeight.w500;
    } else {
      labelColor = AppColors.ink900;
      labelWeight = FontWeight.w800;
    }

    return SizedBox(
      width: 56,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isLocked ? null : amori.primaryGradient,
              color: isLocked ? Colors.white : null,
              border: isLocked
                  ? Border.all(color: AppColors.ink100, width: 1.5)
                  : null,
              boxShadow: isActive ? amori.glowShadow : const [],
            ),
            child: Icon(
              stage.icon,
              size: 18,
              color: isLocked ? AppColors.ink300 : Colors.white,
            ),
          ),
          AppSpacing.vXs,
          Text(
            stage.label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: labelColor,
              fontWeight: labelWeight,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 17),
      child: filled
          ? Container(height: 2, color: AppColors.primary)
          : CustomPaint(
              size: const Size(double.infinity, 2),
              painter: _DashedLinePainter(),
            ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink100
      ..strokeWidth = 1.5;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1), Offset(x + dashWidth, 1), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.onHeaderTap, required this.onCardTap});

  final VoidCallback onHeaderTap;
  final VoidCallback onCardTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onHeaderTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  '리포트 준비 중',
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.ink500,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        AppSpacing.vSm,
        _LockedMatchCard(onTap: onCardTap),
      ],
    );
  }
}

class _LockedMatchCard extends StatefulWidget {
  const _LockedMatchCard({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_LockedMatchCard> createState() => _LockedMatchCardState();
}

class _LockedMatchCardState extends State<_LockedMatchCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.99 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.rMd,
            border: Border.all(color: AppColors.ink100, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '상',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.ink700,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상대',
                      style: AppTypography.titleMedium.copyWith(fontSize: 15),
                    ),
                    AppSpacing.vXxs,
                    Text(
                      '케미스트리 점수 확인 대기 중',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.lock_rounded, color: AppColors.ink300, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
