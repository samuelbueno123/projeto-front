import 'dart:async';

class HttpStatusException implements Exception {
  const HttpStatusException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'HttpStatusException($statusCode)';
}

abstract class SseTransportConnection {
  Stream<List<int>> get byteStream;
  void close();
}

Future<SseTransportConnection> openSseConnection({
  required Uri uri,
  required Map<String, String> headers,
}) {
  throw UnsupportedError('SSE transport is not supported on this platform.');
}
