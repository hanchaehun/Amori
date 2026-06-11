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
import '../../data/dummy/conversations.dart';

enum _InboxTab { active, scheduled, completed }

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  _InboxTab _tab = _InboxTab.active;

  // 더미 시드를 변경 가능한 로컬 상태로 복사 — 수락 시 목록 간 이동을 반영한다.
  // (실연결: 백엔드 /matches/find·시뮬레이션 결과로 이 목록을 채우는 것이 다음 단계)
  late List<Conversation> _active = [...kActiveConversations];
  late List<Conversation> _scheduled = [...kScheduledConversations];
  late final List<Conversation> _completed = [...kCompletedConversations];

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('대화 검색 — 다음 턴 작업 예정')),
    );
  }

  void _onConversationTap(Conversation c) {
    HapticFeedback.lightImpact();
    context.push('${AppRoutes.chat}?id=${c.id}');
  }

  /// [수락] — 양쪽이 모두 수락하면 '만남 예정'으로 이동한다.
  void _onAccept(Conversation c) {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    if (c.partnerAccepted) {
      // 상대가 이미 수락 → 양쪽 수락 성립 → 만남 예정으로 이동
      setState(() {
        _active.removeWhere((x) => x.id == c.id);
        _scheduled = [
          c.copyWith(
            youAccepted: true,
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
    return AppScaffold(
      bottomBar: const AmoriTabBar(active: AmoriTab.connect),
      body: Column(
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
            child: _conversations.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
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
                      onTap: () => _onConversationTap(_conversations[i]),
                      onAccept: () => _onAccept(_conversations[i]),
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
              icon: const Icon(Icons.search_rounded,
                  size: 22, color: AppColors.ink900),
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
  });
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onAccept;

  @override
  State<_ConversationCard> createState() => _ConversationCardState();
}

class _ConversationCardState extends State<_ConversationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    // 약속 조율 완료 + 아직 만남 예정 단계 전 → 민트 강조 테두리
    final highlight = c.appointmentReady && c.status != ConversationStatus.scheduled;
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
            color: highlight ? AppColors.mint.withValues(alpha: 0.04) : Colors.white,
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
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
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
                                style: AppTypography.titleMedium
                                    .copyWith(fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.10),
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
                                  horizontal: 10, vertical: 3),
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
        const Icon(Icons.event_available_rounded,
            size: 16, color: AppColors.mint),
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
            const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
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
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: AppColors.ink300),
            const SizedBox(height: 12),
            Text(
              '아직 이 상태의 인연이 없어요',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.ink500),
            ),
          ],
        ),
      ),
    );
  }
}
