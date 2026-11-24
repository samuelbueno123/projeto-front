import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configurações da API e endpoints com resolução dinâmica para web/LAN e mobile.
class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String _envApiPort = String.fromEnvironment(
    'API_PORT',
    defaultValue: '8080',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '1093543407623-ch2dq0uh0bnvrhm6pkf6kd8v75bvr3a0.apps.googleusercontent.com',
  );

  static const String oauthClientId = String.fromEnvironment(
    'OAUTH_CLIENT_ID',
    defaultValue: 'myclientid',
  );
  static const String oauthClientSecret = String.fromEnvironment(
    'OAUTH_CLIENT_SECRET',
    defaultValue: 'myclientsecret',
  );

  static const String _runtimeBaseUrlStorageKey = 'ancora_api_base_url';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static String? _runtimeOverrideBaseUrl;

  // Timeout padrão para requisições (em segundos)
  static const int requestTimeoutSeconds = 30;

  // Headers padrão
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Endpoints
  static const String authGoogleEndpoint = '/auth/google';
  static const String usersEndpoint = '/users';
  static const String unitsEndpoint = '/units';
  static const String sectorsEndpoint = '/sectors';
  static const String membershipsEndpoint = '/memberships';
  static const String billingPlansEndpoint = '/billingplans';

  static String? get runtimeOverrideBaseUrl => _runtimeOverrideBaseUrl;

  static bool get isRuntimeOverrideActive =>
      _runtimeOverrideBaseUrl != null && _runtimeOverrideBaseUrl!.isNotEmpty;

  /// Carrega uma URL de servidor salva manualmente pelo usuário (ex.: IP da rede local no celular).
  static Future<void> initialize() async {
    try {
      final stored = await _storage.read(key: _runtimeBaseUrlStorageKey);
      _runtimeOverrideBaseUrl = normalizeBaseUrl(stored);
    } catch (_) {
      // Ignora falhas de storage em ambientes de teste ou navegadores restritos.
    }
  }

  /// Define (ou limpa, se nulo/vazio) a URL de API personalizada em tempo de execução.
  static Future<void> setRuntimeBaseUrl(String? rawUrl) async {
    final normalized = normalizeBaseUrl(rawUrl);
    _runtimeOverrideBaseUrl = normalized;
    try {
      if (normalized == null) {
        await _storage.delete(key: _runtimeBaseUrlStorageKey);
      } else {
        await _storage.write(
          key: _runtimeBaseUrlStorageKey,
          value: normalized,
        );
      }
    } catch (_) {}
  }

  @visibleForTesting
  static void setRuntimeBaseUrlForTest(String? rawUrl) {
    _runtimeOverrideBaseUrl = normalizeBaseUrl(rawUrl);
  }

  /// Normaliza uma URL informada pelo usuário (adiciona `http://` se faltar e remove barra final).
  static String? normalizeBaseUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    var trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('://')) {
      trimmed = 'http://$trimmed';
    }
    trimmed = trimmed.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty) {
      return null;
    }
    return uri.toString().replaceAll(RegExp(r'/+$'), '');
  }

  static bool _isLocalhostHost(String host) {
    final lower = host.trim().toLowerCase();
    return lower == 'localhost' ||
        lower == '127.0.0.1' ||
        lower == '0.0.0.0' ||
        lower == '::1' ||
        lower == '[::1]';
  }

  static String get _resolvedPort {
    final trimmed = _envApiPort.trim();
    return trimmed.isEmpty ? '8080' : trimmed;
  }

  /// Resolve a URL base da API respeitando:
  /// 1) Override salvo em runtime no dispositivo
  /// 2) `--dart-define=API_BASE_URL=...` explícito (não-localhost)
  /// 3) Host atual do navegador quando rodando no Web em rede local (ex.: celular acessando IP do PC)
  /// 4) Fallback padrão (`http://localhost:8080` ou valor de ambiente)
  static String resolveBaseUrl({
    bool? isWeb,
    Uri? currentUri,
    String? envBaseUrlOverride,
  }) {
    final runtime = _runtimeOverrideBaseUrl;
    if (runtime != null && runtime.isNotEmpty) {
      return runtime;
    }

    final rawEnv = (envBaseUrlOverride ?? _envBaseUrl).trim();
    final isAutoEnv = rawEnv.isEmpty || rawEnv.toLowerCase() == 'auto';
    final normalizedEnv = isAutoEnv ? null : normalizeBaseUrl(rawEnv);

    if (normalizedEnv != null) {
      final envUri = Uri.tryParse(normalizedEnv);
      if (envUri != null && !_isLocalhostHost(envUri.host)) {
        return normalizedEnv;
      }
    }

    final runningOnWeb = isWeb ?? kIsWeb;
    if (runningOnWeb) {
      final pageUri = currentUri ?? Uri.base;
      if ((pageUri.scheme == 'http' || pageUri.scheme == 'https') &&
          pageUri.host.trim().isNotEmpty &&
          !_isLocalhostHost(pageUri.host)) {
        final hasExplicitPort = const bool.hasEnvironment('API_PORT');
        final portPart = (pageUri.scheme == 'https' && !hasExplicitPort)
            ? ''
            : ':$_resolvedPort';
        return '${pageUri.scheme}://${pageUri.host}$portPart';
      }
    }

    if (normalizedEnv != null) {
      return normalizedEnv;
    }
    return 'http://localhost:$_resolvedPort';
  }

  static String get baseUrl => resolveBaseUrl();

  /// Resolve um caminho relativo de mídia do servidor (ex.: "media/pictures/user_1_abc.png")
  /// ou asset local ("assets/...") para a URL/caminho adequado.
  static String? resolveMediaUrl(String? rawPath) {
    if (rawPath == null) return null;
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('data:') || trimmed.startsWith('assets/')) {
      return trimmed;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final mediaUri = Uri.tryParse(trimmed);
      final activeBaseUri = Uri.tryParse(baseUrl);
      if (mediaUri != null &&
          activeBaseUri != null &&
          _isLocalhostHost(mediaUri.host) &&
          !_isLocalhostHost(activeBaseUri.host)) {
        return mediaUri
            .replace(
              scheme: activeBaseUri.scheme,
              host: activeBaseUri.host,
              port: activeBaseUri.hasPort ? activeBaseUri.port : null,
            )
            .toString();
      }
      return trimmed;
    }
    final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanRelative = trimmed.replaceFirst(RegExp(r'^/+'), '');
    return '$cleanBase/$cleanRelative';
  }
}
