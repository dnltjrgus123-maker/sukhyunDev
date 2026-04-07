class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  final int statusCode;
  final String message;
  final String? body;

  @override
  String toString() {
    if (body == null || body!.isEmpty) {
      return "ApiException($statusCode): $message";
    }
    return "ApiException($statusCode): $message - $body";
  }
}
