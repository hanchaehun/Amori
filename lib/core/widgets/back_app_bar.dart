import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class BackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BackAppBar({
    super.key,
    this.title,
    this.trailing,
    this.onBack,
    this.showBack = true,
  });

  final String? title;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              splashRadius: 22,
              tooltip: '뒤로',
              color: AppColors.ink900,
            )
          : const SizedBox.shrink(),
      title: title == null
          ? null
          : Text(title!, style: AppTypography.titleMedium),
      centerTitle: true,
      actions: trailing == null
          ? null
          : [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(child: trailing!),
              ),
            ],
    );
  }
}
