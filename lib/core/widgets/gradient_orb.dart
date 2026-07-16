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

/// 앱 아이콘과 같은 로고 마크 — 배경 없이 말풍선·하트만 남긴 투명 PNG
/// (런처 아이콘 원본에서 추출, assets/images/logo_mark.png).
class AmoriLogoMark extends StatelessWidget {
  const AmoriLogoMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
