import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dokan_pro/core/database/app_database.dart';
import 'package:dokan_pro/core/database/encrypted_database_opener.dart';
import 'package:dokan_pro/core/database/encryption/database_key_manager.dart';
import 'package:dokan_pro/core/database/encryption/secure_key_store.dart';
import 'package:dokan_pro/core/database/outbox/outbox_event_draft.dart';
import 'package:dokan_pro/core/identifiers/uuid_v4.dart';
import 'package:dokan_pro/core/time/device_clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for platform secure storage (unit tests only). The real
/// Keystore-backed store is exercised by the on-device integration test.
class InMemorySecureKeyStore implements SecureKeyStore {
  final Map<String, String> values = {};
  bool failReads = false;
  bool failWrites = false;

  /// Simulates a store that accepts writes but does not persist them.
  bool dropWrites = false;

  @override
  Future<String?> read(String name) async {
    if (failReads) throw StateError('secure storage read failed');
    return values[name];
  }

  @override
  Future<void> write(String name, String value) async {
    if (failWrites) throw StateError('secure storage write failed');
    if (!dropWrites) values[name] = value;
  }
}

/// Deterministic clock.
class FixedDeviceClock implements DeviceClock {
  FixedDeviceClock({
    this.utcMicros = 1759200000000000,
    this.offsetMinutes = 300,
  });

  int utcMicros;
  int offsetMinutes;

  @override
  DeviceInstant now() =>
      DeviceInstant(utcMicros: utcMicros, utcOffsetMinutes: offsetMinutes);
}

/// A temporary directory holding one encrypted test database, opened through
/// the production [EncryptedDatabaseOpener] (no plain-SQLite path).
class TestDatabaseEnvironment {
  TestDatabaseEnvironment._(this.directory);

  static Future<TestDatabaseEnvironment> create() async {
    final directory = await Directory.systemTemp.createTemp('dokan_pro_db_');
    final environment = TestDatabaseEnvironment._(directory);
    addTearDown(environment.dispose);
    return environment;
  }

  final Directory directory;
  final InMemorySecureKeyStore store = InMemorySecureKeyStore();
  final FixedDeviceClock clock = FixedDeviceClock();
  final UuidV4Generator ids = UuidV4Generator();
  final List<AppDatabase> _open = [];

  File get databaseFile => File('${directory.path}/dokan_pro_local.db');

  DatabaseKeyManager keyManager() =>
      DatabaseKeyManager(store: store, secureRandom: Random.secure());

  EncryptedDatabaseOpener opener() => EncryptedDatabaseOpener(
    keyManager: keyManager(),
    resolveDatabaseFile: () async => databaseFile,
    ids: ids,
    clock: clock,
  );

  Future<AppDatabase> open() async {
    final database = await opener().open();
    _open.add(database);
    return database;
  }

  Future<void> close(AppDatabase database) async {
    _open.remove(database);
    await database.close();
  }

  /// The stored key in hex (tests only).
  String get storedKeyHex => store.values[DatabaseKeyManager.defaultKeyName]!;

  /// Raw bytes of the database file and any journal/WAL files.
  Map<String, Uint8List> rawFiles() => {
    for (final suffix in ['', '-journal', '-wal', '-shm'])
      if (File('${databaseFile.path}$suffix').existsSync())
        suffix: File('${databaseFile.path}$suffix').readAsBytesSync(),
  };

  Future<void> dispose() async {
    for (final database in List.of(_open)) {
      await database.close();
    }
    _open.clear();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}

/// A valid draft for tests. The IDs are test fixtures, not business data.
OutboxEventDraft testDraft({
  String eventType = 'test.event',
  Map<String, Object?> payload = const {'value': 1},
  String? idempotencyKey,
}) => OutboxEventDraft(
  eventType: eventType,
  schemaVersion: 1,
  payload: payload,
  shopId: 'test-shop',
  localSessionId: 'test-session',
  actorUserId: 'test-actor',
  idempotencyKey: idempotencyKey,
);

/// True if [haystack] contains the bytes of [needle].
bool containsBytes(Uint8List haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
