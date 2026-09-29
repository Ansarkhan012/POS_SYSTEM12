# PHASE_PLAN.md — Implementation Sequence

Phases run strictly in order. A phase starts only after the previous one is
**APPROVED** by the user and the new phase is explicitly activated in
`PHASE_STATUS.md`. No implementation code appears in this document.

## Cross-cutting rules (apply to every phase)

These resolve ordering tensions between phases and are binding:

1. **Localization-ready from Phase 1.** Strings externalized and layouts RTL-safe
   from the first screen. Phase 14 adds full Urdu content and RTL QA — it does not
   retrofit string externalization.
2. **RLS from Phase 3.** Every cloud table with shop data gets RLS and
   cross-tenant tests in the phase that creates it. Phase 17 is hardening/review,
   not the introduction of security.
3. **Outbox from Phase 2.** The outbox structure exists from the local data
   foundation. Every phase that creates syncable local changes (Phase 5 onward)
   writes outbox events in the same local transaction. **Transmission** of the
   outbox is built in Phase 8.
4. **Money/quantity integer rules from Phase 2.** The shared money/quantity module
   (ADR-008 paisa + half-away-from-zero rounding, ADR-015 1 unit = 1000 subunits)
   is built and tested before any financial feature. Fractional/loose goods are
   supported from the start (ADR-018).
5. **Open questions gate phases.** A phase cannot start while any open question
   with that phase as `decide_by` in DECISIONS.md is still OPEN.
6. **Audit from first sensitive action.** Any phase introducing a sensitive action
   also records it (locally and, once synced, in the cloud audit log).
7. **Tests are part of acceptance** for every phase.

---

## Phase 0 — Constitution & Architecture
- **Objective:** Establish binding product, architecture, security, and process documentation.
- **In scope:** AGENTS.md, README.md, docs/* (13 documents total).
- **Out of scope:** Any code, framework init, dependencies, migrations, UI, deploy, commit/push.
- **Prerequisites:** Product brief.
- **Deliverables:** Documentation set; decision log; open questions list.
- **Acceptance criteria:** All documents exist, are mutually consistent, future phases LOCKED, user approves.

## Phase 1 — Flutter Foundation
- **Objective:** Create the single Dokan Pro Flutter application (ADR-026) with quality tooling.
- **In scope:** One Flutter application (location `app/` or conventional root, decided before initialization), feature-first skeleton only as needed (`lib/app`, `lib/core`, `lib/features`), Riverpod wiring (package/version/codegen strategy checked and justified), role-aware and adaptive (phone/tablet) empty navigation shell, lint/format/analysis rules, test harness, localization infrastructure (externalized strings, RTL-safe layout), environment config pattern with no secrets, CI for analyze/test (no deploy).
- **Out of scope:** Business features, database, Supabase integration, real screens beyond shells.
- **Prerequisites:** Phase 0 APPROVED.
- **Deliverables:** Buildable empty application; tooling; dependency justifications recorded.
- **Acceptance criteria:** The app builds and runs on Android phone and tablet form factors; layout adapts by device while capability comes from role (shell level); no monorepo/packages created for artificial separation; no ceremonial empty folders; analyzer clean; tests run in CI; no hard-coded UI strings; English + placeholder Urdu locale switch works on shell; no secrets in repo.

## Phase 2 — Local Data Foundation
- **Objective:** Establish the local database, transactions, migrations, outbox structure, and money/quantity primitives.
- **In scope:** Encrypted SQLite via Drift (ADR-016, ADR-027: SQLCipher-compatible adapter selection, random key in platform secure storage), migration framework and tests, transaction helper, outbox table + event envelope (local only: event_id, idempotency key, device_seq, local session ID, occurred time, clock info, schema version), device-local identity (install ID), money & quantity module (ADR-008, ADR-015), random UUID generation (ADR-013).
- **Out of scope:** Business tables beyond what the foundation needs; cloud sync; UI features.
- **Prerequisites:** Phase 1 APPROVED.
- **Deliverables:** Local DB layer; outbox structure; money/quantity module with exhaustive tests.
- **Acceptance criteria:** Atomic write of business row + outbox entry proven by tests (including simulated crash/rollback); migrations upgrade cleanly from every version (on the encrypted database); database file unreadable without the key; key never hardcoded, in plaintext preferences, or derived from a PIN; zero floating-point in money/quantity paths; rounding tests cover half-away-from-zero for positive and negative amounts; whole-piece validation rejects non-multiples of 1000; no logic orders by UUID.

## Phase 3 — Cloud/Auth/Tenant Foundation
- **Objective:** Stand up Supabase with tenant model, auth, memberships, devices, and RLS.
- **In scope:** Environments (dev/prod separation), organizations, shops, profiles, shop_memberships, devices, audit_logs (cloud), RLS policies + cross-tenant tests, login for owner/manager, online device enrollment and revocation, offline cashier local-PIN sessions per ADR-021 (salted verifier, hashing package choice), local sessions, secure token storage, profile policy (Q17).
- **Out of scope:** Catalog, products, sales, sync engine, owner analytics.
- **Prerequisites:** Phase 2 APPROVED; Q17 decided.
- **Deliverables:** Cloud schema/migrations for tenancy; auth flows; device registration; RLS test suite.
- **Acceptance criteria:** Cross-shop read/write/RPC attempts fail in automated tests; no service-role key in any client artifact; device can be enrolled and revoked; a device that learns of revocation enters a locked state; cashier can unlock offline with a PIN and no plaintext PIN exists anywhere; docs/UI never claim cloud authentication of offline actions.

## Phase 4 — Master Product Catalog
- **Objective:** Create the global master catalog and deliver it to devices for local search.
- **In scope:** master_products (incl. unit type and default fractional indication), master_product_barcodes, product_aliases (cloud + local cache), catalog versioning and delta pull (catalog stream only), WebP thumbnail pipeline per ADR-017 (<= 512 px, target <= 60 KB, ceiling ~100 KB) and storage (Q13), lazy image loading + local cache, local search over cached catalog, initial ~1,000-product data load via trusted admin import (Q15).
- **Out of scope:** Shop products, prices, stock, admin UI, promotion workflow, barcode scanning hardware.
- **Prerequisites:** Phase 3 APPROVED; Q13, Q15 decided.
- **Deliverables:** Catalog in cloud; device catalog cache; image cache; local search.
- **Acceptance criteria:** Catalog contains no shop-specific fields; device receives deltas by version incl. tombstones; no bulk image download at startup; image size limits enforced; search works offline with aliases; ~1,000 products loaded and spot-checked.

## Phase 5 — Shop Products
- **Objective:** Let a shop configure what it sells.
- **In scope:** shop_products (selling unit, fractional flag, enabled/disabled, row version), shop_product_barcodes, "Add to Shop" from master, custom products (shop-private), price/purchase-price-setting/threshold editing with permissions, audit, and version-carrying outbox events (ADR-022), barcode lookup order (manual entry), duplicate-prevention checks (Q14, Q25).
- **Out of scope:** Stock, sales, sync transmission, promotion to master.
- **Prerequisites:** Phase 4 APPROVED; Q14, Q25 decided.
- **Deliverables:** Shop product management (POS manager functions); local persistence + outbox events.
- **Acceptance criteria:** Custom product usable immediately offline; never visible to another shop; never auto-promoted; lookup order matches PRODUCT_CATALOG.md §7.1; price changes audited; config edits carry base versions.

## Phase 6 — Inventory Foundation
- **Objective:** Movement-based inventory.
- **In scope:** inventory_movements (OPENING, ADJUSTMENT, DAMAGE initially) in integer subunits, cached inventory_balances with rebuild, moving weighted average cost state (ADR-019) seeded by opening stock, stock view, low-stock indication, permission + reason + audit for adjustments, outbox events.
- **Out of scope:** Purchases (Phase 10), sales movements (Phase 7), analytics.
- **Prerequisites:** Phase 5 APPROVED; Q20, Q21 decided.
- **Deliverables:** Ledger, balance/average-cost cache, adjustment flows.
- **Acceptance criteria:** Balance always equals sum of movements (property tests); rebuild from ledger matches cache; no direct stock-field writes; negative balances allowed and flagged; average cost computed with integer-safe arithmetic.

## Phase 7 — POS Checkout
- **Objective:** Fast, offline-first cash checkout.
- **In scope:** Checkout screen, cart and cart cancel, local search/quick items, quantity including **fractional/loose goods with manual weight entry** (ADR-018), cash tender with change, sale + sale_items with name/price/`cost_price_snapshot`, SALE movements, device-prefixed receipt numbers, the approved sale-correction boundary: **full-sale void** with manager/owner permission, reason, audit, and reversing events (ADR-020, Q4a), last-sale recall, revoked-device checkout lock (ADR-024), pending sync count / last sync display (ADR-025), outbox events — all in one local transaction.
- **Out of scope:** Digital payments, udhaar, split tender, refunds/returns and REVERSAL (Phase 9), printing/scanning hardware (Phase 15), sync transmission (Phase 8), shifts (Phase 11).
- **Prerequisites:** Phase 6 APPROVED; Q4a, Q11b, Q22 decided.
- **Deliverables:** Working offline cash checkout.
- **Acceptance criteria:** Sale completes in airplane mode; crash tests show all-or-nothing; no floating point; fractional line amounts exact per ADR-008; snapshots immutable; void creates reversing events and never deletes or edits the original; checkout performance target met on a representative low-cost tablet with 5,000 shop products.

## Phase 8 — Offline Sync
- **Objective:** Reliable, idempotent synchronization between devices and cloud.
- **In scope:** Cloud tables for Phase 5–7 data, the server-side financial sync boundary (ADR-014), sync_events, idempotency, device_seq gap detection, retry/backoff, ack handling, rejected-event dead-letter + surfacing, optimistic-concurrency conflicts for config (ADR-022, Q5), pull streams with server cursors, server-time offset and clock-skew flagging (ADR-023, Q6), revoked-device sync handling (ADR-024, Q24), sync status indicator.
- **Out of scope:** LAN sync, real-time collaboration, analytics.
- **Prerequisites:** Phase 7 APPROVED; Q5, Q6, Q24 decided.
- **Deliverables:** Sync engine; ingestion functions; sync monitoring data.
- **Acceptance criteria:** Duplicate/replayed submissions create no duplicates; no client path inserts financial rows directly; stale config edits produce CONFLICT, never silent overwrite; original device timestamps preserved; killed app mid-sync recovers; gaps detected; rejected and revoked-device events never lost; nothing shown as synced before ack; two offline devices converge after reconnect; all ingestion paths pass cross-tenant tests.

## Phase 9 — Payments & Udhaar
- **Objective:** Complete tender types and customer credit.
- **In scope:** Digital payment recording (method + reference; no gateway), split tender, customers, customer_ledger_entries (udhaar sale, repayment, adjustment), refunds (full, then partial) as new linked records per ADR-020 with permissions, reason, audit, RETURN/REFUND movements, defined REVERSAL scenarios.
- **Out of scope:** Payment gateway integration, customer SMS/WhatsApp statements.
- **Prerequisites:** Phase 8 APPROVED; Q4b, Q8, Q23, Q26 decided.
- **Deliverables:** Tender and udhaar flows, refund flow, ledgers synced.
- **Acceptance criteria:** Customer balance = sum of ledger entries; refunds never delete sales; unauthorized refund blocked locally and flagged server-side; all offline-capable.

## Phase 10 — Purchases & Suppliers
- **Objective:** Record stock received and supplier payables.
- **In scope:** suppliers, purchases, purchase_items, PURCHASE movements, supplier_ledger_entries, supplier payments, moving weighted average cost update on receipt (ADR-019).
- **Out of scope:** Purchase orders to distributors, supplier portals.
- **Prerequisites:** Phase 9 APPROVED.
- **Deliverables:** Purchase receiving and supplier ledger.
- **Acceptance criteria:** Purchases produce movements; cost changes don't alter historical sale profit; supplier balance = sum of entries.

## Phase 11 — Shifts & Cash Reconciliation
- **Objective:** Cash accountability per shift.
- **In scope:** shifts, cash_drawer_events (float, cash in/out, drops), expenses (incl. paid from drawer), shift close with counted vs expected cash and recorded difference, relation of local sessions to shifts.
- **Out of scope:** Payroll, bank reconciliation.
- **Prerequisites:** Phase 10 APPROVED; Q9 decided.
- **Deliverables:** Shift open/close, drawer events, expenses.
- **Acceptance criteria:** Expected cash derivable exactly from records; differences recorded and audited, never silently adjusted; closed shifts immutable.

## Phase 12 — Owner Experience
- **Objective:** Remote visibility and control for owners, as a role-based, phone-first (adaptive on tablet) experience inside the single app. (Phase originally titled "Owner App"; renamed per ADR-026 — scope unchanged.)
- **In scope:** Owner login, shop switcher, today/period summaries from transactional data (sales, gross profit from snapshots, payments, udhaar outstanding, cash expected, low stock), cashier activity (voids, refunds, discounts), data freshness and pending/last sync per device, price/product/staff management with version conflicts surfaced (ADR-022).
- **Out of scope:** Push notifications (Phase 13), advanced analytics read models (Phase 16).
- **Prerequisites:** Phase 11 APPROVED; Q10 decided.
- **Deliverables:** Owner experience MVP within the Dokan Pro app.
- **Acceptance criteria:** Numbers reconcile with transactional data; freshness always shown; offline limits of remote data stated honestly; owner sees only their shops; server enforces owner-only capabilities regardless of client UI; cashier checkout path unaffected; config changes reach POS via sync.

## Phase 13 — Notifications
- **Objective:** Actionable owner alerts.
- **In scope:** alerts generation (low stock, large void/refund/discount, cash difference, device not synced, rejected events, clock skew), in-app alert list, push delivery.
- **Out of scope:** Customer-facing notifications, marketing messages.
- **Prerequisites:** Phase 12 APPROVED.
- **Deliverables:** Alert pipeline and delivery.
- **Acceptance criteria:** Alerts are derived, deduplicated, tenant-isolated, and link to their source records.

## Phase 14 — Localization
- **Objective:** Full English and Urdu experience.
- **In scope:** Urdu translations for all strings, RTL QA, Urdu product names/aliases display, number/currency/date formatting (Q11a).
- **Out of scope:** Additional languages.
- **Prerequisites:** Phase 13 APPROVED; Q11a decided.
- **Deliverables:** Complete Urdu locale for all experiences of the app.
- **Acceptance criteria:** Every screen usable in Urdu RTL without layout breakage; language switch without rebuild; no untranslated strings.

## Phase 15 — Hardware Integration
- **Objective:** Thermal receipt printing and barcode scanning.
- **In scope:** Supported printer models (Bluetooth/USB, 58/80 mm), receipt template (English/Urdu), barcode scanning (camera and/or HID scanner) wired to lookup order, printer failure handling that never blocks sale completion.
- **Out of scope:** Weighing-scale integration (weights stay manual unless separately approved), cash drawer kick (unless trivial and approved), label printing.
- **Prerequisites:** Phase 14 APPROVED.
- **Deliverables:** Printing and scanning.
- **Acceptance criteria:** Sale completes even if printer is offline; reprint works; scan-to-cart meets speed target on tested hardware.

## Phase 16 — Analytics
- **Objective:** Richer owner analytics via read models.
- **In scope:** Aggregations (sales, COGS, gross profit, expenses, estimated net profit, payments, udhaar, stock, cashier activity) over periods; read-model refresh strategy.
- **Out of scope:** BI exports, forecasting/AI.
- **Prerequisites:** Phase 15 APPROVED.
- **Deliverables:** Analytics read models and owner-experience views.
- **Acceptance criteria:** Aggregates reconcile with transactional truth; rebuildable; tenant-isolated; performant at target scale.

## Phase 17 — Security Hardening
- **Objective:** Review and strengthen security end-to-end.
- **In scope:** RLS/RPC audit, threat-model review (SECURITY.md §12), secret scanning, key rotation procedure, review of device security (incl. local DB encryption and key handling per ADR-027), evaluation of a device lease/token-expiry mechanism for revocation (ADR-024), review of offline actor-identity limitation (ADR-021), dependency audit.
- **Out of scope:** New features.
- **Prerequisites:** Phase 16 APPROVED.
- **Deliverables:** Security review report and fixes.
- **Acceptance criteria:** All listed threats have verified mitigations or explicitly accepted residual risk.

## Phase 18 — QA / Chaos / Load Testing
- **Objective:** Prove reliability under realistic and adverse conditions.
- **In scope:** Network flapping, long offline periods, crash-during-write, clock skew, duplicate/replay, multi-device convergence, low-end tablet performance, load test toward target shop count.
- **Out of scope:** New features.
- **Prerequisites:** Phase 17 APPROVED.
- **Deliverables:** Test plans, results, fixes.
- **Acceptance criteria:** No lost or duplicated financial records in any scenario; performance targets met.

## Phase 19 — Pilot Release
- **Objective:** Run Dokan Pro in a small number of real Karachi shops.
- **In scope:** Pilot onboarding, device setup, support process, monitoring, feedback capture, backup/restore verification.
- **Out of scope:** Public launch, marketing, admin platform.
- **Prerequisites:** Phase 18 APPROVED; explicit deploy/release instruction from the user.
- **Deliverables:** Pilot deployment and pilot report.
- **Acceptance criteria:** Pilot shops operate daily including offline periods with no data loss; owner confirms reconciled numbers; issues logged in GOTCHAS/DECISIONS.

---

**Post-MVP (not scheduled):** Admin platform (catalog curation, custom product
promotion, shop management, subscriptions — Q16, support diagnostics).
