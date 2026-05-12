import 'package:flutter/material.dart';

import '../theme/amori_theme_ext.dart';
import '../theme/app_radius.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.color = Colors.white,
    this.borderRadius = AppRadius.rXl,
    this.gradient,
    this.useLowShadow = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final BorderRadius borderRadius;
  final Gradient? gradient;
  final bool useLowShadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    final shadows = useLowShadow ? amori.cardShadowLow : amori.cardShadow;

    final decoration = ShapeDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      shadows: shadows,
    );

    final container = Container(
      margin: margin,
      decoration: decoration,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (onTap == null) return container;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: container,
      ),
    );
  }
}
