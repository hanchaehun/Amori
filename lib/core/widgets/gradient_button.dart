import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/amori_theme_ext.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

enum GradientButtonSize { regular, large }

class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = GradientButtonSize.large,
    this.icon,
    this.trailing,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final GradientButtonSize size;
  final IconData? icon;
  final Widget? trailing;
  final bool expand;
  final bool loading;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  double get _height =>
      widget.size == GradientButtonSize.large ? 60 : 52;

  EdgeInsets get _padding => widget.size == GradientButtonSize.large
      ? const EdgeInsets.symmetric(horizontal: 24)
      : const EdgeInsets.symmetric(horizontal: 20);

  void _setPressed(bool v) {
    if (!_enabled) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.amori;
    final scale = _pressed ? 0.97 : 1.0;
    final opacity = _enabled ? 1.0 : 0.5;

    return Opacity(
      opacity: opacity,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: _enabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onPressed!();
                }
              : null,
          child: Container(
            height: _height,
            width: widget.expand ? double.infinity : null,
            padding: _padding,
            decoration: ShapeDecoration(
              gradient: theme.primaryGradient,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
              shadows: _pressed
                  ? const []
                  : theme.glowShadow,
            ),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.loading) {
      return const Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: AppTypography.button,
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 8),
          IconTheme.merge(
            data: const IconThemeData(color: Colors.white, size: 20),
            child: widget.trailing!,
          ),
        ],
      ],
    );
  }
}

class GradientArrowTrailing extends StatelessWidget {
  const GradientArrowTrailing({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.arrow_forward_rounded, color: Colors.white);
  }
}

class WhiteSurfaceButton extends StatefulWidget {
  const WhiteSurfaceButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  State<WhiteSurfaceButton> createState() => _WhiteSurfaceButtonState();
}

class _WhiteSurfaceButtonState extends State<WhiteSurfaceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.amori;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onPressed!();
              },
        child: Container(
          height: 60,
          width: widget.expand ? double.infinity : null,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
            shadows: theme.cardShadowLow,
          ),
          child: Text(
            widget.label,
            style: AppTypography.button.copyWith(color: AppColors.ink900),
          ),
        ),
      ),
    );
  }
}
