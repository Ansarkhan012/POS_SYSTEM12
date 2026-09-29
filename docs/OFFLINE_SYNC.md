# OFFLINE_SYNC.md — Local-First Writes & Synchronization

Status: **Conceptual (Phase 0).** No sync engine exists. The exact event schema
is designed in Phase 2 (local outbox) and Phase 8 (sync engine and server boundary).

## 1. Principles

1. A normal local cash sale **never** waits for the network.
2. Every important cashier action is a **local DB transaction first**.
3. Every local change that must reach the cloud is recorded in the **outbox in
   the same local transaction** — so it cannot be lost or duplicated by a crash.
4. Financial mutations reach the cloud **only through the server-side financial
   sync boundary** (ADR-014), never by direct client inserts. This validation
   happens **after** the local sale has completed — checkout never waits for it.
5. The server **applies events idempotently**; sending the same event twice has
   the same effect as sending it once.
6. **Nothing is silently dropped.** Every event ends in an explicit terminal
   state: acknowledged, or rejected-and-surfaced.
7. The server **records facts that already happened at the counter.** It does not
   reject a completed sale for business reasons like negative stock; it flags
   anomalies instead. Rejection is reserved for auth, tenant, device, schema,
   and integrity failures.
8. **Financial events** are immutable, idempotent events. **Editable
   configuration** uses versioning / optimistic concurrency (§8, ADR-022).
9. **IDs are identity, not chronology** (ADR-013). Ordering never depends solely
   on the device wall clock (ADR-023).
10. Nothing is shown as "synced"/"backed up" before **server acknowledgement** (ADR-025).

## 2. Local-first write flow

```
User action
  → Local DB transaction (business rows + outbox event, atomic)
  → Immediate UI result
  → Outbox / sync queue
  → Later: server-side validation & sync, acknowledgement recorded locally
```

Example — completing a sale, **in one local transaction**:
sale header, sale items (name/price/`cost_price_snapshot`, quantity in subunits),
payments and/or udhaar ledger entry, SALE inventory movements, cached
balance updates, audit entry if sensitive, and outbox event(s). Either all
commit or none.

## 3. Outbox pattern

Each outbox entry (local-only) conceptually holds:

| Field | Meaning |
|---|---|
| `event_id` | Random UUID generated on the device (ADR-013). Identity only — never used for ordering. |
| `idempotency_key` | Key the server uses to deduplicate; defaults to `event_id` (kept distinct in concept so a logical operation retried as a new event can still dedupe if needed). |
| `shop_id` | Tenant. |
| `device_id` | Enrolled device that created the event. |
| `local_session_id` | Local session (online login or offline PIN) in which the action occurred (ADR-021). |
| `actor_user_id` | User who performed the action — **device-asserted** for offline sessions. |
| `device_seq` | Monotonic per-device sequence number (no gaps, assigned in the local transaction). |
| `event_type` | e.g., `sale.completed`, `sale.voided`, `payment.recorded`, `inventory.adjusted`, `shop_product.updated`. |
| `schema_version` | Payload schema version. |
| `payload` | Full data needed to apply the event (not a diff that depends on server state). Config edits include the **base version** they were made against. |
| `occurred_at_device` | Device wall-clock time of the action, plus shop timezone. |
| `clock_info` | Last known server-time offset and its age; time-confidence/anomaly flags (ADR-023). |
| `sync_status` | `PENDING` → `IN_FLIGHT` → `ACKED` / `REJECTED` / `CONFLICT` (see §8–9). |
| `attempts`, `last_error`, `next_attempt_at` | Retry bookkeeping. |

The server stores its view of each received event in `sync_events` (DATA_MODEL.md)
with `server_received_at` and the processing result. The server **never
overwrites or discards** `occurred_at_device`.

## 4. Idempotency

- The server enforces uniqueness on the idempotency key per shop and on
  (`device_id`, `device_seq`).
- If an already-applied event arrives again, the server returns the **original
  result** (`DUPLICATE_ACCEPTED`) and applies nothing.
- Business rows created by events use the **client-generated IDs** from the
  payload, so even a partial retry cannot create a second sale, payment, or
  inventory movement.
- Applying one event (e.g., a sale with items, payments, movements, ledger
  entries) is **one server DB transaction**.

This prevents: **duplicate sales, duplicate payments, duplicate/missing
inventory movements, replayed mutations**.

## 5. Server-side financial sync boundary (ADR-014)

Before applying a financial event, the boundary validates at minimum:
authenticated user · registered, non-revoked device (revoked → §6.1) · shop
membership · tenant ownership of every referenced record · mutation type ·
payload/schema version · idempotency key · duplicate detection · permissions of
the asserted actor · relevant business invariants (e.g., totals recomputed from
lines with ADR-008 rounding, whole-piece quantities divisible by 1000).

Permission violations and invariant mismatches on facts that already happened at
the counter are **flagged and surfaced** (alert + audit) rather than silently
applied or silently dropped; exact per-invariant handling is finalized in Phase 8.

## 6. Device identity

- Each POS install is **enrolled** to exactly one shop while online, by an authorized user.
- `device_id` is stable for the install; reinstall = new device (old one can be revoked).
- Receipt/invoice numbers are generated offline with a **per-device prefix +
  per-device counter**, so two offline counters never collide.

### 6.1 Revoked devices (ADR-024)
- When a device **learns** it is revoked (on its next contact), **checkout is locked**.
- Sync from a revoked device is a **security-sensitive case**: events are not
  applied as normal, and are **never silently discarded** — they are held for a
  review/recovery workflow (Q24, decided before Phase 8).
- Limitation: a fully offline (e.g., stolen) device cannot learn of revocation and
  may keep operating until it next connects. No lease/token-expiry mechanism is
  introduced now (may be evaluated in Phase 17).

## 7. Retry, sequence & version concepts

- Push when connectivity is detected, on a periodic timer, and after local writes (debounced).
- Batches in `device_seq` order; a batch is size-limited.
- Transient failures (network, timeout, 5xx, rate limit): exponential backoff
  with jitter and a cap; retry indefinitely — financial events never expire locally.
- Auth failures: refresh session; if still failing, stop pushing and surface
  to owner/manager (never discard events). Checkout continues (except §6.1).
- **`device_seq`** — ordering and completeness per device. The server tracks the
  highest contiguous sequence per device; a **gap** means an event is missing and
  is reported (prevents **silent sync loss**).
- **`schema_version`** — the server accepts all supported versions; unsupported
  versions are handled by an explicit upgrade policy (never silent drop).
- **Catalog version** — monotonic server version for master catalog deltas (PRODUCT_CATALOG.md §5).
- **Row version** — editable configuration rows carry a version for optimistic concurrency (§8).
- **Pull cursors** — per data stream, a server-assigned cursor (never a device timestamp, never a UUID).

## 8. Conflict categories

| Category | Examples | Strategy |
|---|---|---|
| **A. Append-only financial events** | sales, sale items, payments, ledger entries, inventory movements, cash drawer events, expenses | **No conflicts by design.** Each event is a new immutable fact with its own ID. Two counters selling the same item both apply; stock is the sum of movements. |
| **B. Corrections / state transitions** | VOID of a sale, REFUND, shift close | Modeled as **new linked events** (ADR-020); the original is never rewritten. Server validates the transition (e.g., a second void of the same sale is a duplicate/no-op reported back; a void of an already-refunded sale is rejected-and-surfaced). Cart cancel creates no event. |
| **C. Editable configuration** | shop product sale price, purchase price settings, low-stock threshold, name override, configuration settings, permissions | **Optimistic concurrency (ADR-022).** Each edit carries its base version. If the base is stale for an important commercial field, the server **does not apply it silently**: it returns `CONFLICT`, preserves both values with context (who, device, when, base/current versions), and the conflict requires deterministic resolution (workflow: Q5). **Unconditional last-write-wins is forbidden** for price, permissions, and sensitive commercial configuration. Sales already completed at an older price stay valid via their price snapshot. |
| **D. Uniqueness conflicts** | same barcode assigned offline to two products; same customer created on two devices | Flagged for resolution by manager/owner (or the config event returns `CONFLICT`) — never corrupts financial history. |
| **E. Global catalog** | master product changed while device offline | Server-authoritative, read-only for shops; device applies deltas. No shop-side conflict possible. |

## 9. Server acknowledgement & failed events

Per-event results:
- `ACCEPTED` — applied; device marks `ACKED`.
- `DUPLICATE_ACCEPTED` — already applied earlier; device marks `ACKED`.
- `CONFLICT` — configuration version conflict (§8 C); kept locally until resolved.
- `REJECTED_RETRYABLE` — e.g., depends on an event not yet received; retry later.
- `REJECTED_PERMANENT` — auth/tenant/schema/integrity failure.

Permanently rejected or conflicting events:
- are **kept locally** (dead-letter / conflict state), **never deleted**;
- remain visible in a sync-problems view for owner/manager (and support later);
- raise an alert;
- do not block unrelated later events, but dependent events (e.g., a void of a
  rejected sale) are held and surfaced too;
- are resolved by explicit action — a local financial record is never silently lost.

Only `ACKED` events may be presented as synced/backed up.

## 10. Offline recovery & unsynced data risk (ADR-025)

- The device can operate offline for checkout indefinitely (bounded by storage).
- On reconnect: push outbox first (oldest `device_seq` first), then pull deltas.
- **Accepted physical limitation:** if a device creates transactions fully offline
  and the device or its storage is destroyed or irrecoverably lost before sync,
  those transactions **cannot exist in the cloud**. This cannot be eliminated
  while operating fully offline.
- Mitigations: sync automatically whenever connectivity exists; retry aggressively
  but safely; show **pending sync count** and **last successful sync** on the POS;
  warn when unsynced data remains unusually long (threshold decided in Phase 8);
  alert the owner when a device has not synced; **never show "backed up" before
  server acknowledgement**.
- A replacement device pulls shop configuration and required history from the
  cloud and enrolls as a new device.

## 11. App crash during mutation

- Business rows and the outbox entry are written in **one local transaction**; a
  crash results in either the full sale + outbox entry, or nothing.
- Crash between local commit and UI update: on restart, the sale exists; the UI
  shows the last completed sale so the cashier does not re-ring it.
- Crash during push: `IN_FLIGHT` events revert to `PENDING` on restart and are
  resent — idempotency makes this safe.

## 12. Duplicated network request

- A request may succeed on the server while the response is lost. The device
  resends; the server recognizes the idempotency key / (`device_id`, `device_seq`)
  and returns the original result. No duplicate rows.

## 13. Clock differences (ADR-023)

- Device clocks may be wrong (manual setting, dead RTC battery, timezone mistakes).
- Each event can store distinct concepts: **device occurred time, server
  received time, device sequence, shop timezone, and time-confidence/anomaly
  information**. The server never rewrites the original device timestamp.
- When online, the client maintains its known **server-time offset**.
- Obvious clock skew causes events to be **flagged** (and alerted), not silently
  given false precision.
- **Ordering:** within a device by `device_seq`; cross-device ingestion by server
  receipt; never by UUID; never solely by device wall clock.
- **Reports** use an explicitly defined **effective business timestamp/date**
  (rule and skew thresholds: Q6, decided before Phase 8).

## 14. Eventual synchronization

- All devices of a shop and owner-experience sessions converge to the cloud state once all
  outboxes are drained, conflicts resolved, and deltas pulled.
- The owner experience shows per-device last-sync time so "eventual" is visible.
- Two counters **do not see each other's sales in real time** without cloud sync
  (no LAN sync in scope). Local stock on each counter is approximate until sync;
  this must not block sales.

## 15. Pull (cloud → device) streams

Conceptual streams, each with its own server-assigned cursor:
- master catalog deltas (global)
- shop configuration with row versions (shop products, barcodes, prices, users/permissions, data needed for offline PIN login — mechanism defined in Phase 3, customers, suppliers)
- other devices' movements/balances (to refresh local stock and average cost)
- device/shop status (revocation → checkout lock; subscription state — never blocks a local cash sale)
