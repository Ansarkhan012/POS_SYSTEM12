import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dokan_pro/core/database/app_database.dart';
import 'package:dokan_pro/core/database/device/device_identity_reader.dart';
import 'package:dokan_pro/core/database/encrypted_database_opener.dart';
import 'package:dokan_pro/core/database/encryption/database_key_manager.dart';
import 'package:dokan_pro/core/database/encryption/encrypted_connection.dart';
import 'package:dokan_pro/core/database/encryption/secure_key_store.dart';
import 'package:dokan_pro/core/database/local_transaction.dart';
import 'package:dokan_pro/core/database/outbox/outbox_event_draft.dart';
import 'package:dokan_pro/core/database/outbox/outbox_reader.dart';
import 'package:dokan_pro/core/database/outbox/outbox_writer.dart';
import 'package:dokan_pro/core/identifiers/uuid_v4.dart';
import 'package:dokan_pro/core/time/device_clock.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// On-device proof of encryption with the REAL Android implementation:
/// SQLite3 Multiple Ciphers native library, Android Keystore-backed
/// `flutter_secure_storage`, and the app-private support directory.
///
/// Isolated from real app data: its own database file name and its own
/// secure-storage namespace and key name.
///
/// Phases (`--dart-define=DOKAN_IT_PHASE=...`):
/// - `single` (default): create, verify, reopen, then clean up.
/// - `create`: create and leave the data for a later `verify` run.
/// - `verify`: requires data from a previous `create` run (proves the key and
///   data survive a full app restart), verifies, then cleans up.
const String _phase = String.fromEnvironment(
  'DOKAN_IT_PHASE',
  defaultValue: 'single',
);
const String _namespace = 'dokan_pro_integration_test';
const String _keyName = 'dokan_pro.integration_test.key.v1';
const String _fileName = 'dokan_pro_integration_test.db';
const String _marker = 'DOKAN-PRO-DEVICE-MARKER-4c1d8b2e';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late File file;

  EncryptedDatabaseOpener opener() => EncryptedDatabaseOpener(
    keyManager: DatabaseKeyManager(
      store: PlatformSecureKeyStore(namespace: _namespace),
      secureRandom: Random.secure(),
      keyName: _keyName,
    ),
    resolveDatabaseFile: () async => file,
    ids: UuidV4Generator(),
    clock: const SystemDeviceClock(),
  );

  Future<String?> storedKey() => const FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: _namespace),
  ).read(key: _keyName);

  Future<void> cleanUp() async {
    for (final suffix in ['', '-journal', '-wal', '-shm']) {
      final f = File('${file.path}$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    // Test-owned key only; the app itself never deletes its key.
    await const FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: _namespace),
    ).delete(key: _keyName);
  }

  setUpAll(() async {
    final directory = await getApplicationSupportDirectory();
    file = File(p.join(directory.path, _fileName));
    if (_phase != 'verify' && file.existsSync()) await cleanUp();
  });

  testWidgets('encrypted database on a real Android device ($_phase)', (
    tester,
  ) async {
    if (_phase == 'verify') {
      expect(file.existsSync(), isTrue, reason: 'run the create phase first');
    }

    // Open (create or reopen) through the production opener.
    AppDatabase db = await opener().open();
    final installId = await DeviceIdentityReader(db).installId();
    final before = await OutboxReader(db).eventsInDeviceSeqOrder();
    if (_phase == 'verify') {
      expect(
        before.map(_markerOf),
        contains(_marker),
        reason: 'data from the create run must survive an app restart',
      );
    }
    if (_phase != 'verify') {
      await LocalTransactionRunner(db).run(
        (ctx) =>
            OutboxWriter(
              ids: UuidV4Generator(),
              clock: const SystemDeviceClock(),
            ).append(
              ctx,
              const OutboxEventDraft(
                eventType: 'integration_test.marker',
                schemaVersion: 1,
                payload: {'marker': _marker},
                shopId: 'integration-test-shop',
                localSessionId: 'integration-test-session',
                actorUserId: 'integration-test-actor',
              ),
            ),
      );
    }
    await db.close();

    // 1. Header is not plaintext SQLite.
    expect(hasPlaintextSqliteHeader(file), isFalse);
    // 2. The engine is SQLite3 Multiple Ciphers with the SQLCipher scheme.
    final probe = sqlite3.openInMemory();
    expect(
      probe.select("PRAGMA cipher = 'sqlcipher';").first.values.first,
      'sqlcipher',
    );
    probe.close();
    // 3. No key: unreadable.
    final noKey = sqlite3.open(file.path);
    expect(
      () => noKey.select('SELECT count(*) FROM sqlite_master;'),
      throwsA(isA<SqliteException>()),
    );
    noKey.close();
    // 4. Wrong key: unreadable.
    final wrongKey = sqlite3.open(file.path)
      ..execute("PRAGMA cipher = 'sqlcipher';")
      ..execute('PRAGMA legacy = 4;')
      ..execute('PRAGMA key = "x\'${'ef' * 32}\'";');
    expect(
      () => wrongKey.select('SELECT count(*) FROM sqlite_master;'),
      throwsA(isA<SqliteException>()),
    );
    wrongKey.close();
    // 5. The marker is not in the raw bytes of any database file.
    final markerBytes = utf8.encode(_marker);
    for (final suffix in ['', '-journal', '-wal', '-shm']) {
      final f = File('${file.path}$suffix');
      if (!f.existsSync()) continue;
      expect(
        _contains(f.readAsBytesSync(), markerBytes),
        isFalse,
        reason: 'marker found in $suffix',
      );
    }
    // 6. The key lives only in Keystore-backed secure storage: 64 hex chars,
    //    and not inside the app's support directory files.
    final key = await storedKey();
    expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
    for (final entity in file.parent.listSync(recursive: true)) {
      if (entity is File && entity.lengthSync() < 10 * 1024 * 1024) {
        expect(
          _contains(entity.readAsBytesSync(), utf8.encode(key!)),
          isFalse,
          reason: 'key found in ${entity.path}',
        );
      }
    }
    // 7. Reopen with fresh objects: reads the data; install ID is stable.
    db = await opener().open();
    final events = await OutboxReader(db).eventsInDeviceSeqOrder();
    expect(events.map(_markerOf), contains(_marker));
    expect(await DeviceIdentityReader(db).installId(), installId);
    await db.close();

    if (_phase != 'create') await cleanUp();
  });
}

/// The `marker` value of an event payload (maps compare by identity, so the
/// decoded map itself cannot be matched with `contains`).
Object? _markerOf(OutboxEventRow event) =>
    (jsonDecode(event.payloadJson) as Map<String, Object?>)['marker'];

bool _contains(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
