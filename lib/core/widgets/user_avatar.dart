import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'smart_image.dart';

ImageProvider<Object>? resolveAvatarImageProvider(String? source) =>
    resolveSmartImageProvider(source);

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

  String _initials() {
    final clean = (name ?? '').trim();
    if (clean.isEmpty) return 'U';
    final parts = clean
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final provider = resolveSmartImageProvider(imageSource);
    final bg = backgroundColor ?? tokens.accent.withValues(alpha: 0.14);
    final fg = foregroundColor ?? tokens.accent;
    final bColor = borderColor ?? tokens.borderStrong;

    Widget avatar = Container(
      padding: EdgeInsets.all(borderWidth > 0 ? borderWidth : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: bColor, width: borderWidth)
            : null,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        backgroundImage: provider,
        onBackgroundImageError: provider == null ? null : (_, __) {},
        child: provider == null
            ? Text(
                _initials(),
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: (radius * 0.72).clamp(11.0, 26.0),
                ),
              )
            : null,
      ),
    );

    if (onTap != null) {
      avatar = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: avatar),
      );
    }

    if (tooltip != null && tooltip!.isNotEmpty) {
      avatar = Tooltip(message: tooltip!, child: avatar);
    }

    return avatar;
  }
}
