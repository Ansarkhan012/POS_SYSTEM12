import 'package:drift/drift.dart';

import '../app_database.dart';

/// Reads the local outbox. The only ordering is `device_seq` — never IDs or
/// timestamps (GOTCHAS G04, G37).
class OutboxReader {
  const OutboxReader(this._database);

  final AppDatabase _database;

  Future<List<OutboxEventRow>> eventsInDeviceSeqOrder({int? limit}) {
    final query = _database.select(_database.outboxEvents)
      ..orderBy([(t) => OrderingTerm.asc(t.deviceSeq)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }
}
