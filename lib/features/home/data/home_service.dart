import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/http/http_client_wrapper.dart';
import '../../../core/http/api_exception.dart';

class HomeService {
  HomeService({required this.token, http.Client? client})
    : _wrapper = HttpClientWrapper(httpClient: client, authToken: token);

  final String? token;
  final HttpClientWrapper _wrapper;

  String get baseUrl => ApiConfig.baseUrl;

  Future<dynamic> get(String path) async {
    try {
      final response = await _wrapper.get<dynamic>(
        path,
        fromJsonT: (json) => json,
      );
      return response.data;
    } on ApiException catch (e) {
      throw HomeApiException(e.message);
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

  Future<dynamic> delete(String path) =>
      send('DELETE', path);

  Future<dynamic> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      dynamic response;
      if (method.toUpperCase() == 'POST') {
        response = await _wrapper.post<dynamic>(
          path,
          body: body,
          fromJsonT: (json) => json,
        );
      } else if (method.toUpperCase() == 'PUT') {
        response = await _wrapper.put<dynamic>(
          path,
          body: body,
          fromJsonT: (json) => json,
        );
      } else if (method.toUpperCase() == 'PATCH') {
        response = await _wrapper.patch<dynamic>(
          path,
          body: body,
          fromJsonT: (json) => json,
        );
      } else if (method.toUpperCase() == 'DELETE') {
        response = await _wrapper.delete<dynamic>(
          path,
          fromJsonT: (json) => json,
        );
      } else {
        throw HomeApiException('Método HTTP não suportado: \$method');
      }
      return response.data;
    } on ApiException catch (e) {
      throw HomeApiException(e.message);
    } catch (e) {
      throw HomeApiException(e.toString());
    }
  }
}

class HomeApiException implements Exception {
  const HomeApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
