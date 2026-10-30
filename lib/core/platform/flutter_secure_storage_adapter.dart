import 'package:fin_pay/core/storage/secure_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [SecureStorage] backed by `flutter_secure_storage` (Android Keystore,
/// iOS Keychain). Every plugin error is surfaced as a
/// [SecureStorageException] so callers can map it to a typed failure.
class FlutterSecureStorageAdapter implements SecureStorage {
  FlutterSecureStorageAdapter([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Exception catch (e) {
      throw SecureStorageException('secure storage failed', e);
    }
  }

  @override
  Future<String?> read(String key) => _guard(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _guard(() => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) => _guard(() => _storage.delete(key: key));

  @override
  Future<bool> containsKey(String key) =>
      _guard(() => _storage.containsKey(key: key));

  @override
  Future<void> deleteAll() => _guard(_storage.deleteAll);
}
