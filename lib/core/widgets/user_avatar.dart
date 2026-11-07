import 'package:flutter/material.dart';

import '../design_system/saas_design_system.dart';
import 'full_screen_image_viewer.dart';

/// Reusable avatar widget that reliably resolves images (base64, remote URL,
/// backend media path) and falls back gracefully to user initials or a person icon,
/// preventing blank or gray placeholder circles.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageSource,
    this.name,
    this.radius = 18,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 1.5,
    this.onTap,
    this.tooltip,
  });

  final String? imageSource;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final String? tooltip;

  String _getInitials(String? text) {
    if (text == null) return '';
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return '${parts.first.characters.take(1)}${parts.last.characters.take(1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = radius * 2;

    final bgColor = backgroundColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF));
    final fgColor = foregroundColor ??
        (isDark ? const Color(0xFF93C5FD) : SaaSColors.primary);
    final bColor = borderColor ??
        (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1));

    final imageProvider = resolveAvatarImageProvider(imageSource);
    final initials = _getInitials(name);

    Widget fallbackWidget = Center(
      child: initials.isNotEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: fgColor,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            )
          : Icon(
              Icons.person_rounded,
              color: fgColor,
              size: radius * 1.1,
            ),
    );

    Widget content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: bColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: imageProvider != null
            ? Image(
                image: imageProvider,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallbackWidget,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      fallbackWidget,
                      SizedBox(
                        width: radius,
                        height: radius,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fgColor.withValues(alpha: 0.6),
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    ],
                  );
                },
              )
            : fallbackWidget,
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      content = Tooltip(message: tooltip!, child: content);
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: content,
        ),
      );
    }

    return content;
  }
}
