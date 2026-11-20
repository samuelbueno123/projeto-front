import 'dart:async';
import 'package:http/http.dart' as http;

class SseTransportConnection {
  SseTransportConnection._(this._client, this.byteStream);

  final http.Client _client;
  final Stream<List<int>> byteStream;

  void close() {
    _client.close();
  }
}

Future<SseTransportConnection> openSseConnection({
  required Uri uri,
  required Map<String, String> headers,
}) async {
  final client = http.Client();
  try {
    final request = http.Request('GET', uri);
    request.headers.addAll(headers);
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      client.close();
      throw HttpStatusException(response.statusCode);
    }
    return SseTransportConnection._(client, response.stream);
  } catch (e) {
    client.close();
    rethrow;
  }
}

class HttpStatusException implements Exception {
  const HttpStatusException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'HttpStatusException($statusCode)';
}
