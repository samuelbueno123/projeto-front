import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Helper to check if running in automated widget test environment
bool get isRunningTestEnvironment {
  if (kIsWeb) return false;
  return Platform.environment.containsKey('FLUTTER_TEST');
}

extension SaasAnimateExtension on Widget {
  Widget saasFadeIn({
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
  }) {
    if (isRunningTestEnvironment) return this;
    return animate().fadeIn(duration: duration, delay: delay);
  }

  Widget saasSlideY({
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
    double begin = 0.05,
    double end = 0,
  }) {
    if (isRunningTestEnvironment) return this;
    return animate()
        .fadeIn(duration: duration, delay: delay)
        .slideY(begin: begin, end: end);
  }

  Widget saasSlideX({
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
    double begin = -0.05,
    double end = 0,
  }) {
    if (isRunningTestEnvironment) return this;
    return animate()
        .fadeIn(duration: duration, delay: delay)
        .slideX(begin: begin, end: end);
  }

  Widget saasScale({
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutBack,
  }) {
    if (isRunningTestEnvironment) return this;
    return animate().scale(duration: duration, curve: curve);
  }
}

/// Semantic colors for modern SaaS styling.
class SaaSColors {
  static const primary = Color(0xFF2563EB); // Vibrant Royal / Electric Blue
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

  static Color background(bool isDark) =>
      isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);

  static Color surface(bool isDark) =>
      isDark ? const Color(0xFF0F172A) : Colors.white;

  static Color surfaceSubtle(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  static Color border(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

  static Color textPrimary(bool isDark) =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

  static Color textSecondary(bool isDark) =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  static Color muted(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return textSecondary(isDark);
  }
}

/// A modern Shadcn-style metric / KPI card.
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = iconColor ?? SaaSColors.primary;
    final bg = iconBgColor ??
        (isDark
            ? fg.withValues(alpha: 0.15)
            : fg.withValues(alpha: 0.1));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: SaaSColors.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SaaSColors.border(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SaaSColors.textSecondary(isDark),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: fg),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: SaaSColors.textPrimary(isDark),
                letterSpacing: -0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null || trend != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (trend != null) ...[
                    Icon(
                      trendPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 15,
                      color: trendPositive
                          ? SaaSColors.success
                          : SaaSColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: trendPositive
                            ? SaaSColors.success
                            : SaaSColors.error,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (subtitle != null)
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: SaaSColors.textSecondary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).saasSlideY(duration: 300.ms, begin: 0.08);
  }
}

/// A sleek status badge / chip in Shadcn style.
enum SaaSBadgeVariant {
  neutral,
  primary,
  success,
  warning,
  error,
}

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

    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case SaaSBadgeVariant.primary:
        bg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
        fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        border = isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE);
        break;
      case SaaSBadgeVariant.success:
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
        border = isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0);
        break;
      case SaaSBadgeVariant.warning:
        bg = isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB);
        fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
        border = isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A);
        break;
      case SaaSBadgeVariant.error:
        bg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
        fg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
        border = isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA);
        break;
      case SaaSBadgeVariant.neutral:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        break;
    }

    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: widget,
      );
    }
    return widget;
  }
}

/// A Section Header for dashboard areas with optional actions.
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: SaaSColors.textPrimary(isDark),
                                letterSpacing: -0.4,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            badge!,
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: SaaSColors.textSecondary(isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Empty state illustration and call to action.
class SaaSEmptyState extends StatelessWidget {
  const SaaSEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: SaaSColors.surfaceSubtle(isDark),
                shape: BoxShape.circle,
                border: Border.all(color: SaaSColors.border(isDark)),
              ),
              child: Icon(
                icon,
                size: 32,
                color: SaaSColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: SaaSColors.textPrimary(isDark),
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: SaaSColors.textSecondary(isDark),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ShadButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ).saasFadeIn(duration: 250.ms);
  }
}

/// A polished card wrapper for SaaS panels.
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

    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? SaaSColors.surface(isDark),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? SaaSColors.border(isDark),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      );
    }

    return card;
  }
}
