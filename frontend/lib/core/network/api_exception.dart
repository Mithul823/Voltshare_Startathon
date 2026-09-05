class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.details = const {},
    this.statusCode,
    this.requestId,
  });

  final String code;
  final String message;
  final Map<String, Object?> details;
  final int? statusCode;
  final String? requestId;

  @override
  String toString() => message;
}
