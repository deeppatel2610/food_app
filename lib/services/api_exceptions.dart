class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message, 503);
}

class AuthException extends ApiException {
  AuthException(String message) : super(message, 401);
}

class ValidationException extends ApiException {
  ValidationException(String message) : super(message, 400);
}
