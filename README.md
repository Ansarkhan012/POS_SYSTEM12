# Dokan Pro

> ⚠️ **Foundation only — no business features.** Phase 1 added a single
> Flutter app (Android) with a role-aware, adaptive, localized (English / Urdu
> placeholder) empty navigation shell. Phase 2 added the encrypted local data
> foundation (encrypted SQLite via Drift, Keystore-protected key, outbox,
> money/quantity primitives); the app does **not** open the database at startup
> yet. There is no authentication, Supabase, checkout, catalog, inventory, sync,
> or any real business data.

**Dokan Pro** is an offline-first point-of-sale product for small grocery /
kiryana / general stores, starting in Karachi, Pakistan. It consists of:

1. **One Dokan Pro Flutter application** (one Play Store listing) with
   role-based experiences and adaptive phone/tablet layouts:
   - **Cashier experience** — tablet-optimized, fast offline-first checkout.
   - **Owner experience** — phone-optimized remote sales, profit, inventory,
     udhaar, cashier monitoring, alerts, and management.
   - **Manager experience** — operational management within permissions.
2. **Cloud backend** — Supabase (PostgreSQL, Auth, Storage, Row Level Security).
3. **Admin platform** — future phase (catalog, shops, subscriptions, support).

## Current status

| Item          | Value                                   |
|---------------|-----------------------------------------|
| Active phase  | **Phase 2 — Local Data Foundation**     |
| Status        | **APPROVED**                            |
| Phases 0–1    | APPROVED                                |
| Phases 3–19   | LOCKED                                  |

See [`docs/PHASE_STATUS.md`](docs/PHASE_STATUS.md).

## Run and test

Requires Flutter **3.44.1** (stable). The app lives at the repository root
(ADR-028); Android is the only platform.

```bash
flutter pub get
```

```bash
flutter gen-l10n
```

Generate Drift code (not committed, ADR-029):

```bash
dart run build_runner build
```

Generate the Drift schema test helpers from the committed dumps:

```bash
mkdir -p test/core/database/generated && dart run drift_dev schema generate drift_schemas/ test/core/database/generated/
```

```bash
flutter analyze
```

```bash
flutter test
```

On-device encryption test (real Android device or emulator; uses its own
isolated database file and secure-storage namespace):

```bash
flutter test integration_test/local_database_encryption_test.dart -d <device-id>
```

```bash
flutter run --dart-define-from-file=config/dart_defines.example.json
```

The build hook of `package:sqlite3` downloads the SQLite3 Multiple Ciphers
native binaries from GitHub releases at build time, so builds need network
access. After changing the Drift schema, bump `schemaVersion`, add a migration
step and refresh the dump with
`dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/`.

`APP_ENV` must be `dev` or `prod` (defaults to `dev`; anything else fails at
startup). Copy the example to a git-ignored `config/<name>.json` for local use.
Never put keys, URLs or tokens in define files. Debug builds show a clearly
labeled developer role preview (not sign-in) to view the owner, manager and
cashier shells.

## Architecture principles (summary)

- **Offline-first:** a normal cash sale never requires internet (the only designed checkout lock is a device that has learned it is revoked).
- **Local-first writes:** action → local DB transaction → immediate UI → outbox → cloud sync later.
- **Durable cloud copy:** operational data syncs to the cloud when connectivity returns.
- **No financial hard deletes:** corrections via VOID / REFUND / REVERSAL / ADJUSTMENT.
- **Encrypted local database:** SQLite3 Multiple Ciphers (SQLCipher-4-compatible) via Drift, raw 256-bit key in Android Keystore-backed storage; fail closed, no recovery key (ADR-027, ADR-029).
- **Integer money:** signed 64-bit integer paisa; round half away from zero; never floating point.
- **Fixed-point quantity:** 1 unit = 1000 subunits; loose goods by weight supported from the start.
- **Movement-based inventory:** stock is derived from an inventory movement ledger; profit uses moving weighted average cost captured per sale item.
- **Global master catalog ≠ shop products:** prices, costs, and stock are shop-specific.
- **Multi-tenant isolation:** shop-scoped data protected by RLS; financial sync only through a validated server-side boundary; no service-role key in apps.
- **Honest offline limits:** offline cashier identity is device-asserted; unsynced data on a destroyed device is lost; a fully offline device cannot learn of revocation.
- **One app, many roles:** role controls capability; device size controls layout; UI visibility is never authorization.
- **Encrypted local DB:** SQLite/Drift encrypted from day one; key in platform secure storage, never the cashier PIN.
- **Simple first:** one Flutter app (Riverpod, feature-first) + Supabase/PostgreSQL modular monolith; no premature microservices.

## Documentation map

| Document | Purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Controlling rules for coding agents — **read first** |
| [`docs/PRODUCT.md`](docs/PRODUCT.md) | Purpose, customer, MVP boundaries, non-goals |
| [`docs/DESIGN.md`](docs/DESIGN.md) | Interaction and usability principles |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | High-level system architecture |
| [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) | Conceptual entity model |
| [`docs/PRODUCT_CATALOG.md`](docs/PRODUCT_CATALOG.md) | Authoritative catalog behavior |
| [`docs/OFFLINE_SYNC.md`](docs/OFFLINE_SYNC.md) | Local-first writes, outbox, sync, conflicts |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Tenant isolation, RLS, roles, threats |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Architecture decision records |
| [`docs/GOTCHAS.md`](docs/GOTCHAS.md) | Implementation traps — scan before coding |
| [`docs/PHASE_PLAN.md`](docs/PHASE_PLAN.md) | Phase 0–19 implementation sequence |
| [`docs/PHASE_STATUS.md`](docs/PHASE_STATUS.md) | Current phase and status |
