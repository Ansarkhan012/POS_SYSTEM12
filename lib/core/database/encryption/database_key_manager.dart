import 'dart:math';

import '../local_data_failure.dart';
import 'database_key.dart';
import 'secure_key_store.dart';

/// Obtains the database key from platform secure storage (ADR-027).
///
/// The API takes no PIN or user input: the key is never derived from a PIN.
/// It fails closed (P2-D3): a missing or malformed key for an existing
/// database is an error, never a reason to create a new key or database.
class DatabaseKeyManager {
  DatabaseKeyManager({
    required this._store,
    required this._secureRandom,
    this.keyName = defaultKeyName,
  });

  static const String defaultKeyName = 'dokan_pro.local_database.key.v1';

  final SecureKeyStore _store;
  final Random _secureRandom;
  final String keyName;

  /// Returns the key for the database. A new key is generated only when
  /// [databaseExists] is false and no key is stored.
  Future<DatabaseKey> obtainKey({required bool databaseExists}) async {
    final stored = await _read();
    if (stored != null) {
      try {
        return DatabaseKey.fromStoredHex(stored);
      } on FormatException {
        throw const LocalDataUnavailable(LocalDataUnavailableReason.keyCorrupt);
      }
    }
    if (databaseExists) {
      throw const LocalDataUnavailable(LocalDataUnavailableReason.keyMissing);
    }

    final key = DatabaseKey.generate(_secureRandom);
    final hex = key.toHex();
    try {
      await _store.write(keyName, hex);
    } on Object {
      throw const SecureStorageUnavailable();
    }
    // Read back so a silently failing store can never leave a database whose
    // key was not persisted.
    if (await _read() != hex) throw const SecureStorageUnavailable();
    return key;
  }

  Future<String?> _read() async {
    try {
      return await _store.read(keyName);
    } on Object {
      throw const SecureStorageUnavailable();
    }
  }
}
