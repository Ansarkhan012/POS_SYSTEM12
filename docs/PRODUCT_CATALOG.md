# PRODUCT_CATALOG.md — Authoritative Catalog Behavior

This document is **authoritative** for catalog behavior. If another document
disagrees on catalog matters, this one wins until the conflict is reported and resolved.

## 1. Two layers

| Layer | What it is | Who manages it | Scope |
|---|---|---|---|
| **Master product** | Reusable product *identity* | Dokan Pro (admin) | Global, all shops |
| **Shop product** | A shop's *commercial configuration* for something it sells | The shop (owner/manager) | One shop |

### 1.1 Master product contains (identity only)
- standardized product name (English; Urdu name where available)
- brand
- category
- variant / size (e.g., 1.5 L, 500 g)
- unit type (piece, pack, kg, litre, …) and a default indication of whether fractional quantity is normal (e.g., loose sugar by kg)
- manufacturer barcode(s) when known (`master_product_barcodes`)
- compressed image reference (thumbnail)
- search aliases (`product_aliases`)
- active status
- version / update metadata

### 1.2 Master product MUST NOT contain
- sale price · purchase price / cost · current stock or any inventory data ·
  shop SKU · shop low-stock threshold · any other shop-specific value

**Inventory never belongs to the global product** (ADR-006).

### 1.3 Shop product contains
- reference to a master product (optional)
- shop-specific sale price and purchase price settings (integer paisa)
- enabled/disabled status
- barcode override / shop-specific barcodes (`shop_product_barcodes`)
- shop SKU (optional), low-stock threshold, name override, other shop-specific configuration
- effective **selling unit** and **fractional-allowed** flag (ADR-015/ADR-018; override rules vs master defaults: Q14)
- a **version** for optimistic concurrency on edits (ADR-022)
- for **custom** products only: the identity fields themselves (name, brand, size, unit, category, optional image)

Example:

```
master: Pepsi 1.5L (brand Pepsi, category Soft Drinks, barcode 8961…)
  ├─ Shop A product → sale Rs 200, purchase price setting Rs 175, threshold 12, enabled
  └─ Shop B product → sale Rs 210, purchase price setting Rs 178, threshold 6, enabled
  (Each shop's authoritative cost for profit is its own moving weighted average
   cost in shop inventory state — ADR-019 — never a master catalog field.)
```

A shop product that references a master product **does not copy** master
identity fields; it reads them through the reference. (Optional local display
denormalization for speed is allowed in the local DB as a cache, never as a
second source of truth.)

## 2. Initial catalog goal

- Target: **~1,000 common Pakistani grocery / FMCG products** at launch
  (beverages, dairy, edible oil/ghee, flour/rice/pulses, spices, tea, biscuits/snacks,
  soap/detergent, personal care, baby care, household basics).
- Quality bar per entry: correct name/brand/size, category, unit type, at least one
  alias, barcode where verifiable, thumbnail where available.
- Loose commodities (e.g., sugar, daal, rice sold by weight) may exist as generic
  master products (e.g., "Sugar (loose)") with unit type kg.
- Data sourcing and curation workflow (who compiles, how barcodes are verified) is
  open question Q15 (decide by Phase 4).

## 3. Images

- Master images are **optimized lightweight thumbnails** (ADR-017):
  - format **WebP**;
  - **maximum longest edge 512 px** initially;
  - **target ≤ 60 KB** where practical; **hard ceiling ≈ 100 KB** except
    explicitly reviewed exceptions;
  - usable visual clarity preserved;
  - no multi-megabyte originals are ever delivered to POS clients (originals, if
    kept, stay in admin-only storage).
  - Exact encoder/package is decided in Phase 4.
- **Metadata and images are separate.** Catalog sync delivers metadata only;
  metadata contains an image reference (content-hashed path/URL).
- Images are stored in Supabase Storage. Master thumbnails are non-sensitive
  (public-read or authenticated-read — Q13, decide by Phase 4). Custom product images
  are shop-private.
- Content-addressed/versioned image references: when an image changes, its
  reference changes, so caches invalidate naturally.

### 3.1 Lazy loading & local cache
- The app **must not download every image on every startup**, nor the full
  image library at install.
- Images download **on demand** (when a product first appears on screen) and
  optionally via a background prefetch limited to the shop's own products,
  on Wi-Fi/unmetered connections.
- Downloaded images are cached locally with a size cap and eviction policy
  (e.g., LRU); the POS works fully without any images (text-only tiles).

## 4. Local catalog cache

- The POS keeps a **locally searchable cache** of catalog metadata:
  - all of the shop's own products (always, complete), and
  - a cached subset of master products for search and "Add to Shop".
- At ~1,000 master products, full metadata (no images) is small enough to cache
  entirely; if the master catalog grows much larger, the cached subset may be
  limited (e.g., by category/region/popularity). Subset policy is decided in Phase 4.
- The cashier **never** calls the cloud on each typed character.

## 5. Catalog version / update strategy

- Every master catalog change (insert, update, deactivate, alias/barcode change)
  increments a **catalog version** (monotonic, server-assigned).
- Devices store the last applied version and request **deltas since that version**.
- Deactivated master products/barcodes are delivered as **tombstones**
  (status change), never silently removed — shop products may still reference them.
- A master change never changes shop prices, cost, stock, or historical sales.
- If a device is too far behind (e.g., delta window expired), it performs a full
  metadata refresh (still no image bulk download).

## 6. Search

- Local search over: product name (English/Urdu), brand, size/variant, barcode, aliases
  (including Roman Urdu spellings, e.g., "cheeni" → sugar).
- Normalization: case-folding, whitespace/punctuation normalization, size unit
  normalization (e.g., "1.5ltr" / "1.5 L" / "1500ml").
- Ranking favors the shop's own active products, then frequently sold items, then master cache.
- **No fuzzy/AI search** in current scope. Local full-text indexing approach is
  decided in Phase 2/4 (SQLite FTS is a candidate).

## 7. Barcode architecture

Two barcode kinds:

| Kind | Table | Scope | Example |
|---|---|---|---|
| Manufacturer (global) | `master_product_barcodes` | Global | EAN-13 printed by the manufacturer |
| Shop-specific | `shop_product_barcodes` | One shop | In-store label, custom product, or override of a wrong/missing manufacturer barcode |

### 7.1 Lookup order (future behavior)

1. **Shop barcode:** match in `shop_product_barcodes` (shop overrides/custom) → sell that shop product.
2. **Master barcode for a product the shop already sells:** match in cached
   `master_product_barcodes` whose master product is referenced by an active shop product → sell it.
3. **Master barcode, product not in shop:** offer **"Add to Shop"** (enter sale
   price; permission-gated) → creates a shop product referencing the master product.
4. **Unknown barcode:** offer to create a **custom product** with this barcode (permission-gated) or search manually.

Barcode scanning itself is implemented in Phase 15; lookup logic may be built earlier with manual entry.

## 8. Custom products

- If a product is not in the master catalog, a shop may create a **custom product**.
- A custom product:
  - works **immediately locally** (sellable offline right after creation),
  - synchronizes to **that shop's** cloud data,
  - is **private to that shop** by default — invisible to other shops.
- **A user-created custom product must NEVER automatically become a global master product.**
- Before creating, the app should check the local master cache (barcode, normalized
  name+brand+size) and suggest the existing master product to avoid duplicates.

## 9. Admin promotion workflow (future — admin platform)

1. Admin tooling identifies candidate custom products (e.g., same barcode or
   normalized name across many shops). Candidate discovery must respect privacy
   rules defined at that time.
2. An admin reviews, cleans identity data, verifies barcode, adds image/aliases.
3. A **new master product** is created (never by mutating a shop's record into a master).
4. Optionally, shops may be **offered** to link their custom product to the new
   master product; linking must preserve the shop product's ID, prices, stock
   history, and sales history. No automatic re-linking without the shop's consent
   (policy to be confirmed in the admin phase).

## 10. Duplicate prevention principles

- One active master product per real-world product identity
  (normalized brand + name + variant/size + unit).
- One active master product per active manufacturer barcode.
- One active shop product per (shop, master product) — unless variant/pack
  handling requires otherwise (Q14: e.g., selling a carton vs a single piece).
- One active shop product per active shop barcode within a shop.
- Creation flows search before creating (master cache for shops; full catalog for admins).
- Duplicates are resolved by **deactivation + linking**, never by deleting records referenced by history.
