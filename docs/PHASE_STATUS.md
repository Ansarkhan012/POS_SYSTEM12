# PHASE_STATUS.md

**Project:** Dokan Pro

**Current Phase:** PHASE 2 — Local Data Foundation

**Status:** READY_FOR_REVIEW

_Phase 0 — Constitution & Architecture: APPROVED. Phase 1 — Flutter Foundation: APPROVED._

> Only the user may set a phase to `APPROVED` or activate the next phase.
> Status values: `LOCKED` · `IN_PROGRESS` · `READY_FOR_REVIEW` · `APPROVED` · `BLOCKED`

## Phase 0 approval basis

Phase 0 was set to `APPROVED` on the user's explicit instruction (2026-09-29),
conditional on Q18 and Q12 being resolved and no other Phase 0 architectural
blocker remaining. Both conditions were verified by a cross-document audit:

- Q18 → ADR-026 (one Flutter app, role-based/adaptive experiences, Riverpod, feature-first)
- Q12 → ADR-027 (encrypted SQLite/Drift from the first implementation)

All remaining open questions have `blocks_phase` of Phase 3 or later (see
`DECISIONS.md` → Open questions). At the time of Phase 0 approval, Phase 1 had
not started and remained `LOCKED` until the user explicitly activated it.

## Phase 2 — Local Data Foundation (READY_FOR_REVIEW)

**Dependencies (exact resolved):** `drift` 2.35.0, `sqlite3` 3.5.2 (hook
`source: sqlite3mc` → SQLite3 Multiple Ciphers 2.5.0 / SQLite 3.53.4),
`flutter_secure_storage` 11.2.0, `path_provider` 2.1.6, `path` 1.9.1; dev:
`drift_dev` 2.35.0, `build_runner` 2.15.1, `integration_test` (SDK). Toolchain
unchanged (Flutter 3.44.1 / Dart 3.12.1). Android: minSdk 24, targetSdk 36,
compileSdk 36 (unchanged); app-data backup disabled (P2-D4). Details: ADR-029.

Checklist (Phase 2 instruction §17; engine-specific `cipher_version` check
replaced by the user-approved SQLite3MC verification):
- [x] 1. Encrypted SQLite via Drift with the approved SQLite3MC engine (SQLCipher-4-compatible, raw 256-bit key); no unencrypted production path, no fallback
- [x] 2. Encryption proven by evidence: runtime `PRAGMA cipher` + real read in production; non-plaintext header; unreadable without/with wrong key; marker absent from DB/journal bytes; correct key reopens; mutation check; on-device test on the Android emulator incl. `adb run-as` pull and restart persistence. **Real-tablet run of the Phase 2 encryption integration test: NOT PERFORMED.** Separately, the user installed and opened the Phase 2 debug APK on their real Android tablet and confirmed the existing Phase 1 UI still works (APK smoke test only; the app does not open the database at startup per P2-D2, so this is not encryption evidence)
- [x] 3. Key: 256-bit, `Random.secure()`, only in Keystore-backed `flutter_secure_storage` (dedicated namespace); never hardcoded/committed/plaintext/logged/PIN-derived; no PIN input; no recovery key
- [x] 4. Missing/corrupt/wrong key and unavailable storage fail closed; existing database byte-identical afterwards (tests)
- [x] 5. Backup disabled (`allowBackup=false`, `fullBackupContent=false`, data-extraction exclusions); verified in merged manifest
- [x] 6. Schema v1 = `device_identity` + `outbox_events` only; STRICT tables; append-only/immutability triggers; CHECK constraints; ordering by `device_seq` only
- [x] 7. Committed schema dump; encrypted file-based schema validation and all-versions upgrade harness; unknown version fails closed; CI checks dump freshness
- [x] 8. Atomic business row + outbox + `device_seq` (commit, exception rollback, reopen, killed writer isolate); append outside a transaction impossible
- [x] 9. `device_seq` monotonic, gap-free, unique (1000 sequential, 200 concurrent, across reopen); install ID UUIDv4 and stable
- [x] 10. Money/Quantity integer-only, half-away-from-zero tested ±, overflow detected, whole-piece validation, exact parsing; zero `double` in money/quantity/outbox paths
- [x] 11. UUIDv4 generator (in-house, `Random.secure()`), identity only
- [x] 12. Riverpod providers overridable, dispose closes DB, no retry on fail-closed; no UI access, no startup wiring (P2-D2), no `lib/features/`
- [x] 13. 186 tests pass (92 Phase 1 unchanged + 94 Phase 2); none skipped or weakened
- [x] 14. `dart format` clean; `flutter analyze` zero issues; `flutter build apk --debug` succeeds
- [~] 15. CI updated (Drift codegen, schema-dump check, schema helpers; pinned; no secrets); validated locally from a clean state. **GitHub execution: not yet executed — pending user push**
- [x] 16. Only approved dependencies; `pubspec.lock` commit-ready
- [x] 17. No forbidden §5 items (no Supabase/auth/sessions/business tables/sync/UI/audit table)
- [x] 18. Documentation updated; ADR-029 ACCEPTED; Phase 2 READY_FOR_REVIEW; Phase 3 LOCKED
- [x] 19. No commits, push, deploy or publish

## Phase 1 — Flutter Foundation (APPROVED)

**Approval basis:** set to `APPROVED` on the user's explicit conditional
instruction (2026-09-30): approve only if the configured GitHub Actions workflow
completed successfully. Verified: workflow run
[36616155683](https://github.com/Ansarkhan012/POS_SYSTEM12/actions/runs/36616155683)
on commit `521d63d` (branch `main`) completed with conclusion **success**
(checkout, Flutter setup, pub get, gen-l10n, analyze, test all succeeded).
Phase 2 remains `LOCKED` until the user explicitly activates it.

**Toolchain:** Flutter 3.44.1 (stable, framework 924134a44c, engine c416acfeb8),
Dart 3.12.1. **Android:** applicationId `com.dokanpro.dokan_pro`; minSdk 24,
targetSdk 36, compileSdk 36 (Flutter Gradle defaults, untuned — Phase 2 revisits
for the encrypted database adapter).

**Manual device QA (performed by the user on a real Android tablet, 2026-09-29).**
The user confirmed: the app installs and opens correctly; the tablet layout works
correctly; the developer role preview works; role-based shell behaviour is
correct; English works correctly; Urdu switching works correctly; RTL behaviour
works correctly; no blocking UI issue was observed during the tablet check.
No other device checks are claimed (earlier emulator attempts were inconclusive
because the emulator was overloaded; no phone device was checked).

Checklist (Phase 1 instruction §11):
- [x] 1. One Flutter app at the repository root; Android only; applicationId uses `com.dokanpro`
- [x] 2. `flutter build apk --debug` succeeds. **Real Android tablet QA completed by the user** (see above). Phone form factor on a real device: **not verified** (not part of the user's QA); covered by widget tests only
- [x] 3. Layout adapts by width (NavigationBar / NavigationRail); capabilities from role only (tests)
- [x] 4. Default "no session"; role destinations only via labeled debug-only developer preview; no auth UI/logic
- [x] 5. Cashier opens on Checkout with one secondary entry; no owner/analytics destinations
- [x] 6. No `lib/features/`, no empty/ceremonial folders, no `packages/`, no monorepo tooling
- [x] 7. `flutter_riverpod` via `ProviderScope`; no codegen, no legacy APIs, no global mutable state
- [x] 8. `flutter analyze`: zero issues; `dart format`: no changes
- [x] 9. All required tests exist and pass (92 tests); none skipped or weakened
- [x] 10. CI workflow: setup + gen-l10n + analyze + test, read-only, pinned SHAs and Flutter 3.44.1, no secrets/deploy; validated locally from a clean state; **GitHub Actions run 36616155683 on `521d63d`: success**
- [x] 11. No hard-coded user-facing strings; en/ur key parity; runtime en ⇄ ur switch with full RTL (widget tests)
- [x] 12. `APP_ENV` config pattern with placeholder-only example; no secrets or Supabase references
- [x] 13. Only permitted dependencies, justified in ADR-028; `pubspec.lock` present
- [x] 14. No forbidden §5 items
- [x] 15. Documentation updated; Phase 1 APPROVED (user's conditional instruction, CI verified); Phase 2 LOCKED
- [x] 16. Git initialized and `main` pushed only on the user's explicit instruction (commit `521d63d`); nothing deployed or published

## Phase 0 checklist — required documents

- [x] `AGENTS.md`
- [x] `README.md`
- [x] `docs/PRODUCT.md`
- [x] `docs/DESIGN.md`
- [x] `docs/ARCHITECTURE.md`
- [x] `docs/DATA_MODEL.md`
- [x] `docs/PRODUCT_CATALOG.md`
- [x] `docs/OFFLINE_SYNC.md`
- [x] `docs/SECURITY.md`
- [x] `docs/DECISIONS.md`
- [x] `docs/GOTCHAS.md`
- [x] `docs/PHASE_PLAN.md`
- [x] `docs/PHASE_STATUS.md`
- [x] Initial consistency audit completed
- [x] Final review binding decisions 1–15 applied (ADR-008, ADR-013 to ADR-025)
- [x] Final cross-document audit completed
- [x] Phase 0 blockers resolved: Q18 (ADR-026), Q12 (ADR-027)
- [x] One-app architecture correction applied across all documents
- [x] Post-correction contradiction audit completed
- [x] User approval of Phase 0 (conditional instruction, conditions met)

## Phase 0 constraints confirmed
- No application code, framework initialization, dependency installation,
  migrations, UI screens, deployment, commit, or push.

## All phases

| Phase | Name | Status |
|---|---|---|
| 0 | Constitution & Architecture | **APPROVED** |
| 1 | Flutter Foundation | **APPROVED** |
| 2 | Local Data Foundation | **READY_FOR_REVIEW** |
| 3 | Cloud/Auth/Tenant Foundation | LOCKED |
| 4 | Master Product Catalog | LOCKED |
| 5 | Shop Products | LOCKED |
| 6 | Inventory Foundation | LOCKED |
| 7 | POS Checkout | LOCKED |
| 8 | Offline Sync | LOCKED |
| 9 | Payments & Udhaar | LOCKED |
| 10 | Purchases & Suppliers | LOCKED |
| 11 | Shifts & Cash Reconciliation | LOCKED |
| 12 | Owner Experience (formerly "Owner App") | LOCKED |
| 13 | Notifications | LOCKED |
| 14 | Localization | LOCKED |
| 15 | Hardware Integration | LOCKED |
| 16 | Analytics | LOCKED |
| 17 | Security Hardening | LOCKED |
| 18 | QA / Chaos / Load Testing | LOCKED |
| 19 | Pilot Release | LOCKED |

## Change log
- 2026-09-29 — Phase 0 documentation created; status set to READY_FOR_REVIEW.
- 2026-09-29 — Phase 0 final review: binding decisions 1–15 recorded (ADR-008
  and ADR-013 to ADR-017 finalized; ADR-018 to ADR-025 added); open questions
  given `blocks_phase` / `decide_by`; cross-document audit completed. Status
  remains READY_FOR_REVIEW because of blockers Q18 (Phase 1) and Q12 (Phase 2).
- 2026-09-29 — Architecture correction: one Flutter application with role-based,
  adaptive experiences, Riverpod, feature-first (ADR-026, supersedes the two-app
  part of ADR-002; resolves Q18). Encrypted local DB from the first implementation
  (ADR-027; resolves Q12). Two-app references removed from all documents; Phase 12
  renamed "Owner Experience" (scope unchanged). Audit found no remaining Phase 0
  blocker. **Phase 0 set to APPROVED** per user instruction. Phase 1 LOCKED.
- 2026-09-29 — User activated Phase 1 (Flutter Foundation). Pre-work checks:
  repository contains only AGENTS.md, README.md, docs/ (expected state); Flutter
  3.44.1 on the stable channel is installed. User confirmed project name
  `dokan_pro` and chose to use the installed Flutter 3.44.1 (no upgrade).
  **Phase 1 set to BLOCKED** per the Phase 1 instruction §12: the permanent
  Android organization / applicationId prefix (`--org`) was not provided, and the
  user chose to decide later. Nothing was created; ADR-028 not yet recorded.
  Unblock by providing the `--org` value. Phase 2 remains LOCKED.
- 2026-09-29 — Phase 1 unblocked by the user: `--org com.dokanpro`,
  `--project-name dokan_pro` → applicationId `com.dokanpro.dokan_pro`. Flutter
  3.44.1 stable kept as-is and pinned in CI. **Phase 1 set to IN_PROGRESS.**
  User-approved Phase 1 decisions (recorded as ADR-028): single Flutter app at the
  conventional repository root (no `app/` directory); `flutter_riverpod`; no
  Riverpod code generation (no riverpod_annotation/riverpod_generator/build_runner/
  riverpod_lint/custom_lint; no legacy APIs); GitHub Actions CI limited to
  `flutter analyze` + `flutter test` and their setup steps.
- 2026-09-29 — Phase 1 implementation complete: single Flutter app at repo root
  (Android only, `com.dokanpro.dokan_pro`), Riverpod-wired role-aware adaptive
  shell with no-session default and debug-only developer role preview, en + ur
  (provisional) gen-l10n with runtime RTL switch, `APP_ENV` config pattern, strict
  analysis, 92 passing tests, GitHub Actions CI (not yet executed — pending user
  push). Flutter 3.44.1 / Dart 3.12.1; minSdk 24, targetSdk 36. ADR-028 recorded;
  ARCHITECTURE §4.1, README and GOTCHAS (G63–G70) updated. Device verification
  only partial (tablet emulator overloaded). **Phase 1 set to READY_FOR_REVIEW.**
  Phase 2 remains LOCKED.
- 2026-09-29 — User completed manual QA of Phase 1 on a real Android tablet
  (install/open, tablet layout, developer role preview, role-based shell, English,
  Urdu switching, RTL; no blocking UI issue). User authorized initializing Git and
  pushing Phase 1 to `https://github.com/Ansarkhan012/POS_SYSTEM12` (branch
  `main`). Phase 1 stays READY_FOR_REVIEW until the GitHub Actions workflow is
  verified as passing. Phase 2 remains LOCKED.
- 2026-09-30 — Git initialized (branch `main`); Phase 1 foundation committed as
  `521d63d` and pushed to `origin` (`https://github.com/Ansarkhan012/POS_SYSTEM12`)
  on the user's explicit instruction. GitHub Actions run 36616155683 completed
  with **success**. Per the user's conditional instruction, **Phase 1 set to
  APPROVED**. Phase 2 remains LOCKED. Nothing deployed or published.
- 2026-09-30 — User approved the Phase 2 implementation instruction and
  **activated Phase 2** (Phase 1 APPROVED; no open question has
  `decide_by: Phase 2`). Pre-work: clean tree on `main` at `edba318`, Flutter
  3.44.1 / Dart 3.12.1, minSdk 24 / targetSdk 36 / compileSdk 36, AGP 9.0.1,
  Kotlin 2.3.20, Gradle 9.1.0; manifest has no backup attributes (Android default
  `allowBackup=true`). User decisions:
  **P2-D1** allow `drift_dev` + `build_runner` solely for Drift code generation
  (Riverpod codegen still forbidden); generated Drift `*.g.dart` not committed, CI
  generates them before analyze/test. **P2-D2** do not open the database at app
  startup in Phase 2. **P2-D3** fail closed when the key is missing, corrupt,
  unusable or wrong while an encrypted database exists; never delete, overwrite,
  rename, recreate or replace it. **P2-D4** disable Android app-data backup with
  data-extraction exclusions. **P2-D5** client-generated UUIDv4 install ID stored
  in the encrypted database = future device_id; reinstall = new install ID.
  **Phase 2 set to IN_PROGRESS — Stage A** (research only; no dependencies installed).
- 2026-09-30 — **Stage A checkpoint reached.** Research recorded as draft
  **ADR-029 (PROPOSED)** in DECISIONS.md: adapter comparison (recommended:
  `sqlite3` 3.5.2 hook `source: sqlite3mc`, SQLCipher-4-compatible scheme, raw
  256-bit key; alternative: `source: sqlcipher`), secure storage (recommended:
  `flutter_secure_storage` 11.2.0 pinned), supporting deps, and toolchain limits
  found (Flutter 3.44.1 `meta` pin blocks `sqlite3` 3.6.0 and `build_runner`
  ≥ 2.15.2). Verified by resolution in a scratch copy only; **no dependency was
  added to the project, no Phase 2 code written, no Stage B work started.**
  Awaiting user approval of Phase 2 dependencies.
- 2026-09-30 — User approved Stage A and authorized **Stage B**: engine Option A
  (SQLite3MultipleCiphers via `sqlite3` 3.5.2, hook `source: sqlite3mc`,
  SQLCipher-4-compatible scheme, raw 256-bit key; no plain SQLite, no unencrypted
  fallback); replacement runtime encryption verification approved (reject empty
  key, configure SQLCipher mode, apply raw key, verify `PRAGMA cipher`, real read,
  fail closed) plus independent test proofs; `flutter_secure_storage` 11.2.0
  (exact) with a dedicated namespace; supporting deps `drift` 2.35.0,
  `path_provider` 2.1.6, `path` 1.9.1, `drift_dev` 2.35.0, `build_runner` 2.15.1,
  `integration_test` (SDK). Stage B compatibility gate: ABIs, no plain-SQLite
  conflict, no minSdk increase, 16 KB page-size alignment.
- 2026-09-30 — **Phase 2 Stage B complete.** Encrypted local data foundation
  implemented in `lib/core/` (database, encryption/key management, outbox,
  device identity, money, quantity, UUIDv4, clock); schema v1 dump committed;
  Android backup disabled; on-device integration test added. Verification:
  186 tests pass, analyze/format clean, debug APK built; compatibility gate
  passed (SQLite3MC for arm64-v8a/armeabi-v7a/x86_64, no plain-SQLite library,
  minSdk 24, 16 KB alignment); on-device encryption proof passed on the Android
  emulator (real tablet run not performed). ADR-029 finalized ACCEPTED; GOTCHAS
  G71–G86 added; README and ARCHITECTURE §5 updated. CI GitHub execution pending
  user push. **Phase 2 set to READY_FOR_REVIEW.** Phase 3 remains LOCKED.
- 2026-09-30 — User reviewed Phase 2 and smoke-tested the Phase 2 debug APK on
  their real Android tablet (installs and opens; Phase 1 UI still works). This
  is **not** an execution of the Phase 2 encryption integration test on the real
  tablet, which remains **NOT PERFORMED**; the Android emulator run remains the
  on-device encryption evidence. User authorized committing and pushing Phase 2.
