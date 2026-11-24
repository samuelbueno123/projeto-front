import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';

/// Cache em memória (LRU com limite de 60 entradas) para evitar base64Decode síncrono em `build()`.
class _SmartImageMemoryCache {
  static const int _maxEntries = 60;
  static final LinkedHashMap<String, Uint8List> _decodedBytes = LinkedHashMap();

  static Uint8List? decodeBase64DataUrl(String dataUrl) {
    final existing = _decodedBytes.remove(dataUrl);
    if (existing != null) {
      _decodedBytes[dataUrl] = existing;
      return existing;
    }
    try {
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex == -1) return null;
      final payload = dataUrl
          .substring(commaIndex + 1)
          .replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(payload);
      while (_decodedBytes.length >= _maxEntries) {
        _decodedBytes.remove(_decodedBytes.keys.first);
      }
      _decodedBytes[dataUrl] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }
}

/// Retorna o `ImageProvider` apropriado (com cache de bytes base64) ou `null` se inválido.
ImageProvider<Object>? resolveSmartImageProvider(String? rawSource) {
  if (rawSource == null) return null;
  final trimmed = rawSource.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('assets/')) {
    return AssetImage(trimmed);
  }
  if (trimmed.startsWith('data:image/')) {
    final bytes = _SmartImageMemoryCache.decodeBase64DataUrl(trimmed);
    return bytes == null ? null : MemoryImage(bytes);
  }
  final resolved = ApiConfig.resolveMediaUrl(trimmed);
  if (resolved == null) return null;
  return NetworkImage(resolved);
}

/// Exibe imagens de rede, assets locais (`assets/...`), `/media/pictures/...` ou data URL base64 sem jank.
class SmartImage extends StatelessWidget {
  const SmartImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon = Icons.image_outlined,
    this.fallbackAsset,
  });

  final String? source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;
  final String? fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final raw = source?.trim() ?? '';

    Widget buildIconPlaceholder() {
      return Container(
        width: width,
        height: height,
        color: tokens.surfaceSubtle,
        alignment: Alignment.center,
        child: Icon(placeholderIcon, color: tokens.textMuted, size: 28),
      );
    }

    Widget buildFallback() {
      if (fallbackAsset != null && fallbackAsset!.trim().isNotEmpty) {
        return Image.asset(
          fallbackAsset!.trim(),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => buildIconPlaceholder(),
        );
      }
      return buildIconPlaceholder();
    }

    if (raw.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: buildFallback(),
      );
    }

    Widget imgWidget;
    if (raw.startsWith('assets/')) {
      imgWidget = Image.asset(
        raw,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => buildFallback(),
      );
    } else if (raw.startsWith('data:image/')) {
      final bytes = _SmartImageMemoryCache.decodeBase64DataUrl(raw);
      if (bytes == null) {
        imgWidget = buildFallback();
      } else {
        imgWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => buildFallback(),
        );
      }
    } else {
      final resolvedUrl = ApiConfig.resolveMediaUrl(raw);
      if (resolvedUrl == null) {
        imgWidget = buildFallback();
      } else {
        imgWidget = Image.network(
          resolvedUrl,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: tokens.surfaceSubtle,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, __, ___) => buildFallback(),
        );
      }
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imgWidget);
    }
    return imgWidget;
  }
}
