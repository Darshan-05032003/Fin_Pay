import 'package:fin_pay/core/storage/secure_storage.dart';

/// In-memory [SecureStorage] for tests. Set [failing] to make every call
/// throw a [SecureStorageException], simulating a broken keystore.
class FakeSecureStorage implements SecureStorage {
  FakeSecureStorage([Map<String, String>? initial]) : values = {...?initial};

  /// The backing map, exposed so tests can inspect or pre-seed it.
  final Map<String, String> values;

  /// When true every operation throws.
  bool failing = false;

  /// Number of writes performed, for idempotency assertions.
  int writes = 0;

  void _check() {
    if (failing) throw const SecureStorageException('keystore unavailable');
  }

  @override
  Future<String?> read(String key) async {
    _check();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _check();
    writes++;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _check();
    values.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async {
    _check();
    return values.containsKey(key);
  }

  @override
  Future<void> deleteAll() async {
    _check();
    values.clear();
  }
}
