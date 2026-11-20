import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class HttpStatusException implements Exception {
  const HttpStatusException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'HttpStatusException($statusCode)';
}

class SseTransportConnection {
  SseTransportConnection._(this._abortController, this._controller);

  final web.AbortController _abortController;
  final StreamController<List<int>> _controller;
  bool _closed = false;

  Stream<List<int>> get byteStream => _controller.stream;

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      _abortController.abort();
    } catch (_) {}
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

Future<SseTransportConnection> openSseConnection({
  required Uri uri,
  required Map<String, String> headers,
}) async {
  final abortController = web.AbortController();
  final jsHeaders = web.Headers();
  headers.forEach((name, value) => jsHeaders.append(name, value));

  final init = web.RequestInit(
    method: 'GET',
    headers: jsHeaders,
    signal: abortController.signal,
  );

  final response = await web.window
      .fetch(uri.toString().toJS, init)
      .toDart
      .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          abortController.abort();
          throw TimeoutException('Tempo esgotado ao abrir canal SSE');
        },
      );

  if (response.status != 200) {
    abortController.abort();
    throw HttpStatusException(response.status);
  }

  final body = response.body;
  if (body == null) {
    abortController.abort();
    throw StateError('Corpo da resposta SSE vazio');
  }

  final controller = StreamController<List<int>>();
  final connection = SseTransportConnection._(abortController, controller);
  final reader = body.getReader() as web.ReadableStreamDefaultReader;

  unawaited(() async {
    try {
      while (!connection._closed) {
        final chunk = await reader.read().toDart;
        if (chunk.done || connection._closed) {
          break;
        }
        final value = chunk.value;
        if (value != null && !controller.isClosed) {
          final bytes = (value as JSUint8Array).toDart;
          if (bytes.isNotEmpty) {
            controller.add(bytes);
          }
        }
      }
    } catch (e) {
      if (!connection._closed && !controller.isClosed) {
        controller.addError(e);
      }
    } finally {
      try {
        reader.releaseLock();
      } catch (_) {}
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }());

  return connection;
}
