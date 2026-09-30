import 'dart:math';

import 'package:dokan_pro/core/database/encryption/database_key.dart';
import 'package:dokan_pro/core/database/encryption/database_key_manager.dart';
import 'package:dokan_pro/core/database/local_data_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database_test_support.dart';

void main() {
  late InMemorySecureKeyStore store;
  late DatabaseKeyManager manager;

  setUp(() {
    store = InMemorySecureKeyStore();
    manager = DatabaseKeyManager(store: store, secureRandom: Random.secure());
  });

  group('DatabaseKey', () {
    test('is 32 random bytes rendered as 64 hex characters', () {
      final key = DatabaseKey.generate(Random.secure());
      expect(key.toHex(), matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(DatabaseKey.lengthInBytes, 32);
    });

    test('generated keys differ', () {
      final keys = {
        for (var i = 0; i < 100; i++)
          DatabaseKey.generate(Random.secure()).toHex(),
      };
      expect(keys, hasLength(100));
    });

    test('round-trips through its stored form', () {
      final key = DatabaseKey.generate(Random.secure());
      expect(DatabaseKey.fromStoredHex(key.toHex()).toHex(), key.toHex());
    });

    test('rejects malformed stored values without echoing them', () {
      for (final bad in ['', 'abc', 'G' * 64, 'A' * 64, 'a' * 63, 'a' * 65]) {
        try {
          DatabaseKey.fromStoredHex(bad);
          fail('accepted "$bad"');
        } on FormatException catch (error) {
          expect(error.source, isNull);
          if (bad.isNotEmpty) expect(error.toString(), isNot(contains(bad)));
        }
      }
    });

    test('toString redacts the key', () {
      final key = DatabaseKey.generate(Random.secure());
      expect(key.toString(), 'DatabaseKey(<redacted>)');
      expect(key.toString(), isNot(contains(key.toHex())));
      expect('$key', isNot(contains(key.toHex().substring(0, 8))));
    });
  });

  group('DatabaseKeyManager', () {
    test(
      'creates a key once for a new database and returns it afterwards',
      () async {
        final first = await manager.obtainKey(databaseExists: false);
        final stored = store.values[DatabaseKeyManager.defaultKeyName];
        expect(stored, first.toHex());
        final second = await manager.obtainKey(databaseExists: true);
        expect(second.toHex(), first.toHex());
        expect(store.values, hasLength(1));
      },
    );

    test(
      'never creates a key for an existing database (fail closed)',
      () async {
        await expectLater(
          manager.obtainKey(databaseExists: true),
          throwsA(
            isA<LocalDataUnavailable>().having(
              (f) => f.reason,
              'reason',
              LocalDataUnavailableReason.keyMissing,
            ),
          ),
        );
        expect(store.values, isEmpty);
      },
    );

    test('a corrupt stored key fails closed and is not replaced', () async {
      store.values[DatabaseKeyManager.defaultKeyName] = 'not-a-key';
      for (final exists in [true, false]) {
        await expectLater(
          manager.obtainKey(databaseExists: exists),
          throwsA(
            isA<LocalDataUnavailable>().having(
              (f) => f.reason,
              'reason',
              LocalDataUnavailableReason.keyCorrupt,
            ),
          ),
        );
      }
      expect(store.values[DatabaseKeyManager.defaultKeyName], 'not-a-key');
    });

    test(
      'secure storage failures surface as SecureStorageUnavailable',
      () async {
        store.failReads = true;
        await expectLater(
          manager.obtainKey(databaseExists: false),
          throwsA(isA<SecureStorageUnavailable>()),
        );
        store
          ..failReads = false
          ..failWrites = true;
        await expectLater(
          manager.obtainKey(databaseExists: false),
          throwsA(isA<SecureStorageUnavailable>()),
        );
      },
    );

    test('a store that silently drops writes is detected', () async {
      store.dropWrites = true;
      await expectLater(
        manager.obtainKey(databaseExists: false),
        throwsA(isA<SecureStorageUnavailable>()),
      );
    });

    test('failure messages never contain key material', () async {
      final key = await manager.obtainKey(databaseExists: false);
      const failures = <LocalDataFailure>[
        LocalDataUnavailable(LocalDataUnavailableReason.keyMissing),
        LocalDataUnavailable(LocalDataUnavailableReason.keyCorrupt),
        LocalDataUnavailable(
          LocalDataUnavailableReason.wrongKeyOrUnreadableDatabase,
        ),
        SecureStorageUnavailable(),
        EncryptionNotActive('x'),
      ];
      for (final failure in failures) {
        expect(failure.toString(), isNot(contains(key.toHex())));
      }
    });
  });
}
