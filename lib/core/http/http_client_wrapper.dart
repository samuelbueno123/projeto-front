import 'dart:async' as async;
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';
import 'api_response.dart';

class _CacheEntry {
  _CacheEntry(this.response, this.expiresAt);

  final ApiResponse<dynamic> response;
  final DateTime expiresAt;

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class HttpClientWrapper {
  HttpClientWrapper({
    http.Client? httpClient,
    this.baseUrl = ApiConfig.baseUrl,
    this.authToken,
    this.maxRetries = 2,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final String baseUrl;
  final int maxRetries;
  String? authToken;

  static const int _maxCacheEntries = 80;

  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();
  final Map<String, Future<http.Response>> _inFlightRequests = {};
  static int _requestSequence = 0;

  static void Function()? onUnauthorized;
  static Future<String?> Function()? onRefreshToken;
  static Future<String?>? _refreshInFlight;
  static bool _handlingUnauthorized = false;

  String _generateCorrelationId() {
    _requestSequence++;
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'req-$micros-${_requestSequence.toRadixString(36)}';
  }

  String _tokenBucket() {
    final token = authToken;
    if (token == null || token.isEmpty) return 'anon';
    return 'tok_${token.hashCode}';
  }

  void clearCache() {
    _cache.clear();
  }

  void invalidateCache([String? pattern]) {
    if (pattern == null || pattern.isEmpty) {
      _cache.clear();
      return;
    }
    _cache.removeWhere((key, _) => key.contains(pattern));
  }

  void setAuthToken(String? token) {
    final normalized = token?.trim();
    if (authToken == normalized) return;
    authToken = (normalized == null || normalized.isEmpty) ? null : normalized;
    _cache.clear();
    _inFlightRequests.clear();
  }

  void clearAuthToken() {
    authToken = null;
    _cache.clear();
    _inFlightRequests.clear();
  }

  void close() {
    _cache.clear();
    _inFlightRequests.clear();
    _httpClient.close();
  }

  Uri _buildUri(String endpoint, [Map<String, String>? queryParameters]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$cleanBase$cleanPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    final merged = <String, String>{...uri.queryParameters, ...queryParameters};
    return uri.replace(queryParameters: merged);
  }

  Map<String, String> _buildHeaders({
    Map<String, String>? customHeaders,
    String? correlationId,
    bool jsonContentType = true,
  }) {
    final headers = <String, String>{
      if (jsonContentType) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    if (correlationId != null && correlationId.isNotEmpty) {
      headers['X-Correlation-ID'] = correlationId;
    }
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  String _resolveCorrelationId(Map<String, String>? customHeaders) {
    final explicit =
        customHeaders?['X-Correlation-ID'] ??
        customHeaders?['x-correlation-id'];
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }
    return _generateCorrelationId();
  }

  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() requestAction, {
    required bool isIdempotent,
    required String correlationId,
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await requestAction().timeout(
          const Duration(seconds: ApiConfig.requestTimeoutSeconds),
        );
        if (isIdempotent &&
            attempts <= maxRetries &&
            (response.statusCode == 502 ||
                response.statusCode == 503 ||
                response.statusCode == 504)) {
          await Future.delayed(Duration(milliseconds: 220 * attempts));
          continue;
        }
        return response;
      } on async.TimeoutException {
        if (isIdempotent && attempts <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 220 * attempts));
          continue;
        }
        throw TimeoutException(
          'A requisição demorou mais que o esperado. Tente novamente.',
          correlationId: correlationId,
        );
      } on http.ClientException catch (e) {
        if (isIdempotent && attempts <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 220 * attempts));
          continue;
        }
        throw NetworkException(
          'Falha de comunicação com o servidor: ${e.message}',
          correlationId: correlationId,
        );
      } on Object catch (e) {
        if (e is ApiException) rethrow;
        throw NetworkException(
          'Erro inesperado de rede ao contactar a API.',
          correlationId: correlationId,
        );
      }
    }
  }

  bool _isExplicitReauthPath(String path) =>
      path.contains('/oauth2/') ||
      path.contains('/auth/google') ||
      path.contains('/users/me/password') ||
      path.endsWith('/users');

  Future<http.Response> _executeWithAuthRefresh(
    Future<http.Response> Function() requestAction, {
    required bool isIdempotent,
    required String correlationId,
    required String path,
    required Map<String, String> headers,
  }) async {
    final response = await _executeWithRetry(
      requestAction,
      isIdempotent: isIdempotent,
      correlationId: correlationId,
    );
    if (response.statusCode == 401 &&
        !_isExplicitReauthPath(path) &&
        onRefreshToken != null) {
      String? newToken;
      try {
        _refreshInFlight ??= onRefreshToken!().whenComplete(() {
          _refreshInFlight = null;
        });
        newToken = await _refreshInFlight;
      } catch (_) {
        newToken = null;
      }
      if (newToken != null && newToken.trim().isNotEmpty) {
        authToken = newToken.trim();
        headers['Authorization'] = 'Bearer $authToken';
        return _executeWithRetry(
          requestAction,
          isIdempotent: isIdempotent,
          correlationId: correlationId,
        );
      }
    }
    return response;
  }

  void _storeCache(
    String cacheKey,
    ApiResponse<dynamic> response,
    Duration ttl,
  ) {
    _cache.remove(cacheKey);
    while (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = _CacheEntry(response, DateTime.now().add(ttl));
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParameters,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
    Duration? cacheDuration,
    bool forceRefresh = false,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final cacheKey = '${_tokenBucket()}|GET|$uri';

    if (!forceRefresh && cacheDuration != null) {
      final cached = _cache[cacheKey];
      if (cached != null) {
        if (cached.isValid) {
          _cache.remove(cacheKey);
          _cache[cacheKey] = cached;
          final cachedData = cached.response.data;
          if (cachedData is T) {
            return ApiResponse<T>(
              success: cached.response.success,
              statusCode: cached.response.statusCode,
              data: cachedData,
              message: cached.response.message,
            );
          }
        } else {
          _cache.remove(cacheKey);
        }
      }
    }

    final correlationId = _resolveCorrelationId(customHeaders);
    final headers = _buildHeaders(
      customHeaders: customHeaders,
      correlationId: correlationId,
      jsonContentType: false,
    );

    final http.Response response;
    if (!forceRefresh) {
      final existing = _inFlightRequests[cacheKey];
      if (existing != null) {
        response = await existing;
      } else {
        final future = _executeWithAuthRefresh(
          () => _httpClient.get(uri, headers: headers),
          isIdempotent: true,
          correlationId: correlationId,
          path: uri.path,
          headers: headers,
        );
        _inFlightRequests[cacheKey] = future;
        try {
          response = await future;
        } finally {
          _inFlightRequests.remove(cacheKey);
        }
      }
    } else {
      response = await _executeWithAuthRefresh(
        () => _httpClient.get(uri, headers: headers),
        isIdempotent: true,
        correlationId: correlationId,
        path: uri.path,
        headers: headers,
      );
    }

    final parsed = _handleResponse<T>(
      response,
      fromJsonT,
      correlationId,
      uri.path,
    );
    if (cacheDuration != null) {
      _storeCache(cacheKey, parsed, cacheDuration);
    }
    return parsed;
  }

  Future<Uint8List> getBytes(
    String endpoint, {
    Map<String, String>? queryParameters,
    Map<String, String>? customHeaders,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final correlationId = _resolveCorrelationId(customHeaders);
    final headers = _buildHeaders(
      customHeaders: {'Accept': '*/*', ...?customHeaders},
      correlationId: correlationId,
      jsonContentType: false,
    );

    final response = await _executeWithAuthRefresh(
      () => _httpClient.get(uri, headers: headers),
      isIdempotent: true,
      correlationId: correlationId,
      path: uri.path,
      headers: headers,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    _throwHttpError(response, correlationId, uri.path);
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    invalidateCache();
    final correlationId = _resolveCorrelationId(customHeaders);
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(
      customHeaders: customHeaders,
      correlationId: correlationId,
    );
    final encodedBody = body == null
        ? null
        : (body is String ? body : jsonEncode(body));

    final response = await _executeWithAuthRefresh(
      () => _httpClient.post(uri, headers: headers, body: encodedBody),
      isIdempotent: false,
      correlationId: correlationId,
      path: uri.path,
      headers: headers,
    );
    return _handleResponse<T>(response, fromJsonT, correlationId, uri.path);
  }

  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    invalidateCache();
    final correlationId = _resolveCorrelationId(customHeaders);
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(
      customHeaders: customHeaders,
      correlationId: correlationId,
    );
    final encodedBody = body == null
        ? null
        : (body is String ? body : jsonEncode(body));

    final response = await _executeWithAuthRefresh(
      () => _httpClient.put(uri, headers: headers, body: encodedBody),
      isIdempotent: false,
      correlationId: correlationId,
      path: uri.path,
      headers: headers,
    );
    return _handleResponse<T>(response, fromJsonT, correlationId, uri.path);
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    invalidateCache();
    final correlationId = _resolveCorrelationId(customHeaders);
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(
      customHeaders: customHeaders,
      correlationId: correlationId,
      jsonContentType: false,
    );

    final response = await _executeWithAuthRefresh(
      () => _httpClient.delete(uri, headers: headers),
      isIdempotent: false,
      correlationId: correlationId,
      path: uri.path,
      headers: headers,
    );
    return _handleResponse<T>(response, fromJsonT, correlationId, uri.path);
  }

  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    dynamic body,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    invalidateCache();
    final correlationId = _resolveCorrelationId(customHeaders);
    final uri = _buildUri(endpoint);
    final headers = _buildHeaders(
      customHeaders: customHeaders,
      correlationId: correlationId,
    );
    final encodedBody = body == null
        ? null
        : (body is String ? body : jsonEncode(body));

    final response = await _executeWithAuthRefresh(
      () => _httpClient.patch(uri, headers: headers, body: encodedBody),
      isIdempotent: false,
      correlationId: correlationId,
      path: uri.path,
      headers: headers,
    );
    return _handleResponse<T>(response, fromJsonT, correlationId, uri.path);
  }

  Future<ApiResponse<T>> send<T>(
    String method,
    String endpoint, {
    dynamic body,
    Map<String, String>? queryParameters,
    T Function(Map<String, dynamic>)? fromJsonT,
    Map<String, String>? customHeaders,
  }) async {
    final upper = method.toUpperCase();
    if (upper != 'GET' && upper != 'HEAD') {
      invalidateCache();
    }
    final correlationId = _resolveCorrelationId(customHeaders);
    final uri = _buildUri(endpoint, queryParameters);
    final headers = _buildHeaders(
      customHeaders: customHeaders,
      correlationId: correlationId,
      jsonContentType: body != null,
    );

    final response = await _executeWithAuthRefresh(
      () {
        final req = http.Request(upper, uri);
        req.headers.addAll(headers);
        if (body != null) {
          req.body = body is String ? body : jsonEncode(body);
        }
        return _httpClient.send(req).then(http.Response.fromStream);
      },
      isIdempotent: upper == 'GET' || upper == 'HEAD',
      correlationId: correlationId,
      path: uri.path,
      headers: headers,
    );
    return _handleResponse<T>(response, fromJsonT, correlationId, uri.path);
  }

  String _decodeUtf8Body(http.Response response) {
    if (response.bodyBytes.isEmpty) return '';
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>)? fromJsonT,
    String correlationId,
    String path,
  ) {
    final serverCorrelationId =
        response.headers['x-correlation-id'] ?? correlationId;
    final bodyString = _decodeUtf8Body(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 || bodyString.trim().isEmpty) {
        return ApiResponse<T>(
          success: true,
          statusCode: response.statusCode,
          data: null,
        );
      }

      try {
        final dynamic decoded = jsonDecode(bodyString);
        if (fromJsonT != null && decoded is Map<String, dynamic>) {
          return ApiResponse<T>(
            success: true,
            statusCode: response.statusCode,
            data: fromJsonT(decoded),
          );
        }
        if (decoded is T) {
          return ApiResponse<T>(
            success: true,
            statusCode: response.statusCode,
            data: decoded,
          );
        }
        return ApiResponse<T>(
          success: true,
          statusCode: response.statusCode,
          data: decoded as T?,
        );
      } catch (e) {
        throw ParsingException(
          message: 'Erro ao interpretar resposta do servidor.',
          cause: e,
          correlationId: serverCorrelationId,
        );
      }
    }

    _throwHttpError(
      response,
      serverCorrelationId,
      path,
      decodedBody: bodyString,
    );
  }

  Never _throwHttpError(
    http.Response response,
    String correlationId,
    String path, {
    String? decodedBody,
  }) {
    final bodyString = decodedBody ?? _decodeUtf8Body(response);
    final serverCorrelationId =
        response.headers['x-correlation-id'] ?? correlationId;
    String errorMessage =
        'Ocorreu um erro na requisição (${response.statusCode})';
    String? extractedCorrelationId = serverCorrelationId;

    if (bodyString.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(bodyString);
        if (decoded is Map<String, dynamic>) {
          if (decoded['correlationId'] is String &&
              (decoded['correlationId'] as String).isNotEmpty) {
            extractedCorrelationId = decoded['correlationId'] as String;
          }
          final errors = decoded['errors'];
          if (errors is List && errors.isNotEmpty) {
            final details = errors
                .whereType<Map>()
                .map((e) {
                  final f = e['fieldName']?.toString() ?? '';
                  final m = e['message']?.toString() ?? '';
                  if (m.isEmpty) return null;
                  return f.isEmpty ? m : '$f: $m';
                })
                .whereType<String>()
                .toList();
            if (details.isNotEmpty) {
              errorMessage = details.join('\n');
            }
          }
          final msg = decoded['message']?.toString();
          final oauthErr = decoded['error_description']?.toString();
          if (msg != null &&
              msg.trim().isNotEmpty &&
              errorMessage.startsWith('Ocorreu um erro')) {
            errorMessage = msg;
          } else if (oauthErr != null &&
              oauthErr.trim().isNotEmpty &&
              errorMessage.startsWith('Ocorreu um erro')) {
            errorMessage = oauthErr;
          }
        }
      } catch (_) {}
    }

    if (response.statusCode == 401) {
      final isExplicitReauthPath =
          path.contains('/oauth2/') ||
          path.contains('/auth/google') ||
          path.contains('/users/me/password') ||
          path.endsWith('/users');
      if (!isExplicitReauthPath &&
          onUnauthorized != null &&
          !_handlingUnauthorized) {
        _handlingUnauthorized = true;
        try {
          onUnauthorized!();
        } finally {
          _handlingUnauthorized = false;
        }
      }
      throw UnauthorizedException(
        message: errorMessage,
        statusCode: 401,
        responseBody: bodyString,
        correlationId: extractedCorrelationId,
      );
    }

    if (response.statusCode == 403) {
      throw UnauthorizedException(
        message: errorMessage,
        statusCode: 403,
        responseBody: bodyString,
        correlationId: extractedCorrelationId,
      );
    }

    if (response.statusCode == 404) {
      throw NotFoundException(
        message: errorMessage,
        responseBody: bodyString,
        correlationId: extractedCorrelationId,
      );
    }

    if (response.statusCode >= 500) {
      throw ServerException(
        message: errorMessage,
        statusCode: response.statusCode,
        responseBody: bodyString,
        correlationId: extractedCorrelationId,
      );
    }

    throw ClientException(
      message: errorMessage,
      statusCode: response.statusCode,
      responseBody: bodyString,
      correlationId: extractedCorrelationId,
    );
  }
}
