# PHASE_STATUS.md

**Project:** Dokan Pro

**Current Phase:** PHASE 1 — Flutter Foundation

**Status:** READY_FOR_REVIEW

_Phase 0 — Constitution & Architecture: APPROVED._

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

## Phase 1 — Flutter Foundation (READY_FOR_REVIEW)

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
- [~] 10. CI workflow: setup + gen-l10n + analyze + test, read-only, pinned SHAs and Flutter 3.44.1, no secrets/deploy; validated locally from a clean state. **GitHub execution: not yet executed — pending user push**
- [x] 11. No hard-coded user-facing strings; en/ur key parity; runtime en ⇄ ur switch with full RTL (widget tests)
- [x] 12. `APP_ENV` config pattern with placeholder-only example; no secrets or Supabase references
- [x] 13. Only permitted dependencies, justified in ADR-028; `pubspec.lock` present
- [x] 14. No forbidden §5 items
- [x] 15. Documentation updated; Phase 1 READY_FOR_REVIEW; Phase 2 LOCKED
- [x] 16. Nothing pushed, deployed or published; no commits; no git repository initialized

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
| 1 | Flutter Foundation | **READY_FOR_REVIEW** |
| 2 | Local Data Foundation | LOCKED |
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
