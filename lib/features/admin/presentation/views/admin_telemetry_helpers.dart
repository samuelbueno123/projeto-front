import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Utilitários compartilhados para leitura segura de payloads de telemetria.
abstract final class AdminTelemetryHelpers {
  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static double asDouble(dynamic value, [double fallback = 0.0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int asInt(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<double> extractSeries(
    List<Map<String, dynamic>> points,
    String key,
  ) {
    return points.map((p) => asDouble(p[key])).toList();
  }

  static List<String> extractTimeLabels(List<Map<String, dynamic>> points) {
    return points.map((p) {
      final raw = p['timestamp']?.toString() ?? '';
      final dt = DateTime.tryParse(raw)?.toLocal();
      if (dt == null) return '';
      return DateFormat('HH:mm:ss').format(dt);
    }).toList();
  }

  static String formatBytes(num bytes) {
    final b = bytes.toDouble();
    if (b >= 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (b >= 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (b >= 1024) {
      return '${(b / 1024).toStringAsFixed(1)} KB';
    }
    return '${b.toInt()} B';
  }

  static String formatMb(num mb) {
    final v = mb.toDouble();
    if (v >= 1024) {
      return '${(v / 1024).toStringAsFixed(1)} GB';
    }
    return '${v.toStringAsFixed(0)} MB';
  }

  static String formatUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  static Widget responsiveTwoColumn({
    required BuildContext context,
    required Widget left,
    required Widget right,
    double spacing = 16,
  }) {
    final isWide = MediaQuery.sizeOf(context).width >= 960;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          SizedBox(width: spacing),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        left,
        SizedBox(height: spacing),
        right,
      ],
    );
  }
}
