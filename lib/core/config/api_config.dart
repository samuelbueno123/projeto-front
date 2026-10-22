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
}
