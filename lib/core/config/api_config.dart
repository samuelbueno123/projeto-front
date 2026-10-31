/// Configurações da API e endpoints
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
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

  /// Resolve um caminho relativo de mídia do servidor (ex.: "media/pictures/user_1_abc.png")
  /// para a URL completa servida pelo backend.
  static String? resolveMediaUrl(String? rawPath) {
    if (rawPath == null) return null;
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('data:') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return trimmed;
    }
    final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanRelative = trimmed.replaceFirst(RegExp(r'^/+'), '');
    return '$cleanBase/$cleanRelative';
  }
}
