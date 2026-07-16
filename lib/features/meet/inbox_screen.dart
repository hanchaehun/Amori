import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/state/purchase_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_tab_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/exit_guard.dart';
import '../../data/api/api_exception.dart';
import '../../data/dummy/conversations.dart';
import '../../data/repositories/match_repository.dart';

enum _InboxTab { active, scheduled, completed }

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  _InboxTab _tab = _InboxTab.active;

  final MatchRepository _matches = MatchRepository();
  bool _loading = true;

  /// 백엔드 목록을 받아왔는가. false면 더미 폴백 상태 — 수락도 로컬에서만 처리한다.
  bool _fromBackend = false;

  List<Conversation> _active = [];
  List<Conversation> _scheduled = [];
  List<Conversation> _completed = [];

  /// 케미 점수가 75점에 닿지 못한 대화 — 우하단 버튼으로 진입하는 별도 화면에 표시.
  List<FailedMatch> _failed = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 시뮬레이션 결과(GET /matches)로 목록을 채운다. 실패 시 더미 폴백.
  Future<void> _load() async {
    try {
      final items = await _matches.listMatches();
      final convs = items.where((m) => !m.failed).map(_toConversation).toList();
      final failed = items.where((m) => m.failed).map(_toFailedMatch).toList();
      if (!mounted) return;
      setState(() {
        _fromBackend = true;
        _loading = false;
        _active = convs
            .where(
              (c) =>
                  c.status == ConversationStatus.active ||
                  c.status == ConversationStatus.scheduling,
            )
            .toList();
        _scheduled = convs
            .where((c) => c.status == ConversationStatus.scheduled)
            .toList();
        _completed = convs
            .where((c) => c.status == ConversationStatus.completed)
            .toList();
        _failed = failed;
      });
    } catch (e) {
      debugPrint('inbox: GET /matches 실패 — 빈 상태로 표시: $e');
      if (!mounted) return;
      setState(() {
        _fromBackend = false;
        _loading = false;
        _active = [];
        _scheduled = [];
        _completed = [];
        _failed = [];
      });
    }
  }

  Conversation _toConversation(MatchSummary m) {
    final name = (m.partnerName?.isNotEmpty ?? false) ? m.partnerName! : '상대';
    final status = switch (m.status) {
      'scheduled' => ConversationStatus.scheduled,
      'met' => ConversationStatus.completed,
      _ =>
        m.appointmentReady
            ? ConversationStatus.scheduling
            : ConversationStatus.active,
    };
    return Conversation(
      id: m.matchId,
      name: name,
      initial: name.substring(0, 1),
      photoUrl: m.partnerPhotoUrl,
      score: m.score?.round() ?? 0,
      lastMessage: m.lastMessage ?? '에이전트 대화 ${m.turnCount}턴 완료',
      time: _formatTime(m.updatedAt),
      status: status,
      unread: m.appointmentReady && !m.youAccepted,
      appointmentReady: m.appointmentReady,
      appointmentLabel: m.appointmentSlot,
      partnerAccepted: m.partnerAccepted,
      youAccepted: m.youAccepted,
    );
  }

  FailedMatch _toFailedMatch(MatchSummary m) {
    final name = (m.partnerName?.isNotEmpty ?? false) ? m.partnerName! : '상대';
    return FailedMatch(
      id: m.matchId,
      name: name,
      initial: name.substring(0, 1),
      score: m.reportScore ?? m.score?.round() ?? 0,
      reason: m.failureReason ?? '케미 점수가 기준에 닿지 못했어요',
      expiresAt: m.failedExpiresAt,
    );
  }

  static String _formatTime(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(local.year, local.month, local.day)).inDays;
    if (days <= 0) {
      final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final mm = local.minute.toString().padLeft(2, '0');
      return '${local.hour < 12 ? '오전' : '오후'} $h12:$mm';
    }
    return days == 1 ? '어제' : '$days일 전';
  }

  /// '진행 중' 정렬: 약속 조율 완료 카드를 맨 위로.
  List<Conversation> get _sortedActive {
    final list = [..._active];
    list.sort((a, b) {
      if (a.appointmentReady != b.appointmentReady) {
        return a.appointmentReady ? -1 : 1;
      }
      return 0;
    });
    return list;
  }

  List<Conversation> get _conversations => switch (_tab) {
    _InboxTab.active => _sortedActive,
    _InboxTab.scheduled => _scheduled,
    _InboxTab.completed => _completed,
  };

  void _onSearch() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('대화 검색 — 다음 턴 작업 예정')));
  }

  Future<void> _onConversationTap(Conversation c) async {
    HapticFeedback.lightImpact();
    await context.push('${AppRoutes.chat}?id=${c.id}', extra: c);
    // 채팅방에서 약속 취소 등 상태가 바뀌었을 수 있다 — 목록 갱신
    if (mounted && _fromBackend) _load();
  }

  void _openFailed() {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.failedMatches, extra: _failed);
  }

  /// [리포트 먼저 보기] — 수락 전 리포트 열람. 구독자·단건 구매자는 바로,
  /// 아니면 페이월(단건결제/구독 선택)로 보낸다.
  Future<void> _onViewReport(Conversation c) async {
    HapticFeedback.lightImpact();
    final canView = await PurchaseStore.instance.canViewReport(c.id);
    if (!mounted) return;
    if (canView) {
      context.push('${AppRoutes.fullReport}?id=${c.id}');
    } else {
      context.push('${AppRoutes.paywall}?id=${c.id}');
    }
  }

  /// [수락] — 양쪽이 모두 수락하면 '만남 예정'으로 이동한다.
  /// 백엔드 모드면 POST /matches/{id}/accept 결과를 따르고,
  /// 더미 폴백 모드면 로컬 상태로만 처리한다.
  Future<void> _onAccept(Conversation c) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);

    var bothAccepted = c.partnerAccepted;
    if (_fromBackend) {
      try {
        final result = await _matches.acceptMatch(c.id);
        bothAccepted = result.bothAccepted;
      } on ApiException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      if (!mounted) return;
    }

    if (bothAccepted) {
      // 양쪽 수락 성립 → 만남 예정으로 이동
      setState(() {
        _active.removeWhere((x) => x.id == c.id);
        _scheduled = [
          c.copyWith(
            youAccepted: true,
            partnerAccepted: true,
            status: ConversationStatus.scheduled,
          ),
          ..._scheduled,
        ];
      });
      messenger.showSnackBar(
        SnackBar(content: Text('${c.name}님과 만남이 확정됐어요! 만남 예정으로 이동했어요')),
      );
    } else {
      // 내 수락만 기록 — 상대 수락 대기
      setState(() {
        _active = [
          for (final x in _active)
            if (x.id == c.id) x.copyWith(youAccepted: true) else x,
        ];
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('수락했어요. 상대의 수락을 기다리는 중이에요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExitGuard(
      child: AppScaffold(
        bottomBar: const AmoriTabBar(active: AmoriTab.connect),
        body: Stack(
          children: [
            Column(
              children: [
                _TopBar(onSearch: _onSearch),
                _SubTabs(
                  active: _tab,
                  activeCount: _active.length,
                  scheduledCount: _scheduled.length,
                  completedCount: _completed.length,
                  onChange: (t) => setState(() => _tab = t),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _conversations.isEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) =>
                                      SingleChildScrollView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        child: SizedBox(
                                          height: constraints.maxHeight,
                                          child: const _EmptyState(),
                                        ),
                                      ),
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.lg,
                                    AppSpacing.lg,
                                    AppSpacing.xl,
                                  ),
                                  itemCount: _conversations.length,
                                  separatorBuilder: (_, _) => AppSpacing.vSm,
                                  itemBuilder: (_, i) => _ConversationCard(
                                    conversation: _conversations[i],
                                    onTap: () =>
                                        _onConversationTap(_conversations[i]),
                                    onAccept: () =>
                                        _onAccept(_conversations[i]),
                                    onViewReport: () =>
                                        _onViewReport(_conversations[i]),
                                  ),
                                ),
                        ),
                ),
              ],
            ),
            // 닿지 않은 인연(케미 75점 미만) 진입 버튼 — 데이터가 있을 때만 노출
            if (!_loading && _failed.isNotEmpty)
              Positioned(
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: _FailedFab(count: _failed.length, onTap: _openFailed),
              ),
          ],
        ),
      ),
    );
  }
}

class _FailedFab extends StatelessWidget {
  const _FailedFab({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink100, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.heart_broken_rounded,
              size: 26,
              color: AppColors.ink700,
            ),
          ),
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
              child: Text(
                '$count',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSearch});
  final VoidCallback onSearch;

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
            Text('연결된 인연', style: AppTypography.titleLarge),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(
                Icons.search_rounded,
                size: 22,
                color: AppColors.ink900,
              ),
              onPressed: onSearch,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubTabs extends StatelessWidget {
  const _SubTabs({
    required this.active,
    required this.activeCount,
    required this.scheduledCount,
    required this.completedCount,
    required this.onChange,
  });

  final _InboxTab active;
  final int activeCount;
  final int scheduledCount;
  final int completedCount;
  final ValueChanged<_InboxTab> onChange;

  @override
  Widget build(BuildContext context) {
    final entries = <(_InboxTab, String, int)>[
      (_InboxTab.active, '진행 중', activeCount),
      (_InboxTab.scheduled, '만남 예정', scheduledCount),
      (_InboxTab.completed, '만남 완료', completedCount),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink100, width: 1)),
      ),
      child: Row(
        children: [
          for (final entry in entries)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChange(entry.$1);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: entry.$1 == active
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    '${entry.$2} (${entry.$3})',
                    style: AppTypography.label.copyWith(
                      color: entry.$1 == active
                          ? AppColors.primary
                          : AppColors.ink500,
                      fontWeight: entry.$1 == active
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

class _ConversationCard extends StatefulWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
    required this.onAccept,
    required this.onViewReport,
  });
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onViewReport;

  @override
  State<_ConversationCard> createState() => _ConversationCardState();
}

class _ConversationCardState extends State<_ConversationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    // 약속 조율 완료 + 아직 만남 예정 단계 전 → 민트 강조 테두리
    final highlight =
        c.appointmentReady && c.status != ConversationStatus.scheduled;
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
            color: highlight
                ? AppColors.mint.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: AppRadius.rMd,
            border: Border.all(
              color: highlight ? AppColors.mint : AppColors.ink100,
              width: highlight ? 1.8 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (highlight) ...[
                const _AppointmentBadge(),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                      image: (c.photoUrl?.isNotEmpty ?? false)
                          ? DecorationImage(
                              image: NetworkImage(c.photoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (c.photoUrl?.isNotEmpty ?? false)
                        ? null
                        : Text(
                            c.initial,
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.name,
                                style: AppTypography.titleMedium.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (c.score > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '${c.score}점',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              c.time,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.ink500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.ink500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                c.status.label,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.ink700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // 에이전트들이 실일정에서 합의한 약속 시간
                            if (c.appointmentLabel != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.mint.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 11,
                                      color: AppColors.mint,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      c.appointmentLabel!,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.mint,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (c.unread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (highlight) ...[
                const SizedBox(height: 12),
                // 수락 전에 리포트를 먼저 볼 수 있게 — 구독자는 바로,
                // 비구독자는 페이월(단건/구독) 경유 (제품 결정 2026-07-15).
                _ViewReportAction(onViewReport: widget.onViewReport),
                const SizedBox(height: 8),
                _AcceptAction(
                  youAccepted: c.youAccepted,
                  onAccept: widget.onAccept,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentBadge extends StatelessWidget {
  const _AppointmentBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.event_available_rounded,
          size: 16,
          color: AppColors.mint,
        ),
        const SizedBox(width: 6),
        Text(
          '약속 조율 완료',
          style: AppTypography.caption.copyWith(
            color: AppColors.mint,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '· AI 대화에서 만남이 잡혔어요',
          style: AppTypography.caption.copyWith(
            color: AppColors.ink500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ViewReportAction extends StatelessWidget {
  const _ViewReportAction({required this.onViewReport});

  final VoidCallback onViewReport;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onViewReport,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '리포트 먼저 보기',
              style: AppTypography.label.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptAction extends StatelessWidget {
  const _AcceptAction({required this.youAccepted, required this.onAccept});

  final bool youAccepted;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    if (youAccepted) {
      // 내 수락 완료, 상대 수락 대기
      return Container(
        width: double.infinity,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '수락 완료 · 상대의 수락을 기다리는 중',
          style: AppTypography.label.copyWith(
            color: AppColors.ink500,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onAccept,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.mint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              '만남 수락하기',
              style: AppTypography.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppColors.ink300,
            ),
            const SizedBox(height: 12),
            Text(
              '아직 이 상태의 인연이 없어요',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.ink500),
            ),
          ],
        ),
      ),
    );
  }
}
