/// Key/value storage backed by the platform keystore (Android Keystore /
/// iOS Keychain). Holds credential hashes, the session marker and card
/// PAN/CVV; never the sqflite data.
///
/// Implemented by `FlutterSecureStorageAdapter` in production and
/// `FakeSecureStorage` in tests.
abstract interface class SecureStorage {
  /// Returns the value for [key], or null when absent.
  Future<String?> read(String key);

  /// Writes [value] under [key], replacing any previous value.
  Future<void> write(String key, String value);

  /// Removes [key]; a missing key is not an error.
  Future<void> delete(String key);

  /// True when [key] holds a value.
  Future<bool> containsKey(String key);

  /// Removes every key written by the app.
  Future<void> deleteAll();
}

/// Thrown by a [SecureStorage] when the platform store is unavailable or
/// corrupt (for example after a keystore reset).
class SecureStorageException implements Exception {
  const SecureStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'SecureStorageException: $message';
}
