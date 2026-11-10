import 'dart:async' as async;
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';
import 'api_response.dart';

class _CacheEntry {
  _CacheEntry({required this.response, required this.expiry});
  final http.Response response;
  final DateTime expiry;
  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// Cliente HTTP customizado com suporte a autenticação, Correlation IDs, retentativas, deduplicação em voo e cache de leitura
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

  static int _requestSequence = 0;

  /// Global callback for 401 Unauthorized
  static void Function()? onUnauthorized;

  /// Mapa de deduplicação de requisições GET em voo (in-flight request deduplication)
  final Map<String, Future<http.Response>> _inFlightRequests = {};

  /// Cache em memória local para requisições GET idempotentes
  final Map<String, _CacheEntry> _cache = {};

  /// Limpa todo o cache em memória do cliente HTTP
  void clearCache() {
    _cache.clear();
  }

  /// Invalida entradas de cache que casem com determinado padrão ou limpa tudo
  void invalidateCache([String? pattern]) {
    if (pattern == null || pattern.isEmpty) {
      _cache.clear();
      return;
    }
    _cache.removeWhere((key, _) => key.contains(pattern));
  }

  /// Gera um identificador de correlação único para rastreamento de requisições
  String _generateCorrelationId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _requestSequence++;
    final rand = (now ^ (_requestSequence * 31)) & 0xFFFFFF;
    return 'req-${now.toRadixString(16)}-${rand.toRadixString(16)}';
  }

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
    String url;
    if (endpoint.startsWith('http')) {
      url = endpoint;
    } else {
      final base = _baseUrl.replaceAll(RegExp(r'/+$'), '');
      final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      url = '$base$path';
    }
    final uri = Uri.parse(url);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        ...queryParameters,
      },
    );
  }

  /// Constrói headers padrão com autenticação e Correlation ID
  Map<String, String> _buildHeaders({
    Map<String, String>? customHeaders,
    String? correlationId,
  }) {
    final headers = <String, String>{...ApiConfig.defaultHeaders};

    final traceId = correlationId ?? _generateCorrelationId();
    headers['X-Correlation-ID'] = traceId;

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

  /// Executa chamada HTTP com política de retry para erros temporários (503, 504 e falhas transitórias de conexão)
  Future<http.Response> _executeWithRetry(
    String method,
    Future<http.Response> Function() requestAction, {
    int maxRetries = 2,
    Duration retryDelay = const Duration(milliseconds: 300),
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await requestAction();
        final isIdempotent = method == 'GET' || method == 'HEAD' || method == 'OPTIONS' || method == 'PUT' || method == 'DELETE';
        if (isIdempotent && attempts <= maxRetries && (response.statusCode == 503 || response.statusCode == 504)) {
          await Future.delayed(retryDelay * attempts);
          continue;
        }
        return response;
      } on http.ClientException {
        final isIdempotent = method == 'GET' || method == 'HEAD';
        if (isIdempotent && attempts <= maxRetries) {
          await Future.delayed(retryDelay * attempts);
          continue;
        }
        rethrow;
      }
    }
  }

  /// Log de requisição (apenas em debug mode)
  void _logRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    if (!enableLogging) return;
  }

  /// Log de resposta (apenas em debug mode)
  void _logResponse(int statusCode, String body) {
    if (!enableLogging) return;
  }

  /// Faz requisição GET com suporte a deduplicação de requisições em voo e cache de leitura
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParameters,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
    Duration? cacheDuration,
    bool forceRefresh = false,
  }) async {
    final correlationId = customHeaders?['X-Correlation-ID'] ?? _generateCorrelationId();
    final uri = _buildUri(endpoint, queryParameters: queryParameters);
    final cacheKey = uri.toString();

    // 1. Verifica cache local se aplicável
    if (!forceRefresh && cacheDuration != null) {
      final cached = _cache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return _handleResponse<T>(cached.response, fromJsonT: fromJsonT, correlationId: correlationId);
      } else {
        _cache.remove(cacheKey);
      }
    }

    final headers = _buildHeaders(customHeaders: customHeaders, correlationId: correlationId);
    _logRequest('GET', uri, headers, null);

    try {
      // 2. Se já existe uma requisição idêntica em andamento, compartilha o Future (in-flight deduplication)
      Future<http.Response> requestFuture;
      if (_inFlightRequests.containsKey(cacheKey)) {
        requestFuture = _inFlightRequests[cacheKey]!;
      } else {
        final completer = async.Completer<http.Response>();
        _inFlightRequests[cacheKey] = completer.future;

        _executeWithRetry(
          'GET',
          () => _httpClient
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds)),
        ).then((resp) {
          if (cacheDuration != null && resp.statusCode >= 200 && resp.statusCode < 300) {
            _cache[cacheKey] = _CacheEntry(
              response: resp,
              expiry: DateTime.now().add(cacheDuration),
            );
          }
          completer.complete(resp);
        }).catchError((Object err, StackTrace st) {
          completer.completeError(err, st);
        }).whenComplete(() {
          _inFlightRequests.remove(cacheKey);
        });

        requestFuture = completer.future;
      }

      final response = await requestFuture;
      _logResponse(response.statusCode, response.body);

      return _handleResponse<T>(response, fromJsonT: fromJsonT, correlationId: correlationId);
    } on async.TimeoutException {
      throw TimeoutException('Timeout ao conectar ao servidor', correlationId: correlationId);
    } catch (e) {
      return _handleException<T>(e, correlationId: correlationId);
    }
  }

  /// Faz requisição POST (invalida caches locais relacionados)
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    invalidateCache(); // Limpa cache para garantir dados frescos após mutação
    final correlationId = customHeaders?['X-Correlation-ID'] ?? _generateCorrelationId();
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(customHeaders: customHeaders, correlationId: correlationId);
    final bodyEncoded = body != null ? jsonEncode(body) : null;

    _logRequest('POST', uri, headers, bodyEncoded);

    try {
      final response = await _executeWithRetry(
        'POST',
        () => _httpClient
            .post(uri, headers: headers, body: bodyEncoded)
            .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds)),
        maxRetries: 0, // POST por padrão não deve ser repetido para evitar duplo envio
      );

      _logResponse(response.statusCode, response.body);

      return _handleResponse<T>(response, fromJsonT: fromJsonT, correlationId: correlationId);
    } on async.TimeoutException {
      throw TimeoutException('Timeout ao conectar ao servidor', correlationId: correlationId);
    } catch (e) {
      return _handleException<T>(e, correlationId: correlationId);
    }
  }

  /// Faz requisição PUT (invalida caches locais)
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    invalidateCache();
    final correlationId = customHeaders?['X-Correlation-ID'] ?? _generateCorrelationId();
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(customHeaders: customHeaders, correlationId: correlationId);
    final bodyEncoded = body != null ? jsonEncode(body) : null;

    _logRequest('PUT', uri, headers, bodyEncoded);

    try {
      final response = await _executeWithRetry(
        'PUT',
        () => _httpClient
            .put(uri, headers: headers, body: bodyEncoded)
            .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds)),
      );

      _logResponse(response.statusCode, response.body);

      return _handleResponse<T>(response, fromJsonT: fromJsonT, correlationId: correlationId);
    } on async.TimeoutException {
      throw TimeoutException('Timeout ao conectar ao servidor', correlationId: correlationId);
    } catch (e) {
      return _handleException<T>(e, correlationId: correlationId);
    }
  }

  /// Faz requisição DELETE (invalida caches locais)
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    invalidateCache();
    final correlationId = customHeaders?['X-Correlation-ID'] ?? _generateCorrelationId();
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(customHeaders: customHeaders, correlationId: correlationId);

    _logRequest('DELETE', uri, headers, null);

    try {
      final response = await _executeWithRetry(
        'DELETE',
        () => _httpClient
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds)),
      );

      _logResponse(response.statusCode, response.body);

      return _handleResponse<T>(response, fromJsonT: fromJsonT, correlationId: correlationId);
    } on async.TimeoutException {
      throw TimeoutException('Timeout ao conectar ao servidor', correlationId: correlationId);
    } catch (e) {
      return _handleException<T>(e, correlationId: correlationId);
    }
  }

  /// Faz requisição PATCH (invalida caches locais)
  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    invalidateCache();
    final correlationId = customHeaders?['X-Correlation-ID'] ?? _generateCorrelationId();
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(customHeaders: customHeaders, correlationId: correlationId);
    final bodyEncoded = body != null ? jsonEncode(body) : null;

    _logRequest('PATCH', uri, headers, bodyEncoded);

    try {
      final response = await _executeWithRetry(
        'PATCH',
        () => _httpClient
            .patch(uri, headers: headers, body: bodyEncoded)
            .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds)),
        maxRetries: 0,
      );

      _logResponse(response.statusCode, response.body);

      return _handleResponse<T>(response, fromJsonT: fromJsonT, correlationId: correlationId);
    } on async.TimeoutException {
      throw TimeoutException('Timeout ao conectar ao servidor', correlationId: correlationId);
    } catch (e) {
      return _handleException<T>(e, correlationId: correlationId);
    }
  }

  /// Executa requisição genérica baseada no método HTTP especificado
  Future<ApiResponse<T>> send<T>(
    String method,
    String endpoint, {
    dynamic body,
    Map<String, String>? queryParameters,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    final m = method.toUpperCase();
    switch (m) {
      case 'GET':
        return get<T>(
          endpoint,
          queryParameters: queryParameters,
          fromJsonT: fromJsonT,
          customHeaders: customHeaders,
        );
      case 'POST':
        return post<T>(
          endpoint,
          body: body,
          fromJsonT: fromJsonT,
          customHeaders: customHeaders,
        );
      case 'PUT':
        return put<T>(
          endpoint,
          body: body,
          fromJsonT: fromJsonT,
          customHeaders: customHeaders,
        );
      case 'DELETE':
        return delete<T>(
          endpoint,
          fromJsonT: fromJsonT,
          customHeaders: customHeaders,
        );
      case 'PATCH':
        return patch<T>(
          endpoint,
          body: body,
          fromJsonT: fromJsonT,
          customHeaders: customHeaders,
        );
      default:
        throw ArgumentError('Método HTTP não suportado: $method');
    }
  }

  /// Processa resposta HTTP e extrai dados e erros associando o Correlation ID
  ApiResponse<T> _handleResponse<T>(
    http.Response response, {
    T Function(Map<String, dynamic>)? fromJsonT,
    String? correlationId,
  }) {
    if (response.statusCode == 204) {
      return ApiResponse.success(null as T, statusCode: 204);
    }

    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    // Tenta fazer parse do JSON
    dynamic decodedJson;
    late Map<String, dynamic> jsonData;
    try {
      if (response.body.trim().isEmpty) {
        decodedJson = <String, dynamic>{};
        jsonData = <String, dynamic>{};
      } else {
        final decoded = jsonDecode(response.body);
        decodedJson = decoded;
        if (decoded is Map<String, dynamic>) {
          jsonData = decoded;
        } else if (decoded is Map) {
          jsonData = Map<String, dynamic>.from(decoded);
        } else if (decoded is List) {
          jsonData = <String, dynamic>{};
        } else if (isSuccess) {
          return ApiResponse.success(
            decoded as T,
            statusCode: response.statusCode,
          );
        } else {
          jsonData = <String, dynamic>{};
        }
      }
    } catch (e) {
      if (isSuccess) {
        throw ParsingException(
          message: 'Erro ao fazer parse da resposta JSON',
          cause: e,
          correlationId: correlationId,
        );
      }
      decodedJson = <String, dynamic>{};
      jsonData = <String, dynamic>{};
    }

    // Resolve o Correlation ID
    String? resolvedId = correlationId;
    if (jsonData['correlationId'] is String && (jsonData['correlationId'] as String).trim().isNotEmpty) {
      resolvedId = (jsonData['correlationId'] as String).trim();
    } else {
      final headerVal = response.headers['x-correlation-id'] ?? response.headers['X-Correlation-ID'];
      if (headerVal != null && headerVal.trim().isNotEmpty) {
        resolvedId = headerVal.trim();
      }
    }

    // Verifica se é sucesso (2xx)
    if (isSuccess) {
      if (decodedJson is List) {
        return ApiResponse.success(
          decodedJson as T,
          statusCode: response.statusCode,
        );
      }

      T? data;
      if (fromJsonT != null && jsonData.isNotEmpty) {
        try {
          data = fromJsonT(jsonData);
        } catch (e) {
          throw ParsingException(
            message: 'Erro ao desserializar dados',
            cause: e,
            correlationId: resolvedId,
          );
        }
      } else if (fromJsonT == null && jsonData.isNotEmpty) {
        data = jsonData as T;
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
      if (response.statusCode == 401 && onUnauthorized != null) {
        onUnauthorized!();
      }
      throw UnauthorizedException(
        message: errorMessage,
        statusCode: response.statusCode,
        responseBody: response.body,
        correlationId: resolvedId,
      );
    } else if (response.statusCode == 404) {
      throw NotFoundException(
        message: errorMessage,
        responseBody: response.body,
        correlationId: resolvedId,
      );
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      throw ClientException(
        message: errorMessage,
        statusCode: response.statusCode,
        responseBody: response.body,
        correlationId: resolvedId,
      );
    } else if (response.statusCode >= 500) {
      throw ServerException(
        message: errorMessage,
        statusCode: response.statusCode,
        responseBody: response.body,
        correlationId: resolvedId,
      );
    }

    throw NetworkException(errorMessage, correlationId: resolvedId);
  }

  /// Trata exceções gerais associando o Correlation ID
  ApiResponse<T> _handleException<T>(dynamic exception, {String? correlationId}) {
    if (exception is ApiException) {
      throw exception;
    }

    if (exception is async.TimeoutException) {
      throw TimeoutException('Timeout ao conectar ao servidor', correlationId: correlationId);
    }

    throw NetworkException('Erro de rede: ${exception.toString()}', correlationId: correlationId);
  }

  /// Extrai mensagem de erro de diferentes formatos de resposta
  String? _extractErrorMessage(Map<String, dynamic> jsonData) {
    final errorsList = jsonData['errors'];
    if (errorsList is List && errorsList.isNotEmpty) {
      final first = errorsList.first;
      if (first is String && first.trim().isNotEmpty) {
        return first;
      }
      if (first is Map) {
        final field = first['fieldName'] ?? first['field'];
        final msg = first['message'] ?? first['error'];
        if (msg is String && msg.trim().isNotEmpty) {
          return field != null ? '$field: $msg' : msg;
        }
      }
    }

    final keys = ['message', 'detail', 'msg', 'error'];

    for (final key in keys) {
      final value = jsonData[key];

      if (value is String && value.trim().isNotEmpty) {
        return value;
      }

      if (value is Map<String, dynamic>) {
        final msg = value['message'];
        if (msg is String && msg.trim().isNotEmpty) {
          return msg;
        }
      }

      if (value is List && value.isNotEmpty) {
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
