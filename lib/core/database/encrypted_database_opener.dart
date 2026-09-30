import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import '../identifiers/uuid_v4.dart';
import '../time/device_clock.dart';
import 'app_database.dart';
import 'encryption/database_key.dart';
import 'encryption/database_key_manager.dart';
import 'encryption/encrypted_connection.dart';
import 'local_data_failure.dart';

/// The only way to open or create the POS database (ADR-027).
///
/// There is no unencrypted path and no fallback. Every connection is
/// configured and verified by [configureEncryptedConnection] before anything
/// else touches the file. Failures are typed [LocalDataFailure]s; the existing
/// database file is never deleted, overwritten, renamed or recreated (P2-D3).
///
/// Statement logging is never enabled: it would print the key PRAGMA.
class EncryptedDatabaseOpener {
  EncryptedDatabaseOpener({
    required this._keyManager,
    required this._resolveDatabaseFile,
    required this._ids,
    required this._clock,
  });

  final DatabaseKeyManager _keyManager;
  final Future<File> Function() _resolveDatabaseFile;
  final UuidV4Generator _ids;
  final DeviceClock _clock;

  Future<AppDatabase> open() async {
    final file = await _resolveDatabaseFile();
    final databaseExists = file.existsSync();
    if (databaseExists && hasPlaintextSqliteHeader(file)) {
      // Never open (and thereby keep using) a plaintext database.
      throw const EncryptionNotActive(
        'existing database file is not encrypted',
      );
    }

    final key = await _keyManager.obtainKey(databaseExists: databaseExists);

    // Preflight on this isolate: proves the encrypted engine is loaded and the
    // key is correct, producing typed failures before Drift runs any schema
    // work. Nothing is written by the preflight.
    _preflight(file, key);

    // Runs off the UI isolate. The setup callback executes first on every
    // connection and re-verifies encryption before Drift reads or writes.
    final executor = NativeDatabase.createInBackground(
      file,
      setup: (raw) => configureEncryptedConnection(raw, key),
    );
    final database = AppDatabase(executor, ids: _ids, clock: _clock);

    try {
      // Opens the connection: runs setup, then creates or validates schema.
      await database.customSelect('SELECT 1').get();
      if (hasPlaintextSqliteHeader(file)) {
        throw const EncryptionNotActive('database file is not encrypted');
      }
      return database;
    } on Object {
      await _closeQuietly(database);
      rethrow;
    }
  }

  static void _preflight(File file, DatabaseKey key) {
    final raw = sqlite3.open(file.path);
    try {
      configureEncryptedConnection(raw, key);
    } finally {
      raw.close();
    }
  }

  static Future<void> _closeQuietly(AppDatabase database) async {
    try {
      await database.close();
    } on Object {
      // The original failure is more important than a close error.
    }
  }
}
