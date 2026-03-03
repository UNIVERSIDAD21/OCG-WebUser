import 'package:flutter/material.dart';

import 'ocg_colors.dart';
import 'ocg_text_styles.dart';

class OcgTheme {
  OcgTheme._();

  static ThemeData get light {
    final scheme = const ColorScheme.light(
      primary: OcgColors.espresso,
      secondary: OcgColors.bronze,
      error: OcgColors.error,
      surface: OcgColors.ivory,
      onPrimary: OcgColors.ivory,
      onSecondary: OcgColors.ivory,
      onSurface: OcgColors.ink,
      onError: OcgColors.ivory,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: OcgColors.ivory,
      textTheme: const TextTheme(
        displayLarge: OcgTextStyles.display,
        displayMedium: OcgTextStyles.display,
        headlineMedium: OcgTextStyles.title,
        bodyLarge: OcgTextStyles.body,
        bodyMedium: OcgTextStyles.body,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: OcgColors.espresso,
        foregroundColor: OcgColors.ivory,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: OcgColors.espresso,
          foregroundColor: OcgColors.ivory,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: OcgColors.espresso.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: OcgColors.espresso.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: OcgColors.espresso.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: OcgColors.bronze, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: OcgColors.error, width: 1.2),
        ),
      ),
      cardTheme: CardThemeData(
        color: OcgColors.mist,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
