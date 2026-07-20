import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';
import 'amori_theme_ext.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSurface: AppColors.ink900,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.materialTextTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink900,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: AppTypography.titleMedium,
        iconTheme: IconThemeData(color: AppColors.ink900, size: 24),
      ),
      iconTheme: const IconThemeData(color: AppColors.ink700, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.ink500),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.rMd,
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.ink100,
        thickness: 1,
        space: 1,
      ),
      extensions: <ThemeExtension<dynamic>>[AmoriThemeExt.light],
    );
  }
}
