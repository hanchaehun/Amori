import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.rows,
  });

  final String title;
  final List<SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              title.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ),
          for (final row in rows) row,
        ],
      ),
    );
  }
}

class SettingsRow extends StatefulWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.last = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;
  final bool last;
  final bool danger;

  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? AppColors.danger : AppColors.ink900;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed ? AppColors.surfaceMuted : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            decoration: BoxDecoration(
              border: widget.last
                  ? null
                  : const Border(
                      bottom: BorderSide(color: AppColors.ink100, width: 1),
                    ),
            ),
            height: 56,
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: color),
                AppSpacing.hMd,
                Expanded(
                  child: Text(
                    widget.label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: color,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (widget.detail != null) ...[
                  Text(
                    widget.detail!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.ink300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
