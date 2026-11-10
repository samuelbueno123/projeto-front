/// Exceção base para erros de API com suporte a rastreabilidade (Correlation ID)
abstract class ApiException implements Exception {
  const ApiException(this.message, {this.correlationId});

  final String message;
  final String? correlationId;

  /// Retorna a mensagem de erro acompanhada do código de correlação, se disponível
  String get displayMessage {
    if (correlationId != null && correlationId!.trim().isNotEmpty) {
      return '$message\n(Código de rastreamento: $correlationId)';
    }
    return message;
  }

  @override
  String toString() => displayMessage;
}

/// Erro de rede/conectividade
class NetworkException extends ApiException {
  const NetworkException(super.message, {super.correlationId});
}

/// Erro 4xx (cliente)
class ClientException extends ApiException {
  ClientException({
    required String message,
    required this.statusCode,
    this.responseBody,
    super.correlationId,
  }) : super(message);

  final int statusCode;
  final String? responseBody;
}

/// Erro 401/403 (autenticação/autorização)
class UnauthorizedException extends ClientException {
  UnauthorizedException({
    required super.message,
    required super.statusCode,
    super.responseBody,
    super.correlationId,
  });
}

/// Erro 404 (não encontrado)
class NotFoundException extends ClientException {
  NotFoundException({
    required super.message,
    super.responseBody,
    super.correlationId,
  }) : super(statusCode: 404);
}

/// Erro 5xx (servidor)
class ServerException extends ApiException {
  ServerException({
    required String message,
    required this.statusCode,
    this.responseBody,
    super.correlationId,
  }) : super(message);

  final int statusCode;
  final String? responseBody;
}

/// Erro de parsing/desserialização
class ParsingException extends ApiException {
  ParsingException({
    required String message,
    this.cause,
    super.correlationId,
  }) : super(message);

  final dynamic cause;
}

/// Erro de timeout
class TimeoutException extends ApiException {
  const TimeoutException(super.message, {super.correlationId});
}
