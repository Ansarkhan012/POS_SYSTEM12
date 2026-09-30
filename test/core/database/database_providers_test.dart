import 'dart:io';

import 'package:dokan_pro/core/database/app_database.dart';
import 'package:dokan_pro/core/database/database_providers.dart';
import 'package:dokan_pro/core/database/encryption/secure_key_store.dart';
import 'package:dokan_pro/core/database/local_data_failure.dart';
import 'package:dokan_pro/core/database/outbox/outbox_reader.dart';
import 'package:dokan_pro/core/identifiers/uuid_v4.dart';
import 'package:dokan_pro/core/time/device_clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'database_test_support.dart';

/// Counts reads so tests can prove failures are not retried.
class _CountingStore extends InMemorySecureKeyStore {
  int reads = 0;

  @override
  Future<String?> read(String name) {
    reads++;
    return super.read(name);
  }
}

/// Disposes [container] after closing its database, so Windows releases the
/// file before the temp directory is deleted (provider disposal cannot await).
final Set<ProviderContainer> _disposed = {};

Future<void> _disposeAndClose(ProviderContainer container) async {
  if (!_disposed.add(container)) return;
  final database = container.exists(appDatabaseProvider)
      ? container.read(appDatabaseProvider).value
      : null;
  await database?.close();
  container.dispose();
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dokan_pro_providers_');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
  });

  File databaseFile() => File('${directory.path}/dokan_pro_local.db');

  ProviderContainer container(SecureKeyStore store) {
    final container = ProviderContainer(
      overrides: [
        secureKeyStoreProvider.overrideWithValue(store),
        databaseFileResolverProvider.overrideWithValue(
          () async => databaseFile(),
        ),
        deviceClockProvider.overrideWithValue(FixedDeviceClock()),
      ],
    );
    addTearDown(() => _disposeAndClose(container));
    return container;
  }

  test('providers open the encrypted database and wire the outbox', () async {
    final c = container(InMemorySecureKeyStore());
    final db = await c.read(appDatabaseProvider.future);
    final runner = await c.read(localTransactionRunnerProvider.future);
    final writer = c.read(outboxWriterProvider);

    await runner.run((ctx) => writer.append(ctx, testDraft()));
    expect(await OutboxReader(db).eventsInDeviceSeqOrder(), hasLength(1));
    expect(isUuidV4(c.read(uuidV4GeneratorProvider).next()), isTrue);
  });

  test('disposing the container closes the database', () async {
    final c = ProviderContainer(
      overrides: [
        secureKeyStoreProvider.overrideWithValue(InMemorySecureKeyStore()),
        databaseFileResolverProvider.overrideWithValue(
          () async => databaseFile(),
        ),
      ],
    );
    final AppDatabase db = await c.read(appDatabaseProvider.future);
    c.dispose();
    await pumpEventQueue();
    await expectLater(db.customSelect('SELECT 1').get(), throwsA(anything));
    await db.close(); // idempotent; ensures the handle is released
  });

  test('a fail-closed error is surfaced once and not retried', () async {
    // An existing database file with no stored key.
    final creator = container(InMemorySecureKeyStore());
    await creator.read(appDatabaseProvider.future);
    await _disposeAndClose(creator);

    final store = _CountingStore();
    final c = container(store);
    await expectLater(
      c.read(appDatabaseProvider.future),
      throwsA(isA<LocalDataUnavailable>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(store.reads, 1);
    expect(store.values, isEmpty);
  });
}
