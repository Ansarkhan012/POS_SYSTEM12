# DESIGN.md — Interaction & Usability Principles

This document defines **interaction rules**, not visual branding. Colors, logos,
typography choices, illustrations, and decorative language are intentionally
**not decided** in Phase 0.

## 0. One app, adaptive experiences

- Dokan Pro is **one application** (ADR-026). The cashier, manager, and owner
  experiences are distinct UX surfaces inside it.
- **Role controls capability; device characteristics control presentation.**
  Never infer permissions from screen size; never infer layout solely from role.
- A shop tablet is usually used by cashiers, but an owner may sign in on it; an
  owner usually uses a phone. Each gets the layout that fits the device and the
  capabilities that fit their role.
- Hiding a screen is **not** authorization — the server enforces permissions.
- Owner features must never clutter, slow, or complicate the cashier checkout path.

## 1. Tablet-first cashier experience

- The cashier experience is designed for an **Android tablet**, landscape orientation
  as the primary layout (portrait support is open question Q11b, decide by Phase 7).
- **Checkout is the home screen.** No dashboards, feeds, or menus in front of it.
- **Minimal navigation:** everything a cashier does routinely is reachable within
  one tap from checkout. Secondary functions (customers, stock lookup, shift) sit
  behind a single, clearly labeled entry point.
- **Minimal typing:** favorites/quick items, recent items, search-as-you-type on
  local data, quantity steppers, numeric keypad for amounts. Barcode scanning later.
- **Speed over decoration:** no animation that delays input or result. Transitions,
  if any, must never block the next tap. Target: a common 3-item cash sale in
  seconds, with no waiting on network.
- The cart and total are **always visible** during checkout.
- **No cost or profit data** is shown to cashiers.

## 2. Owner mobile experience

- Mobile-first, portrait, single-hand use; an **expanded adaptive layout** on
  tablets (not a second app, and not the cashier POS layout).
- Lead with **clear financial numbers**: sales, gross profit, cash expected,
  udhaar outstanding — for today, with easy period switching.
- **Simple summaries first, detail on demand** (drill-down to sales, items, cashier activity).
- **Actionable alerts:** each alert says what happened, where, when, who, and what
  the owner can do next.
- Always show **data freshness** ("Shop last synced 12 min ago"), because owner
  data depends on the shop's sync.

## 3. Localization principles

- English and Urdu must be supported **without rebuilding screens**:
  - No hard-coded user-facing strings in widgets; all strings externalized from Phase 1.
  - Layouts must tolerate **RTL mirroring** (Urdu) and variable text length.
  - Directional icons (back/forward) follow text direction; numeric keypads do not mirror.
- Product names may exist in English, Urdu, and Roman Urdu; search aliases cover
  common spellings (see PRODUCT_CATALOG.md).
- Money formatting: currency "Rs" / "روپے", no floating point, grouping per
  locale. Numeral style in Urdu UI (Western vs Eastern Arabic-Indic digits) is open question
  **Q11a** (decide by Phase 14).
- Dates/times shown in shop local time (Asia/Karachi).
- Use simple words; avoid accounting jargon in cashier UI.

## 4. Touch-target principles

- Minimum touch target **48×48 dp** everywhere.
- Primary checkout actions (Pay / Complete Sale, quantity +/−, product tiles)
  should be **substantially larger** (guideline ≥ 64 dp height) and well separated.
- Destructive or irreversible controls must never sit adjacent to the primary
  "complete" action.
- Design for use while standing, in a hurry, possibly with wet or dirty hands.

## 5. Checkout simplicity

- One primary flow: **add items → review total → take payment → done.**
- The default payment is cash; other tenders (digital, udhaar, split) are one tap away.
- **Loose/weighed goods** (rice, sugar, flour, pulses, spices) are first-class:
  the cashier enters weight/quantity manually (e.g., 0.750 kg) with a numeric
  keypad; whole-piece products only accept whole quantities. No scale hardware
  initially (ADR-018).
- Change due is computed and shown prominently.
- After completion, the screen resets to an empty cart immediately; the last sale
  remains accessible (reprint, view).
- Price override, discount, void, and refund are **permission-gated** and require a reason.

## 6. Offline states

- **Offline is a normal state, not an error.** Never block checkout, never show
  a modal because the network is unavailable.
- A small, persistent, non-intrusive sync indicator shows: *online & synced*,
  *offline — N changes waiting*, *syncing*, *sync problem — needs attention*.
- The POS always exposes the **pending sync count** and **last successful sync**
  time, and warns when unsynced data has been waiting unusually long (ADR-025).
- **Never display "synced"/"backed up" before server acknowledgement.**
- A **clock problem** (large device clock skew) is shown as a warning to
  manager/owner; it does not block checkout (ADR-023).
- **Revoked device:** once the device learns it has been revoked, checkout is
  locked with a clear explanation and no data is discarded (ADR-024). This is the
  only designed checkout lock; offline status never locks checkout.
- Features that genuinely require the cloud (e.g., first-time login, device
  registration, downloading images not yet cached) explain that clearly and
  degrade gracefully.

## 7. Loading / error / sync-state philosophy

- Local operations should feel instant; show a progress state only if an
  operation can take noticeable time.
- Errors must say **what happened and what to do**, in plain language, localized.
- Never silently swallow errors. Sync failures that need human attention are
  surfaced to owner/manager (and support later), not hidden.
- Never show raw stack traces or technical codes as the primary message
  (a secondary diagnostic code is acceptable).
- Owner experience: stale data is clearly labeled as stale, never presented as
  live; remote data unavailable offline says so plainly.

## 8. Destructive-action confirmation principles

- Financial records are never deleted; "destructive" actions are **VOID, REFUND,
  ADJUSTMENT, deactivate**. Each:
  - requires the appropriate permission (and may require manager/owner PIN approval),
  - requires a **reason** (selectable common reasons + optional note),
  - shows a clear confirmation summarizing the effect (amount, items, stock impact),
  - is recorded in the audit log.
- **Cart cancel** (clearing an uncompleted cart) is not a financial action but
  should still be confirmable/undoable to prevent accidental loss.
- **Void** (ADR-020) is full-sale only and requires manager/owner permission and
  a reason. **Refund** creates a new linked record (full, later partial). The UI
  must never present these as "delete".
- Confirmation dialogs must not be used for routine, reversible actions (avoid
  confirmation fatigue).

## 9. Accessibility

- Sufficient contrast for bright shop lighting and low-cost screens.
- **Never communicate state by color alone** (use icon + text).
- Support system font scaling without breaking checkout layout.
- Large, legible numerals for totals and change due.
- Screen-reader labels for interactive elements (baseline, not a primary use case).

## 10. Visual hierarchy

- Cashier: **Total and primary action dominate**; cart second; product search/grid third.
- Owner: **headline numbers** first, trends second, lists/detail third.
- Warnings (low stock, sync problem, cash difference) are visually distinct from
  normal information, and prioritized by severity.
- Consistency: the same concept uses the same label, icon, and position everywhere.
