# DHAV — Customer App Redesign + Multi-Marketplace Plan

> **Source of truth for the UI = `customer_app_design_ss/` (16 screenshots).** Match layout,
> spacing, card style, sections and flows exactly; keep **DHAV branding** and the 4 marketplace
> theme colors (do NOT copy "Zepto / Super Mall / cafe / district" brand names or logos).
> Decision (Harshad, 2026-06-21): **full plan first, then build**; **match layout/structure,
> DHAV branding** (not pixel-for-pixel brand copy).

---

## 0. State of the world (verified 2026-06-21)

| Layer | Status | Notes |
|---|---|---|
| DB schema (marketplace) | ✅ DONE | `004_marketplace_taxonomy.sql`: `marketplace_type` on items/stores/orders; `categories`+`subcategories`; product fields `brand/sku/description/mrp/discount_percent/stock_quantity/images[]/specs{}`. `000_full_schema.sql` folds it all. |
| Seed data | ✅ DONE | `005_*`: 69 categories, 157 subcategories, ~1000 products (3–5 images), 8 stores, demo customers. Regenerate via `scripts/build_seed.py`. **Must be run in Supabase.** |
| Backend catalog API | ✅ DONE | `/catalog/categories`, `/subcategories`, `/items`, `/items/nearby`, `/stores/nearby[/all]` all accept `marketplace_type`; nearby filters stores by `store_type`. |
| Customer `CatalogProvider` | ✅ DONE | `_marketplace`, `setMarketplace()` reloads, `loadSubcategories(categoryId)`, all calls scoped to marketplace. |
| Customer `MarketplaceProvider` + theming | ✅ DONE | 4 themes in `marketplace_theme.dart`; `main.dart` rebuilds `MaterialApp` via `AppTheme.forMarketplace(mp.theme)`. Engine ready. |
| **Customer UI screens** | ❌ **NOT MATCHING** | Home/category/detail/filter/cart/checkout/orders all need rebuild to the screenshots. **This is the bulk of the work.** |
| Store app store_type isolation | ⚠️ PARTIAL | Schema has `store_type`; need registration field + inventory scoped to store's marketplace. |
| Admin category/subcategory/product CRUD UI | ❌ TODO | Backend tables exist; admin screens to manage them are not built. |
| Order routing by marketplace | ⚠️ VERIFY | `orders.marketplace_type` column exists; confirm broadcast routes only to matching `store_type`. |

**Conclusion:** ~80% of backend/data is done. The work is overwhelmingly **customer-app UI**, then
**store/admin UI**, then **verification of order routing**.

---

## 1. The marketplace tab switcher (Harshad's explicit ask)

Reference: `home_page_tab_here_you_can_see...primay-color-will-change-enterily-of-app.jpeg`.

- A row of **card-style tabs** under the location header: **DHAV · Fresh Fruits · Electronics · Pharmacy**.
- The **active tab is a raised white card that connects into the header** below it (notch/merge look);
  inactive tabs are flat translucent cards on the themed header.
- Tapping a tab calls `MarketplaceProvider.setActive(m)` **and** `CatalogProvider.setMarketplace(m.wire)`
  → the whole app re-skins (header gradient, search bar accents, ADD pills, price color, bottom nav,
  chips) to that marketplace's theme, and the catalog reloads for that `marketplace_type`.
- Theme colors (already defined): DHAV = blue `#1E88E5`, Fruits = green `#2E7D32`,
  Electronics = indigo `#1A237E`, Pharmacy = teal `#00897B`.

This replaces the current "⚡ DHAV / 🏪 Stores" two-tab control. (Stores becomes a section within a
tab / a secondary view, not a top-level tab — matches the screenshots which have no "Stores" top tab.)

---

## 2. Screen-by-screen plan (mapped to each screenshot)

### 2.1 Home — `features/home/home_screen.dart` (rebuild)
Screenshots: `home_page_tab_we_want_similary...`, `...primay-color-will-change...`, `home_page_catlgory...`
- Themed gradient header: **ETA line** ("16 minutes" style → reuse our ETA), location row with wallet +
  profile icons, the **card tab switcher** (§1), floating white **search bar** + a promo chip on the right.
- Horizontal scrollable **category strip** with emoji/image circles (DB categories for the active marketplace).
- **Category sections** like `home_page_catlgory`: "Grocery & Kitchen", "Snacks & Drinks", etc. — section
  title + 4-per-row image tiles (category image + name), DB-driven from `categories`/`subcategories`.
- Keep existing: Welcome sheet auto-popup, Zatpat AI chip, Deal of Day, banners, track-order banner,
  ComingSoon (no-store) scene, location prompt. Re-skin them to the active theme.
- Bottom nav (reference electronics screenshot): **Home · Order Again · Categories · (Print→remove) · Profile**
  — adapt to DHAV's real tabs (Home / Search / Orders / Profile already exist in `MainShell`).

### 2.2 Category listing — NEW `features/catalog/category_listing_screen.dart`
Screenshots: `see-in-this-design-when-wlick-on-any-catlgory...left-corne`, `frutite-tab-details-catagory-page`, `home_page_catlgory` (Atta/Bakery)
- **Left vertical rail** of subcategory circles (image + label), active item highlighted with a green/theme
  accent bar; tapping scrolls/filters the right grid. Data = `subcategories` for the tapped category.
- Top app bar: category name + "Delivering to <address>" + search + share icons.
- **Filter row**: `Filters ⌄ · Sort ⌄ · Quantity/Type/Brand ⌄ · Price ⌄` chips (horizontally scrollable).
- **2-column product grid** = `ProductCard` reused/upgraded: image, weight/unit pill bottom-left, **ADD
  button** (with "N options" when variants), price + struck MRP + "X% OFF", rating, ETA, "N left".
- Fruits variant shows a banner header inside the list ("Fresh seasonal fruits"); "See all products" button.

### 2.3 Brand / electronics extras
Screenshots: `electronic-now-here...brand-details`, `see-how-good-itis-hsoing-on-left-some-brand`
- Electronics tab home + category: **"Best brands"** grid (brand logo tiles) sourced from distinct
  `brand` values for the marketplace/category.
- Brand can act as a filter (tap brand → grid filtered by `brand`).

### 2.4 Product detail — `features/catalog/item_detail_screen.dart` (rebuild)
Screenshots: `see-how-details-page`, `MOST_IMP...similar-product`, `see-how-good-prouct-details` (View details sheet), `when-we-click-on-view-details...for-food...how-is-selling`
- **Image carousel** (from `images[]`) with heart/search/share; veg/nonveg dot.
- **Highlight chips row** (3 key `specs`, e.g. Shelf Life / Atta Type / Milling Process) + a **"View details"**
  button → opens a **bottom sheet**: "Highlights" + collapsible **Key Information / Nutritional Information /
  Info** sections rendered from `specs{}` + `description` + seller/country/return-policy fields.
- Title, rating + count, ETA.
- **"Select Unit"** variant chips (price + MRP + % OFF + per-kg) — needs a product-variant concept
  (see §4 Open decisions).
- **Brand row** ("<Brand> — Explore all products" →) + **replacement-policy** row.
- **"Similar products"** carousel + **"Top products in this category"** carousel (same marketplace/category).
- Sticky bottom bar: selected unit + price + MRP + **"Add to cart"** (themed).

### 2.5 Filters sheet — NEW `features/catalog/filter_sheet.dart`
Screenshot: `filter-section...`
- Bottom sheet, **left rail of filter groups** (Brand / Price / Diet Preference / Country Of Origin /
  Type / Taste Profile), right = searchable checkbox list (brand logo + name + count).
- Footer: **Clear Filter** + **Apply**. Apply filters the category grid client-side from loaded items.

### 2.6 Cart / Checkout — `features/cart/cart_screen.dart` (rebuild)
Screenshots: `checiout-card...you-might-also-like`, `checkout-cost-breakdonw...bill-details`
- Header "Checkout"; **"Free delivery in 9 minutes"** card + "Shipment of N items".
- Item rows: image, name, unit, "Move to wishlist", **qty stepper** (themed), line price (+ struck MRP).
- **"You might also like"** horizontal carousel (suggested items, same marketplace).
- **Bill details** card: Items total (+ "Saved ₹X"), Delivery charge (FREE), Handling charge, **Grand total**;
  **"Your total savings"** strip.
- Optional (match-but-de-scope): Add GSTIN, Delivery instructions chips, donation strip — build static/visual
  to match; wire later. "Select payment option" CTA → existing place-order flow.

### 2.7 Order history — `features/orders/order_history_screen.dart` (rebuild)
Screenshot: `order-hisoty-page`
- Search bar; per-order cards: green ✓ + "Arrived in N minutes", "₹total · date", **item image row**,
  **Reorder** / **Rate order** actions; "Order placed by <name>" sub-banner when applicable.

### 2.8 Order detail — `features/orders/order_detail_screen.dart` (rebuild)
Screenshot: `order-details-page`
- "Order summary", "Arrived at <time>", **Download Invoice**; "N items in this order" with image + qty + price;
  **"How were your ordered items? → Rate now"**; **Bill details** (MRP, Product discount, Item total, Handling,
  Delivery, Bill total); Order id with copy; **Repeat Order** CTA.

### 2.9 Theming pass (cross-cutting)
- Replace hard-coded `AppColors.primary`/gradients in customer screens with `context.mp*` accessors so every
  screen re-skins per marketplace. Audit: home, search, cart, item detail, store detail, orders, bottom nav,
  badges, qty stepper, product card.

---

## 3. Build order (phased — each phase is shippable + verifiable)

1. **Phase 1 — Home + tab switcher** (§1, §2.1). Wire tabs → `MarketplaceProvider` + `CatalogProvider`.
   Verify: switching tabs re-themes the whole app and reloads catalog. ← *first deliverable to show Harshad.*
2. **Phase 2 — Category listing + filters** (§2.2, §2.5, §2.3 brands).
3. **Phase 3 — Product detail** (§2.4) incl. View-details sheet + similar/top products.
4. **Phase 4 — Cart/Checkout** (§2.6) incl. bill breakdown + you-might-also-like.
5. **Phase 5 — Orders (history + detail)** (§2.7, §2.8).
6. **Phase 6 — Full theming audit** (§2.9) + empty/loading states per theme.
7. **Phase 7 — Store app** store_type isolation (§4).
8. **Phase 8 — Admin** category/subcategory/product CRUD UI (§4).
9. **Phase 9 — Order routing verification** + end-to-end test per marketplace.

---

## 4. Cross-app sync (per CLAUDE.md rule) — REQUIRED / OPTIONAL / SKIP

- **Backend** — mostly REQUIRED-DONE. Remaining: confirm order broadcast routes only to stores whose
  `store_type == order.marketplace_type` (`services/broadcasting.py` + `geofencing.py`); add admin CRUD
  endpoints for categories/subcategories/products if missing; update `API_REFERENCE.md`.
- **Store app** — REQUIRED: `store_type` selector on registration (mandatory); inventory/catalog scoped to the
  store's own marketplace only (no cross-type categories/products). Incoming orders already type-routed by backend.
- **Admin dashboard** — REQUIRED: Category/Subcategory/Product management (create/edit/delete/enable/disable/
  reorder/image upload/assign marketplace), replacing hardcoded categories. Needs Supabase `dhav-images` bucket.
- **Customer app** — the originating surface (this whole plan).

### Decisions (LOCKED — Harshad, 2026-06-21)
1. **Product variants → SEPARATE ITEMS grouped by family.** Each unit (10kg/5kg/1kg) is its own
   `catalog_item` row linked by a `group_id` (SKU family). Detail "Select Unit" chips list all items sharing the
   `group_id`; each carries its own price/mrp/stock. **Backend:** add `group_id TEXT` to `catalog_items`
   (migration), `/catalog/items/group/{group_id}` (or include siblings in detail payload), update seed builder
   to emit families. **Affects §2.4 detail + cart + store inventory.**
2. **Real ratings system.** Aggregate per-product (and per-store) ratings from the existing order rate flow.
   **Backend:** ratings table or `rating_sum`/`rating_count` on `catalog_items`; the customer rate-order sheet
   writes per-item ratings; nearby/detail payloads return `rating` + `rating_count`. "N left" from
   `stock_quantity`, ETA from distance (existing).
3. **Fully implement checkout extras.** Wishlist (persisted per-user, backend endpoints + a Wishlist view),
   Add GSTIN (stored on order), donation (added to order total + recorded), delivery instructions (stored on
   order, shown to store/delivery). Each needs backend fields/endpoints + store/admin visibility where relevant.
4. **Bottom nav = DHAV tabs restyled** (Home / Search / Orders / Profile), per-marketplace themed. No
   "Print/district".

---

*Created 2026-06-21. On approval, start Phase 1. Log progress in SESSION_NOTES.md + ENHANCEMENTS.md.*
