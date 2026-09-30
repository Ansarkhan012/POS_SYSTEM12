import 'dart:io';

import 'package:dokan_pro/core/database/device/device_identity_reader.dart';
import 'package:dokan_pro/core/database/encryption/database_key_manager.dart';
import 'package:dokan_pro/core/database/local_data_failure.dart';
import 'package:dokan_pro/core/identifiers/uuid_v4.dart';
import 'package:flutter_test/flutter_test.dart';

import 'database_test_support.dart';

/// Exact file contents, compared byte for byte.
List<int> _fingerprint(File file) => file.readAsBytesSync().toList();

void main() {
  late TestDatabaseEnvironment env;

  setUp(() async => env = await TestDatabaseEnvironment.create());

  Future<void> createDatabase() async {
    final db = await env.open();
    await env.close(db);
  }

  Matcher unavailable(LocalDataUnavailableReason reason) => throwsA(
    isA<LocalDataUnavailable>().having((f) => f.reason, 'reason', reason),
  );

  test(
    'creates a new encrypted database with key and device identity',
    () async {
      final db = await env.open();
      expect(env.databaseFile.existsSync(), isTrue);
      expect(env.storedKeyHex, hasLength(64));
      expect(isUuidV4(await DeviceIdentityReader(db).installId()), isTrue);
    },
  );

  test('install ID is created once and is stable across reopen', () async {
    final first = await env.open();
    final installId = await DeviceIdentityReader(first).installId();
    await env.close(first);
    final second = await env.open();
    expect(await DeviceIdentityReader(second).installId(), installId);
  });

  group('fails closed and leaves the database file byte-identical', () {
    test('key missing while the database exists', () async {
      await createDatabase();
      final before = _fingerprint(env.databaseFile);
      env.store.values.clear();

      await expectLater(
        env.opener().open(),
        unavailable(LocalDataUnavailableReason.keyMissing),
      );
      expect(_fingerprint(env.databaseFile), before);
      expect(env.store.values, isEmpty, reason: 'no new key may be created');
    });

    test('corrupt key', () async {
      await createDatabase();
      final before = _fingerprint(env.databaseFile);
      env.store.values[DatabaseKeyManager.defaultKeyName] = 'corrupt';

      await expectLater(
        env.opener().open(),
        unavailable(LocalDataUnavailableReason.keyCorrupt),
      );
      expect(_fingerprint(env.databaseFile), before);
      expect(env.store.values[DatabaseKeyManager.defaultKeyName], 'corrupt');
    });

    test('wrong key', () async {
      await createDatabase();
      final before = _fingerprint(env.databaseFile);
      env.store.values[DatabaseKeyManager.defaultKeyName] = 'cd' * 32;

      await expectLater(
        env.opener().open(),
        unavailable(LocalDataUnavailableReason.wrongKeyOrUnreadableDatabase),
      );
      expect(_fingerprint(env.databaseFile), before);
      expect(env.databaseFile.existsSync(), isTrue);
    });

    test('secure storage unavailable', () async {
      await createDatabase();
      final before = _fingerprint(env.databaseFile);
      env.store.failReads = true;

      await expectLater(
        env.opener().open(),
        throwsA(isA<SecureStorageUnavailable>()),
      );
      expect(_fingerprint(env.databaseFile), before);
    });

    test('an existing plaintext database is never opened', () async {
      // Simulates a foreign plaintext file at the database path. It is written
      // as bytes only; no plain SQLite connection is opened.
      env.databaseFile.writeAsBytesSync([
        ...'SQLite format 3\u0000'.codeUnits,
        ...List<int>.filled(4080, 0),
      ]);
      final before = _fingerprint(env.databaseFile);

      await expectLater(
        env.opener().open(),
        throwsA(isA<EncryptionNotActive>()),
      );
      expect(_fingerprint(env.databaseFile), before);
      expect(env.store.values, isEmpty);
    });
  });

  test('retrying after a failure never replaces the database', () async {
    await createDatabase();
    final before = _fingerprint(env.databaseFile);
    env.store.values.clear();
    for (var i = 0; i < 3; i++) {
      await expectLater(env.opener().open(), throwsA(isA<LocalDataFailure>()));
    }
    expect(_fingerprint(env.databaseFile), before);
    expect(
      env.directory.listSync().map(
        (e) => e.path.split(Platform.pathSeparator).last,
      ),
      ['dokan_pro_local.db'],
    );
  });
}
