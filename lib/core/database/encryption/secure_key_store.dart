import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal secure key-value store for the database key.
///
/// There is intentionally no delete operation: the key is never removed by the
/// app (P2-D3, no recovery key per ADR-027).
abstract interface class SecureKeyStore {
  Future<String?> read(String name);

  Future<void> write(String name, String value);
}

/// Android Keystore-backed storage via `flutter_secure_storage` (ADR-029):
/// default `AndroidOptions` (AES-GCM values, key wrapped by a Keystore
/// RSA-OAEP key) in a dedicated Dokan Pro namespace.
class PlatformSecureKeyStore implements SecureKeyStore {
  PlatformSecureKeyStore({String namespace = defaultNamespace})
    : _storage = FlutterSecureStorage(
        aOptions: AndroidOptions(storageNamespace: namespace),
      );

  static const String defaultNamespace = 'dokan_pro_database_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);
}
