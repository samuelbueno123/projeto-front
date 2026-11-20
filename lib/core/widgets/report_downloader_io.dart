import 'dart:io';
import 'dart:typed_data';

Future<String?> downloadReportBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}$safeName',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
