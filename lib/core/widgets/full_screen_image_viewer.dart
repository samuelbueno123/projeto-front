import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/api_config.dart';

Uint8List? decodeDataUrlImage(String rawValue) {
  final value = rawValue.trim();
  if (!value.startsWith('data:image')) {
    return null;
  }
  final parts = value.split(',');
  if (parts.length < 2) {
    return null;
  }
  try {
    return base64Decode(parts.last);
  } catch (_) {
    return null;
  }
}

ImageProvider? resolveAvatarImageProvider(String? rawValue) {
  if (rawValue == null) return null;
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) return null;
  try {
    final bytes = decodeDataUrlImage(trimmed);
    if (bytes != null) {
      return MemoryImage(bytes);
    }
    final resolved = ApiConfig.resolveMediaUrl(trimmed);
    if (resolved == null || resolved.isEmpty) return null;
    return NetworkImage(resolved);
  } catch (_) {
    return null;
  }
}

Future<void> showFullScreenImage(
  BuildContext context, {
  required String imageSource,
  String? title,
}) async {
  final bytes = decodeDataUrlImage(imageSource);
  final resolvedUrl = ApiConfig.resolveMediaUrl(imageSource) ?? imageSource;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: bytes != null
                          ? Image.memory(bytes, fit: BoxFit.contain)
                          : Image.network(
                              resolvedUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Text(
                                'Não foi possível carregar a imagem.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    if (title != null && title.trim().isNotEmpty)
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Material(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(dialogContext).pop(),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Fechar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
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
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Use o gesto de pinça ou rolagem para ampliar a imagem',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class ClickableImagePreview extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final source = imageSource.trim();
    if (source.isEmpty) {
      return const SizedBox.shrink();
    }
    final bytes = decodeDataUrlImage(source);
    final resolvedUrl = ApiConfig.resolveMediaUrl(source) ?? source;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: () =>
            showFullScreenImage(context, imageSource: source, title: title),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              bytes != null
                  ? Image.memory(bytes, height: height, width: width, fit: fit)
                  : Image.network(
                      resolvedUrl,
                      height: height,
                      width: width,
                      fit: fit,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Ampliar imagem',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
