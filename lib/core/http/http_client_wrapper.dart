import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';
import 'api_response.dart';

/// Cliente HTTP customizado com suporte a autenticação, headers e tratamento de erro
class HttpClientWrapper {
  HttpClientWrapper({
    http.Client? httpClient,
    String? baseUrl,
    String? authToken,
    this.enableLogging = false,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _authToken = authToken;

  final http.Client _httpClient;
  final String _baseUrl;
  String? _authToken;
  final bool enableLogging;

  /// Define o token de autenticação (JWT)
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Retorna o token de autenticação atual
  String? getAuthToken() => _authToken;

  /// Limpa o token de autenticação
  void clearAuthToken() {
    _authToken = null;
  }

  /// Constrói URL completa a partir de um endpoint relativo
  Uri _buildUri(String endpoint, {Map<String, String>? queryParameters}) {
    final url = endpoint.startsWith('http') ? endpoint : '$_baseUrl$endpoint';
    return Uri.parse(url).replace(queryParameters: queryParameters);
  }

  /// Constrói headers padrão com autenticação se disponível
  Map<String, String> _buildHeaders({Map<String, String>? customHeaders}) {
    final headers = <String, String>{...ApiConfig.defaultHeaders};

    // Adiciona token de autenticação se disponível
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    // Mescla headers customizados
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  /// Log de requisição (apenas em debug mode)
  void _logRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    if (!enableLogging) return;

    print('=== HTTP REQUEST ===');
    print('$method ${uri.toString()}');
    print('Headers: $headers');
    if (body != null && body.isNotEmpty) {
      print('Body: $body');
    }
  }

  /// Log de resposta (apenas em debug mode)
  void _logResponse(int statusCode, String body) {
    if (!enableLogging) return;

    print('=== HTTP RESPONSE ===');
    print('Status: $statusCode');
    if (body.isNotEmpty) {
      print('Body: $body');
    }
  }

  /// Faz requisição GET
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParameters,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    final uri = _buildUri(endpoint, queryParameters: queryParameters);
    final headers = _buildHeaders(customHeaders: customHeaders);

    _logRequest('GET', uri, headers, null);

    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds));

      _logResponse(response.statusCode, response.body);

      return _handleResponse<T>(response, fromJsonT: fromJsonT);
    } on TimeoutException {
      throw TimeoutException('Timeout ao conectar ao servidor');
    } catch (e) {
      return _handleException<T>(e);
    }
  }

  /// Faz requisição POST
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(customHeaders: customHeaders);
    final bodyEncoded = body != null ? jsonEncode(body) : null;

    _logRequest('POST', uri, headers, bodyEncoded);

    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: bodyEncoded)
          .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds));

      _logResponse(response.statusCode, response.body);

      return _handleResponse<T>(response, fromJsonT: fromJsonT);
    } on TimeoutException {
      throw TimeoutException('Timeout ao conectar ao servidor');
    } catch (e) {
      return _handleException<T>(e);
    }
  }

  /// Faz requisição PUT
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(customHeaders: customHeaders);
    final bodyEncoded = body != null ? jsonEncode(body) : null;

    _logRequest('PUT', uri, headers, bodyEncoded);

    try {
      final response = await _httpClient
          .put(uri, headers: headers, body: bodyEncoded)
          .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds));

      _logResponse(response.statusCode, response.body);

      return _handleResponse<T>(response, fromJsonT: fromJsonT);
    } on TimeoutException {
      throw TimeoutException('Timeout ao conectar ao servidor');
    } catch (e) {
      return _handleException<T>(e);
    }
  }

  /// Faz requisição DELETE
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(customHeaders: customHeaders);

    _logRequest('DELETE', uri, headers, null);

    try {
      final response = await _httpClient
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds));

      _logResponse(response.statusCode, response.body);

      return _handleResponse<T>(response, fromJsonT: fromJsonT);
    } on TimeoutException {
      throw TimeoutException('Timeout ao conectar ao servidor');
    } catch (e) {
      return _handleException<T>(e);
    }
  }

  /// Faz requisição PATCH
  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(customHeaders: customHeaders);
    final bodyEncoded = body != null ? jsonEncode(body) : null;

    _logRequest('PATCH', uri, headers, bodyEncoded);

    try {
      final response = await _httpClient
          .patch(uri, headers: headers, body: bodyEncoded)
          .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds));

      _logResponse(response.statusCode, response.body);

      return _handleResponse<T>(response, fromJsonT: fromJsonT);
    } on TimeoutException {
      throw TimeoutException('Timeout ao conectar ao servidor');
    } catch (e) {
      return _handleException<T>(e);
    }
  }

  /// Processa resposta HTTP e extrai dados
  ApiResponse<T> _handleResponse<T>(
    http.Response response, {
    T Function(Map<String, dynamic>)? fromJsonT,
  }) {
    if (response.statusCode == 204) {
      // No content - sucesso sem corpo
      return ApiResponse.success(null as T, statusCode: 204);
    }

    // Tenta fazer parse do JSON
    late Map<String, dynamic> jsonData;
    try {
      if (response.body.isEmpty) {
        jsonData = {};
      } else {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          jsonData = decoded;
        } else {
          throw ParsingException(
            message: 'Resposta não é um JSON válido',
            cause: decoded,
          );
        }
      }
    } catch (e) {
      throw ParsingException(
        message: 'Erro ao fazer parse da resposta JSON',
        cause: e,
      );
    }

    // Verifica se é sucesso (2xx)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      T? data;
      if (fromJsonT != null && jsonData.isNotEmpty) {
        try {
          data = fromJsonT(jsonData);
        } catch (e) {
          throw ParsingException(
            message: 'Erro ao desserializar dados',
            cause: e,
          );
        }
      }

      final message = jsonData['message'] as String?;
      return ApiResponse.success(
        data as T,
        statusCode: response.statusCode,
        message: message,
      );
    }

    // Extrai mensagem de erro
    String errorMessage =
        _extractErrorMessage(jsonData) ?? 'Erro na requisição';

    // Trata diferentes status codes de erro
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw UnauthorizedException(
        message: errorMessage,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    } else if (response.statusCode == 404) {
      throw NotFoundException(
        message: errorMessage,
        responseBody: response.body,
      );
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      throw ClientException(
        message: errorMessage,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    } else if (response.statusCode >= 500) {
      throw ServerException(
        message: errorMessage,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    throw NetworkException(errorMessage);
  }

  /// Trata exceções gerais
  ApiResponse<T> _handleException<T>(dynamic exception) {
    if (exception is ApiException) {
      throw exception;
    }

    if (exception is TimeoutException) {
      throw TimeoutException('Timeout ao conectar ao servidor');
    }

    throw NetworkException('Erro de rede: ${exception.toString()}');
  }

  /// Extrai mensagem de erro de diferentes formatos de resposta
  String? _extractErrorMessage(Map<String, dynamic> jsonData) {
    // Tenta diferentes campos comuns para mensagem de erro
    final keys = ['message', 'error', 'errors', 'detail', 'msg'];

    for (final key in keys) {
      final value = jsonData[key];

      if (value is String && value.trim().isNotEmpty) {
        return value;
      }

      if (value is Map<String, dynamic>) {
        // Se é um Map, tenta extrair 'message' do Map
        final msg = value['message'];
        if (msg is String && msg.trim().isNotEmpty) {
          return msg;
        }
      }

      if (value is List && value.isNotEmpty) {
        // Se é uma lista, tenta o primeiro elemento
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) {
          return first;
        }
        if (first is Map<String, dynamic>) {
          final msg = first['message'] ?? first['error'];
          if (msg is String && msg.trim().isNotEmpty) {
            return msg;
          }
        }
      }
    }

    return null;
  }
}
