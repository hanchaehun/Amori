import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AmoriTab { home, match, connect, profile }

class _TabConfig {
  const _TabConfig({
    required this.tab,
    required this.icon,
    required this.label,
    required this.activeColor,
  });

  final AmoriTab tab;
  final IconData icon;
  final String label;
  final Color activeColor;
}

const List<_TabConfig> _tabs = [
  _TabConfig(
    tab: AmoriTab.home,
    icon: Icons.home_rounded,
    label: '홈',
    activeColor: AppColors.primary,
  ),
  _TabConfig(
    tab: AmoriTab.match,
    icon: Icons.favorite_rounded,
    label: '매칭',
    activeColor: AppColors.coral,
  ),
  _TabConfig(
    tab: AmoriTab.connect,
    icon: Icons.chat_bubble_rounded,
    label: '연결',
    activeColor: AppColors.mint,
  ),
  _TabConfig(
    tab: AmoriTab.profile,
    icon: Icons.person_rounded,
    label: '프로필',
    activeColor: AppColors.ink900,
  ),
];

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
              for (final cfg in _tabs)
                _TabItem(
                  icon: cfg.icon,
                  label: cfg.label,
                  activeColor: cfg.activeColor,
                  selected: cfg.tab == active,
                  onTap: () => _onTap(context, cfg.tab),
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
    required this.activeColor,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color activeColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : AppColors.ink300;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label 탭',
        container: true,
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
                  Positioned(
                    top: -8,
                    child: SizedBox(
                      width: 6,
                      height: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: activeColor,
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
      ),
    );
  }
}
