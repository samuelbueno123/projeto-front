import 'package:flutter/material.dart';

class AppTheme {
  // Cores inspiradas no layout moderno do condomínio (Azul Real vibrante e paleta pastel)
  static const Color primary = Color(0xFF1E3A8A); // Deep Royal Blue
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color accentBlue = Color(0xFF2563EB);

  // Paleta de atalhos rápidos e status
  static const Color pastelGreenBg = Color(0xFFDCFCE7);
  static const Color pastelGreenIcon = Color(0xFF15803D);
  static const Color pastelAmberBg = Color(0xFFFEF3C7);
  static const Color pastelAmberIcon = Color(0xFFB45309);
  static const Color pastelPurpleBg = Color(0xFFF3E8FF);
  static const Color pastelPurpleIcon = Color(0xFF7E22CE);
  static const Color pastelBlueBg = Color(0xFFDBEAFE);
  static const Color pastelBlueIcon = Color(0xFF1D4ED8);
  static const Color pastelTealBg = Color(0xFFCCFBF1);
  static const Color pastelTealIcon = Color(0xFF0F766E);
  static const Color pastelRoseBg = Color(0xFFFFE4E6);
  static const Color pastelRoseIcon = Color(0xFFBE123C);

  // Notificador global de tema (SYSTEM, LIGHT, DARK)
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  static void setThemePreference(String? preference) {
    if (preference == null) return;
    switch (preference.toUpperCase()) {
      case 'DARK':
        themeModeNotifier.value = ThemeMode.dark;
        break;
      case 'LIGHT':
        themeModeNotifier.value = ThemeMode.light;
        break;
      default:
        themeModeNotifier.value = ThemeMode.system;
        break;
    }
  }

  static ThemeData light() {
    const background = Color(0xFFF8FAFC);
    const surface = Colors.white;
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF64748B);
    const border = Color(0xFFE2E8F0);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: accentBlue,
      surface: surface,
      error: const Color(0xFFDC2626),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontSize: 15.5,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 14.5),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.4),
        bodySmall: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        labelStyle: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 10,
        shadowColor: Colors.black12,
        indicatorColor: pastelBlueBg,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: primary);
          }
          return const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: textSecondary);
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  static ThemeData dark() {
    const background = Color(0xFF0F172A); // Dark Slate
    const surface = Color(0xFF1E293B);
    const textPrimary = Color(0xFFF8FAFC);
    const textSecondary = Color(0xFF94A3B8);
    const border = Color(0xFF334155);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentBlue,
      brightness: Brightness.dark,
      primary: accentBlue,
      secondary: const Color(0xFF38BDF8),
      surface: surface,
      error: const Color(0xFFEF4444),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontSize: 15.5,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 14.5),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.4),
        bodySmall: TextStyle(color: Color(0xFF64748B), fontSize: 12),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 10,
        indicatorColor: const Color(0xFF334155),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF38BDF8));
          }
          return const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: textSecondary);
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
