import 'package:drift/drift.dart';

import '../identifiers/uuid_v4.dart';
import '../time/device_clock.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The encrypted local database (ADR-016, ADR-027, ADR-029).
///
/// Construct it only through `EncryptedDatabaseOpener`, which supplies an
/// encrypted, verified connection. Schema v1 contains foundation tables only.
@DriftDatabase(
  tables: [DeviceIdentity, OutboxEvents],
  include: {'foundation_triggers.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {required this._ids, required this._clock});

  final UuidV4Generator _ids;
  final DeviceClock _clock;

  /// Bump only with a migration step, a new schema dump and migration tests.
  static const int currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // Schema and the device identity are created in one transaction, so a
      // database never exists without its install ID (P2-D5).
      await transaction(() async {
        await m.createAll();
        await into(deviceIdentity).insert(
          DeviceIdentityCompanion.insert(
            installId: _ids.next(),
            createdAtUtcMicros: _clock.now().utcMicros,
          ),
        );
      });
    },
    onUpgrade: (m, from, to) async {
      // Forward-only, non-destructive steps are added per version together
      // with a schema dump and tests. Unknown transitions fail closed.
      throw UnsupportedError(
        'No migration from schema v$from to v$to is defined',
      );
    },
  );
}
