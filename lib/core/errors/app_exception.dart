/// Base exception class for the application
abstract class AppException implements Exception {
  
  const AppException(this.message, [this.originalError]);
  final String message;
  final Object? originalError;
  
  @override
  String toString() => message;
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException(super.message, [super.originalError]);
}

/// Database-related exceptions
class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.originalError]);
}

/// Authentication-related exceptions
class AuthenticationException extends AppException {
  const AuthenticationException(super.message, [super.originalError]);
}

/// Validation-related exceptions
class ValidationException extends AppException {
  const ValidationException(super.message, [super.originalError]);
}

/// Not found exceptions
class NotFoundException extends AppException {
  const NotFoundException(super.message, [super.originalError]);
}

/// Generic application exceptions
class AppError extends AppException {
  const AppError(super.message, [super.originalError]);
}

