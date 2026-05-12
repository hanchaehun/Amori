import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_gradients.dart';
import 'app_shadows.dart';

@immutable
class AmoriThemeExt extends ThemeExtension<AmoriThemeExt> {
  const AmoriThemeExt({
    required this.primaryGradient,
    required this.softGradient,
    required this.cardShadow,
    required this.cardShadowLow,
    required this.glowShadow,
    required this.surfaceMuted,
    required this.surfaceSoft,
  });

  final LinearGradient primaryGradient;
  final LinearGradient softGradient;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> cardShadowLow;
  final List<BoxShadow> glowShadow;
  final Color surfaceMuted;
  final Color surfaceSoft;

  static final AmoriThemeExt light = AmoriThemeExt(
    primaryGradient: AppGradients.primary,
    softGradient: AppGradients.primarySoft,
    cardShadow: AppShadows.card,
    cardShadowLow: AppShadows.cardLow,
    glowShadow: AppShadows.glow(),
    surfaceMuted: AppColors.surfaceMuted,
    surfaceSoft: AppColors.surfaceSoft,
  );

  @override
  AmoriThemeExt copyWith({
    LinearGradient? primaryGradient,
    LinearGradient? softGradient,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? cardShadowLow,
    List<BoxShadow>? glowShadow,
    Color? surfaceMuted,
    Color? surfaceSoft,
  }) {
    return AmoriThemeExt(
      primaryGradient: primaryGradient ?? this.primaryGradient,
      softGradient: softGradient ?? this.softGradient,
      cardShadow: cardShadow ?? this.cardShadow,
      cardShadowLow: cardShadowLow ?? this.cardShadowLow,
      glowShadow: glowShadow ?? this.glowShadow,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
    );
  }

  @override
  AmoriThemeExt lerp(ThemeExtension<AmoriThemeExt>? other, double t) {
    if (other is! AmoriThemeExt) return this;
    return AmoriThemeExt(
      primaryGradient: LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
      softGradient: LinearGradient.lerp(softGradient, other.softGradient, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? cardShadow,
      cardShadowLow: BoxShadow.lerpList(cardShadowLow, other.cardShadowLow, t) ?? cardShadowLow,
      glowShadow: BoxShadow.lerpList(glowShadow, other.glowShadow, t) ?? glowShadow,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
    );
  }
}

extension AmoriThemeAccess on BuildContext {
  AmoriThemeExt get amori => Theme.of(this).extension<AmoriThemeExt>()!;
}
