import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const baseColor = Color(0xFF2F3FB0);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: baseColor,
        primary: baseColor,
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF13162A)),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF13162A)),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF13162A)),
        bodyMedium: TextStyle(color: Color(0xFF5C6179)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
