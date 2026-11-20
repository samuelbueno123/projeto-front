import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Tokens semânticos da identidade visual Âncora Gestão para Light & Dark modes.
class AncoraThemeTokens extends ThemeExtension<AncoraThemeTokens> {
  const AncoraThemeTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSubtle,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.isDark,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSubtle;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final bool isDark;

  static const AncoraThemeTokens lightTokens = AncoraThemeTokens(
    canvas: Color(0xFFF8FAFC),
    surface: Colors.white,
    surfaceElevated: Colors.white,
    surfaceSubtle: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0xFFEFF6FF),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    info: Color(0xFF0284C7),
    isDark: false,
  );

  static const AncoraThemeTokens darkTokens = AncoraThemeTokens(
    canvas: Color(0xFF0B1120),
    surface: Color(0xFF111827),
    surfaceElevated: Color(0xFF1E293B),
    surfaceSubtle: Color(0xFF172033),
    border: Color(0xFF273549),
    borderStrong: Color(0xFF334155),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
    accent: Color(0xFF3B82F6),
    accentSoft: Color(0xFF1E3A8A),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF38BDF8),
    isDark: true,
  );

  static AncoraThemeTokens of(BuildContext context) {
    final ext = Theme.of(context).extension<AncoraThemeTokens>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark
        ? darkTokens
        : lightTokens;
  }

  @override
  AncoraThemeTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSubtle,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    bool? isDark,
  }) {
    return AncoraThemeTokens(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AncoraThemeTokens lerp(ThemeExtension<AncoraThemeTokens>? other, double t) {
    if (other is! AncoraThemeTokens) return this;
    return AncoraThemeTokens(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t) ??
          surfaceElevated,
      surfaceSubtle:
          Color.lerp(surfaceSubtle, other.surfaceSubtle, t) ?? surfaceSubtle,
      border: Color.lerp(border, other.border, t) ?? border,
      borderStrong:
          Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      info: Color.lerp(info, other.info, t) ?? info,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

class AppTheme {
  // Brand Colors - Modern Indigo & Slate SaaS Palette
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color accentBlue = Color(0xFF3B82F6);

  // Semantic Pastel Accents
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

  static const String fontFamily = 'Plus Jakarta Sans';
  static const List<String> fontFallbacks = [
    'Inter',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  // Notificador reativo para alternância instantânea entre Light/Dark/System mode
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
    ThemeMode.system,
  );
  static String _currentPreference = 'SYSTEM';
  static String get currentPreference => _currentPreference;

  static void setThemePreference(String? preference) {
    final normalized = (preference ?? 'SYSTEM').trim().toUpperCase();
    _currentPreference = switch (normalized) {
      'LIGHT' || 'DARK' || 'SYSTEM' => normalized,
      _ => 'SYSTEM',
    };
    themeModeNotifier.value = switch (_currentPreference) {
      'LIGHT' => ThemeMode.light,
      'DARK' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static bool isDarkContext(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static ShadThemeData shadcnLight() => ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadBlueColorScheme.light(),
  );

  static ShadThemeData shadcnDark() => ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: const ShadBlueColorScheme.dark(),
  );

  static TextTheme _buildTextTheme(
    TextTheme base,
    Color textColor,
    Color subColor,
  ) {
    return base
        .copyWith(
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: textColor,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: textColor,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
            color: textColor,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
            color: textColor,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
            color: textColor,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: textColor,
            height: 1.45,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontWeight: FontWeight.w400,
            color: subColor,
            height: 1.45,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        )
        .apply(fontFamily: fontFamily);
  }

  static ThemeData light() {
    const tokens = AncoraThemeTokens.lightTokens;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: tokens.surface,
      primary: primary,
      secondary: const Color(0xFF0EA5E9),
      error: tokens.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.canvas,
    );

    return base.copyWith(
      extensions: const [tokens],
      textTheme: _buildTextTheme(
        base.textTheme,
        tokens.textPrimary,
        tokens.textSecondary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surface,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.75),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.75),
        ),
        labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13.5),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaceSubtle,
        selectedColor: primaryLight,
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
      ),
    );
  }

  static ThemeData dark() {
    const tokens = AncoraThemeTokens.darkTokens;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.accent,
      brightness: Brightness.dark,
      surface: tokens.surface,
      primary: tokens.accent,
      secondary: tokens.info,
      error: tokens.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.canvas,
    );

    return base.copyWith(
      extensions: const [tokens],
      textTheme: _buildTextTheme(
        base.textTheme,
        tokens.textPrimary,
        tokens.textSecondary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surface,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Color(0xFFF8FAFC),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFCBD5E1)),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tokens.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tokens.borderStrong),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.borderStrong),
        ),
        textStyle: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.accent, width: 1.75),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.danger, width: 1.75),
        ),
        labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 13.5),
        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13.5),
      ),
      dividerTheme: DividerThemeData(color: tokens.border, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaceSubtle,
        selectedColor: tokens.accent.withValues(alpha: 0.22),
        labelStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: tokens.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: tokens.surfaceElevated,
        contentTextStyle: TextStyle(color: tokens.textPrimary, fontSize: 13.5),
      ),
    );
  }
}
