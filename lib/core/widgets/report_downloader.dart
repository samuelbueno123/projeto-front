import 'dart:typed_data';

import 'report_downloader_stub.dart'
    if (dart.library.io) 'report_downloader_io.dart'
    if (dart.library.js_interop) 'report_downloader_web.dart'
    as impl;

/// Salva ou inicia o download de bytes recebidos de endpoints autenticados (PDF/CSV).
Future<String?> downloadReportBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) => impl.downloadReportBytes(
  bytes: bytes,
  filename: filename,
  mimeType: mimeType,
);
