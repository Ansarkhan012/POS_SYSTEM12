# GOTCHAS.md — Implementation Traps (scan before coding)

Each item: **the trap** → what to do instead. Add new traps as they are
discovered (AGENTS.md §4). Never delete an entry; mark it obsolete with a reason.

## Offline & sync
- **G01 — Waiting for the cloud before committing a local sale.** → Commit locally, update UI, queue outbox. Network is never on the checkout path.
- **G02 — Writing business rows and the outbox entry in separate transactions.** → One local transaction, or a crash creates unsynced sales or phantom events.
- **G03 — Letting a sync retry duplicate a sale, payment, or inventory event.** → Client-generated IDs + server idempotency key + (device_id, device_seq) uniqueness; one server transaction per event. Retries must be safe.
- **G04 — Trusting only the client wall clock.** → Store device occurred time **and** server received time, device_seq, shop timezone, and anomaly flags; order by device_seq/server receipt; use server-assigned cursors; flag skew (ADR-023). Never rewrite the original device time.
- **G05 — Silently dropping a rejected or conflicting sync event.** → Keep it locally (REJECTED/CONFLICT), surface it, alert. Never delete.
- **G06 — Blocking a sale because local stock is zero/negative.** → Offline counters can't see each other; allow and warn. Negative balance is a signal, not an error.
- **G07 — Server rejecting a completed sale for business rules.** → The server records facts from the counter; reject only for auth/tenant/device/schema/integrity failures; flag the rest.
- **G08 — Receipt numbers from a shared counter while offline.** → Per-device prefix + per-device counter.
- **G09 — Assuming both counters see each other's sales instantly.** → No LAN sync in scope; they converge via cloud.
- **G10 — Letting session expiry or subscription status stop checkout.** → They may stop sync/admin features, never a local cash sale. (The only designed checkout lock is a device that has learned it is revoked — ADR-024.)
- **G37 — Using device UUID ordering as transaction chronology.** → IDs are random UUIDv4-style identity only (ADR-013). Order by device_seq, occurred time, server received time.
- **G38 — Marking an event "backed up"/"synced" before server acknowledgement.** → Only ACKED/DUPLICATE_ACCEPTED events count as synced (ADR-025). Show pending count and last successful sync.
- **G39 — Silently dropping pending events from a revoked device.** → Lock checkout once revocation is known; hold its events for security review (Q24); never discard (ADR-024).
- **G40 — Letting the Flutter client insert financial rows directly into cloud tables.** → Financial mutations go through the server-side sync boundary (ADR-014).
- **G41 — Silent last-write-wins on important commercial configuration.** → Price, purchase price settings, thresholds, name overrides, permissions use versioned optimistic concurrency; stale edits return CONFLICT, preserving both values (ADR-022).

## Catalog
- **G11 — Turning global catalog data into shop inventory data** (putting stock, price, cost, SKU, or thresholds on the master product). → These belong to shop_products / inventory. Inventory never belongs to the global product.
- **G12 — Automatically promoting shop-created products to the global catalog.** → Custom products are shop-private; promotion is an admin-reviewed future process.
- **G13 — Downloading the entire image library at every startup (or at install).** → Lazy-load images on demand, cache locally with a cap.
- **G14 — Remote search on every keystroke.** → Search the local DB.
- **G15 — Bundling images inside catalog metadata payloads, or shipping original multi-megabyte images to POS.** → Metadata and images are separate; WebP, ≤ 512 px longest edge, target ≤ 60 KB, ceiling ≈ 100 KB (ADR-017).
- **G16 — Hard-deleting master products or barcodes.** → Deactivate (tombstone via catalog delta); shop products and history may reference them.
- **G17 — Copying master identity fields into every shop product as a second source of truth.** → Reference the master product; local denormalization is cache only.

## Money, quantity & cost
- **G18 — Using binary floating point (`double`/`float`/`real`) for money or authoritative quantities** (DB, Dart, JSON, rounding). → Signed 64-bit integer paisa; quantity in subunits (1 unit = 1000).
- **G19 — Calculating historical profit from the product's current cost or price.** → Use sale_item `cost_price_snapshot` and price snapshot (ADR-019).
- **G20 — Treating cached inventory balance as immutable source of truth.** → The movement ledger is the truth; balances are rebuildable caches.
- **G21 — Updating a `stock` field directly without a movement.** → Every stock change is a movement with type, reason, actor, device.
- **G22 — Rounding inconsistently between device and server.** → One shared money module: line amount = price × qty / 1000, round half away from zero, integer math only; server recomputes and flags mismatches.
- **G42 — Accepting 0.5 of a whole-piece product.** → Whole-piece products require quantities divisible by 1000; only fractional-allowed products accept < 1000.
- **G43 — Computing weighted average cost with floats or lossy integer division.** → Integer-safe fixed-point arithmetic with a defined precision (Q20).
- **G44 — Treating loose goods as a future feature.** → Fractional quantities are required from the start (ADR-018).

## Financial integrity
- **G23 — Hard-deleting completed sales (or payments, ledger entries, movements).** → VOID / REFUND / defined REVERSAL / ADJUSTMENT events.
- **G24 — Editing a completed sale in place.** → Corrections are new records linked to the original.
- **G25 — Treating analytics/read models as financial truth.** → Transactional records are truth; analytics are derived.
- **G26 — Sensitive actions without actor, device, local session, timestamp, and reason.** → Always attribute; write audit log.
- **G45 — Confusing cart cancel with void.** → Cart cancel = no financial record. Void = completed sale, full-sale only, manager/owner, reason, reversing events (ADR-020).
- **G46 — Using REVERSAL as a generic "undo" to rewrite history.** → Only for explicitly defined system/payment corrections (Q23).

## Security
- **G27 — Storing the Supabase service-role key in Flutter code, config, assets, or git.** → Never. Clients use anon key + user session + RLS.
- **G28 — Enforcing permissions only in the Flutter UI.** → Server (RLS/RPC) must enforce; UI only hides.
- **G29 — Tables exposed via the API without RLS, or "temporary" permissive policies.** → RLS on every exposed table from day one, with cross-tenant tests.
- **G30 — Trusting client-supplied shop_id, role, or totals.** → Derive tenant/role from membership; recompute totals server-side.
- **G31 — SECURITY DEFINER / privileged functions that skip membership checks.** → Every privileged function re-checks tenant, device, and role.
- **G47 — Claiming offline cashier identity was independently authenticated by the cloud.** → Offline actor identity is device-asserted by the enrolled device (ADR-021). Say so in docs, UI, and reports.
- **G48 — Storing or logging a plaintext PIN.** → Only a salted PIN verifier in secure storage.

## One app, roles & devices (ADR-026)
- **G49 — Splitting Owner and Cashier into separate applications.** → One Dokan Pro app. A split requires a new approved ADR.
- **G50 — Inferring permissions from device size** (e.g., "tablet = cashier, phone = owner"). → Role controls capability; device characteristics control presentation.
- **G51 — Inferring layout solely from role.** → An owner on a tablet gets an expanded owner layout; a cashier on a phone still gets a usable layout if permitted.
- **G52 — Treating a hidden screen as authorization.** → Hiding UI is not security; RLS, server authorization, and the sync boundary enforce permissions.
- **G53 — Letting Owner features complicate the cashier checkout path.** → Keep checkout fast, minimal, and free of owner analytics.
- **G54 — Letting remote Owner requirements make local checkout cloud-dependent.** → Checkout stays local-first; owner remote data may need connectivity, checkout never does.
- **G55 — Treating Riverpod state as financial storage.** → Riverpod holds UI/app state; the encrypted local DB (then acknowledged cloud data) holds financial truth.
- **G56 — Putting database/network business logic directly in widgets.** → Widgets → controllers → injected repositories.
- **G57 — Giant global state objects or mutable global business singletons.** → Feature-scoped providers; inject dependencies.
- **G58 — Creating `packages/core`, `packages/shared_ui`, or monorepo tooling for artificial separation.** → Shared concepts live in `lib/core`; feature behavior stays in its feature.

## Local database encryption (ADR-027)
- **G59 — Storing an unencrypted production POS database.** → Encrypted SQLite (SQLCipher-compatible or reviewed equivalent) via Drift from the first implementation.
- **G60 — Using the cashier PIN as (or as the sole source of) the database encryption key.** → Strong random key in platform-backed secure storage; PIN and DB key are separate; PIN changes never re-encrypt the database.
- **G61 — Hardcoding, committing, or storing the DB key in plaintext preferences, or adding a universal recovery key.** → Never. Key loss is handled by re-enrollment and cloud re-pull, not a backdoor.
- **G62 — Believing encryption protects an unlocked or compromised device.** → It protects data at rest only.

## Flutter foundation (discovered in Phase 1)
- **G63 — Running `flutter create` directly in the non-empty repository.** → The template includes its own `README.md` and other files; whether it would skip or replace existing files was deliberately not relied upon. Generate into a scratch directory and copy with no-clobber, then verify `AGENTS.md`, `README.md`, `docs/**` hashes are unchanged.
- **G64 — Omitting `--project-name`.** → The repository directory name (`POS_SYSTEM`) is not a valid Dart package name; always pass `--project-name dokan_pro`.
- **G65 — Re-pumping a `ProviderScope` with different `overrideWith` overrides in one widget test.** → The existing container is kept and the new role/locale is silently ignored, so tests can pass for the wrong reason. Give each pumped scope a fresh key (see `test/helpers/pump_app.dart`) and assert the requested state is actually shown.
- **G66 — Comparing `List`s by putting them in a `Set`.** → Dart lists use identity equality; compare with `expect(a, b)` / `equals`.
- **G67 — Running `flutter analyze` on a clean checkout without generating localizations.** → Generated l10n files are not committed (ADR-028); run `flutter gen-l10n` first (CI does).
- **G68 — Using `null` as a `PopupMenuButton` item value.** → A null result is treated as "cancelled" and `onSelected` never fires; use an explicit enum value (e.g., "no session").
- **G69 — Assuming `--no-pub` stops `flutter create` from writing `pubspec.lock`.** → In Flutter 3.44.1 the lock file was still written; regenerate it with `flutter pub get` in the real project.
- **G70 — Trusting a heavily loaded Android emulator for UI verification.** → On this host the tablet AVD repeatedly showed system ANR dialogs (load average > 30) even after a cold boot; treat device checks as unverified rather than claiming them.

## Encrypted local database (discovered in Phase 2, ADR-029)
- **G71 — Trusting SQLite3 Multiple Ciphers to fail on a bad key.** → An omitted/empty key means *no encryption*, and `PRAGMA key` returns `ok` even for a wrong key. Always verify `PRAGMA cipher`, perform a real read, and check the file header (see `configureEncryptedConnection`).
- **G72 — Letting a `SqliteException` escape from key setup.** → Its `toString()` quotes the failing statement, i.e. `PRAGMA key` with the key. Replace such errors with typed failures without a cause.
- **G73 — Enabling Drift `logStatements`.** → It would print the key PRAGMA. Never enable it.
- **G74 — Adding `sqlite3_flutter_libs` / `sqlcipher_flutter_libs` or changing the `sqlite3` hook `source`.** → They are EOL and risk loading plain SQLite; the hook must stay `source: sqlite3mc`.
- **G75 — Using Drift's in-memory `SchemaVerifier` / `validateDatabaseSchema`.** → SQLite3MC cannot key in-memory databases, so they would be unkeyed. Compare schemas of encrypted **file** databases (see `schema_migration_test.dart`).
- **G76 — Upgrading `sqlite3` beyond 3.5.2 or `build_runner` beyond 2.15.1 on Flutter 3.44.1.** → Flutter's `meta` pin makes them unresolvable; they move only with an approved toolchain upgrade.
- **G77 — Passing `--delete-conflicting-outputs` to `build_runner` 2.15.** → The flag was removed; use `dart run build_runner build`.
- **G78 — Running `drift_dev schema generate` into a missing directory.** → Create the output directory first (`mkdir -p test/core/database/generated`).
- **G79 — Expecting data to survive two `flutter test integration_test` runs.** → The app is uninstalled after each run (wiping data and Keystore entries). Use `--no-uninstall` for restart-persistence checks.
- **G80 — Letting Riverpod 3 auto-retry a fail-closed provider.** → Riverpod 3 retries failing providers by default; database providers set `retry: (_, _) => null`.
- **G81 — Deleting a test database directory while the database is still open (Windows).** → Provider `onDispose` cannot await `close()`; close the database explicitly before deleting temp files.
- **G82 — Comparing Drift schema SQL verbatim.** → Generated reference schemas quote primary-key identifiers differently; compare structure plus whitespace/quote-normalized SQL.
- **G83 — Using `contains` with decoded JSON maps.** → Dart maps compare by identity; compare extracted values.
- **G84 — Re-enabling Android Auto Backup.** → A restored database without its Keystore key is unreadable (`InvalidKeyException`) and data would leave the device; keep P2-D4.
- **G85 — Casually upgrading `flutter_secure_storage`.** → The 11.x line had breaking and frequent releases; it is pinned exactly and every upgrade needs review.
- **G86 — Building offline.** → The `sqlite3` hook downloads prebuilt native binaries from GitHub releases at build time (sha256-verified); builds and CI need network access (or a reviewed `url_pattern` mirror).

## Scope & architecture
- **G32 — Putting every future feature into the first schema.** → Model only what the active phase needs; extend later with migrations.
- **G33 — Prematurely introducing microservices, Kafka, Kubernetes, Redis clusters.** → Modular monolith on Supabase until a measured need exists.
- **G34 — Implementing work from a LOCKED phase "while you're there".** → Only the active phase. Report ideas instead.
- **G35 — Hard-coding UI strings or LTR-only layouts.** → Externalize strings and support RTL from Phase 1, even though Urdu content lands in Phase 14.
- **G36 — Adding a package without justification.** → Justify per AGENTS.md; record significant ones in DECISIONS.md.
