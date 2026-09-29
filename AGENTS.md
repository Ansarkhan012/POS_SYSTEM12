# AGENTS.md — Controlling Instructions for Coding Agents

This file governs every coding agent (human or AI) working on **Dokan Pro**.
It takes precedence over habits, defaults, and assumptions. If anything here
conflicts with another document, **stop and report the conflict** — do not guess.

> **Do not expand product scope without explicit approval.**

---

## 1. Before you edit anything

1. Read this file completely.
2. Read `docs/PHASE_STATUS.md` to learn the **active phase** and its status.
3. Read `docs/PHASE_PLAN.md` for the active phase's in-scope / out-of-scope lists.
4. Read `docs/GOTCHAS.md` — every time, before implementing.
5. Read the documents relevant to your change:

| If you touch…                          | You must read                                   |
|----------------------------------------|-------------------------------------------------|
| Anything                               | `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`       |
| UI / interaction                       | `docs/DESIGN.md`                                |
| Entities, tables, local DB, migrations | `docs/DATA_MODEL.md`                            |
| Products, barcodes, images, search     | `docs/PRODUCT_CATALOG.md`                       |
| Writes, outbox, sync, conflicts        | `docs/OFFLINE_SYNC.md`                          |
| Auth, RLS, roles, secrets, storage     | `docs/SECURITY.md`                              |
| Any architectural choice               | `docs/DECISIONS.md`                             |

## 2. Hard rules (non-negotiable)

- **Never assume requirements.** If a requirement is missing or ambiguous, ask.
- **Never change architecture silently.** Architectural changes require a new or
  superseding entry in `docs/DECISIONS.md` and explicit approval.
- **Never implement future phases.** Only the phase marked active in
  `docs/PHASE_STATUS.md` may be modified. Work belonging to a `LOCKED` phase must
  not be started, stubbed, or "prepared in advance".
- **Do not expand product scope without explicit approval.**
- **Never add dependencies without justification.** Every new package must be
  justified (purpose, alternatives, maintenance status, licence) in the change
  description, and significant ones recorded in `docs/DECISIONS.md`.
- **Never weaken security for convenience.** No disabling RLS, no broad
  policies "for testing", no permissive storage buckets, no skipped auth checks.
- **Never expose secret or service-role credentials.** The Supabase
  service-role key must never appear in the Flutter app code, client config, assets,
  logs, screenshots, or version control.
- **Never make cloud connectivity mandatory for cashier checkout.** A normal
  local cash sale must complete with no network. Owner-experience requirements
  must never make local checkout cloud-dependent.
- **One application.** Dokan Pro is one Flutter app with role-based, adaptive
  experiences (ADR-026). Do not split it into separate apps without a new
  approved ADR. Hiding a screen is not authorization.
- **Never store an unencrypted production POS database** or use the cashier PIN
  as (or as the sole source of) the database key (ADR-027).
- **Never hard-delete financial history.** Sales, sale items, payments, ledger
  entries, inventory movements, cash drawer events, and audit logs are corrected
  only through explicit events as defined in ADR-020 (VOID, REFUND, REVERSAL,
  ADJUSTMENT).
- **Never introduce floating-point financial calculations.** Money is signed
  64-bit integer paisa (ADR-008); authoritative quantities are integer subunits,
  1 unit = 1000 (ADR-015).
- **Never bypass tests to make a build pass.** Do not delete, skip, or weaken
  tests or assertions to get green. Fix the cause or report the blocker.
- **Never modify generated files manually** unless required and documented;
  regenerate them from their source instead.
- **Never push, deploy, publish, or run remote migrations unless explicitly
  instructed** for that specific action.

## 3. Working style

- **Prefer the smallest change that satisfies the active phase.**
- Do not add speculative abstractions, feature flags, or "future-proofing" code
  for features that belong to later phases.
- Keep local operational paths and cloud synchronization paths separate
  (see `docs/ARCHITECTURE.md`).
- Every sensitive action must be attributable to user, shop, device, local
  session, timestamp, and reason where appropriate.
- IDs are identity, not chronology (ADR-013); never trust only the device clock (ADR-023).

## 4. Documentation duties

- **Update `docs/PHASE_STATUS.md`** after approved implementation work
  (status transitions, checklist items).
- **Record significant architecture choices in `docs/DECISIONS.md`** (ADR format).
- **Record discovered traps/problems in `docs/GOTCHAS.md`** as soon as found.
- Keep documents consistent. If you change one document's rule, update every
  document that restates it — or reference the single source instead.

## 5. Conflict and uncertainty protocol

If documentation conflicts, or a requested change conflicts with documentation:

1. **Stop.** Do not pick an interpretation.
2. Report: the files and sections in conflict, the exact conflicting statements,
   and the options you see.
3. Wait for an explicit decision, then record it in `docs/DECISIONS.md`.

## 6. Phase status values

`LOCKED` · `IN_PROGRESS` · `READY_FOR_REVIEW` · `APPROVED` · `BLOCKED`

- A phase may only move to `IN_PROGRESS` after the previous phase is `APPROVED`
  and the user explicitly activates it.
- Agents may set `READY_FOR_REVIEW`. **Only the user sets `APPROVED`.**
- A phase that cannot proceed is set to `BLOCKED` with the reason recorded.

## 7. Definition of done (any phase)

- All acceptance criteria of the phase in `docs/PHASE_PLAN.md` are met.
- No out-of-scope work was added.
- Tests for the phase exist and pass without being weakened.
- `docs/PHASE_STATUS.md`, `docs/DECISIONS.md`, and `docs/GOTCHAS.md` are updated.
- No secrets in the diff. No push/deploy unless instructed.
