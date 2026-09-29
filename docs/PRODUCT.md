# PRODUCT.md — Dokan Pro Product Definition

## 1. Purpose

Dokan Pro helps small grocery / kiryana / general store owners in Pakistan
**sell fast, keep accurate records, and see their shop remotely** — even when
the internet is unreliable and the owner is not in the shop.

## 2. Initial customer

| Attribute        | Profile                                                      |
|------------------|--------------------------------------------------------------|
| Business type    | Small grocery / kiryana / general store                      |
| Location         | Karachi first                                                |
| Counters         | 1–2                                                          |
| Products         | ~500–5,000 SKUs                                              |
| Staff            | 1–5 employees                                                |
| Owner presence   | Often **not** physically present                             |
| Payments         | Cash, udhaar (customer credit), recorded digital payments    |
| POS hardware     | Android tablet (primary)                                     |
| Language         | Urdu or simple English                                       |
| Connectivity     | Unreliable internet; power/network interruptions are normal  |

## 3. Primary problems

1. **Slow or error-prone billing** with paper, memory, or calculators.
2. **No reliable stock visibility** — owners don't know what is low, lost, or damaged.
3. **Udhaar tracking** in notebooks is lost, disputed, or forgotten.
4. **Absent owners cannot see** sales, cash, and cashier behavior remotely.
5. **Cash leakage** — unrecorded sales, unexplained voids/refunds, drawer shortfalls.
6. **Unknown true profit** — cost of goods is not tracked against sales.
7. **Internet dependence** of existing cloud tools makes them unusable at the counter.

Dokan Pro is **one application** (one Play Store listing). The cashier, owner,
and manager experiences below are role-based surfaces of that one app, with
layouts adapted to phone or tablet (ADR-026).

## 4. Cashier experience (target)

- Open app → already on the checkout screen.
- Find a product by typing a few letters, tapping a recent/favorite item, or (later) scanning.
- Adjust quantity with minimal taps; for loose goods (rice, sugar, flour, pulses,
  spices) enter the weight manually (e.g., 0.750 kg); see running total clearly.
- Take cash (with change calculation), record digital payment, or mark udhaar.
- Sale completes **instantly, offline or online**. Receipt printing later.
- Restricted: cannot see profit/cost, cannot void/refund/override price without permission.

## 5. Owner experience (target)

- On their phone (or an expanded tablet layout), anywhere: today's sales, gross profit, cash expected in drawer,
  udhaar outstanding, low stock, and cashier activity (voids, refunds, discounts).
- Actionable alerts (e.g., unusual void, low stock, shift cash difference).
- Manage prices, products, and staff permissions.
- Remote owner information requires connectivity when it is not on that device;
  full offline remote analytics are not promised.
- Data is as fresh as the shop's last successful sync; freshness is always shown.
  Transactions made on a device that is destroyed before syncing cannot reach
  the cloud (accepted offline-first limitation, ADR-025).

## 6. Initial supported business type

**Only** small grocery / kiryana / general stores. All MVP decisions optimize for this.

## 7. MVP boundaries

The MVP (through Phase 19 pilot) includes, in phased order (see `PHASE_PLAN.md`):

- Cashier checkout (offline-first) on Android tablet, including **loose/fractional
  goods sold by weight** with manual quantity entry (required from the start)
- Master product catalog (~1,000 common Pakistani FMCG products) + shop products + custom products
- Movement-based inventory (opening, purchase, sale, return, damage, adjustment)
  with moving weighted average cost and per-sale cost snapshots
- Payments: cash, recorded digital payments, udhaar (customer ledger)
- Purchases and suppliers (with supplier ledger)
- Shifts and cash drawer reconciliation
- Expenses (for estimated net profit)
- Owner experience (phone-first, adaptive on tablet) with analytics and alerts
- English and Urdu
- Thermal receipt printing and barcode scanning (hardware phase)
- Roles: OWNER, MANAGER, CASHIER

## 8. Non-goals (explicitly out of scope for MVP)

- Pharmacies, restaurants, clothing, electronics, or other verticals
- Wholesale/distribution ERP, multi-warehouse logistics
- Full accounting suite (general ledger, tax filing, balance sheets)
- Payroll / HR
- E-commerce, online ordering, delivery
- Loyalty programs, coupons, marketing campaigns
- Processing digital payments (we **record** JazzCash/Easypaisa/bank transfers; we do not integrate payment gateways)
- FBR/tax-authority integration (not required for initial customer; revisit only if needed)
- AI / fuzzy / semantic search
- Weighing-scale hardware integration (initially; weights are entered manually)
- iOS, desktop, or web builds (Android-first; no iOS/desktop/web POS in MVP)
- LAN peer-to-peer sync between counters
- Admin platform (future phase, not MVP)

## 9. Long-term direction (NOT current requirements)

These are ideas only. They must not influence current implementation without
explicit approval and a new phase:

- Admin platform for catalog curation, shop management, subscriptions, support diagnostics
- Expansion beyond Karachi
- Supplier ordering / distributor integration
- Tax authority integration if regulations require
- Other retail verticals
- Customer-facing udhaar statements (SMS/WhatsApp)
