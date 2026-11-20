import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/motion_system.dart';
import '../theme/app_theme.dart';
import 'smart_image.dart';

/// Abre uma imagem em visualização tela cheia com suporte a pinça/zoom, arrasto e tecla ESC.
Future<void> showFullScreenImage(
  BuildContext context, {
  required String imageSource,
  String? title,
  String? subtitle,
}) {
  final reduce = AncoraMotion.shouldReduceMotion(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar visualização',
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: reduce ? Duration.zero : AncoraMotion.normal,
    pageBuilder: (ctx, _, __) => _FullScreenImageDialog(
      imageSource: imageSource,
      title: title,
      subtitle: subtitle,
    ),
    transitionBuilder: (ctx, animation, _, child) {
      if (reduce) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: AncoraMotion.easeOut,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _FullScreenImageDialog extends StatelessWidget {
  const _FullScreenImageDialog({
    required this.imageSource,
    this.title,
    this.subtitle,
  });

  final String imageSource;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.5,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SmartImage(
                          source: imageSource,
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.72),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (title != null && title!.trim().isNotEmpty)
                                Text(
                                  title!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (subtitle != null &&
                                  subtitle!.trim().isNotEmpty)
                                Text(
                                  subtitle!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        IconButton.filled(
                          tooltip: 'Fechar (ESC)',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview de imagem clicável com bordas arredondadas, cache em memória e indicação de zoom no hover.
class ClickableImagePreview extends StatefulWidget {
  const ClickableImagePreview({
    super.key,
    required this.imageSource,
    this.title,
    this.height = 180,
    this.width = double.infinity,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
  });

  final String imageSource;
  final String? title;
  final double height;
  final double width;
  final double borderRadius;
  final BoxFit fit;

  @override
  State<ClickableImagePreview> createState() => _ClickableImagePreviewState();
}

class _ClickableImagePreviewState extends State<ClickableImagePreview> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final source = widget.imageSource.trim();
    if (source.isEmpty) return const SizedBox.shrink();
    final tokens = AncoraThemeTokens.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => showFullScreenImage(
          context,
          imageSource: source,
          title: widget.title,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SmartImage(
                  source: source,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                ),
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: AncoraMotion.duration(context, AncoraMotion.fast),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.28),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.zoom_in_rounded,
                            size: 16,
                            color: tokens.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ampliar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
