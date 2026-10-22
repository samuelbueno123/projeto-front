/// Exceção base para erros de API
abstract class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Erro de rede/conectividade
class NetworkException extends ApiException {
  const NetworkException(String message) : super(message);
}

/// Erro 4xx (cliente)
class ClientException extends ApiException {
  ClientException({
    required String message,
    required this.statusCode,
    this.responseBody,
  }) : super(message);

  final int statusCode;
  final String? responseBody;
}

/// Erro 401/403 (autenticação/autorização)
class UnauthorizedException extends ClientException {
  UnauthorizedException({
    required String message,
    required int statusCode,
    String? responseBody,
  }) : super(
         message: message,
         statusCode: statusCode,
         responseBody: responseBody,
       );
}

/// Erro 404 (não encontrado)
class NotFoundException extends ClientException {
  NotFoundException({required String message, String? responseBody})
    : super(message: message, statusCode: 404, responseBody: responseBody);
}

/// Erro 5xx (servidor)
class ServerException extends ApiException {
  ServerException({
    required String message,
    required this.statusCode,
    this.responseBody,
  }) : super(message);

  final int statusCode;
  final String? responseBody;
}

/// Erro de parsing/desserialização
class ParsingException extends ApiException {
  ParsingException({required String message, this.cause}) : super(message);

  final dynamic cause;
}

/// Erro de timeout
class TimeoutException extends ApiException {
  const TimeoutException(String message) : super(message);
}
