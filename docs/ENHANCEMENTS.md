# 🚀 DHAV — Enhancement Tracker (the post-phases era)

> **This file replaces phase tracking.** All build phases (0–8) in `BUILD_PLAN.md` are
> **code-complete** — the project is now in **Enhancement Mode**: improving UI/UX, adding
> features, changing earlier decisions, and filling gaps missed during the phases.
>
> **Rule:** at the end of every session, log what changed here (newest first) and keep the
> "Current Architecture" section truthful. Detailed dev-journal entries still go in
> `SESSION_NOTES.md`; this file is the *summary + truth* so nobody re-reads stale docs.

---

## 🏗️ CURRENT ARCHITECTURE — single source of truth (2026-06-13)

> ⚠️ `docs/ARCHITECTURE.md` and `backend/ARCHITECTURE.md` describe the OLD
> Firebase-RTDB-on-Railway design. **This section is the current truth.**

| Layer | Technology | Notes |
|---|---|---|
| Backend | FastAPI (Python) on **Render** free tier | `https://dhav-backend.onrender.com` — sleeps after 15 min idle (~1 min cold start); use a cron-job.org `/health` pinger for demos. Deploy = `git push origin main` (auto). |
| Database | **Supabase PostgreSQL** via asyncpg (`backend/services/db.py`) | ALL app data. Transaction pooler :6543 for queries, session pooler :5432 for migrations. Schema: `backend/migrations/*.sql`. Firebase RTDB **removed**. |
| File storage | **Supabase Storage** | Firebase Storage removed. |
| Auth | Firebase Auth (Google + Email/Password) | Unchanged — backend verifies ID tokens. |
| Push | Firebase FCM | Unchanged — HIGH-priority order alerts, push-driven customer UI. |
| Dynamic UI | **Firebase Remote Config** (customer app, added 2026-06-13) | Home header colours/greeting/search/banners/deal — editable from the **admin dashboard "Home UI"** screen (backend `/admin/home-config` → RC REST API) OR the Firebase console; in-app defaults as fallback. The **Deal of the Day** now carries a real admin-set discount: `home_deal_item_id` + `home_deal_discount_percent` + `home_deal_ends_at` (added 2026-06-14, #3). |
| Realtime tracking | WebSocket `/ws/order/{id}/location`, in-memory + optional Redis Pub/Sub | Redis OFF (no `REDIS_URL`) → **run 1 worker only**. |
| Scheduler | APScheduler in-process | Settlements, suspensions, auto-fail crons. Pauses while Render sleeps. |
| Customer app | Flutter (`com.dhav.customer`) | Points to Render URL ✅ |
| Store app | Flutter (`com.dhav.store`, store owner + delivery roles) | Points to Render URL ✅ |
| Admin dashboard | Flutter Web on Firebase Hosting | LIVE: `https://dhav-quick-commerce.web.app`, points to Render URL ✅ |

> 🎨 **Brand primary colour = blue `#1E88E5`** (customer app `core/theme/app_colors.dart`).
> This is the source of truth. Some older session notes describe a "teal/saffron" brand —
> those are **stale**; the brand colour is blue and the 2026-06-19 UI redesign keeps it.

---

## ✅ ENHANCEMENT LOG (newest first)

### 2026-06-21 — Customer app rebuilt to `customer_app_design_ss/` + multi-marketplace UI
- **Context:** Harshad's design screenshots (`customer_app_design_ss/`, 16 files — filenames carry the
  requirements) are the source of truth. The 2026-06-19 "Blinkit-blue" redesign did NOT match them,
  and the prior marketplace conversion had finished the **backend/data** (migrations 004/005, marketplace-
  scoped catalog API, `MarketplaceProvider`/`MarketplaceTheme`, `AppTheme.forMarketplace` wired in
  `main.dart`) but **never rebuilt the UI**. Plan: `docs/CUSTOMER_APP_REDESIGN_PLAN.md`.
- **Decisions (locked):** variants = separate items grouped by `group_id`; real ratings; fully-implemented
  checkout extras (wishlist/GSTIN/donation/delivery-instructions); bottom nav stays DHAV's 4 tabs restyled.
- **Phase 1 — Home + marketplace switcher:** new `features/home/marketplace_tab_bar.dart` — card tabs
  (DHAV/Fresh Fruits/Electronics/Pharmacy); active card merges into the header. Tap → `MarketplaceProvider.setActive`
  + `CatalogProvider.setMarketplace` → **whole app re-themes** + catalog reloads. Home category strip + new
  "Shop by Category" grid are **DB-driven**. Removed the old 2-tab DHAV/Stores PageView; Stores is now a pushed
  screen. `main_shell.dart` bottom nav + cart bar themed via `context.mp`.
- **Phase 2 — Category listing:** new `features/catalog/category_listing_screen.dart` (left subcategory rail +
  filter/sort chips + 2-col grid) and `filter_sheet.dart` (brand facet + Clear/Apply).
- **Phase 3 — Product detail:** rebuilt `item_detail_screen.dart` — carousel, highlight chips + "View details"
  sheet, **Select Unit** variants (via `group_id`), brand row, replacement policy, **Similar** + **Top in category**
  carousels. Added `groupId`/`rating`/`ratingCount` to `CatalogItem` + `siblingsOf`/`similarTo`/`topInCategory`
  to `CatalogProvider` (degrade gracefully when data absent).
- **Phase 4 — Checkout:** rebuilt `cart_screen.dart` — delivery card, item rows w/ Move-to-wishlist + struck MRP,
  "You might also like", full **Bill details** (items/handling/delivery/grand total + savings), GSTIN, delivery-
  instructions chips, donation strip. New `WishlistProvider` (local; in `main.dart`). `CartProvider` gained
  gstin/donation/instructions/handling + `grandTotal`. ⚠️ extras captured client-side; payload persistence = 6b.
- **Phase 5 — Orders:** history past card → ✓-arrived + item image thumbnails + Reorder/Rate; detail → order
  summary + Download Invoice + items w/ images + Rate-now + **Bill details** breakdown + copyable id + Repeat Order.
- **Phase 6 (backend) — migration written:** `backend/migrations/007_variants_ratings_checkout.sql` adds
  `group_id` + `rating`/`rating_count` (+ seeds demo ratings), order `gstin`/`donation_amount`/`handling_charge`/
  `delivery_instructions`, and the `wishlist` table. Folded into `000_full_schema.sql`. **Ratings light up with
  no redeploy** (`/catalog/items` returns all columns). ⚠️ **Run 007 in Supabase.**
- **Phase 6b — checkout extras wired end-to-end:** `OrderProvider.placeOrder/placeDirectOrder` +
  `cart_screen` now send gstin/donation/handling/delivery_instructions; backend `models/order.py` +
  `routers/orders.py` (both INSERTs) persist them (`total_customer_amount = items + handling + donation`).
  Wishlist API added (`GET/POST/DELETE /customers/me/wishlist`). `API_REFERENCE.md` updated.
- **Phase 7 — store_type isolation: VERIFIED DONE** (prior session): registration has a mandatory store-type
  selector; `InventoryProvider.load(marketplaceType:)` scopes categories + items to the store's own
  marketplace. **Fixed** a latent bug: `/catalog/categories` now returns objects, so the store inventory
  category chips mapped `e.toString()` (stringified maps) → now reads `e['name']`.
- **Phase 8 — admin CRUD: VERIFIED DONE** (prior session): backend `routers/admin.py` has full
  categories/subcategories/products CRUD + reorder + `/upload-image`; admin web `features/catalog/` (catalog
  screen + category/subcategory manager tabs + product dialog + image upload) is wired (provider + route +
  sidebar). Tidied one unused import.
- **Phase 9 — order routing: VERIFIED** by code: `place_order(marketplace_type)` → `start_broadcast` →
  `find_nearby_stores_async(store_type=...)` → SQL `WHERE COALESCE(store_type,'grocery') = $2`. Type-correct
  (an electronics order never reaches a grocery/fruits/pharmacy store).
- **Status:** customer_app + store_app + admin_dashboard changed files **analyzer-clean**; backend
  `py_compile`-clean. **NOT device-run.** ⚠️ Remaining manual steps: (1) **run `007` in Supabase**;
  (2) `git push origin main` (backend order fields + wishlist); (3) seed `group_id` families in
  `build_seed.py` for "Select Unit" variants (data-only; degrades gracefully now); (4) rebuild/redeploy apps.

### 2026-06-21 — Store self-delivery (owner rides + shares live GPS, no delivery partner)
- **What:** a store can now declare **`self_delivery`** — it delivers its own orders. The owner
  rides the order and **streams live GPS to the customer** (the customer's existing live-tracking
  map + deliverer card "just work"), with **no delivery-partner step**.
- **Why it was mostly wiring, not new infra:** the live-location pipeline already existed
  (`services/location_ws.py` WS hub + customer `order_tracking_screen.dart` animated marker +
  `DeliveryLocationStreamer` on the store side). The only real backend gap: the WS authorizes a
  rider by `uid == assigned_delivery_boy_id` (or `accepted_by_store_id`, which is the **store row
  id**, NOT the owner's uid → never matches the owner). Fix: on **dispatch**, a self-delivery store
  stamps `assigned_delivery_boy_id = owner_uid` so the owner's stream is authorized.
- **Backend (REQUIRED):** `self_delivery BOOLEAN DEFAULT false` on `stores`
  (migration `006_self_delivery.sql` + added to `000_full_schema.sql`); `Store` model +
  `StoreSelfRegisterRequest` + `StoreProfileUpdateRequest` carry it (`models/store.py`); `/stores/register`
  INSERT + `/stores/me/profile` PATCH persist it (`routers/stores.py`); **`POST /orders/{id}/dispatched`**
  (`routers/orders.py`) — when the store is self-delivery and no partner was assigned, stamps
  `assigned_delivery_boy_id = owner_uid`, `delivery_boy_name = shop name`, `delivery_boy_phone = store phone`.
  `API_REFERENCE.md` updated.
- **Store app (REQUIRED):** `Store.selfDelivery` (parse + copyWith); a **"Delivery method" toggle** in
  registration (`store_registration_screen.dart`) and **Store Profile** (`store_profile_screen.dart` →
  `PATCH /stores/me/profile`); `StoreProvider.updateProfile(selfDelivery:)` + `auth_service`/`auth_provider`
  `registerStore(selfDelivery:)`. **`active_order_screen.dart`** now branches on self-delivery: the stepper
  drops the "Assign Delivery Boy" step (4 steps: Accepted → Packed → Out for Delivery → Delivered), the CTA
  goes Mark as Packed → **"Start Delivery & Share Location"** (markDispatched + starts `DeliveryLocationStreamer`)
  → Mark Delivered, with a **LIVE badge**, a "Sharing your live location" banner, **Navigate in Google Maps**,
  and a retry-sharing fallback. Reopening mid-delivery resumes the stream.
- **Customer app (SKIP):** no change — its tracking screen already renders the live marker + deliverer card
  from the order's `delivery_boy_*` fields, which the backend now stamps with the shop. **Admin (SKIP):** no
  data-integrity dependency; a "self-delivery" store badge is backlog.
- ⚠️ **Needs:** (1) run migration **`006_self_delivery.sql`** in Supabase; (2) **deploy backend**
  (`git push origin main` → Render) for the model/register/profile/dispatch changes. Store-app changes are
  local/gitignored.
- **Status: backend `py_compile`-clean; all 7 changed store_app Dart files `flutter analyze`-clean (0 issues).
  NOT yet device-run / deployed.**

### 2026-06-19 — Customer app: full UI redesign on a real design-token system
- **What:** a premium Quick-Commerce visual overhaul of the customer app, **keeping the
  current brand primary blue `#1E88E5`** (per Harshad — older "teal/saffron" mentions in
  docs are stale; **the brand colour is and stays blue `#1E88E5`** — this line is the truth,
  see also Current Architecture). Research-first: reviewed 10 real Blinkit App Store
  screenshots (home / category listing / store grid / gifting / payments / live tracking)
  plus known Zepto / Instamart / BigBasket patterns, then applied their *structure* in DHAV blue.
- **No functional change:** all providers, API calls, navigation, address/GPS logic, Remote
  Config, FCM, cart/order flows and special components (mascot ComingSoon, Welcome sheet,
  AI-assistant "Zatpat" chip, Deal-of-Day) are untouched — UI/UX only. customer_app only;
  store_app / admin / backend = SKIP (no shared data/contract change).
- **New design-token system** (`customer_app/lib/core/theme/`): expanded `app_colors.dart`
  (neutral ramp, surfaceTint, dealAmber, etaGreen, header gradient — primary unchanged) +
  new `app_spacing.dart`, `app_radius.dart`, `app_shadows.dart`, `app_text.dart` (Inter type
  scale). `app_theme.dart` wired to the scale (chip/sheet/dialog/snackbar themes added).
- **New shared components** (`customer_app/lib/core/widgets/`): `product_card.dart`
  (`ProductCard` grid + `ProductRow` list — image-led card with an **ADD pill overlapping the
  image**, category badge, `PriceTag` with struck MRP), `qty_stepper.dart` (`QtyStepper`),
  `section_header.dart`, `app_badges.dart` (DiscountBadge / SaveBadge / EtaChip / StatusPill /
  PriceTag / VerifiedTick), `app_chip.dart`, `empty_state.dart`. Redesigned `dhav_bottom_nav.dart`
  (filled active icon + soft active pill).
- **Screens redesigned with the new system:** Home (ETA-style header, floating search,
  circular category strip, track banner, sections via `SectionHeader`, Fresh-For-You grid +
  category browse → `ProductCard`), Search (floating bar, popular-search idle state, chips,
  `ProductRow`), Orders (status-pill cards, segmented tab bar), Notifications (icon-tile rows,
  unread accent), Product detail, Cart (bill card + savings strip), Store detail (kept the
  cross-store "Replace cart?" guard, restyled card). All other customer screens inherit the
  new look automatically through the shared `AppColors`/theme tokens.
- **Status: analyzer-clean** — `flutter analyze` across customer_app shows **0 errors, 0
  warnings**; only the pre-existing `withOpacity`/`desiredAccuracy` deprecation **infos** remain
  (unchanged baseline). **NOT yet device-run.**
- **Follow-ups (token-consistent but not yet bespoke-redesigned):** order tracking / broadcasting /
  order-detail, the address sheets, welcome/AI/coming-soon sheets, profile — they already pick up
  the new palette + type scale via tokens; a deeper per-screen pass is optional next. Eyeball the
  ComingSoon mascot on the new cooler background (`#F6F7F9`) on a device.

### 2026-06-17 (#4) — "Coming Soon" scene: DHAV mascot holding an area signboard
- **What:** replaced the isometric shop+signboard illustration in `ComingSoonView`
  (`customer_app/lib/features/home/coming_soon_view.dart`) with the **DHAV mascot** — a Puneri
  kirana shopkeeper (white kurta + saffron scarf, glasses) holding a blank wooden signboard, with a
  veggie crate, a location pin and a DHAV grocery bag at his feet. Sourced from Harshad's Canva
  design (`DAHMwgCFExA`), exported PNG → `assets/images/coming_soon_mascot.png` (800×1000).
- **Board text is overlaid in code** (the asset board is blank): "COMING SOON" (small, board-brown)
  + the **area name** big below it (e.g. "Hinjawadi"; falls back to "Near You" when the geocode is
  unknown/denied). Placement is a fixed fraction of a same-aspect (0.8) box rendered with
  `BoxFit.contain`, so the text always lands on the board across screen sizes; `FittedBox` shrinks
  long area names. Mascot keeps the gentle bob animation.
- **Layout now mirrors the LoveLocal reference** Harshad shared: mascot → headline
  **"Coming Soon to &lt;Area&gt;"** → subtitle → **Notify Me** pill → "Try a different location".
  ⚠️ **Wording note / changed earlier decision:** the headline is now area-framed ("Coming Soon to
  &lt;Area&gt;") per Harshad's explicit request, reverting the 2026-06-17 (#2) "No stores near you
  yet" choice. To stay honest (a user can be *inside* Hinjawadi but just outside every store's
  radius), the **subtitle keeps the accurate nuance**: "DHAV is still growing around &lt;Area&gt; —
  no store covers your spot just yet."
- **No API/wiring change:** constructor signature is unchanged, so all 3 call sites (Home DHAV tab,
  Home Stores tab, Search screen) work as-is. Removed the old `_shopPairs`/`_pair`/`_signboard`
  machinery; the `shop_*` assets remain in the folder (now unused by this view, harmless).
- **Polish pass (same day, per Harshad's feedback):**
  - **Transparent background:** the Canva PNG exported on a white field (Free plan = no transparent
    export), so the mascot looked like a pasted white rectangle on the off-white feed
    (`AppColors.background` `0xFFFAFAF7`). Removed it locally with a **PIL border flood-fill**
    (thresh 60 → ~63% of pixels cleared, light feather) so only the man + signboard + scarf +
    veggie crate + DHAV bag + location pin remain; re-saved the asset as **RGBA**. (Faint leftover
    clouds are invisible on the warm-white feed.)
  - **Board text now matches the tilt:** measured the wooden frame's top/left edges with numpy →
    board is tilted **≈ -6.5° (CCW)**. The overlaid "COMING SOON / rule / area" block is wrapped in
    `Transform.rotate(angle: -0.113 rad)` so it sits flush on the board (was upright = looked stuck-on).
  - **Bigger mascot:** display width `280 → 340` (height 425, aspect preserved). Board-text fractions
    are unchanged (they're fractions of the box), so alignment holds.
  - **Board typography + colours:** "COMING SOON" is now **Baloo 2** (terracotta `0xFFC1571E`) over a
    matching rule, and the area is hand-lettered in **Caveat** (espresso `0xFF3A2816`) — reads like a
    real painted sign. Area name is **title-cased** (`_titleCase`: "hinjawadi" → "Hinjawadi") on both
    the board and the headline.
  - **Highlighted subtitle:** the subtitle is now `Text.rich` (`_subtitleSpans`) — the **area** is in
    brand colour (w800) and **"no store covers your spot just yet"** is bold `textPrimary`, the rest
    `textSecondary`.
- **Status: analyzer-clean** (`coming_soon_view.dart` 0 issues), `dart format`-clean. customer_app
  only (gitignored). NOT yet device-run. Old `shop_*` illustration assets are now orphaned — safe to
  delete later.

### 2026-06-17 (#3) — Address: reliable save + instant local-first restore + "enable location" prompt
- **Problem (3 things Harshad hit):** (1) saving an address **sometimes failed** ("Failed to save
  address"); (2) on launch the app showed a **loading spinner while it fetched `/customers/me` just to
  discover which saved address was selected**, *then* loaded the catalog — a needless wait; (3) when
  the user had **no address and no location**, the app silently loaded a misleading city-wide catalog
  instead of asking them to enable location.
- **(1) Save reliability (`address_provider.dart` + `backend/routers/customers.py`):** the real cause
  was the **free-tier Render cold start** (~1 min after 15-min idle) → the first save times out / 5xx →
  "Failed to save". `addAddress` now **retries once** (server is warm by the 2nd try; 2 s backoff;
  retries on timeout/connection error and on 5xx, but NOT on a real 4xx rejection). To make the retry
  safe, the backend `POST /me/addresses` is now **idempotent** — it de-dupes by `lat`+`lng`+
  `flat_building`, so a retried request can't create a duplicate address.
- **(2) Instant local-first restore (`address_provider.dart` + `home_screen.dart`):** new
  `AddressProvider.bootstrapSelection()` restores the last-selected address **straight from
  `SharedPreferences` with NO network call** (the full address JSON — incl. lat/lng — was already
  persisted on every select). Home's `initState` now reads that **synchronously**, loads the catalog
  for it **immediately**, and only **then** refreshes the saved-address list with `loadAddresses()`
  **in the background** (was: `await loadAddresses()` blocking the whole feed). `_restoreDefaultSelection`
  now **never discards** an already-restored selection — it only re-points it to the matching freshly-
  loaded server instance (for edit/delete index alignment). Net: no more "loading → figure out selected
  → load catalog" wait; the catalog renders for the saved address on the first frame after boot.
- **(3) "Enable location" prompt (`home_screen.dart`):** when there's **no saved address AND location
  is off/denied**, the DHAV tab now shows a friendly full-page **`_buildLocationPrompt`** (pin icon,
  "Turn on location", "We need your location to show the kirana shops near you…", **Enable location**
  CTA + **Enter address manually** fallback) instead of loading a city-wide catalog the user can't
  actually buy from (consistent with the 2026-06-17 "browse only nearby items" change). `_detectLocation`
  now sets a new `_needLocation` flag when location services are off / permission denied / deniedForever
  (it no longer falls back to the "Pune" catalog). The CTA `_enableLocation` re-requests permission, or
  opens **app settings** (deniedForever) / **location settings** (services off), then retries. New
  `_openAddressSheet()` helper opens the picker and re-syncs the header/area/`_needLocation` state on
  pick; the header tap + DHAV-tab ComingSoonView "change location" now use it.
- **Status: analyzer-clean** — `address_provider.dart` 0 issues; `home_screen.dart` only its pre-existing
  `withOpacity`/`desiredAccuracy` infos (0 errors). `customers.py` `py_compile`-clean.
- ⚠️ **Needs backend deploy** (`git push origin main` → Render) for the idempotent `POST /me/addresses`
  (the client retry works against the current backend too, but until deployed a retried timeout *could*
  still duplicate). customer_app changes are local/gitignored.

### 2026-06-17 (#2) — "No stores near you yet" scene + Notify-Me waitlist (customer + backend)
- **Problem:** when the user's location had **no nearby stores**, the home feed showed a tiny card
  and the search screen let them type into a box that could never return results. No clear, friendly
  message — and "Notify Me" had nowhere to go.
- **New widget `customer_app/lib/features/home/coming_soon_view.dart` (`ComingSoonView`):** a
  full-screen, reusable scene modelled on the LoveLocal reference. Uses the Canva isometric
  kirana-shop illustrations (`shop_kirana/fresh/dairy/bakery/fc.png`) with a **"COMING SOON"
  signboard** overlaid on the matching `*_board.png` hanging above a gently-bobbing shop, a **"Notify
  Me"** CTA, and an optional **"Try a different location"** action (opens the address sheet). Hosts a
  `RefreshIndicator` so pull-to-refresh still re-detects stores. A stable shop illustration is picked
  per-area via `area.hashCode`.
- **Accurate wording (deliberate, per Harshad):** the headline is **"No stores near you yet"** —
  NOT "Coming Soon to <Area>". A user can be *inside* Hinjawadi yet just outside every store's 3 km
  radius while other Hinjawadi users are served, so claiming the whole area is unserved would be
  false. The area is used as **context only**: "DHAV is still growing around <Area> — no store covers
  your spot just yet…" (falls back to "in your area" when the geocode is unknown/denied/detecting).
- **Notify-Me is now wired end-to-end:**
  - **Local-first:** persists to `SharedPreferences` (`coming_soon_notified_<area>`) → instant,
    offline-proof "You're on the list ✓" + snackbar.
  - **Backend (best-effort):** `POST /customers/notify-waitlist {area, lat, lng}`
    (`routers/customers.py`, `require_role("customer")`) upserts into a new **`coming_soon_waitlist`**
    table (migration `backend/migrations/003_coming_soon_waitlist.sql`), idempotent per `(uid, area)`
    (re-tap refreshes the row, resets `notified`). Failure is swallowed (local confirm stands).
  - **Admin demand view:** `GET /admin/waitlist` (`routers/admin.py`, admin-only) returns demand
    **aggregated by area** (request count + avg lat/lng + last_request, most-wanted first) plus the
    raw rows — so the team can see WHERE to onboard stores next. (Admin **UI** not built — query the
    endpoint / Supabase directly for now.)
- **Wired in 3 places** (trigger = `catalog.hasLocation && !catalog.loading &&
  catalog.allNearbyStores.isEmpty`): **Home DHAV tab** (takes over the whole feed, with
  pull-to-refresh), **Home "Stores" tab** (`_NearbyStoresList` early-returns the scene, drops the
  now-pointless store search bar; removed the old "No stores found nearby" placeholder), and the
  **Search screen** (early-returns the scene with a back button). `!hasLocation` still falls back to
  the full catalogue (unchanged); the home `_buildNoStoresCard`/`_buildNoNearbyBanner` remain as a
  fallback for the edge case "stores exist nearby but stock nothing".
- ⚠️ **Needs:** (1) run migration `003_coming_soon_waitlist.sql` in Supabase; (2) **deploy backend**
  (`git push origin main` → Render) for the two new routes. The customer app's POST is best-effort,
  so the UI works before the deploy (just no rows recorded yet).
- **Gap / follow-up:** the waitlist only *collects* demand — nothing yet sends an FCM push when a
  store later goes live near a waiting customer (would scan `coming_soon_waitlist` on store
  verify/activate, haversine-match, push, set `notified=true`).
- **Status: analyzer-clean** — new Dart file 0 issues; `home_screen.dart`/`search_screen.dart` only
  their pre-existing `withOpacity`/`desiredAccuracy` infos (0 errors). Backend `customers.py`/
  `admin.py` `py_compile`-clean. NOT yet device-run / deployed.

### 2026-06-17 — Customer app: browse only nearby-stocked items (hide the rest of the catalog)
- **Problem:** the customer app browsed the **entire catalog** everywhere (home grids, trending,
  category chips/browse, search), merely *greying out* items no nearby shop stocked ("NOT AVAILABLE"
  / "Sold Out"). That advertised products the customer can't actually buy.
- **Fix (`catalog_provider.dart`):** added a new **`availableItems`** getter = only items whose id is
  in `_nearbyItemIds` (the set built from `/catalog/items/nearby`). The existing **`items`** getter is
  unchanged and still returns the FULL catalog (each tagged `isAvailable`) — kept deliberately for
  **ID→item lookups** (order history/detail resolve past-order item names from it; filtering there
  would show "unknown item"). `search()` and `categoryNames` now read `availableItems`, so search
  results and the search category chips only surface nearby products.
- **Graceful fallback:** when location is unknown (`!_hasLocation`), `availableItems` returns the full
  catalog (we can't compute "nearby" yet) — same behaviour `items` already had. When location is known
  but no store is in range, it returns empty → home already shows the "no nearby stores" card/banner.
- **Home (`home_screen.dart`):** the browse list is now `catalog.availableItems` (was `catalog.items`),
  which flows into Fresh-For-You, Trending, category chips and category browse. Banner **category**
  deep-links also open the nearby-only list; banner **item** deep-links still resolve against the full
  `catalog.items` so a pinned product opens (its detail screen shows availability). Deal-of-the-Day was
  already nearby-gated via `isAvailable` (unchanged).
- **Note:** the search-row "NOT AVAILABLE"/"Sold Out" branch is now effectively dead (results are all
  available) but left in place as a harmless defensive fallback.
- **Status: analyzer-clean** on the 3 changed files (only the file's pre-existing `withOpacity`/
  `desiredAccuracy` deprecation infos; 0 errors). customer_app only; backend/API contract unchanged
  (the `/catalog/items/nearby` endpoint already existed). NOT yet device-run.

### 2026-06-14 (#3) — Deal of the Day: real, admin-set discount (product + % + end time)
- **What changed:** the home "Deal of the Day" card was purely cosmetic — it rotated one item by
  day-of-year, showed full price (no discount), and counted to midnight. It is now a **real discount
  the admin sets** from the dashboard "Customer Home UI" screen.
- **Admin sets (Firebase Remote Config, via `/admin/home-config`):** `home_deal_item_id` (pinned
  catalog item, searchable picker — blank = rotate daily), `home_deal_discount_percent` (0–100),
  `home_deal_ends_at` (epoch millis UTC, date+time picker — blank = midnight). Existing
  `home_deal_enabled`/`home_deal_title` unchanged. New keys added to `remote_config.HOME_KEYS`
  (backend) so the publish pipeline accepts them; in-app defaults added in `ui_config_provider.dart`.
- **Customer app (`deal_of_day.dart`):** shows struck-through MRP + green sale price + "X% OFF"
  chip; counts down to the admin end time (falls back to midnight); **hides the card entirely when
  the explicit end time has passed**. Adds the item to the cart at the **discounted** price via a new
  `CatalogItem.copyWith(price:)` — and since the backend totals orders from the client-sent
  `total_price` (`orders.py:59`), the customer is genuinely charged the sale price (no backend
  pricing engine needed).
- **Availability gate (per request):** the deal card only appears if the chosen product is
  **stocked by a nearby shop** — it requires `item.isAvailable` (which `CatalogProvider.items` sets
  from `_nearbyItemIds`). A pinned-but-not-nearby product → no card, so we never advertise a deal the
  customer can't buy.
- **Scope/known gaps:** discount is **deal-card-only** by design — the same product seen in
  search/category grids still shows full price; opening the deal's product-detail screen shows full
  price too. Cart merges by item id, so if the same item is already in the cart at full price, the
  deal ADD increments at the existing price (edge case). Pricing remains client-trusted app-wide
  (pre-existing) — a server-side re-price/validation is the clean hardening if deals are abused.

### 2026-06-14 (#2) — Store app: dashboard fix, Google addresses, address editing, operating-hours fix, permission UX
- 🐞 **Store dashboard showed nothing (no shop name, open/close toggle disabled, only inventory
  worked).** Root cause: `GET /stores/me` returned the raw row whose PK column is `id`, but the
  Flutter `Store.fromJson` required `store_id` → `null as String` threw → parse failed →
  `StoreProvider._store` stayed null (the error was swallowed). Inventory was unaffected because it
  loads from `/catalog/*` with `requireAuth:false`. **Fix (both sides):** backend `/stores/me` now
  also returns `store_id` (= `id`); `store.dart` reads `j['store_id'] ?? j['id']` defensively. The
  Flutter fix alone unblocks against the live backend (response already had `id`).
- **Google reverse-geocoding for full addresses** (was generic "Hinjawadi, Pune" from OSM). Both
  pickers (`store_app/.../store_location_picker_screen.dart` and
  `customer_app/.../add_address_map_screen.dart`) now call the **Google Geocoding API** first for a
  precise `formatted_address`, **falling back to Nominatim/OSM** on any non-OK status (no
  regression). Uses the existing Maps key in the manifests. ⚠️ **Requires the project to ENABLE the
  "Geocoding API"** in Google Cloud + the key to have **no Android-app restriction** (verified the
  API is currently OFF → returns `REQUEST_DENIED` → falls back to OSM until enabled). Security note:
  an unrestricted in-app key should get a daily quota cap; the clean long-term fix is a backend
  geocode proxy with an IP-restricted server key.
- **Store can change its address from the app** (auto-moves delivery zone). New **"Store Address"
  card** in `store_profile_screen.dart` (current address + pinned lat/lng + **CHANGE** → opens the
  full-screen `StoreLocationPickerScreen`). The **"Edit Store Info" bottom sheet** LOCATION section
  was also swapped from the cramped inline 200px map + manual lat/lng + GPS button to the **same
  full-screen picker** flow (removed `geolocator` import + `_useGps`/`_onMarkerDragged`). On save →
  `PATCH /stores/me/profile`, which already recomputes `geohash6`. **No zone table/cache to touch** —
  customer search (`/stores/nearby`, `/items/nearby`) queries `geohash6` live (`geofencing.py`), so
  the store leaves the old zone and joins the new one on the next query automatically.
- 🐞 **Operating hours weren't saved on registration.** `POST /stores/register` accepted
  `operating_hours` but the SQL INSERT omitted the column → silently dropped. **Fix:** added
  `operating_hours` (default `09:00–22:00`) to the register INSERT (`stores.py`). The **Edit Store
  Info** hours path already saved correctly (`PATCH /stores/me/profile` → `update_my_profile`).
  Also **upgraded the registration hours UI** to the same `_timeTile` design as the edit sheet
  (orange "Opens At" sun / indigo "Closes At" moon, big time, "Tap to change").
- **Permission screen UX reworked** (was a blocking screen on EVERY launch). New
  `core/services/permission_service.dart` persists a `perm_onboarding_seen` flag
  (shared_preferences). Splash now shows the gate **only on first launch**; afterwards it goes
  straight to dashboard/delivery-home. The gate is now **skippable** ("Skip for now"/"Close",
  back-button allowed; leaving marks it seen) and accepts a **nullable `nextRoute`** (set =
  onboarding/replace, null = opened from home/pops back). New **red "Permissions needed" card on
  the dashboard** (`_PermissionWarningBanner`) shows whenever a pollable alert permission
  (notifications / ignore-battery / display-over-apps) is missing, opens the gate on tap, and
  re-checks on return + app-resume so it **clears automatically** once granted. (Full-screen-intent
  has no status API, so it's intentionally excluded from the card's check.)
- ⚠️ **Backend changes need a deploy** (`git push origin main` → Render): `/stores/me` `store_id`
  alias + `/stores/register` operating_hours. **Status: all changed store_app files analyzer-clean
  (0 issues); customer map file only its pre-existing `withOpacity`/`desiredAccuracy` infos;
  `stores.py` syntax-checked. NOT yet device-run; Geocoding API not yet enabled.**

### 2026-06-14 — Store app "Register Your Store" UX overhaul
- **Reworked `store_app/lib/features/auth/store_registration_screen.dart`** (store-owner
  self-onboarding) to match customer-app polish:
  - **Prominent "Under review" highlight banner** (green, `verified_user` icon): "Your store is
    reviewed by DHAV before it goes live… customers within range will see it once verified."
  - **Mobile number**: fixed **`+91` prefix**, **digits-only + maxLength 10** (input formatters),
    validates exactly 10 digits. Stored to backend as `+91XXXXXXXXXX`. (earnings UPI derivation
    already strips non-digits, so no regression.)
  - **Address is no longer a raw text field** — replaced with an **"Add store address" button**.
    Tapping it opens a new full-screen map picker (below); once set, the form shows a green
    **"Location pinned"** card (reverse-geocoded address + lat/lng) with an **Edit location** button.
  - **Operating hours via tap-to-pick time pickers** (`showTimePicker`, `TimeOfDay`) instead of
    free-text; highlighted note: *"If you forget to close your shop, DHAV automatically takes you
    offline at your closing time."*
  - **Terms & Conditions checkbox** (required) + a **"Read Terms & Conditions"** bottom sheet
    listing 6 partner terms (verification, accuracy, fulfilment, auto-offline, conduct, fees).
  - **Submit gating**: "Submit for Verification" is **disabled until ALL required info is present** —
    shop name, owner name, 10-digit phone, pinned location (lat/lng + address), open + close time,
    and T&C accepted; helper text explains what's missing.
- **NEW `store_app/lib/features/auth/store_location_picker_screen.dart`** — full-screen draggable
  Google Map picker modelled on the customer app's add-address UX, but **returns a
  `StoreLocationResult{lat,lng,address}`** to the form (doesn't save to a provider). Requests
  **location permission** + "Use current location", reverse-geocodes the pin via Nominatim
  (OSM, no key), highlight banner "Pin your shop exactly — only customers within range will see
  your store", editable "Full shop address / landmark" field, "Confirm store location" CTA.
  - **Working area search** (top bar): debounced **Nominatim `/search`** (`countrycodes=in`,
    no API key — chose this over Google Places to avoid a billed key), suggestion dropdown →
    selecting one recenters the map + fills the address. Clear (✕) + spinner states.
  - 🐞 **Fix:** the "Full shop address / landmark" field now **re-geocodes on every pin-move**
    (was filling only once, so it kept showing the default location's address). Tracks a
    `_userEditedAddress` flag so it stops auto-overwriting once the owner types custom text.
- **Customer app parity** — `customer_app/lib/features/address/add_address_map_screen.dart`: its
  search bar was **decorative** ("taps open map search in future"). Wired the **same debounced
  Nominatim `/search`** + suggestion dropdown → selecting a result recenters the map & sets the
  area; clear button + spinner; tooltip hides while searching. (Drag-to-pin + GPS already worked.)
- 🐞 **"Use current location" button was hidden behind the tall bottom card** (fixed `bottom:`
  offset) in **both** pickers, so after searching you couldn't get back to your GPS spot. Both
  now anchor the button in a bottom Column **directly above the card** (right-aligned), so it's
  always visible/tappable regardless of card height. Store on tap re-geocodes; customer recenters.
- ⚠️ **store_app + customer_app**; backend/service contract unchanged (`registerStore` still takes
  name/shop/phone/address/lat/lng/open/close). **Status: store files analyzer-clean (0 issues);
  customer map screen has only the file's pre-existing `withOpacity`/`desiredAccuracy` infos (0
  errors). NOT yet device-run.**

### 2026-06-13 (#5) — "Welcome to DHAV" sheet + faster config refresh
- **New welcome bottom sheet** (`welcome_sheet.dart`) modelled on the LoveLocal welcome popup:
  namaste mascot (`welcome_charactor.png`) peeking over a teal panel with a "Kasa kay, Punekar!"
  speech bubble, mission line, 4 DHAV promise bullets, and a "Start shopping local" CTA. Opens
  by tapping the greeting card under the search bar (`welcome_greeting.dart` now tappable + a
  trailing chevron affordance). DHAV teal + our own wording (not LoveLocal's copy).
- **Auto-opens once on first launch** (`home_screen.dart` `_maybeShowWelcomeSheet`, gated by a
  `dhav_welcome_seen` shared_preferences flag); afterwards it's tap-only.
- **Final polish**: 250px namaste mascot with a gentle bob (`_AnimatedMascot`); speech bubble
  drawn via `_BubblePainter` (`Path.combine` union body+straight-down tail, no seam), Baloo 2
  font, an animated rotating saffron→pink→purple gradient (`_SpeechBubble`); content is
  professional/mostly-English with one Marathi touch ("Kasa kay, Punekar!") + a mission +
  "EMPOWERING LOCAL RETAILERS" tag; uses "local retailers", not "kirana". Hot-RESTART needed
  to start the animations (set up in initState).
- Config propagation sped up (see details under "Faster config propagation" in #4).
- ⚠️ customer_app only (gitignored / local).

### 2026-06-13 (#4) — Tappable banners (deep links) + position control; removed search-bar Lottie
- **Banners are now tappable to a destination**, set per-banner from the admin "Home UI" editor:
  `action_type` = `category` / `item` / `stores` / `search` (default), `action_value` = category
  name or catalog item id. Customer app routes the tap (`_handleBannerTap` in `home_screen.dart`):
  category → category browse, item → `ItemDetailScreen`, stores → Stores tab, else → Search.
- **Banner position is editable**: up/down arrows in the editor reorder the carousel
  (`moveBanner` in `home_config_provider.dart`); array order = display order.
- Admin editor banner card gained an **"On tap"** dropdown + conditional value field, plus a
  "position N of M" hint. New banner template seeds the action fields.
- **No typing ids/names by hand**: the action value is now a **category dropdown** (real
  categories) and a **searchable product picker dialog** (loads `/admin/catalog/items` on screen
  open; shows name + category + id; falls back to a text field if the catalog can't load).
- 🐞 Fixed a latent admin bug: `AdminCatalogItem.fromJson` read `item_id`, but
  `/admin/catalog/items` returns the DB column `id` → `itemId` was always empty (also affected
  edit/delete). Now reads `item_id ?? id`. The picker stores the DB `id`, which equals the
  customer app's `CatalogItem.id`, so the item deep-link resolves correctly.
- **Removed the Lottie delivery-bike** animation that rode over the search bar (`home_screen.dart`):
  dropped the `lottie`/`lottie_utils` imports + scooter `AnimationController`; search bar top
  margin tightened 38→12. Confirms: the 1st banner image was only an in-app DEFAULT — fully
  changeable via Remote Config `image_url` like every other banner field.
- **Faster config propagation**: Remote Config `minimumFetchInterval` is now `Duration.zero`
  in debug (instant on relaunch/refresh) and 1h in release (`kDebugMode`). Added
  `UiConfigProvider.refresh()`, wired into home **pull-to-refresh** AND **app-foreground**
  auto-refresh (`_HomeScreenState` is a `WidgetsBindingObserver`; re-fetches on
  `AppLifecycleState.resumed`). Reminder: in the Firebase console you must click **Publish
  changes** for an edit to go live (editing alone doesn't).
- ⚠️ These are **customer_app + admin_dashboard** changes (both gitignored) — on disk, run
  locally, NOT in the repo. Backend unchanged this round.
- **Status: analyzer-clean (admin 0 issues; customer only the 4 pre-existing deprecation infos).**

### 2026-06-13 (#3) — Admin-controlled home top-section, end to end (Remote Config CMS)
- **You can now edit the customer home top-section from the admin dashboard** (no Firebase
  console, no APK rebuild): header gradient colours, greeting title/subtitle, search hint,
  Deal toggle/title, and the full promo-banner carousel (title/subtitle/cta/badge/emoji/
  image URL/colours) — with a **live phone preview**. New "Home UI" sidebar item.
- **Backend** `services/remote_config.py` talks to the Firebase Remote Config **REST API**,
  minting an OAuth2 token (`firebase.remoteconfig` scope) from the existing service account.
  New admin endpoints `GET/PUT /admin/home-config` (read merges only the 8 home keys, publish
  uses `If-Match` etag concurrency). `firebase_init.py` gained `get_service_account_info()`.
  `requirements.txt` pins `google-auth==2.53.0`.
- **Customer app**: header gradient is now remote-driven too (`home_header_color_start/_end`,
  default DHAV teal). Concept 23 added to SYSTEM_DESIGN_NOTES.md.
- **Cached** like catalog: the admin read is served from the shared `TTLCache`
  (`home_config` key, 5-min TTL) so the Home UI screen loads instantly; **publish does a
  write-through + cross-worker `cache.invalidate("home_config")`**, so a new value updates the
  cache immediately (no stale reads). Firebase is only hit on a cold cache or a console-side edit.
- ⚠️ **One-time setup**: if `Publish` returns 403, enable the **Firebase Remote Config API**
  in Google Cloud + grant the service account **Firebase Remote Config Admin** role.
- **Status: code-complete; backend boots (87 routes, both home-config routes present); all
  changed Dart files analyzer-clean (0 errors). NOT yet run against live Firebase / device.**

### 2026-06-13 (#2) — Image promo banners + Romanized Marathi (LoveLocal-style top section)
- **Hero banner now supports background photos** (`hero_banner.dart` rewritten): each
  Remote Config banner can set `image_url` → full-bleed promo photo with a left→right
  dark scrim for text legibility + an optional `badge` chip ("up to 20% OFF"), matching
  the LoveLocal "Meaty Delights" reference. No `image_url` → falls back to the old
  gradient + floating-emoji card. Banner height 152→168px. Whole card is tappable.
- **Remote Config schema extended** (`ui_config_provider.dart`): `HomeBannerConfig` gained
  `image_url` + `badge` fields (back-compatible — both optional). Default banner set now
  ships one image banner (Unsplash veggies) + two gradient banners.
- **All home-screen Marathi de-Devanagari'd → Romanized English** per request: greeting
  "कसं काय पुणेकर" → "Kasa kay, Punekar!", subtitle Romanized, search chip "झटपट" → "Zatpat".
  Fonts switched `notoSansDevanagari`→`inter` in greeting + banner + chip. (Language-PICKER
  labels "मराठी"/"हिंदी" left in native script — that's correct UX.)
- To change a banner live: Firebase Console → Remote Config → `home_banners` JSON array
  (set `image_url`/`badge`/`title`/`cta`/colors). Editing this from the admin Flutter app
  is NOT wired yet — see backlog.
- **Status: code-complete, analyzer clean (0 errors; only 4 pre-existing deprecation infos).
  NOT yet device-verified, APK not rebuilt.**

### 2026-06-13 — Customer home UI revamp + default address + Remote Config
- Home screen rebuilt to compete with Zepto/Blinkit/LoveLocal: mascot greeting
  ("कसं काय पुणेकर! 🙏" with `welcome_charactor.png`), two-line location header, white
  search bar with mascot chip, bigger banner carousel, Deal-of-the-Day with live
  countdown, rich "Shops in Your Area" cards. New files in `customer_app/lib/features/home/`.
- Default-address rules implemented (`address_provider.dart` + shared_preferences):
  last selected address persists across restarts and drives catalog loading; no address
  → GPS; "Use current location" remembered as a mode (fresh GPS each launch).
- Firebase Remote Config added (`ui_config_provider.dart`) — home text/banners/deal
  changeable from console without APK rebuild. Concepts 21–22 in SYSTEM_DESIGN_NOTES.md.
- **Status: code-complete, analyzer clean. NOT yet device-verified, APK not rebuilt.**

### ~2026-06-08 — Admin coverage map + store fixes (commit `de0ab32`)
- Admin dashboard: store verify/name alignment fixed; coverage map (Leaflet,
  `web/coverage_map.html`) showing store coverage — adapted for Postgres backend.
- ⚠️ Working tree still has uncommitted admin_dashboard changes (coverage_screen,
  firebase.json, web/) — commit or clean up.

### ~2026-06-06 — PostgreSQL migration 🔴→🟢 (BUILD_PLAN "Phase D" — actually done)
- ALL data moved Firebase RTDB → **Supabase PostgreSQL** (asyncpg pool, JSONB codecs,
  PgBouncer-aware). Firebase kept ONLY for Auth + FCM. Supabase Storage replaces
  Firebase Storage. Migrations in `backend/migrations/`.
- This supersedes: Firebase `.indexOn` work (Concept 19), RTDB security rules, and the
  "keep Firebase, don't migrate" decision in SYSTEM_DESIGN_IMPLEMENTATION.md.

### 2026-06-05 — Hosting: Railway → Render (free, no card)
- `render.yaml` blueprint; deploy = `git push origin main`. Guide: `backend/deployment_step.md`.
- All three Flutter clients updated to the Render URL (done, verified in api_config.dart).

### 2026-05-30 — Production scaling (Phase A+/B code)
- Event-loop unblocking, WS leak fix, event-driven broadcasting, optional Redis bus,
  push-driven customer UI. See SYSTEM_DESIGN_NOTES.md Concepts 9–20.

---

## 🚧 IN PROGRESS / NEEDS VERIFICATION

- [ ] **Run migration `006_self_delivery.sql`** in Supabase (SQL Editor) — adds `stores.self_delivery`.
- [ ] **Deploy backend** for self-delivery (model + `/stores/register` + `/stores/me/profile` +
      `POST /orders/{id}/dispatched` stamping). Then device-test: store with self-delivery ON →
      accept → pack → "Start Delivery & Share Location" → customer sees the shop moving live on the map.
- [ ] **Run migration `003_coming_soon_waitlist.sql`** in Supabase (SQL Editor) — creates the
      `coming_soon_waitlist` table the Notify-Me endpoint writes to.
- [ ] **Deploy backend** (`git push origin main` → Render) to ship `/customers/notify-waitlist`
      + `/admin/waitlist` (2026-06-17 #2), the **idempotent `POST /me/addresses` de-dupe** (2026-06-17
      #3), the `/stores/me` `store_id` alias + `/stores/register` operating_hours fixes from 2026-06-14 (#2).
- [ ] **Enable the "Geocoding API"** in Google Cloud for the Maps project + ensure the key has no
      Android-app restriction (add a daily quota cap), else both apps fall back to OSM addresses.
      Long-term: move geocoding behind a backend proxy with an IP-restricted server key.
- [ ] Device-run the store app: dashboard loads shop name + open/close toggle; address change from
      Profile + Edit sheet; first-run permission gate → skip → red home card → grant clears it.
- [ ] Device-verify the new home screen + address flow (`cd customer_app && flutter run`)
- [ ] Rebuild customer APK (carries home revamp + push-driven UI from 2026-05-30)
- [ ] Commit or clean the uncommitted admin_dashboard working-tree changes
- [ ] **Grant the service account "Firebase Remote Config Admin" + enable the RC API** so the
      admin "Home UI" → Publish works (else 403). Then test: edit a banner → Publish → confirm
      the customer app reflects it after a fetch.
- [ ] Rebuild + redeploy admin dashboard (`flutter build web` → `firebase deploy --only hosting`)
      to ship the new "Home UI" editor.

---

## 📋 KNOWN GAPS — missed during the phases (fill these during enhancements)

**Testing / QA**
- [ ] Real-device FCM verification: store popup rings on silent mode + background/killed wake-up
- [ ] Flutter widget tests (none exist)
- [ ] Manual QA checklist (PRD §24.4) + 15 end-to-end use cases (PRD §26)
- [ ] Backend tests after Postgres migration — re-run `pytest` (last known 39/39 was pre-Postgres)

**Launch (old Phase 7.3 / 7.4 — still pending)**
- [ ] Pilot: onboard 3 test stores in Kothrud, 10 end-to-end orders, 3 friend-testers
- [ ] Soft launch: 20 stores, flyers, daily monitoring
- [ ] Set up the `/health` keep-warm pinger before any demo/pilot day

**Ops (only when scaling)**
- [ ] Redis (Upstash/Render Redis) + `REDIS_URL` + `--workers N` — code ready, ops pending

**Stale docs (rewrite only if/when needed)**
- `docs/ARCHITECTURE.md`, `backend/ARCHITECTURE.md` — pre-Postgres/pre-Render (banners added)
- `docs/API_SPECIFICATIONS.md`, `docs/FIREBASE_SETUP.md` — partially pre-Postgres
- `docs/PRD.md` §4 data models / §23 security rules — describe RTDB, DB is now Postgres

---

## 💡 ENHANCEMENT BACKLOG (ideas, not committed)

- Store app UI polish to match the new customer-app quality
- Search screen: trending searches, voice search (mic is decorative today)
- Cart: delivery-fee transparency, savings strip, suggested add-ons
- Order Again: real item images + one-tap reorder of a full past order
- Customer app localization toggle (EN/MR/HI) — models already carry name_mr/name_hi
- Festival theming via Remote Config (Ganeshotsav/Diwali banners + greeting) — NOTE: the
  admin "Home UI" editor (2026-06-13 #3) already makes this a 10-second non-dev action.
- Store ratings shown in nearby-stores API payload (rating exists in detail only)
- Admin "Home UI" editor polish: drag-reorder banners, image upload to Supabase Storage
  (today it's an image-URL field), a colour-picker widget (today it's a hex field).

---

*Created 2026-06-13 — after this date, update THIS file (not BUILD_PLAN.md) at session end.*
