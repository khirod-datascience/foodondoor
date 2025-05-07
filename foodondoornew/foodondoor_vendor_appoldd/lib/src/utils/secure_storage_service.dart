import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A service class for securely storing key-value pairs.
class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  FlutterSecureStorage get secureStorage => _storage;

  Future<void> write({required String key, required String? value}) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
