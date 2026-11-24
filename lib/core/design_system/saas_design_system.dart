import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../widgets/ancora_charts.dart';
import 'motion_system.dart';
import 'test_env_stub.dart' if (dart.library.io) 'test_env_io.dart';

/// Retorna `true` apenas durante a execução de testes Flutter (`dart:io`),
/// sendo seguro no Flutter Web/WASM via importação condicional.
bool get isRunningTestEnvironment => isFlutterTestEnvironment();

extension SaasAnimateExtension on Widget {
  Widget saasFadeIn({
    Duration duration = const Duration(milliseconds: 280),
    Duration delay = Duration.zero,
  }) {
    if (isRunningTestEnvironment) return this;
    return Builder(
      builder: (context) {
        if (AncoraMotion.shouldReduceMotion(context)) return this;
        return animate().fadeIn(
          duration: duration,
          delay: delay,
          curve: AncoraMotion.easeOut,
        );
      },
    );
  }

  Widget saasSlideY({
    Duration duration = const Duration(milliseconds: 280),
    Duration delay = Duration.zero,
    double begin = 0.05,
    double end = 0,
  }) {
    if (isRunningTestEnvironment) return this;
    return Builder(
      builder: (context) {
        if (AncoraMotion.shouldReduceMotion(context)) return this;
        return animate()
            .fadeIn(
              duration: duration,
              delay: delay,
              curve: AncoraMotion.easeOut,
            )
            .slideY(
              begin: begin,
              end: end,
              duration: duration,
              delay: delay,
              curve: AncoraMotion.easeOut,
            );
      },
    );
  }

  Widget saasSlideX({
    Duration duration = const Duration(milliseconds: 280),
    Duration delay = Duration.zero,
    double begin = -0.05,
    double end = 0,
  }) {
    if (isRunningTestEnvironment) return this;
    return Builder(
      builder: (context) {
        if (AncoraMotion.shouldReduceMotion(context)) return this;
        return animate()
            .fadeIn(
              duration: duration,
              delay: delay,
              curve: AncoraMotion.easeOut,
            )
            .slideX(
              begin: begin,
              end: end,
              duration: duration,
              delay: delay,
              curve: AncoraMotion.easeOut,
            );
      },
    );
  }

  Widget saasScale({
    Duration duration = const Duration(milliseconds: 260),
    Curve curve = Curves.easeOutBack,
  }) {
    if (isRunningTestEnvironment) return this;
    return Builder(
      builder: (context) {
        if (AncoraMotion.shouldReduceMotion(context)) return this;
        return animate().scale(duration: duration, curve: curve);
      },
    );
  }
}

class SaaSColors {
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFFEFF6FF);

  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFECFDF5);
  static const successText = Color(0xFF065F46);

  static const warning = Color(0xFFF59E0B);
  static const warningBg = Color(0xFFFFFBEB);
  static const warningText = Color(0xFF92400E);

  static const error = Color(0xFFEF4444);
  static const errorBg = Color(0xFFFEF2F2);
  static const errorText = Color(0xFF991B1B);

  static const info = Color(0xFF3B82F6);
  static const infoBg = Color(0xFFEFF6FF);
  static const infoText = Color(0xFF1E40AF);

  static const purple = Color(0xFF8B5CF6);
  static const purpleBg = Color(0xFFF3E8FF);
  static const purpleText = Color(0xFF5B21B6);

  static const deepNavy = Color(0xFF080B14);
  static const cardNavy = Color(0xFF0F1424);
  static const borderSubtle = Color(0xFF1E293B);

  static Color background(bool isDark) => isDark
      ? AncoraThemeTokens.darkTokens.canvas
      : AncoraThemeTokens.lightTokens.canvas;

  static Color surface(bool isDark) => isDark
      ? AncoraThemeTokens.darkTokens.surface
      : AncoraThemeTokens.lightTokens.surface;

  static Color surfaceSubtle(bool isDark) => isDark
      ? AncoraThemeTokens.darkTokens.surfaceSubtle
      : AncoraThemeTokens.lightTokens.surfaceSubtle;

  static Color border(bool isDark) => isDark
      ? AncoraThemeTokens.darkTokens.border
      : AncoraThemeTokens.lightTokens.border;

  static Color textPrimary(bool isDark) => isDark
      ? AncoraThemeTokens.darkTokens.textPrimary
      : AncoraThemeTokens.lightTokens.textPrimary;

  static Color textSecondary(bool isDark) => isDark
      ? AncoraThemeTokens.darkTokens.textSecondary
      : AncoraThemeTokens.lightTokens.textSecondary;

  static Color muted(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return textSecondary(isDark);
  }
}

class SaaSMetricCard extends StatelessWidget {
  const SaaSMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.iconColor,
    this.iconBgColor,
    this.trend,
    this.trendPositive = true,
    this.sparklineValues,
    this.sparklineColor,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? iconColor;
  final Color? iconBgColor;
  final String? trend;
  final bool trendPositive;
  final List<double>? sparklineValues;
  final Color? sparklineColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgIcon = iconColor ?? SaaSColors.primary;
    final bgIcon =
        iconBgColor ??
        (isDark
            ? fgIcon.withValues(alpha: 0.18)
            : fgIcon.withValues(alpha: 0.11));

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgIcon,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: fgIcon, size: 20),
            ),
            if (trend != null && trend!.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendPositive
                      ? (isDark
                            ? SaaSColors.success.withValues(alpha: 0.18)
                            : SaaSColors.successBg)
                      : (isDark
                            ? SaaSColors.error.withValues(alpha: 0.18)
                            : SaaSColors.errorBg),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trendPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 13,
                      color: trendPositive
                          ? (isDark
                                ? const Color(0xFF34D399)
                                : SaaSColors.successText)
                          : (isDark
                                ? const Color(0xFFF87171)
                                : SaaSColors.errorText),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: trendPositive
                            ? (isDark
                                  ? const Color(0xFF34D399)
                                  : SaaSColors.successText)
                            : (isDark
                                  ? const Color(0xFFF87171)
                                  : SaaSColors.errorText),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: SaaSColors.textPrimary(isDark),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (sparklineValues != null && sparklineValues!.length >= 2) ...[
          const SizedBox(height: 8),
          AncoraSparkline(
            values: sparklineValues!,
            color: sparklineColor ?? fgIcon,
            height: 24,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SaaSColors.textSecondary(isDark),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return AncoraInteractiveCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      backgroundColor: SaaSColors.surface(isDark),
      borderColor: SaaSColors.border(isDark),
      child: cardContent,
    ).saasSlideY(duration: 280.ms, begin: 0.06);
  }
}

enum SaaSBadgeVariant { primary, success, warning, error, purple, neutral }

class SaaSBadge extends StatelessWidget {
  const SaaSBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = SaaSBadgeVariant.neutral,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final SaaSBadgeVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late final Color bg;
    late final Color fg;
    late final Color border;

    switch (variant) {
      case SaaSBadgeVariant.primary:
        bg = isDark
            ? SaaSColors.primary.withValues(alpha: 0.2)
            : SaaSColors.infoBg;
        fg = isDark ? const Color(0xFF93C5FD) : SaaSColors.infoText;
        border = isDark
            ? SaaSColors.primary.withValues(alpha: 0.4)
            : const Color(0xFFBFDBFE);
        break;
      case SaaSBadgeVariant.success:
        bg = isDark
            ? SaaSColors.success.withValues(alpha: 0.18)
            : SaaSColors.successBg;
        fg = isDark ? const Color(0xFF6EE7B7) : SaaSColors.successText;
        border = isDark
            ? SaaSColors.success.withValues(alpha: 0.35)
            : const Color(0xFFA7F3D0);
        break;
      case SaaSBadgeVariant.warning:
        bg = isDark
            ? SaaSColors.warning.withValues(alpha: 0.18)
            : SaaSColors.warningBg;
        fg = isDark ? const Color(0xFFFCD34D) : SaaSColors.warningText;
        border = isDark
            ? SaaSColors.warning.withValues(alpha: 0.35)
            : const Color(0xFFFDE68A);
        break;
      case SaaSBadgeVariant.error:
        bg = isDark
            ? SaaSColors.error.withValues(alpha: 0.2)
            : SaaSColors.errorBg;
        fg = isDark ? const Color(0xFFFCA5A5) : SaaSColors.errorText;
        border = isDark
            ? SaaSColors.error.withValues(alpha: 0.35)
            : const Color(0xFFFECACA);
        break;
      case SaaSBadgeVariant.purple:
        bg = isDark
            ? SaaSColors.purple.withValues(alpha: 0.2)
            : SaaSColors.purpleBg;
        fg = isDark ? const Color(0xFFC4B5FD) : SaaSColors.purpleText;
        border = isDark
            ? SaaSColors.purple.withValues(alpha: 0.4)
            : const Color(0xFFDDD6FE);
        break;
      case SaaSBadgeVariant.neutral:
        bg = SaaSColors.surfaceSubtle(isDark);
        fg = SaaSColors.textSecondary(isDark);
        border = SaaSColors.border(isDark);
        break;
    }

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: pill,
    );
  }
}

class SaaSSectionHeader extends StatelessWidget {
  const SaaSSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? badge;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                  color: SaaSColors.textPrimary(isDark),
                ),
              ),
            ),
            if (badge != null) ...[const SizedBox(width: 10), badge!],
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 13,
              color: SaaSColors.textSecondary(isDark),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (action != null && constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerText,
                const SizedBox(height: 10),
                action!,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: headerText),
              if (action != null) ...[
                const SizedBox(width: 12),
                Flexible(child: action!),
              ],
            ],
          );
        },
      ),
    );
  }
}

class SaaSEmptyState extends StatelessWidget {
  const SaaSEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description = '',
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyText = (subtitle != null && subtitle!.isNotEmpty)
        ? subtitle!
        : description;

    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: SaaSColors.surface(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SaaSColors.border(isDark)),
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SaaSColors.primary.withValues(alpha: isDark ? 0.24 : 0.12),
                    SaaSColors.info.withValues(alpha: isDark ? 0.14 : 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: isDark ? const Color(0xFF93C5FD) : SaaSColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: SaaSColors.textPrimary(isDark),
              ),
            ),
            if (bodyText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                bodyText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: SaaSColors.textSecondary(isDark),
                  height: 1.45,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ] else if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
        ),
      ),
    ).saasFadeIn(duration: 240.ms);
  }
}

class SaaSCard extends StatelessWidget {
  const SaaSCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 16,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final widget = AncoraInteractiveCard(
      onTap: onTap,
      padding: padding,
      borderRadius: BorderRadius.circular(borderRadius),
      backgroundColor: backgroundColor ?? SaaSColors.surface(isDark),
      borderColor: borderColor ?? SaaSColors.border(isDark),
      child: child,
    );

    if (margin != null) {
      return Padding(padding: margin!, child: widget);
    }
    return widget;
  }
}

class SaaSFeedback {
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _show(
      context,
      message: message,
      title: title,
      duration: duration,
      icon: Icons.check_circle_rounded,
      fgColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
      bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
      borderColor: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onRetry,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _show(
      context,
      message: message,
      title: title ?? 'Atenção',
      duration: duration,
      icon: Icons.error_rounded,
      fgColor: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
      bgColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2),
      borderColor: isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA),
      onAction: onRetry,
      actionLabel: onRetry != null ? 'Tentar novamente' : null,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _show(
      context,
      message: message,
      title: title,
      duration: duration,
      icon: Icons.warning_rounded,
      fgColor: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
      bgColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB),
      borderColor: isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A),
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _show(
      context,
      message: message,
      title: title,
      duration: duration,
      icon: Icons.info_rounded,
      fgColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
      bgColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
      borderColor: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    String? title,
    required Duration duration,
    required IconData icon,
    required Color fgColor,
    required Color bgColor,
    required Color borderColor,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: fgColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null && title.isNotEmpty) ...[
                      Text(
                        title,
                        style: TextStyle(
                          color: fgColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      message,
                      style: TextStyle(
                        color: fgColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: fgColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SaaSLoadingState extends StatelessWidget {
  const SaaSLoadingState({
    super.key,
    this.message = 'Carregando dados...',
    this.submessage,
  });

  final String message;
  final String? submessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: SaaSColors.surface(isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SaaSColors.border(isDark)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: SaaSColors.textPrimary(isDark),
                ),
              ),
              if (submessage != null && submessage!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  submessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: SaaSColors.textSecondary(isDark),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SaaSSkeleton extends StatelessWidget {
  const SaaSSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.margin,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final block = AncoraShimmerBlock(
      width: width ?? double.infinity,
      height: height,
      borderRadius: BorderRadius.circular(borderRadius),
    );
    if (margin != null) {
      return Padding(padding: margin!, child: block);
    }
    return block;
  }
}

class SaaSErrorState extends StatelessWidget {
  const SaaSErrorState({
    super.key,
    required this.message,
    this.title = 'Não foi possível carregar',
    this.onRetry,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: SaaSColors.surface(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: SaaSColors.error.withValues(alpha: isDark ? 0.45 : 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? SaaSColors.error.withValues(alpha: 0.2)
                    : SaaSColors.errorBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 30,
                color: SaaSColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SaaSColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: SaaSColors.textSecondary(isDark),
                height: 1.45,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SaaSSearchBar extends StatefulWidget {
  const SaaSSearchBar({
    super.key,
    this.hintText = 'Buscar registros...',
    required this.onChanged,
    this.onSubmitted,
    this.initialValue = '',
    this.trailing,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String initialValue;
  final Widget? trailing;

  @override
  State<SaaSSearchBar> createState() => _SaaSSearchBarState();
}

class _SaaSSearchBarState extends State<SaaSSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: (val) {
              setState(() {});
              widget.onChanged(val);
            },
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: SaaSColors.textSecondary(isDark),
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() {});
                        widget.onChanged('');
                        widget.onSubmitted?.call('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: SaaSColors.surface(isDark),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 10),
          widget.trailing!,
        ],
      ],
    );
  }
}

class SaaSMetricGrid extends StatelessWidget {
  const SaaSMetricGrid({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = maxW >= 1100
            ? 4
            : (maxW >= 700 ? 2 : (maxW >= 460 ? 2 : 1));
        const spacing = 14.0;
        final itemWidth = (maxW - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth > 0 ? itemWidth : maxW,
                  child: item,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class SaaSDataCard extends StatelessWidget {
  const SaaSDataCard({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.leadingIcon,
    this.metadata = const [],
    this.actions = const [],
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? badge;
  final IconData? leadingIcon;
  final List<Widget> metadata;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SaaSCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leadingIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SaaSColors.primary.withValues(
                      alpha: isDark ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    leadingIcon,
                    size: 20,
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : SaaSColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SaaSColors.textPrimary(isDark),
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: SaaSColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[const SizedBox(width: 8), badge!],
            ],
          ),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, children: metadata),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Bloco de carregamento skeleton discreto com suporte a movimento reduzido.
class AncoraSkeletonBox extends StatelessWidget {
  const AncoraSkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
    if (isRunningTestEnvironment || AncoraMotion.shouldReduceMotion(context)) {
      return box;
    }
    return box
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 0.45, end: 0.9, duration: 850.ms);
  }
}

/// Indicador compacto de estado (ativo, alerta, erro, inativo).
class AncoraStatusDot extends StatelessWidget {
  const AncoraStatusDot({
    super.key,
    required this.color,
    this.size = 8,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// Seletor segmentado estilo Vercel/Linear para janelas temporais e filtros rápidos.
class AncoraFilterPills<T> extends StatelessWidget {
  const AncoraFilterPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<({T value, String label})> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
          final isActive = opt.value == selected;
          return InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: () => onSelected(opt.value),
            child: AnimatedContainer(
              duration: AncoraMotion.duration(context, AncoraMotion.fast),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? tokens.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: isActive ? Border.all(color: tokens.border) : null,
              ),
              child: Text(
                opt.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? tokens.textPrimary : tokens.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
        ),
      ),
    );
  }
}

/// Coluna para [AncoraDataTable].
class AncoraTableColumn<T> {
  const AncoraTableColumn({
    required this.label,
    required this.cellBuilder,
    this.sortValue,
    this.numeric = false,
  });

  final String label;
  final Widget Function(T row) cellBuilder;
  final Comparable Function(T row)? sortValue;
  final bool numeric;
}

/// Tabela analítica reutilizável (estilo Stripe/GitHub) com ordenação, paginação e scroll seguro.
class AncoraDataTable<T> extends StatefulWidget {
  const AncoraDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.pageSize = 8,
    this.emptyMessage = 'Nenhum registro encontrado.',
  });

  final List<AncoraTableColumn<T>> columns;
  final List<T> rows;
  final int pageSize;
  final String emptyMessage;

  @override
  State<AncoraDataTable<T>> createState() => _AncoraDataTableState<T>();
}

class _AncoraDataTableState<T> extends State<AncoraDataTable<T>> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _page = 0;

  @override
  void didUpdateWidget(covariant AncoraDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxPage = math.max(0, ((widget.rows.length - 1) / widget.pageSize).floor());
    if (_page > maxPage) {
      _page = maxPage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    if (widget.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            widget.emptyMessage,
            style: TextStyle(fontSize: 13, color: tokens.textMuted),
          ),
        ),
      );
    }

    final sorted = List<T>.from(widget.rows);
    if (_sortColumnIndex != null && _sortColumnIndex! < widget.columns.length) {
      final col = widget.columns[_sortColumnIndex!];
      if (col.sortValue != null) {
        sorted.sort((a, b) {
          final cmp = col.sortValue!(a).compareTo(col.sortValue!(b));
          return _sortAscending ? cmp : -cmp;
        });
      }
    }

    final totalPages = math.max(1, (sorted.length / widget.pageSize).ceil());
    final safePage = _page.clamp(0, totalPages - 1);
    final start = safePage * widget.pageSize;
    final end = math.min(sorted.length, start + widget.pageSize);
    final pageRows = sorted.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            headingRowHeight: 40,
            dataRowMinHeight: 42,
            dataRowMaxHeight: 54,
            horizontalMargin: 12,
            columnSpacing: 20,
            headingRowColor: WidgetStatePropertyAll(tokens.surfaceSubtle),
            dividerThickness: 0.7,
            columns: [
              for (int i = 0; i < widget.columns.length; i++)
                DataColumn(
                  numeric: widget.columns[i].numeric,
                  onSort: widget.columns[i].sortValue == null
                      ? null
                      : (colIdx, asc) {
                          setState(() {
                            _sortColumnIndex = colIdx;
                            _sortAscending = asc;
                          });
                        },
                  label: Text(
                    widget.columns[i].label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
            ],
            rows: pageRows
                .map(
                  (row) => DataRow(
                    cells: widget.columns
                        .map((c) => DataCell(c.cellBuilder(row)))
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
        if (totalPages > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Página ${safePage + 1} de $totalPages (${sorted.length} itens)',
                style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Página anterior',
                visualDensity: VisualDensity.compact,
                onPressed: safePage > 0
                    ? () => setState(() => _page = safePage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Próxima página',
                visualDensity: VisualDensity.compact,
                onPressed: safePage < totalPages - 1
                    ? () => setState(() => _page = safePage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
