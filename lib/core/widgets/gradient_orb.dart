import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/amori_theme_ext.dart';

class GradientOrb extends StatelessWidget {
  const GradientOrb({
    super.key,
    required this.size,
    this.opacity = 0.85,
    this.blur = 0,
  });

  final double size;
  final double opacity;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    final orb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: amori.primaryGradient,
      ),
    );
    if (blur <= 0) {
      return Opacity(opacity: opacity, child: orb);
    }
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Opacity(opacity: opacity, child: orb),
    );
  }
}

class AmoriLogoMark extends StatelessWidget {
  const AmoriLogoMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        gradient: amori.primaryGradient,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        shadows: amori.glowShadow,
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: size * 0.55,
        height: size * 0.32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: _ring(size * 0.32),
            ),
            Positioned(
              right: 0,
              child: _ring(size * 0.32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.2),
      ),
    );
  }
}
