import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../identifiers/uuid_v4.dart';
import '../time/device_clock.dart';
import 'app_database.dart';
import 'encrypted_database_opener.dart';
import 'encryption/database_key_manager.dart';
import 'encryption/secure_key_store.dart';
import 'local_transaction.dart';
import 'outbox/outbox_writer.dart';

/// Riverpod wiring for the local data foundation. Nothing reads these from the
/// UI in Phase 2 and the app does not open the database at startup (P2-D2).
/// All providers can be overridden in tests.

/// File name of the encrypted POS database in the app-private support
/// directory (ADR-029).
const String localDatabaseFileName = 'dokan_pro_local.db';

Future<File> resolveDefaultDatabaseFile() async {
  final directory = await getApplicationSupportDirectory();
  return File(p.join(directory.path, localDatabaseFileName));
}

final secureKeyStoreProvider = Provider<SecureKeyStore>(
  (ref) => PlatformSecureKeyStore(),
);

final secureRandomProvider = Provider<Random>((ref) => Random.secure());

final databaseKeyManagerProvider = Provider<DatabaseKeyManager>(
  (ref) => DatabaseKeyManager(
    store: ref.watch(secureKeyStoreProvider),
    secureRandom: ref.watch(secureRandomProvider),
  ),
);

final databaseFileResolverProvider = Provider<Future<File> Function()>(
  (ref) => resolveDefaultDatabaseFile,
);

final encryptedDatabaseOpenerProvider = Provider<EncryptedDatabaseOpener>(
  (ref) => EncryptedDatabaseOpener(
    keyManager: ref.watch(databaseKeyManagerProvider),
    resolveDatabaseFile: ref.watch(databaseFileResolverProvider),
    ids: ref.watch(uuidV4GeneratorProvider),
    clock: ref.watch(deviceClockProvider),
  ),
);

/// The opened database. Errors surface as typed `LocalDataFailure`s and are
/// never retried automatically (fail closed, P2-D3). Closed on dispose.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final database = await ref.watch(encryptedDatabaseOpenerProvider).open();
  ref.onDispose(() => unawaited(database.close()));
  return database;
}, retry: (retryCount, error) => null);

final localTransactionRunnerProvider = FutureProvider<LocalTransactionRunner>(
  (ref) async =>
      LocalTransactionRunner(await ref.watch(appDatabaseProvider.future)),
  retry: (retryCount, error) => null,
);

final outboxWriterProvider = Provider<OutboxWriter>(
  (ref) => OutboxWriter(
    ids: ref.watch(uuidV4GeneratorProvider),
    clock: ref.watch(deviceClockProvider),
  ),
);
