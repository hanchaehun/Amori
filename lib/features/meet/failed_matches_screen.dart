import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/dummy/conversations.dart';

/// 닿지 않은 인연 — 케미 점수가 75점을 넘지 못한 대화 모음.
/// 연결 화면 우하단 원형 버튼으로 진입한다. 3일이 지나면 자연 소멸.
class FailedMatchesScreen extends StatelessWidget {
  const FailedMatchesScreen({super.key, required this.items});

  final List<FailedMatch> items;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(onBack: () => context.pop()),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(
              'AI 소개팅에서 케미 점수가 75점에 닿지 못한 인연이에요.\n카드를 누르면 대화를 볼 수 있고, 3일이 지나면 자연스럽게 사라져요.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink500,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => AppSpacing.vSm,
                    itemBuilder: (_, i) => _FailedCard(item: items[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.ink900,
              ),
              onPressed: onBack,
            ),
            Text('닿지 않은 인연', style: AppTypography.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({required this.item});
  final FailedMatch item;

  void _onTap(BuildContext context) {
    HapticFeedback.lightImpact();
    // 대화는 읽기 전용으로 다시 볼 수 있다 — failed=1이면 잠금 문구가 바뀐다.
    context.push('${AppRoutes.chat}?id=${item.id}&failed=1');
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = item.daysLeft;
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
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
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink100),
              ),
              child: Text(
                item.initial,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.ink300,
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
                          item.name,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 15,
                            color: AppColors.ink700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ink100,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${item.score}점',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.ink500,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.hourglass_bottom_rounded,
                        size: 13,
                        color: AppColors.ink300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        daysLeft <= 0 ? '오늘 사라져요' : '$daysLeft일 후 사라져요',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.ink300,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.ink300,
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
              Icons.favorite_border_rounded,
              size: 48,
              color: AppColors.ink300,
            ),
            const SizedBox(height: 12),
            Text(
              '닿지 않은 인연이 없어요',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.ink500),
            ),
          ],
        ),
      ),
    );
  }
}
