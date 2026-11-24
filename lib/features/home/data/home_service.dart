import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/http/api_exception.dart';
import '../../../core/http/http_client_wrapper.dart';

class HomeService {
  HomeService({String? token, http.Client? client, String? baseUrl})
    : _wrapper = HttpClientWrapper(
        httpClient: client,
        authToken: token,
        baseUrl: baseUrl,
      );

  final HttpClientWrapper _wrapper;
  String get baseUrl => _wrapper.baseUrl;

  Future<dynamic> get(
    String path, {
    Duration? cacheDuration,
    bool forceRefresh = false,
  }) async {
    try {
      final res = await _wrapper.get<dynamic>(
        path,
        cacheDuration: cacheDuration,
        forceRefresh: forceRefresh,
      );
      return res.data;
    } on ApiException catch (e) {
      throw HomeApiException(e.message, correlationId: e.correlationId);
    } catch (e) {
      throw HomeApiException(e.toString());
    }
  }

  Future<Uint8List> getBytes(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    try {
      return await _wrapper.getBytes(path, queryParameters: queryParameters);
    } on ApiException catch (e) {
      throw HomeApiException(e.message, correlationId: e.correlationId);
    } catch (e) {
      throw HomeApiException(e.toString());
    }
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      send('POST', path, body: body);

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => send('DELETE', path);

  Future<dynamic> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      dynamic response;
      final upper = method.toUpperCase();
      if (upper == 'POST') {
        response = await _wrapper.post<dynamic>(path, body: body);
      } else if (upper == 'PUT') {
        response = await _wrapper.put<dynamic>(path, body: body);
      } else if (upper == 'PATCH') {
        response = await _wrapper.patch<dynamic>(path, body: body);
      } else if (upper == 'DELETE') {
        response = await _wrapper.delete<dynamic>(path);
      } else if (upper == 'GET') {
        response = await _wrapper.get<dynamic>(path);
      } else {
        throw HomeApiException('Método HTTP não suportado: $method');
      }
      return response.data;
    } on HomeApiException {
      rethrow;
    } on ApiException catch (e) {
      throw HomeApiException(e.message, correlationId: e.correlationId);
    } catch (e) {
      throw HomeApiException(e.toString());
    }
  }

  void dispose() => _wrapper.close();
}

class HomeApiException implements Exception {
  const HomeApiException(this.message, {this.correlationId});

  final String message;
  final String? correlationId;

  @override
  String toString() => message;
}
