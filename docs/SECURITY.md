# SECURITY.md — Security Principles

Status: **Conceptual (Phase 0).** No security implementation exists. These
principles are binding for every future phase; RLS is required from the first
cloud phase (Phase 3), not deferred to Phase 17.

## 1. Tenant isolation

- Hierarchy: **Organization / Owner → Shop → Users (memberships) → Devices → Shop data.**
- **`shop_id` is the tenant boundary** for all shop-owned business data (ADR-011).
  Organization-level access is derived from shop ownership, never by skipping the shop check.
- A user from Shop A must **never** read or write Shop B data — regardless of
  what the client sends.
- The **global master catalog** is the only shared data set; it is read-only to shops.
- Every shop-scoped query path is indexed with `shop_id`.

## 2. Authentication boundaries

- Supabase Auth identifies people (owners, managers, cashiers).
- POS devices are **securely enrolled** to a shop by an authorized user while online.
- **Shared-tablet cashier login (ADR-021):** after enrollment, authorized cashier
  accounts may use a **local PIN** for offline shift/session authentication.
  - The device stores **only a salted PIN verifier** produced by an appropriate
    password/PIN hashing mechanism, in secure device storage where appropriate.
    **The plaintext PIN is never stored** (nor logged or synced). The hashing
    package is chosen in Phase 3.
  - Every locally generated financial event carries actor user ID, device ID,
    **local session ID**, and shop ID.
  - **Limitation (stated honestly):** for offline events the server knows only that
    the actor identity was **asserted by the enrolled device**. The cloud did
    **not** independently authenticate each offline cashier action. At sync the
    server can verify the device is enrolled and not revoked and that the asserted
    actor is an active member with the needed permission — nothing more.
  - Sensitive owner/manager actions may receive stricter requirements later.
- Session expiry must not interrupt an in-progress sale; re-auth happens at
  sync time, and failure to re-auth stops sync (not checkout) and is surfaced.
- **Device revocation (ADR-024):** once a device learns it is revoked, checkout is
  locked and its sync is handled as a security-sensitive case; its pending data is
  never silently discarded (review workflow: Q24). A fully offline device cannot
  learn of revocation — an offline stolen tablet may keep working until it
  reconnects. No lease/token-expiry mechanism now; evaluate in Phase 17.

## 3. Row Level Security requirements

- **RLS enabled on every table exposed through the Supabase API.** No exceptions
  for "internal" or "temporary" tables that are reachable via the API.
- Policies check **active membership** of `auth.uid()` in the row's `shop_id`
  and the role/permission needed for the operation.
- Append-only tables: no client UPDATE/DELETE policies at all.
- **Financial sync boundary (ADR-014):** financial mutations are never blindly
  inserted by the Flutter client; direct client INSERT/UPDATE/DELETE on financial
  tables is denied. They pass through a controlled server-side boundary
  (Supabase PostgreSQL RPC/function or an equivalent reviewed backend) that
  validates authenticated user, registered non-revoked device, shop membership,
  tenant ownership, mutation type, payload/schema version, idempotency key,
  duplicate detection, permissions, and business invariants. The boundary must
  never become an RLS bypass. Checkout never waits for it (validation happens at sync).
- Editable configuration updates are version-checked (ADR-022); stale edits to
  price, permissions, and sensitive commercial fields return a conflict — never
  silent last-write-wins.
- Global catalog: read for authenticated users; write only for admin roles
  (future admin platform), never for shop roles.
- RLS policies require **automated tests** proving cross-shop access is denied
  (read, insert, update, RPC) — part of the acceptance criteria of every phase
  that adds shop data.

## 4. Role concepts

Roles live on `shop_memberships`. Do not over-engineer RBAC; start with three
roles plus a small set of explicit permission flags for sensitive actions.

| Capability | OWNER | MANAGER | CASHIER |
|---|:-:|:-:|:-:|
| Checkout (sell), take cash/digital payment | ✅ | ✅ | ✅ |
| Record udhaar sale for existing customer | ✅ | ✅ | ✅ (configurable) |
| Create customer | ✅ | ✅ | configurable |
| View cost, profit, financial reports | ✅ | configurable | ❌ |
| Price override / discount at checkout | ✅ | ✅ (limits) | ❌ unless approved |
| Void sale | ✅ | ✅ | ❌ unless approved |
| Refund / return | ✅ | ✅ (limits) | ❌ unless approved |
| Stock adjustment / damage | ✅ | ✅ | ❌ |
| Receive purchases | ✅ | ✅ | ❌ (configurable) |
| Edit prices / products / add to shop | ✅ | ✅ | ❌ |
| Create custom product | ✅ | ✅ | configurable |
| Open/close shift, cash in/out | ✅ | ✅ | own shift |
| Manage staff & roles | ✅ | ❌ | ❌ |
| Register / revoke devices | ✅ | configurable | ❌ |
| Organization, billing, subscription | ✅ | ❌ | ❌ |

"Approved" = a manager/owner authorizes the specific action (e.g., PIN on the
device), and both requester and approver are recorded. Permission checks are
enforced **locally** (for UX and offline) **and** validated on the server at sync
(server records a violation flag if a device submits an action the actor was not
permitted to perform).

## 5. Service-role restrictions

- The Supabase **service-role key must never be in the Flutter app**, client config,
  build artifacts, assets, logs, crash reports, screenshots, or git.
- Service-role use is restricted to trusted server-side contexts (server functions,
  admin/back-office tooling, CI with secret storage), with minimal scope.
- The app uses only the anon/publishable key + user session; all authority
  comes from RLS and validated RPC.

## 6. Local device security considerations

- The tablet stores shop data (sales, customers' phone numbers, udhaar balances).
- Mitigations: OS-level device lock; app-level PIN per user with only a salted
  verifier stored (ADR-021); secure storage for tokens (platform keystore);
  auto-lock after inactivity.
- **Local DB encryption (ADR-027):** the POS SQLite database is encrypted from the
  first implementation (SQLCipher-compatible or reviewed equivalent, via Drift).
  The key is strong and random, protected by platform-backed secure storage
  (e.g., Android Keystore-backed); never hardcoded, committed, kept in plaintext
  preferences, equal to or derived solely from a cashier PIN. PIN and database key
  are separate: changing a PIN never re-encrypts the database. **No universal
  recovery key.**
- Encryption protects data **at rest**; it does not protect against an attacker
  controlling an already-unlocked or compromised device. Unsynced data on a lost
  device remains unrecoverable (ADR-025).
- Cashier UI must not expose cost/profit data; the local DB may still contain it
  — local role checks are UX, not a security boundary against a rooted device.
- Device revocation stops cloud access; it cannot erase an offline stolen device.

## 7. Audit logging

- Append-only `audit_logs` for sensitive actions: void, refund, price override,
  discount beyond threshold, stock adjustment/damage, cash in/out, shift close
  with difference, role/membership changes, device registration/revocation,
  product price change, custom product creation, sync rejections.
- Each entry: actor, approver (if any), shop, device, local timestamp, server
  timestamp, action, target, reason, before/after values where applicable.
- Clients can insert (via validated paths) but never update or delete audit entries.

## 8. Sensitive actions

Refund, void, price override, discount, major stock adjustment, cash out, role
change, device registration: must support **permission checks**, **reason
capture**, **optional approval**, and **audit**. Thresholds (e.g., "major"
adjustment) are shop-configurable later.

## 9. Secret management

- No secrets in the repository. Environment-specific config via untracked files
  or CI secret stores; example files contain placeholders only.
- Separate Supabase projects/environments for development and production
  (details in Phase 3).
- Rotate keys if exposure is suspected; document the procedure in Phase 17.

## 10. Storage access principles

- Master catalog thumbnails: non-sensitive; public or authenticated read,
  admin-only write.
- Shop files (custom product images, future receipts/exports): private,
  path-scoped by `shop_id`, access controlled by storage policies mirroring RLS.
- Upload size/type limits enforced; no user-uploaded executable content.

## 11. Owner / cashier permission separation

- One app serves all roles (ADR-026). **Role controls capability; device size
  controls layout.** Hiding a screen is not authorization; a modified client that
  changes UI state gains no permissions because RLS, server authorization, and
  the sync boundary enforce them.

- Cashiers: checkout-focused; no cost/profit visibility; no destructive actions
  without approval.
- Managers: operational control within explicit permissions.
- Owners: full control and financial visibility; the only role that manages staff and billing.
- **Security never relies only on Flutter UI permissions.** UI hides; server enforces.

## 12. Threat list

| Threat | Description | Primary mitigations |
|---|---|---|
| **Cross-shop access** | User reads/writes another shop's data | RLS on `shop_id` + membership; RPC checks; automated cross-tenant tests |
| **Modified client requests** | Tampered app/requests alter shop_id, amounts, roles | Server never trusts client-supplied tenant/role; RLS + RPC validation; server recomputes totals from lines |
| **Stolen tablet** | Device with local data and session taken | Device lock, app PIN (salted verifier only), token in secure storage, device revocation → checkout lock once learned (ADR-024), owner alert on unknown activity. **Limitation:** a fully offline stolen device cannot learn of revocation; its unsynced data is also at risk (ADR-025) |
| **Replayed mutation** | Captured request resent | Idempotency keys, (device_id, device_seq) uniqueness, auth token required, server-side sync boundary (ADR-014), revoked-device handling as security-sensitive (held, never silently applied or dropped) |
| **Duplicate transaction** | Retry creates second sale/payment | Client-generated IDs + server idempotency (OFFLINE_SYNC.md §4) |
| **Privilege escalation** | Cashier grants self MANAGER, edits membership, or unlocks owner screens in a modified app | Membership changes OWNER-only via RLS; audited; no client-writable role claims; UI role state is never trusted by the server (ADR-026) |
| **Service key leakage** | Service-role key shipped in app or repo | Never in client; secret scanning; rotation procedure |
| **Unauthorized refund** | Cashier refunds to pocket cash | Permission + approval + reason + audit; owner alerts on refunds/voids |
| **Unauthorized stock adjustment** | Stock written off to hide theft | Permission + reason + audit; movement ledger shows every change; alerts on large adjustments |
| **Unrecorded / deleted sales** | Sale removed to hide cash | No hard deletes; device_seq gap detection; void audit; shift cash reconciliation |
| **Clock manipulation** | Device time changed to shift sales between days | Original device time preserved plus server received time, device_seq ordering, server-offset tracking, skew flagging and alerts (ADR-023) |
| **Offline actor spoofing** | Cashier uses another's PIN | Individual PINs, local session IDs on every event, audit, shift attribution. **Residual risk accepted explicitly:** offline actor identity is device-asserted, not cloud-authenticated (ADR-021) |
