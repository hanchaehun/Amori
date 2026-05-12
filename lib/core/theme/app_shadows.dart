import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  AppShadows._();

  // Apple-style: stack one tight ambient shadow with a wide soft one.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A0B0F1A),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x140B0F1A),
      blurRadius: 32,
      offset: Offset(0, 16),
      spreadRadius: -8,
    ),
  ];

  static const List<BoxShadow> cardLow = [
    BoxShadow(
      color: Color(0x0A0B0F1A),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0F0B0F1A),
      blurRadius: 18,
      offset: Offset(0, 8),
      spreadRadius: -6,
    ),
  ];

  static const List<BoxShadow> sheet = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 48,
      offset: Offset(0, 24),
      spreadRadius: -12,
    ),
  ];

  static List<BoxShadow> glow({double opacity = 0.32}) => [
        BoxShadow(
          color: AppColors.gradientStart.withValues(alpha: opacity * 0.6),
          blurRadius: 24,
          offset: const Offset(0, 12),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: AppColors.gradientEnd.withValues(alpha: opacity * 0.35),
          blurRadius: 32,
          offset: const Offset(0, 20),
          spreadRadius: -8,
        ),
      ];

  static const List<BoxShadow> none = [];
}
