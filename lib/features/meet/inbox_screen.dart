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

  List<Conversation> get _conversations => switch (_tab) {
        _InboxTab.active => kActiveConversations,
        _InboxTab.scheduled => kScheduledConversations,
        _InboxTab.completed => kCompletedConversations,
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bottomBar: const AmoriTabBar(active: AmoriTab.connect),
      body: Column(
        children: [
          _TopBar(onSearch: _onSearch),
          _SubTabs(
            active: _tab,
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
  const _SubTabs({required this.active, required this.onChange});

  final _InboxTab active;
  final ValueChanged<_InboxTab> onChange;

  @override
  Widget build(BuildContext context) {
    final entries = <(_InboxTab, String, int)>[
      (_InboxTab.active, '진행 중', kActiveConversations.length),
      (_InboxTab.scheduled, '만남 예정', kScheduledConversations.length),
      (_InboxTab.completed, '만남 완료', kCompletedConversations.length),
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
  const _ConversationCard({required this.conversation, required this.onTap});
  final Conversation conversation;
  final VoidCallback onTap;

  @override
  State<_ConversationCard> createState() => _ConversationCardState();
}

class _ConversationCardState extends State<_ConversationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
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
          child: Row(
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
