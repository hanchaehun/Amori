import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AmoriTab { home, match, connect, profile }

class AmoriTabBar extends StatelessWidget {
  const AmoriTabBar({super.key, required this.active});

  final AmoriTab active;

  void _onTap(BuildContext context, AmoriTab tab) {
    if (tab == active) return;
    HapticFeedback.selectionClick();
    switch (tab) {
      case AmoriTab.home:
        context.go(AppRoutes.home);
      case AmoriTab.match:
        context.go(AppRoutes.matchList);
      case AmoriTab.connect:
        context.go(AppRoutes.inbox);
      case AmoriTab.profile:
        context.go(AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.ink100, width: 1)),
      ),
      padding: const EdgeInsets.only(bottom: 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _TabItem(
                icon: Icons.home_rounded,
                label: '홈',
                selected: active == AmoriTab.home,
                onTap: () => _onTap(context, AmoriTab.home),
              ),
              _TabItem(
                icon: Icons.favorite_rounded,
                label: '매칭',
                selected: active == AmoriTab.match,
                onTap: () => _onTap(context, AmoriTab.match),
              ),
              _TabItem(
                icon: Icons.chat_bubble_rounded,
                label: '연결',
                selected: active == AmoriTab.connect,
                onTap: () => _onTap(context, AmoriTab.connect),
              ),
              _TabItem(
                icon: Icons.person_rounded,
                label: '프로필',
                selected: active == AmoriTab.profile,
                onTap: () => _onTap(context, AmoriTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.ink300;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 24, color: color),
                if (selected)
                  const Positioned(
                    top: -8,
                    child: SizedBox(
                      width: 6,
                      height: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
