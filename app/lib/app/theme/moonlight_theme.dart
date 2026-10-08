import 'package:flutter/material.dart';

/// The "moonlight" visual language: deep navy/black, restrained
/// blue-purple glow, minimal gradients, no neon. See docs/architecture.md
/// for the full rationale — this file is the single place color/typography
/// decisions live, so the rest of the UI never hardcodes a Color value.
class MoonlightPalette {
  static const background = Color(0xFF0B0E1A);
  static const surface = Color(0xFF12162A);
  static const surfaceRaised = Color(0xFF181D36);
  static const border = Color(0xFF262C4A);
  static const accentPrimary = Color(0xFF6C7BFF);
  static const accentSecondary = Color(0xFF9D7BFF);
  static const textPrimary = Color(0xFFE7E9F7);
  static const textSecondary = Color(0xFF9AA0C3);
  static const success = Color(0xFF5FD4A6);
  static const warning = Color(0xFFE8B15B);
  static const danger = Color(0xFFE86B6B);
}

ThemeData buildMoonlightTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: MoonlightPalette.background,
    colorScheme: base.colorScheme.copyWith(
      surface: MoonlightPalette.surface,
      primary: MoonlightPalette.accentPrimary,
      secondary: MoonlightPalette.accentSecondary,
      error: MoonlightPalette.danger,
    ),
    cardTheme: CardThemeData(
      color: MoonlightPalette.surfaceRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MoonlightPalette.border, width: 1),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: MoonlightPalette.textPrimary,
      displayColor: MoonlightPalette.textPrimary,
    ),
    dividerColor: MoonlightPalette.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: MoonlightPalette.background,
      elevation: 0,
      foregroundColor: MoonlightPalette.textPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MoonlightPalette.accentPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}
