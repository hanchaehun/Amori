import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradients {
  AppGradients._();

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
  );

  static const LinearGradient primarySoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF1ECFF), Color(0xFFE6FFF8)],
  );

  static const LinearGradient backdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF7F8FA)],
  );

  static const RadialGradient orb = RadialGradient(
    center: Alignment(-0.2, -0.3),
    radius: 0.9,
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
  );

  // Coral pink accent — used sparingly to break visual monotony
  // (e.g., S04 persona orb, illustrative spotlights).
  static const LinearGradient coral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF85A1), Color(0xFFFFB088)],
  );

  static const RadialGradient coralHalo = RadialGradient(
    center: Alignment(0.2, -0.2),
    radius: 0.85,
    colors: [Color(0x33FF7AA2), Color(0x00FF7AA2)],
  );
}
