class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.message,
  });

  final bool success;
  final int statusCode;
  final T? data;
  final String? message;

  factory ApiResponse.success(
    T? data, {
    required int statusCode,
    String? message,
  }) => ApiResponse(
    success: true,
    statusCode: statusCode,
    data: data,
    message: message,
  );
}
