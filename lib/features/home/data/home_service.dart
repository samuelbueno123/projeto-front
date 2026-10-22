import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';

class HomeService {
  HomeService({required this.token, http.Client? client})
    : _client = client ?? http.Client();
  final String? token;
  final http.Client _client;

  Future<dynamic> get(String path) async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: {
            'Accept': 'application/json',
            if (token != null && token!.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Falha ao carregar dados (${response.statusCode}).';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] is String) {
          message = body['message'] as String;
        }
      } catch (_) {}
      throw HomeApiException(message);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<dynamic> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty)
          'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Falha ao salvar dados (${response.statusCode}).';
      try {
        final result = jsonDecode(response.body);
        if (result is Map && result['message'] is String) {
          message = result['message'] as String;
        }
      } catch (_) {}
      throw HomeApiException(message);
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }
}

class HomeApiException implements Exception {
  const HomeApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
