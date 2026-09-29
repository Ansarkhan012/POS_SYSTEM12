# DECISIONS.md — Architecture Decision Log

ADR-style log. Statuses: **ACCEPTED** (decided), **PROPOSED** (recommended
direction, not yet approved — must be confirmed before the phase that needs it),
**SUPERSEDED**, **REJECTED**. Accepted decisions are never edited silently;
changes are made by adding a superseding entry. PROPOSED entries may be
finalized in place, with a revision note.

Phase 0 decisions derive from the Phase 0 product brief and the Phase 0 final
review binding decisions (2026-09-29).

---

### ADR-001 — Phase-gated development with documentation constitution
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** Work proceeds in strict phases (PHASE_PLAN.md). Only the active phase may be modified; no phase starts until the previous is APPROVED by the user. AGENTS.md controls agent behavior.
- **Context:** Multiple agents/contributors over a long build; high risk of scope creep and silent architectural drift.
- **Alternatives:** Ad-hoc feature development; loose milestone list.
- **Rationale:** Predictability, reviewability, consistent architecture.
- **Consequences:** Slower start; every phase needs review. Documentation must be kept current.

### ADR-002 — Flutter for the client application
- **Date:** 2026-09-29 · **Status:** ACCEPTED (Flutter as client technology) / **PARTIALLY SUPERSEDED by ADR-026** (the original "separate Cashier POS app and Owner app" structure)
- **Decision (original):** Cashier POS (Android tablet) and Owner app (mobile) are built with Flutter.
- **Decision (still in force):** The Dokan Pro client is built with Flutter. The two-application structure is superseded: there is **one** Flutter application (ADR-026).
- **Context:** Android-first; tablet POS and phone owner usage; need shared domain code.
- **Alternatives:** Native Android (Kotlin); React Native; Kotlin Multiplatform.
- **Rationale:** One language/toolkit, strong Android tablet and phone support, good offline/SQLite ecosystem, RTL support for Urdu.
- **Consequences:** Hardware integrations (thermal printer, scanner) need Flutter plugins or platform channels (Phase 15). Structure and state management: ADR-026.

### ADR-003 — Supabase / PostgreSQL cloud backend
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** Cloud backend is Supabase: PostgreSQL, Auth, Storage, Row Level Security, RPC/functions.
- **Context:** Small team; need relational integrity for financial data, auth, storage, and tenant isolation without running custom infrastructure.
- **Alternatives:** Firebase/Firestore; custom Node/Go API + managed Postgres.
- **Rationale:** Relational model with transactions and constraints suits financial/ledger data; RLS gives database-enforced tenancy; managed services reduce ops burden.
- **Consequences:** Security depends on correct RLS; business-critical validation moves into SQL/RPC; vendor coupling accepted, mitigated by standard PostgreSQL.

### ADR-004 — Offline-first POS
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** The cashier experience must search, sell, update local inventory, (later) print, and continue working with no internet. Cloud connectivity is never required for a normal local cash sale.
- **Context:** Karachi internet and power are unreliable; a POS that stops selling is unacceptable.
- **Alternatives:** Online-only; online with offline fallback mode.
- **Rationale:** Checkout availability is the core value.
- **Consequences:** Requires local DB, outbox sync, idempotent server, conflict strategy; owner data is eventually consistent. Known exceptions/limitations: ADR-024 (revoked device locks checkout once it learns of revocation), ADR-025 (unsynced data loss risk).

### ADR-005 — Local-first transaction writes with outbox
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** Action → local DB transaction (including outbox event) → immediate UI → background sync. The user never waits for Supabase for a local sale.
- **Context:** Follows from ADR-004; must avoid lost or duplicated events.
- **Alternatives:** Write-through to cloud with local cache; CRDT-based replication.
- **Rationale:** Transactional outbox guarantees atomicity of local change + sync intent; simple to reason about; event-based fits financial data.
- **Consequences:** Server must be idempotent (ADR-014); sync engine in Phase 8; outbox structure in Phase 2, written by local mutation phases from Phase 5 onward.

### ADR-006 — Global master catalog separated from shop products
- **Date:** 2026-09-29 · **Status:** ACCEPTED (reconfirmed as binding in Phase 0 final review)
- **Decision:** A global, admin-managed master catalog holds product **identity only**: standardized name, brand, category, size/variant, unit type, known manufacturer barcode(s), image, aliases, active status, version metadata. Each shop has **shop products** holding shop-specific prices, enabled/disabled status, shop barcode overrides, low-stock threshold, and other shop-specific configuration, optionally referencing a master product. **Inventory never belongs to the global product.** Custom products are allowed (ADR-012).
- **Context:** ~1,000 common FMCG products are shared across shops; commercial data differs per shop.
- **Alternatives:** Per-shop catalog only; single shared catalog with per-shop price columns.
- **Rationale:** Fast onboarding, consistent identity/barcodes, clean tenancy.
- **Consequences:** Catalog versioning/delta sync; duplicate prevention; admin curation. See PRODUCT_CATALOG.md (authoritative).

### ADR-007 — Inventory movement ledger
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** Authoritative stock history is an append-only `inventory_movements` ledger (OPENING, PURCHASE, SALE, RETURN, REFUND, DAMAGE, ADJUSTMENT, plus VOID reversal movements). Cached balances may exist but are derived and rebuildable.
- **Context:** Mutable stock fields lose history, can't merge offline multi-device changes, and hide theft.
- **Alternatives:** Mutable `stock` column; periodic snapshots only.
- **Rationale:** Auditability; conflict-free merging (sum of movements); accurate COGS.
- **Consequences:** Balance caching and rebuild logic; negative balances possible and allowed as warnings.

### ADR-008 — Integer money representation and rounding
- **Date:** 2026-09-29 · **Status:** ACCEPTED (finalized in Phase 0 final review)
- **Decision:**
  - All authoritative monetary values are **signed 64-bit integer paisa** (1 PKR = 100 paisa). Examples: Rs 1.00 = 100; Rs 125.50 = 12,550. PostgreSQL `bigint`; Dart 64-bit `int`; JSON integers.
  - Floating-point values are **never** authoritative financial values (DB, Dart, JSON, reports).
  - **Line amount** = unit price (paisa) × quantity (subunits, ADR-015) / 1000, computed with **integer arithmetic**, rounded to the nearest paisa using **round half away from zero** (a remainder of 0.5 paisa or more rounds outward to the next paisa; negative amounts round symmetrically). Binary floating point must not be used for this calculation.
  - Future percentage discounts/taxes use integer/fixed-point representations such as **basis points** (1% = 100 bp) or another explicitly documented integer scale (exact scale: Q22).
  - **No cash-to-nearest-rupee rounding** is required initially.
  - Currency is PKR per shop. Formatting converts to display text at the UI edge only.
- **Context:** Floating-point errors corrupt totals and ledgers; weighed goods and averaged costs produce sub-rupee values.
- **Alternatives:** Whole rupees (loses precision); decimal/`numeric` types (inconsistent across Dart/JSON); floating point (rejected).
- **Rationale:** Exact, identical arithmetic on device, wire, and server.
- **Consequences:** One shared, exhaustively tested money module; the server recomputes line amounts with the same rule and flags mismatches.

### ADR-009 — No financial hard deletes
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** Sales, sale items, payments, ledger entries, inventory movements, cash drawer events, expenses, purchases, and audit logs are never hard-deleted (nor silently edited). Corrections use the explicitly defined events of ADR-020. Every sensitive action is attributable to user, shop, device, local session, timestamp, and reason where appropriate.
- **Context:** Trust, owner oversight of absent-owner shops, fraud prevention, sync correctness.
- **Alternatives:** Soft delete flags on financial rows; editable sales.
- **Rationale:** Immutable events are auditable and merge safely across devices.
- **Consequences:** Correction flows need UI and permissions; storage grows (acceptable at target scale). Configuration data uses deactivation, not deletion, when referenced.

### ADR-010 — Modular monolith first; no premature microservices
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** Start with one Flutter application (ADR-026) + a single Supabase project/PostgreSQL database organized into clear modules. No Kafka, Kubernetes, Redis clusters, or microservices without a demonstrated, measured need.
- **Context:** Target is correctness and reliability first; ~5,000 small shops is modest for PostgreSQL with good tenant indexing.
- **Alternatives:** Microservices; event-streaming backbone.
- **Rationale:** Lower complexity and cost; faster, safer iteration.
- **Consequences:** Keep module boundaries, tenant indexing, and sync batching clean.

### ADR-011 — `shop_id` as the tenant boundary
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** All shop-owned cloud business data is scoped by `shop_id`, under an organization. RLS is mandatory for exposed shop data; service-role credentials never in the Flutter app; security never relies only on UI.
- **Context:** Multi-tenant SaaS; owners may have multiple shops.
- **Alternatives:** Organization-level scoping only; separate schemas/databases per tenant.
- **Rationale:** Shop is the operational unit (devices, stock, cash); simple, indexable policies.
- **Consequences:** Cross-shop features (org-wide reports, shared customers) need explicit, reviewed designs.

### ADR-012 — Custom products are shop-private; never auto-promoted
- **Date:** 2026-09-29 · **Status:** ACCEPTED (reconfirmed)
- **Decision:** Shop-created custom products work locally immediately, sync to the shop's cloud data, stay private by default, and never automatically become master products. Promotion is a future admin-reviewed process that creates a new master product.
- **Context:** Data quality and tenant privacy of the global catalog.
- **Alternatives:** Crowd-sourced auto-merge.
- **Rationale:** Prevents catalog pollution and privacy leaks.
- **Consequences:** Admin tooling needed later; duplicates across shops are expected until curated.

### ADR-013 — Client-generated random UUIDs (identity, not chronology)
- **Date:** 2026-09-29 · **Status:** ACCEPTED (finalized in Phase 0 final review)
- **Revision note:** The earlier PROPOSED preference for time-ordered UUIDv7 is replaced by random UUIDv4-style IDs.
- **Decision:** Records that must be created while offline use **client-generated random UUIDs (UUIDv4-style)** unless a later implementation review documents a stronger reason to change. The server never reassigns these IDs. **IDs are identity, not chronology:** no logic may depend on ID ordering. Business ordering uses explicit fields: device sequence, device occurred time, server received time (ADR-023).
- **Context:** Offline creation of sales/items/movements must not collide and must be idempotent.
- **Alternatives:** Server-assigned sequences with temp-ID remapping; time-ordered UUIDv7.
- **Rationale:** No ID remapping; natural idempotency; avoids coupling identity to (untrusted) device clocks.
- **Consequences:** Human-facing receipt numbers are separate (device prefix + per-device counter). Index locality of random UUIDs is acceptable at target scale.

### ADR-014 — Server-side financial sync boundary
- **Date:** 2026-09-29 · **Status:** ACCEPTED (finalized in Phase 0 final review)
- **Decision:** Financial mutations synchronized to the cloud are **never blindly inserted directly by the Flutter client**. They pass through a controlled server-side synchronization boundary — a Supabase PostgreSQL RPC/function or an equivalent explicitly reviewed backend boundary — that eventually validates at minimum: authenticated user, registered (non-revoked) device, shop membership, tenant ownership, mutation type, payload/schema version, idempotency key, duplicate event detection, permissions, and relevant business invariants. Direct client INSERT/UPDATE/DELETE on financial tables is denied by RLS. **This does not make checkout wait for the server:** local checkout completes locally → outbox → later server-side validation/sync.
- **Alternatives:** Direct table writes protected only by RLS.
- **Rationale:** Multi-row atomicity, idempotency, and server-side recomputation cannot be guaranteed by direct table writes.
- **Consequences:** The boundary is security-critical, must never become an RLS bypass, and requires cross-tenant tests. Exact RPC/function design is Phase 8 (with tenancy foundations in Phase 3).

### ADR-015 — Fixed-point integer quantity representation
- **Date:** 2026-09-29 · **Status:** ACCEPTED (finalized in Phase 0 final review)
- **Decision:** Quantities are integers with **1 unit = 1000 quantity subunits**. Examples: 1 piece = 1000; 2 pieces = 2000; 1 kg = 1000; 0.750 kg = 750; 0.250 kg = 250. The product/unit model distinguishes the **selling unit** and whether **fractional quantity is permitted**. For whole-piece products, validation requires quantities divisible by 1000; for fractional products, values below 1000 are allowed. Floating point is never used for authoritative quantity calculations.
- **Context:** Kiryana stores sell loose goods by weight (ADR-018); money × quantity must stay exact.
- **Alternatives:** Integer pieces only; per-unit-type scales; decimal types.
- **Rationale:** One exact representation for pieces and weights.
- **Consequences:** Line amounts use ADR-008 rounding. Precision finer than 1/1000 of a unit is not supported.

### ADR-016 — Local database: SQLite via Drift
- **Date:** 2026-09-29 · **Status:** ACCEPTED (finalized in Phase 0 final review)
- **Decision:** Flutter local persistence uses **SQLite through Drift** for: offline-first transaction storage, shop product cache, master catalog cache, inventory ledger, sales, payments, local sessions, outbox/sync queue, and sync metadata. Drift is **not installed in Phase 0**; installation and setup belong to Phase 2.
- **Alternatives:** Isar, Hive/ObjectBox (non-relational), raw sqflite.
- **Rationale:** Relational + transactional needs mirror PostgreSQL; typed queries, migrations, reactive streams; full-text search available.
- **Consequences:** Dependency justification per AGENTS.md at install time. The database is encrypted from the first implementation (ADR-027).

### ADR-017 — Master catalog image standard
- **Date:** 2026-09-29 · **Status:** ACCEPTED (finalized in Phase 0 final review)
- **Decision:** Master product images are **WebP**, thumbnail-oriented assets: **maximum longest edge 512 px** initially; **target ≤ 60 KB** where practical; **hard ceiling ≈ 100 KB** except explicitly reviewed exceptions; preserve usable visual clarity; no multi-megabyte originals are ever delivered to POS clients. Images remain separate from metadata, load lazily, and cache locally; the app never downloads all catalog images at startup. The exact encoder/package is not a Phase 0 decision.
- **Alternatives:** JPEG/PNG; embedding images in catalog payloads.
- **Rationale:** Small size, good quality, broad Android support.
- **Consequences:** Admin image pipeline must resize/convert and enforce limits (Phase 4).

### ADR-018 — Loose / fractional grocery goods are required
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** Selling loose goods by weight/fraction (rice, sugar, flour, pulses, spices, etc.) is a **required initial capability**, supported from the beginning via ADR-015. Weighing-scale hardware integration is **not** required initially; the cashier enters the quantity/weight manually.
- **Context:** Loose goods are a core part of kiryana sales in Karachi.
- **Alternatives:** Whole-piece only MVP (rejected).
- **Consequences:** Checkout (Phase 7) includes fractional quantity entry; unit model in Phases 4–5 carries selling unit + fractional flag.

### ADR-019 — Moving weighted average cost; cost snapshots on sale items
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** Initial inventory costing uses **moving weighted average cost per shop product**. On receiving purchase stock: new average cost = (existing quantity × existing average cost + incoming quantity × incoming cost) / new total quantity, computed with integer-safe/fixed-point arithmetic. Every completed sale item stores its own **`cost_price_snapshot`**; historical COGS/profit never changes after sale completion and is never recalculated from current cost. FIFO is not part of the initial system; last-purchase-cost is not the authoritative profit method.
- **Alternatives:** FIFO; last purchase cost; standard cost.
- **Rationale:** Simple, stable, suitable for fungible grocery stock.
- **Consequences:** Difficult cases — negative stock, returns, opening stock without cost, average-cost precision, cross-device ordering of cost-affecting events — are implementation concerns resolved in the inventory phases (Q20, Q21).

### ADR-020 — Cart cancel, void, refund, reversal definitions
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:**
  - **CART CANCEL** — an uncompleted cart may be cancelled. It is not a financial transaction; no reversal is needed because no completed sale exists.
  - **VOID** — a completed sale may be **fully** voided (full-sale only) with **manager/owner permission** and a **required reason**. The original sale remains permanently stored; reversing financial and inventory events are created; attribution includes user, device, and time. A void never deletes the original sale.
  - **REFUND** — used after a completed sale when money/items are returned. May eventually support full and partial refund. Creates a **new linked financial record**; the original sale stays immutable.
  - **REVERSAL** — reserved for explicitly defined system/payment correction scenarios. **Never** a generic way to rewrite history.
- **Consequences:** Void time-window rules (Q4a), refund record structure (Q4b), and permitted reversal scenarios (Q23) are finalized before the phases that implement them.

### ADR-021 — Offline cashier login on a shared tablet
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** A tablet is first **securely enrolled to a shop while online**. Authorized cashier accounts may then use a **local PIN** for offline shift/session authentication. The device stores **only a salted PIN verifier** produced by an appropriate password/PIN hashing mechanism, using secure device storage where appropriate — **never the plaintext PIN**. Each locally generated financial event includes actor/user ID, device ID, **local session ID**, and shop ID.
- **Limitation (explicit):** For offline events, the server knows that the **actor identity was asserted by the enrolled device**; it did **not** independently authenticate each cashier action. Documents must never claim otherwise.
- **Consequences:** Exact hashing package chosen in Phase 3. Sensitive owner/manager actions may get stricter requirements later.

### ADR-022 — Optimistic concurrency for editable configuration
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** Financial events sync as immutable, idempotent events. **Editable configuration** (product sale price, purchase price settings, low-stock threshold, product name override, configuration settings, permissions) uses **explicit versioning / optimistic concurrency**. A stale offline edit must not silently overwrite a newer important cloud value: for important commercial fields the server **detects the version conflict, returns a conflict state, preserves both values and their context, and requires deterministic resolution**. **Unconditional last-write-wins is forbidden** for price, permissions, and other sensitive commercial configuration. A sale completed offline at an older price remains valid via its captured price snapshot.
- **Consequences:** Config rows carry versions from Phase 5; the resolution workflow is Q5.

### ADR-023 — Device time and business time
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** Never trust only the device wall clock. Events can store distinct concepts: **device occurred time, server received time, device sequence, shop timezone, and time-confidence/anomaly information**. The server never rewrites or discards the original device timestamp. When online, the client maintains knowledge of server time / clock offset. Obvious clock skew causes events to be **flagged**, not silently given false precision. Reports use an **explicitly defined effective business timestamp/date** (rule: Q6). Identity and ordering never depend solely on device time.
- **Consequences:** Exact skew thresholds and recovery are finalized in Phase 8.

### ADR-024 — Device revocation
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** A known-revoked device must not continue normal POS operation indefinitely: **when the device learns it has been revoked, checkout is locked**. Sync from a revoked device is treated as a **security-sensitive case**. Pending data from a revoked device is **never silently discarded**; a recovery/review workflow must be defined before implementation (Q24). No device lease/token-expiry system is introduced now (may be evaluated in Phase 17).
- **Limitation (explicit):** Revocation cannot reach a device that is completely offline; an offline stolen device can remain unaware of revocation temporarily.
- **Consequences:** This is a deliberate exception to "never block checkout" (ADR-004), limited to known revocation.

### ADR-025 — Unsynced data loss is an accepted physical limitation
- **Date:** 2026-09-29 · **Status:** ACCEPTED
- **Decision:** If a tablet creates transactions fully offline and the device or its storage is destroyed or irrecoverably lost before synchronization, those transactions cannot exist in the cloud. This risk cannot be eliminated while operating fully offline. Mitigations: sync automatically whenever connectivity exists; retry aggressively but safely; expose pending sync count; expose last successful sync; warn when unsynced data remains unusually long; **never display "backed up"/"synced" before server acknowledgement**.

### ADR-026 — One Flutter application with role-based, adaptive experiences; Riverpod; feature-first
- **Date:** 2026-09-29 · **Status:** ACCEPTED (resolves Q18; supersedes the two-app part of ADR-002)
- **Decision:**
  - Dokan Pro is **one Flutter application**, distributed as **one Play Store application/package**, serving OWNER, MANAGER, and CASHIER.
  - **Role-based experiences:** authentication and shop membership determine capabilities. Cashier experience = POS, checkout, product search, shift, allowed customer/udhaar operations. Owner experience = dashboard, sales/profit, inventory, udhaar, cashier activity, alerts, management. Manager experience = operational management, allowed reports, inventory operations, approved sensitive actions.
  - **Adaptive layouts:** device characteristics (phone vs tablet) control presentation; role controls capability — separate concerns. Permissions are never inferred from screen size; layout is never inferred solely from role. One device is not permanently one role.
  - **Role visibility in Flutter is not the security boundary.** Server-side authorization, RLS, and the sync boundary (ADR-014) remain authoritative; a modified client gains nothing by changing UI state.
  - **Repository:** a single Flutter application repository (conceptually `app/` + `docs/` + `AGENTS.md` + `README.md`; Phase 1 may choose a conventional Flutter root layout before initialization). No monorepo tooling and no `packages/core` / `packages/shared_ui` for artificial separation.
  - **Feature-first organization** (`lib/app`, `lib/core`, `lib/features/<feature>`), layers only where useful, domain layer only where business rules justify it, no ceremonial empty folders; `core` holds genuinely shared concepts (money, quantity, identifiers, errors, database infrastructure, security primitives, localization, shared UI primitives) and is not a dumping ground.
  - **Riverpod** is the primary state-management and dependency-wiring approach. Exact packages/versions/code-generation strategy are checked at implementation; code generation is not mandated. Feature-scoped state; no giant global state object; no mutable global business singletons; widgets don't own database/network business logic; repositories/database injected; Riverpod memory state is never authoritative financial storage.
  - Offline-first cashier checkout is unchanged. Remote owner analytics may require connectivity for data not on that device; full offline remote analytics are not promised.
- **Context:** The earlier documents assumed separate Cashier and Owner apps; that is unnecessary for one product with shared domain, database, and sync logic.
- **Alternatives:** Two Flutter apps sharing packages (monorepo); one app per role; other state-management approaches (BLoC, Provider, hand-written DI).
- **Rationale:** Single distribution artifact; one Play Store listing; simpler releases; shared domain/database/sync implementation without package plumbing; role-specific UX still possible; adaptive layouts handle phone/tablet differences; server authorization stays independent of UI roles. Riverpod gives testable, injectable, feature-scoped state without global singletons.
- **Consequences:** Owner features must not complicate or slow the cashier checkout path, and must never make local checkout cloud-dependent. A future split into separate apps requires a new approved ADR.

### ADR-027 — Encrypted local SQLite database from the first implementation
- **Date:** 2026-09-29 · **Status:** ACCEPTED (resolves Q12; complements ADR-016)
- **Decision:**
  - The POS local SQLite database **is encrypted from the beginning**, still via Drift (ADR-016), using a **SQLCipher-compatible encrypted SQLite implementation** or another explicitly reviewed equivalent. Exact package/adapter selected in Phase 2 after checking current compatibility and maintenance. No unencrypted production POS database.
  - **Encryption key:** a strong random key, protected by platform-backed secure storage (e.g., Android Keystore-backed storage; appropriate equivalents on other supported platforms). **Never** hardcoded, committed, stored in plaintext preferences, equal to the cashier PIN, or derived solely from a short cashier PIN.
  - The **cashier PIN (ADR-021) and the database key are separate concepts**; changing a PIN never requires database re-encryption.
  - **No insecure universal recovery key.**
- **Limitations:** Encryption primarily protects data **at rest**; it does not protect against an attacker controlling an already-unlocked or compromised device. The unsynced-data-loss limitation (ADR-025) is unchanged — if the device or its key storage is lost before sync, unsynced data cannot be recovered.
- **Alternatives:** OS-level protection only; adding encryption later (rejected — would require migrating every device's database file).
- **Rationale:** The tablet holds sales, customer phone numbers, and udhaar balances; shared shop tablets are easily lost or stolen.
- **Consequences:** Phase 2 must verify the encrypted adapter works with Drift and migrations; key-loss behavior (e.g., app data cleared) must be handled by re-enrolling and re-pulling from the cloud, never by a backdoor key.

### ADR-028 — Phase 1 foundation choices
- **Date:** 2026-09-29 · **Status:** ACCEPTED (user-approved in the Phase 1 instruction; complements ADR-026, which is unchanged)
- **Decision:**
  1. **Location:** the single Flutter application lives at the **conventional repository root** (`pubspec.yaml`, `lib/`, `test/`, `android/` beside `docs/`, `AGENTS.md`, `README.md`). No `app/` directory. Android is the only platform. applicationId `com.dokanpro.dokan_pro` (`--org com.dokanpro`, `--project-name dokan_pro`); permanent once published.
  2. **State management:** `flutter_riverpod`.
  3. **No Riverpod code generation:** no `riverpod_annotation`, `riverpod_generator`, `build_runner`, `riverpod_lint` / `custom_lint`; only current non-legacy APIs (`Provider`, `Notifier`/`NotifierProvider`, …); `package:flutter_riverpod/legacy.dart` is never imported.
  4. **CI:** GitHub Actions running only setup + `flutter analyze` + `flutter test` (plus `flutter gen-l10n`), read-only permissions, actions pinned by commit SHA, Flutter pinned to the local version (3.44.1 stable). No secrets, builds, uploads, deploys or releases.
  5. **Localization generated files are not committed:** gen-l10n output (`lib/l10n/app_localizations*.dart`) is git-ignored and regenerated with `flutter gen-l10n` (CI does this before analyze/test). Rationale: ARB files stay the single source of truth, and generated code can never drift from them or be hand-edited.
- **Dependencies (exact resolved versions, Phase 1):**

  | Package | Version | Purpose | Alternatives considered | Maintenance | Licence |
  |---|---|---|---|---|---|
  | `flutter_riverpod` | 3.4.3 (brings `riverpod` 3.4.3, `state_notifier` 1.0.0) | State management and dependency wiring (ADR-026) | Provider, BLoC, hand-written DI | Actively maintained by Remi Rousselet; latest stable at implementation | MIT |
  | `flutter_localizations` | Flutter SDK 3.44.1 | Material/Widgets localizations for en/ur, RTL | none (SDK standard) | Flutter team | BSD-3-Clause |
  | `intl` | 0.20.2 (`any`, pinned by `flutter_localizations`) | Required by gen-l10n output | none | Dart team | BSD-3-Clause |
  | `flutter_lints` (dev) | 6.0.0 (brings `lints` 6.1.0) | Lint baseline (template default) | `very_good_analysis`, custom sets | Flutter team | BSD-3-Clause |
  | `flutter_test` (dev) | Flutter SDK 3.44.1 | Test harness | none | Flutter team | BSD-3-Clause |

  Template default `cupertino_icons` was **removed** (not on the permitted list; iOS-style icons are unused).
- **GitHub Actions:** `actions/checkout` v7.0.1 @ `3d3c42e5aac5ba805825da76410c181273ba90b1` (repository checkout; GitHub-maintained, MIT); `subosito/flutter-action` v2.23.0 @ `1a449444c387b1966244ae4d4f8c696479add0b2` (installs the pinned Flutter SDK; widely used community action, MIT). Both pinned by commit SHA.
- **Rationale:** smallest foundation satisfying ADR-026 without code generation or build tooling; conventional layout avoids an extra directory level for a single app.
- **Consequences:** Any additional package requires justification and approval (AGENTS.md §2). A clean checkout must run `flutter gen-l10n` before `flutter analyze`.

---

## Open questions

Status legend: **OPEN**, **RESOLVED** (answered by an ADR). IDs are stable.
`blocks_phase` = the first phase that cannot start (or cannot complete the named
part) without the answer; `decide_by` = latest phase by which it must be decided
(before that phase starts).

### Resolved
| # | Question | Resolved by |
|---|---|---|
| Q18 | Repository layout and state management | ADR-026 (one Flutter app, role-based/adaptive experiences, Riverpod, feature-first) |
| Q12 | Local DB encryption at rest | ADR-027 (encrypted SQLite/Drift from initial implementation) |
| Q1 | Offline shared-tablet cashier authentication | ADR-021 |
| Q2 | Money rounding rules | ADR-008 |
| Q3 | Quantity scale; weighed/loose items | ADR-015, ADR-018 |
| Q7 | COGS costing method | ADR-019 |
| Q19 | Revoked-device checkout behavior | ADR-024 |
| Q4 | Refund/void modeling | Split: void basics resolved by ADR-020; remaining parts tracked as Q4a, Q4b |
| Q11 | Urdu numerals; POS portrait support | Split into Q11a, Q11b |

### Open
| # | Question | Why it matters | blocks_phase | decide_by | Status |
|---|---|---|---|---|---|
| Q17 | Profile deactivation/anonymization when referenced by financial history | Profiles are created in Phase 3 and referenced forever by audit/financial records | Phase 3 | Phase 3 | OPEN |
| Q13 | Master image bucket: public-read vs authenticated-read | Storage policy and image URL design | Phase 4 | Phase 4 | OPEN |
| Q15 | Master catalog data sourcing & barcode verification workflow | Quality of the initial ~1,000 products | Phase 4 | Phase 4 | OPEN |
| Q14 | Pack/variant handling (carton vs piece), multiple shop products per master product, and selling-unit/fractional-flag override rules between master and shop product | Duplicate rules and unit model for shop products | Phase 5 | Phase 5 | OPEN |
| Q25 | Shop-level search aliases for shop/custom products | Local search quality for custom products | Phase 5 | Phase 5 | OPEN |
| Q20 | Average-cost precision scale (per-unit cost in paisa may lose precision) and cost for opening stock entered without a cost | Integer-safe weighted average needs a defined scale; opening stock sets the first average | Phase 6 | Phase 6 | OPEN |
| Q21 | Weighted-average behavior under negative stock, returns/refunds, voids, and cost-affecting events arriving from multiple devices out of order | Determines cost snapshots and COGS correctness | Phase 6 (negative stock), Phase 9 (returns), Phase 10 (purchases) | Phase 6 | OPEN |
| Q4a | Void time window (e.g., only same shift / before shift close / any time) and manager approval mechanics on the counter | Void is part of Phase 7's sale correction boundary | Phase 7 | Phase 7 | OPEN |
| Q11b | POS orientation: landscape only vs landscape + portrait | Checkout layout design | Phase 7 | Phase 7 | OPEN |
| Q22 | Exact integer scale for percentage discounts (basis points or other) and whether discounts are in Phase 7 or Phase 9 | Discount arithmetic must be exact and consistent | Phase 7 (if discounts included there) | Phase 7 | OPEN |
| Q5 | Config conflict resolution workflow: who resolves, UI, deterministic rule, and which fields (if any) may use simpler policies | ADR-022 requires deterministic resolution | Phase 8 | Phase 8 | OPEN |
| Q6 | Effective business timestamp/date rule for reports, and clock-skew thresholds | ADR-023 requires an explicit definition | Phase 8 | Phase 8 | OPEN |
| Q24 | Recovery/review workflow for pending data from a revoked device | ADR-024 forbids silent discard | Phase 8 | Phase 8 | OPEN |
| Q4b | Refund record structure (typed sale vs separate return entity), partial refund rules, refund payment-out handling | Refund flows are Phase 9 | Phase 9 | Phase 9 | OPEN |
| Q23 | Permitted REVERSAL scenarios (system/payment corrections) | ADR-020 restricts REVERSAL to defined cases | Phase 9 | Phase 9 | OPEN |
| Q26 | Udhaar repayments: recorded in `payments` and the customer ledger, or ledger only | Avoids double-counting cash received | Phase 9 | Phase 9 | OPEN |
| Q8 | Customers/suppliers shop-scoped vs organization-shared | Tenant model for udhaar and suppliers | Phase 9 | Phase 9 | OPEN |
| Q9 | Multiple cashiers per shift / per device; relation of local sessions to shifts | Cash accountability | Phase 11 | Phase 11 | OPEN |
| Q10 | Owner experience: offline-capable config edits or online-only | Owner-experience data path | Phase 12 | Phase 12 | OPEN |
| Q11a | Urdu numerals (Western vs Eastern Arabic-Indic digits) | Formatting of money/quantities in Urdu | Phase 14 | Phase 14 | OPEN |
| Q16 | Subscription enforcement policy (must never block a local cash sale) | Billing behavior | Admin phase (post-MVP) | Admin phase | OPEN |
