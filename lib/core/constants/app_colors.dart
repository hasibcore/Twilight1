import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Theme Palette (YouTube Music inspired)
  static const Color backgroundDark = Color(0xFF030303);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceVariantDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF242424);

  // Light Theme Palette
  static const Color backgroundLight = Color(0xFFF9F9F9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFEEEEEE);
  static const Color cardLight = Color(0xFFF3F3F3);

  // Brand Accents
  static const Color primary =
      Color(0xFFFF0033); // YouTube Red / Music Pink-Red
  static const Color primaryAccent = Color(0xFFFF2A54);
  static const Color secondaryAccent = Color(0xFFFF5252);

  // Text Colors
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFAAAAAA);
  static const Color textTertiaryDark = Color(0xFF717171);

  static const Color textPrimaryLight = Color(0xFF0F0F0F);
  static const Color textSecondaryLight = Color(0xFF606060);
  static const Color textTertiaryLight = Color(0xFF909090);

  // Status & Actions
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA000);
  static const Color info = Color(0xFF29B6F6);

  // Theme-aware dynamic helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondaryLight;

  static Color textTertiary(BuildContext context) =>
      isDark(context) ? textTertiaryDark : textTertiaryLight;

  static Color background(BuildContext context) =>
      isDark(context) ? backgroundDark : backgroundLight;

  static Color surface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color surfaceVariant(BuildContext context) =>
      isDark(context) ? surfaceVariantDark : surfaceVariantLight;

  static Color card(BuildContext context) =>
      isDark(context) ? cardDark : cardLight;

  static Color icon(BuildContext context) =>
      isDark(context) ? Colors.white70 : const Color(0xFF424242);

  static Color iconMuted(BuildContext context) =>
      isDark(context) ? Colors.white38 : const Color(0xFF757575);

  static const LinearGradient playerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF20000A), Color(0xFF0F0005), Color(0xFF030303)],
  );
}
