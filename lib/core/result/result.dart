/// Result pattern for functional error handling
/// 
/// This sealed class represents either a success or failure,
/// eliminating the need for exceptions in business logic.
sealed class Result<T> {
  const Result();
}

/// Represents a successful operation
final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

/// Represents a failed operation
final class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  const Failure(this.message, [this.error]);
}

/// Extension methods for Result
extension ResultExtensions<T> on Result<T> {
  /// Check if result is success
  bool get isSuccess => this is Success<T>;
  
  /// Check if result is failure
  bool get isFailure => this is Failure<T>;
  
  /// Get data if success, null otherwise
  T? get dataOrNull => switch (this) {
    Success(data: final d) => d,
    Failure() => null,
  };
  
  /// Get error message if failure, null otherwise
  String? get errorOrNull => switch (this) {
    Success() => null,
    Failure(message: final m) => m,
  };
  
  /// Map the data if success
  Result<R> map<R>(R Function(T) mapper) {
    return switch (this) {
      Success(data: final d) => Success(mapper(d)),
      Failure(message: final m, error: final e) => Failure(m, e),
    };
  }
  
  /// Flat map (chain operations)
  Result<R> flatMap<R>(Result<R> Function(T) mapper) {
    return switch (this) {
      Success(data: final d) => mapper(d),
      Failure(message: final m, error: final e) => Failure(m, e),
    };
  }
  
  /// Flat map async (chain async operations)
  Future<Result<R>> flatMapAsync<R>(Future<Result<R>> Function(T) mapper) async {
    return switch (this) {
      Success(data: final d) => await mapper(d),
      Failure(message: final m, error: final e) => Failure(m, e),
    };
  }
  
  /// Execute on success
  Result<T> onSuccess(void Function(T) action) {
    if (this is Success<T>) {
      action((this as Success<T>).data);
    }
    return this;
  }
  
  /// Execute on failure
  Result<T> onFailure(void Function(String, Object?) action) {
    if (this is Failure<T>) {
      final failure = this as Failure<T>;
      action(failure.message, failure.error);
    }
    return this;
  }
}

