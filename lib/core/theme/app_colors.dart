import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color gradientStart = Color(0xFF7000FF);
  static const Color gradientEnd = Color(0xFF21FFC3);

  static const Color primary = Color(0xFF7000FF);
  static const Color secondary = Color(0xFF21FFC3);

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF7F8FA);
  static const Color surfaceSoft = Color(0xFFF1ECFF);

  static const Color ink900 = Color(0xFF0B0F1A);
  static const Color ink700 = Color(0xFF2A2F3A);
  static const Color ink500 = Color(0xFF6B7280);
  static const Color ink300 = Color(0xFFC9CED6);
  static const Color ink100 = Color(0xFFEEF0F4);

  static const Color danger = Color(0xFFFF3B5B);
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFFFB020);

  static Color get scrim => ink900.withValues(alpha: 0.04);
  static Color get divider => ink100;
  static Color get hint => ink500;
}
