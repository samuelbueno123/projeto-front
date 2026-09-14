/// Configurações da API e endpoints
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://localhost:8080',
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
