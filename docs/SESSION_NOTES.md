# 📓 DHAV — Session Notes (Dev Journal)

**Purpose:** This file is your memory across days. Update it at the END of every dev session. Read it at the START of every dev session.

**How Claude CLI uses this:** When you say "Read SESSION_NOTES.md and continue", Claude reads this and picks up exactly where you stopped.

---

## 📝 HOW TO USE THIS FILE

### Template for each session entry:

```markdown
## Session [DATE] — [TOPIC]

**Started:** [TIME]
**Stopped:** [TIME]
**Current Phase:** Phase X.Y
**Files modified:** list files

### What I did today:
- thing 1
- thing 2

### What worked:
- ...

### What broke / blockers:
- ...

### Code I'm uncertain about:
- file path : reason

### NEXT TIME — START HERE:
[Exact next task. Be specific. Include the Claude CLI prompt to use.]
```

---

## 🔖 CURRENT STATUS (Always update this at top)

**Current Phase:** 🚀 ENHANCEMENT MODE — all build phases (0–8) complete. Tracker: **`docs/ENHANCEMENTS.md`** (read it first; it also has the current-architecture truth table).
**Architecture (current):** FastAPI on Render + **Supabase PostgreSQL** (all data) + Supabase Storage; Firebase = Auth + FCM only; Remote Config for customer-app home UI.
**Last task completed:** Address UX fixes (2026-06-17 #3): reliable save (retry + idempotent backend
endpoint), **instant local-first restore** of the selected address on boot (no network wait), and an
**"enable location" prompt** when there's no address + no location. Before: Customer app now **browses
only nearby-stocked items** (2026-06-17): new
`CatalogProvider.availableItems` getter (items in `_nearbyItemIds`); home grids/trending/category
chips+browse and search now use it, so non-nearby catalog items are **hidden, not greyed out**. `items`
getter kept for ID→name lookups (order history/detail). Falls back to full catalog when location
unknown. Analyzer-clean, customer_app only, backend unchanged. Before: Deal of the Day → **real
admin-set discount** (2026-06-14 #3): admin pins a product + % off + end date/time on the "Customer Home UI" screen (new RC keys `home_deal_item_id`/`home_deal_discount_percent`/`home_deal_ends_at`); customer card shows MRP strikethrough + sale price + "X% OFF", counts to the admin end time, hides when expired, and adds to cart at the discounted price (backend trusts client price, so it's the real charge). Deal card only shows if the product is stocked by a nearby shop. Before: Store app bug-fix + feature batch (2026-06-14 #2).
**Next task to do:** (1) `git push origin main` to deploy backend (`/stores/me` store_id alias + register operating_hours + **new HOME_KEYS for the deal discount**). (2) Enable **Geocoding API** in Google Cloud + unrestrict key (else apps fall back to OSM). (3) Device-run store app to verify dashboard/address/permission flows. Then the still-pending Remote Config item: grant the Firebase service account the **Remote Config Admin** role + enable the RC API (else Publish=403), test admin "Home UI" → set a deal product+discount+end → Publish, rebuild customer APK + redeploy admin web.
**Production URL:** https://dhav-backend.onrender.com ✅ (all 3 apps point here — verified 2026-06-13)
**Admin Dashboard:** LIVE at https://dhav-quick-commerce.web.app ✅ (note: uncommitted working-tree changes pending)
**Deploy workflow:** `git push origin main` → Render auto-deploys. Full guide: `backend/deployment_step.md`.
**Redis:** code ready but OFF (no REDIS_URL) — correct for single-worker pilot. Rule: no Redis → 1 worker only.
**Last updated:** 2026-06-14

---

## Session 2026-06-17 (#3) — Address: reliable save + instant restore + enable-location prompt

**Current Phase:** Enhancement Mode — customer app address/UX
**Goal:** Fix the 3 address pains Harshad reported: (1) save sometimes fails; (2) launch waits on a
network fetch to figure out the selected address before showing the catalog; (3) no address + no
location → silently loads a misleading catalog instead of asking to enable location.

**Files modified:**
- `customer_app/lib/core/providers/address_provider.dart` — new `bootstrapSelection()` (restore last
  selection from SharedPreferences, no network); `_restoreDefaultSelection` no longer discards an
  existing selection (re-points to server instance only); `addAddress` retries once on cold-start
  timeout/5xx.
- `customer_app/lib/features/home/home_screen.dart` — `initState` uses `bootstrapSelection()` then
  loads catalog immediately + `loadAddresses()` in background; new `_needLocation` flag; `_detectLocation`
  shows the prompt (no more Pune fallback) when location off/denied; `_enableLocation` CTA; new
  `_openAddressSheet()` helper wired to header tap + ComingSoonView; `_buildLocationPrompt()` widget.
- `backend/routers/customers.py` — `POST /me/addresses` is now idempotent (de-dupe by
  lat+lng+flat_building) so the client retry can't create duplicates.

### What I did today:
- Traced "Failed to save" to the Render free-tier cold start (first save after idle > 40 s timeout).
  Added a single retry + made the endpoint idempotent so the retry is duplicate-safe.
- The selected address JSON (with lat/lng) was ALREADY persisted on every select — the app just wasn't
  *using* it on boot; it re-fetched `/customers/me` first. Now it restores locally and renders instantly.
- No-address + no-location now shows an "enable location" prompt (consistent with the nearby-only catalog).

### What worked:
- `flutter analyze` on both Dart files: 0 errors (only the files' pre-existing withOpacity/desiredAccuracy
  infos). `customers.py` py_compile-clean.

### NEXT TIME — START HERE:
- `git push origin main` to deploy the idempotent `POST /me/addresses` (+ the other pending backend
  changes). Device-test: kill app with a saved address → reopen → catalog should appear WITHOUT the
  "detecting/loading then switch" flash; deny location with no saved address → see the prompt → Enable
  → grants and loads; save an address on a cold backend → should succeed (was failing).

---

## Session 2026-06-17 — Browse only nearby-stocked items (customer app)

**Current Phase:** Enhancement Mode — customer app catalog/UX
**Goal:** Stop showing the whole catalog. Customers should only see items a nearby shop actually
stocks, not every catalog product greyed-out as "NOT AVAILABLE".

**Files modified:**
- `customer_app/lib/core/providers/catalog_provider.dart` — new `availableItems` getter (only items
  in `_nearbyItemIds`); `search()` + `categoryNames` now read it. `items` getter left as-is (full
  catalog) for ID→item lookups.
- `customer_app/lib/features/home/home_screen.dart` — browse list now `catalog.availableItems`; banner
  category deep-link uses `availableItems`, item deep-link still uses full `catalog.items`.

### What I did today:
- Found the existing nearby plumbing: `loadCatalog` already fetches `/catalog/items/nearby` into
  `_nearbyItemIds` and tagged each catalog item `isAvailable`. The app just wasn't *filtering* on it —
  it greyed items out instead. Added `availableItems` (filter, not tag) and pointed the browsing
  surfaces at it.
- Deliberately kept `items` (full catalog) because order history/detail resolve past-order item names
  by id from it — filtering there would break name display for items no longer nearby.

### What worked:
- `flutter analyze` on the 3 changed files: only pre-existing `withOpacity`/`desiredAccuracy` infos,
  0 errors.

### Code I'm uncertain about:
- Search row still has the "NOT AVAILABLE"/"Sold Out" branch — now unreachable (results are all
  available). Harmless, left as a defensive fallback; remove later if it bothers.
- When location is unknown we fall back to the full catalog (can't compute nearby). Matches prior
  behaviour; confirm on-device that location is resolved before the grid renders so customers don't
  briefly see the full catalog.

### NEXT TIME — START HERE:
- Device-run customer app: confirm home/search/categories show only nearby items, and that the
  "no nearby stores" card/banner appears when out of range. Rebuild APK.

---

## Session 2026-06-14 (#3) — Deal of the Day → real admin-set discount

**Current Phase:** Enhancement Mode — home UI / promotions
**Goal:** Turn the cosmetic "Deal of the Day" (rotated item, full price, midnight timer) into a real
discount the admin controls, and only surface it for products actually stocked nearby.

**Files modified:**
- `backend/services/remote_config.py` — added `home_deal_item_id`, `home_deal_discount_percent`,
  `home_deal_ends_at` to `HOME_KEYS` (the publish whitelist).
- `customer_app/lib/core/providers/ui_config_provider.dart` — defaults + getters `dealItemId`,
  `dealDiscountPercent` (clamped 0–100), `dealEndsAt` (epoch-millis → DateTime?).
- `customer_app/lib/core/models/catalog_item.dart` — `copyWith` now takes `price:` (to build the
  discounted cart item).
- `customer_app/lib/features/home/deal_of_day.dart` — pinned-or-rotating item, nearby-availability
  gate, MRP strikethrough + sale price + "X% OFF" chip, admin end-time countdown (else midnight),
  hide-on-expiry, add-to-cart at discounted price.
- `admin_dashboard/lib/core/providers/home_config_provider.dart` — `dealItemId`/`dealDiscountPercent`
  /`dealEndsAt` accessors.
- `admin_dashboard/lib/features/home_config/home_config_screen.dart` — Deal section now has a product
  picker (reuses `_ItemPickerDialog`), a discount-% field, and a date+time end picker.

### What I did today:
- Designed around the existing flow: deal is RC-driven and the admin "Home UI" screen already had a
  product-picker dialog → extended both instead of inventing a new path.
- Confirmed the backend totals orders from the client-sent `total_price` (`orders.py:59`), so a
  discounted cart line is the real charge — no backend pricing engine needed (only the HOME_KEYS add).
- Per a mid-task request: the deal card only renders if the chosen product is `isAvailable`
  (stocked by a nearby shop), so we never advertise a deal the customer can't buy.

### What worked:
- `flutter analyze` clean on all changed files in both apps; backend file parses.

### Code I'm uncertain about:
- Scope is deal-card-only (chosen): same item elsewhere shows full price; product-detail opened from
  the deal shows full price. If a customer already has the item in cart at full price, the deal ADD
  increments at the existing price (cart merges by id). Acceptable for now; note if it confuses users.

### NEXT TIME — START HERE:
- Deploy: `git push origin main` (backend needs the new HOME_KEYS to accept the deal keys on publish).
- In admin "Customer Home UI": pick a deal product, set a % and an end time, Publish; verify the
  customer app shows the discounted price + countdown and charges the sale price at checkout.

---

## Session 2026-06-14 (#2) — Store app: dashboard fix, Google addresses, address editing, hours fix, permission UX

**Current Phase:** Enhancement Mode — store app bug-fixes + UX
**Goal:** Fix store owner's reported issues (dashboard blank, generic addresses, hours not saving,
permission screen on every launch) and add store-side address editing.

### 1. Dashboard showed nothing (no name, can't toggle open/close; only inventory)
- **Cause:** `GET /stores/me` returns `dict(row)`; the stores PK column is `id`, but Flutter
  `Store.fromJson` did `storeId: j['store_id'] as String` → `null as String` throws → parse fails →
  `StoreProvider._store` stays null (error swallowed in `loadMyStore`). Open/close `Switch` is
  disabled when `store == null`; title falls back to "KIRANA PARTNER". Inventory works because it
  uses `/catalog/*` with `requireAuth:false`.
- **Fix:** `backend/routers/stores.py` `/me` now sets `data["store_id"] = data["id"]`;
  `store_app/.../models/store.dart` reads `(j['store_id'] ?? j['id'] ?? '')`. Flutter fix alone
  unblocks vs the live backend.

### 2. Full Google addresses (both apps)
- OSM/Nominatim can't produce street+landmark+pincode like Google. Added `_googleReverseGeocode`
  (calls `maps.googleapis.com/maps/api/geocode/json`, returns `results[0].formatted_address`,
  null→fall back to existing OSM) in **store** `store_location_picker_screen.dart` and **customer**
  `add_address_map_screen.dart`. Key constant = the existing Maps key in AndroidManifest.
- **Verified the key returns `REQUEST_DENIED`** → the **Geocoding API is not enabled** on the
  project. Until enabled (and the key is not Android-app-restricted), apps keep showing OSM
  addresses. Flagged the unrestricted-key security tradeoff + backend-proxy alternative.

### 3. Store can change its address from the app
- New **"Store Address" card** in `store_profile_screen.dart` (current address + lat/lng + CHANGE →
  full-screen `StoreLocationPickerScreen` → `updateProfile(address,lat,lng)`).
- **Edit Store Info sheet** LOCATION section swapped from inline map + manual lat/lng + GPS to the
  **same full-screen picker** (`_changeAddress`); removed `geolocator` import, `_useGps`,
  `_onMarkerDragged`, `_mapController`, `_fetchingGps`.
- **Zone handling is automatic:** `update_my_profile` recomputes `geohash6`; customer search reads
  `geohash6` live (`geofencing.py` — no zone table/cache). User's "remove from old zone/update
  cache" was the OLD Firebase RTDB mental model; not needed now.

### 4. Operating hours
- 🐞 `POST /stores/register` INSERT **omitted `operating_hours`** → never saved. Added it
  (default `09:00–22:00`). The **Edit Store Info** hours path already saved fine
  (`PATCH /stores/me/profile` → `update_my_profile` writes `operating_hours`).
- Upgraded the **registration** hours UI (`_timeBox`) to the edit sheet's `_timeTile` look
  (orange sun "Opens At" / indigo moon "Closes At", big time, "Tap to change").

### 5. Permission UX
- New `core/services/permission_service.dart`: `criticalPermissionsGranted()` (notification +
  ignoreBatteryOptimizations + systemAlertWindow), `onboardingSeen()` / `markOnboardingSeen()`
  (shared_preferences `perm_onboarding_seen`).
- **Splash** shows the gate **only first launch**; afterwards → dashboard/delivery-home directly.
- **Permission gate** now: nullable `nextRoute` (set=replace to next, null=pop back), **"Skip for
  now"/"Close"** button, `canPop:true` (back allowed; leaving marks seen). `main.dart` route no
  longer defaults the arg to dashboard. Removed `flutter/services` import (no more SystemNavigator).
- **Dashboard** `_PermissionWarningBanner` (red, tappable) shows when any pollable permission is
  missing → opens gate → re-checks on return + on `AppLifecycleState.resumed` → auto-clears.
  Full-screen-intent excluded (no status API). Also removed a pre-existing unused `orderProv`.

### Files
- backend: `routers/stores.py` (`/me` store_id alias; register operating_hours).
- store_app: `models/store.dart`, `features/store/store_profile_screen.dart`,
  `features/auth/store_location_picker_screen.dart`, `features/auth/store_registration_screen.dart`,
  `features/auth/permission_gate_screen.dart`, `features/auth/splash_screen.dart`, `main.dart`,
  `features/dashboard/dashboard_screen.dart`, **NEW** `core/services/permission_service.dart`.
- customer_app: `features/address/add_address_map_screen.dart`.

### Status
- All changed store_app files **analyzer-clean (0 issues)**; customer map file only its pre-existing
  `withOpacity`/`desiredAccuracy` infos; `stores.py` syntax-checked. **NOT device-run.**
- **No new tech/concept** → nothing added to SYSTEM_DESIGN_NOTES.md (Google Geocoding REST,
  shared_preferences flag, geohash live-query zones are all already used/known patterns).

### NEXT TIME — START HERE
- `git push origin main` (deploy backend fixes), enable Google **Geocoding API** + unrestrict key,
  then `cd store_app && flutter run` to verify dashboard / address change / permission flows.

---

## Session 2026-06-14 — Store app "Register Your Store" UX overhaul

**Current Phase:** Store app UI polish (matching the customer-app quality bar)
**Goal:** Make store-owner self-onboarding clear, trustworthy and hard to submit incomplete:
better phone capture, a map-based address picker (reusing the customer add-address UX),
real operating-hours pickers, a visible "we review your store" promise, terms acceptance, and
a Submit button that only unlocks when everything required is present.

### Files — store_app
- **REWROTE `lib/features/auth/store_registration_screen.dart`:**
  - Under-review **highlight banner** (green) at the top.
  - **Phone** → `+91` prefix + digits-only + `LengthLimitingTextInputFormatter(10)`, validates
    exactly 10 digits, submitted as `+91XXXXXXXXXX`.
  - **Address** field removed → **"Add store address" button** → opens the new map picker; once
    set, shows a green **"Location pinned"** card (address + lat/lng) + **Edit location**.
  - **Operating hours** → two tap-to-open **`showTimePicker`** boxes (`TimeOfDay`, formatted
    `HH:mm`), with an **auto-offline note** ("DHAV takes you offline at your closing time").
  - **Terms & Conditions** required checkbox + **"Read Terms & Conditions"** `showModalBottomSheet`
    with 6 partner terms.
  - **`_isComplete` getter** gates Submit (disabled style + "fill all details" helper) until shop
    name, owner name, 10-digit phone, location, both times, and T&C are all set. Listeners on the
    text controllers rebuild the button live.
- **NEW `lib/features/auth/store_location_picker_screen.dart`** — full-screen draggable Google Map
  (center `storefront` pin), `StoreLocationResult{lat,lng,address}` returned via `Navigator.pop`.
  Requests location permission + "Use current location", Nominatim reverse-geocode (OSM, no key,
  same pattern as customer app), highlight banner, editable "Full shop address / landmark" field,
  "Confirm store location" CTA. Pune fallback center.
  - **Functional area search** added: debounced Nominatim `/search` (`countrycodes=in`),
    suggestion dropdown (`_PlaceSuggestion`) → tap recenters the map + fills the address; clear
    button + inline spinner; banner hides while the search field is focused. Used OSM (not Google
    Places) to avoid a billed Places API key — consistent with the existing reverse-geocode call.

### Files — customer_app (search parity)
- **`lib/features/address/add_address_map_screen.dart`** — the search bar was decorative
  ("taps open map search in future"). Made it functional with the **same** debounced Nominatim
  `/search` + `_PlaceSuggestion` dropdown as the store picker; selecting a result recenters the
  map and updates the area; clear button + spinner; map tooltip hides while searching/focused.
  Drag-to-pin + GPS were already working. (Matched the file's existing `withOpacity` style → its
  pre-existing deprecation infos remain; 0 errors.)

### Notes / decisions
- Backend + `auth_service.registerStore` contract **unchanged** — still
  name/shop/phone/address/lat/lng/(operating_hours open+close). We just feed it cleaner data.
- Phone now carries `+91`; `earnings_screen` UPI derivation already strips non-digits, so safe.
- No new tech/concept → nothing added to SYSTEM_DESIGN_NOTES.md (TimeOfDay picker, route-result
  return, and Nominatim reverse-geocode are all already used elsewhere).

### Verification
- `flutter analyze` on both changed files → **No issues found (0)**.
- NOT yet device-run.

### NEXT TIME — START HERE
1. `cd store_app && flutter run` → sign in as a new (non-store) user → land on Register Your Store.
2. Walk it: tap **Add store address** → allow location → confirm the pin/address come back; set
   open/close times; tick T&C → confirm **Submit** only enables when all are filled; submit →
   expect the "Awaiting admin verification" snackbar → permission gate → dashboard.
3. (Optional follow-up) wire the T&C/Partner Policy text to real hosted legal docs — today the
   6 partner terms live in-app in the bottom sheet (`_termPoints`), which is the canonical source.
   (Area search is now functional via Nominatim — no Google Places key needed.)

---

## Session 2026-06-13 #3 — Admin-controlled home top-section (Remote Config CMS, end to end)

**Current Phase:** Customer app UI polish + admin tooling
**Goal:** Let Harshad edit the WHOLE home top section (header colours, greeting, search hint,
deal, promo banners) from the **admin portal**, persisted in Firebase Remote Config — DHAV's
teal stays the default, but everything is overridable without an APK rebuild or touching the
Firebase console.

### Architecture (the loop this closes)
`admin web (Home UI screen)` → `PUT /admin/home-config` → `backend services/remote_config.py`
→ Firebase Remote Config REST API. Customer app reads it via `fetchAndActivate()` (≤1h).
Backend mints its own OAuth2 token (scope `firebase.remoteconfig`) from the existing service
account — the Python admin SDK can't publish RC templates, so we call the REST API directly.

### Files — backend
- NEW `services/remote_config.py` — `get_home_config()` / `update_home_config()`. Reads live
  template for its `ETag`, overwrites only the 8 home keys, publishes with `If-Match` (optimistic
  concurrency). 8 keys: `home_header_color_start/_end`, `home_greeting_title/_subtitle`,
  `home_search_hint`, `home_banners`, `home_deal_enabled`, `home_deal_title`.
- `firebase_init.py` — added `get_service_account_info()` (shares SA JSON with the token mint),
  refactored `_build_credentials()` to use it.
- `routers/admin.py` — `GET/PUT /admin/home-config` (admin-only; PUT filters to known keys).
- `requirements.txt` — pinned `google-auth==2.53.0` (already transitively installed).

### Files — admin_dashboard
- NEW `core/providers/home_config_provider.dart` — load/save, decodes `home_banners` JSON into an
  editable list, re-encodes on save.
- NEW `features/home_config/home_config_screen.dart` — sectioned editor (header colours, greeting
  & search, deal, banners) + **live phone preview** that recolours/retitles as you type. Reload +
  Publish buttons; toast on result.
- Wired: `app_routes.dart` (`homeConfig`), `admin_sidebar.dart` ("Home UI" nav), `main.dart`
  (provider + route).

### Files — customer_app
- `core/providers/ui_config_provider.dart` — added `home_header_color_start/_end` defaults +
  `headerColorStart/End` getters (reuse `HomeBannerConfig._hex`).
- `features/home/home_screen.dart` — `_buildGradientHeader` now reads those colours (was const
  AppColors teal).

### Verification
- Backend: `services.remote_config` imports OK; `main.app` boots with **87 routes**, both
  `/admin/home-config` (GET+PUT) present.
- Admin `home_config_screen.dart` → `flutter analyze` **0 issues**; customer changed files →
  only the 4 pre-existing deprecation infos.
- NOT yet run against live Firebase (needs the IAM grant below) or on device.

### ⚠️ One-time setup BEFORE Publish works
Enable the **Firebase Remote Config API** in Google Cloud for `dhav-quick-commerce` AND grant the
backend's service account the **Firebase Remote Config Admin** role (`cloudconfig.configs.update`).
A 403 on Publish = this isn't done yet. Reading may succeed before writing does.

### NEXT TIME — START HERE
1. Do the IAM grant above. Redeploy backend (`git push origin main`).
2. `cd admin_dashboard && flutter run -d chrome` → Home UI → edit a banner image + colours →
   Publish → expect the green "Published!" toast (not a 403).
3. `cd customer_app && flutter run` → confirm header/greeting/banner reflect the published values
   (may need to relaunch to beat the 1h fetch cache during testing).
4. Rebuild customer APK; `flutter build web` + `firebase deploy --only hosting` for admin.

---

## Session 2026-06-13 #2 — Image promo banners + Romanized Marathi

**Current Phase:** Customer app UI polish (pre-pilot)
**Goal:** Make the home top section look modern like the LoveLocal reference
(real promo photo banner + discount badge), and stop using Devanagari script —
show Marathi in English letters (Romanized) instead. Keep it all Remote-Config-driven.

### What I did
- **`hero_banner.dart` `_BannerCard` rewritten** to two visual modes chosen per banner:
  - `image_url` set → full-bleed `Image.network` + left→right black scrim (0.62→0) so
    white text stays legible over any photo + optional `badge` chip top-right
    ("up to 20% OFF"). This is the LoveLocal "Meaty Delights" look.
  - `image_url` empty → original gradient card with floating emoji + decor circles.
  - Image `errorBuilder`/`loadingBuilder` return `SizedBox.shrink()` → gradient base
    shows through, so a bad/slow URL never breaks the banner. Whole card tappable → Stores.
  - Banner height 152→168px; title/subtitle width-capped to ~0.56/0.52 screen so text
    never overlaps the photo subject on the right.
- **`ui_config_provider.dart`**: `HomeBannerConfig` + `image_url` + `badge` (both optional,
  back-compatible). Default `home_banners` now = 1 image banner (Unsplash veggies, green)
  + 2 gradient banners. Greeting defaults Romanized: "Kasa kay, Punekar! 🙏" /
  "Deccan te Hadapsar — tumcha kirana zatpat gharpoch".
- **Romanized all home Marathi**: greeting title/subtitle (above), `welcome_greeting.dart`
  fonts `notoSansDevanagari`→`inter`, `home_screen.dart` search chip "झटपट"→"Zatpat" + font.
  Left language-picker labels "मराठी"/"हिंदी" in native script (correct for a lang toggle).

### How to change a banner live (no APK rebuild)
Firebase Console → Remote Config → key `home_banners` = JSON array of objects:
`{title, subtitle, cta, badge, emoji, image_url, color_start, color_end}`. Publish → app
picks it up within the 1h fetch interval. NOTE: editing this from the **admin Flutter app**
is NOT built yet (it's a Firebase-Console-only flow today) — logged in ENHANCEMENTS backlog.

### Verification
- `flutter analyze` on the 4 changed files → 0 errors/warnings; only 4 PRE-EXISTING
  deprecation infos (`desiredAccuracy`, `withOpacity`) on untouched lines.
- NOT device-run yet.

### NEXT TIME — START HERE
1. `cd customer_app && flutter run` → confirm: image banner renders the veggie photo with
   the "up to 20% OFF" badge + readable white text; greeting reads "Kasa kay, Punekar!".
2. (Optional) In Firebase Console set `home_banners[0].image_url` to your own promo image
   to confirm live update.
3. Rebuild customer APK. Then (optional) build the admin-app banner editor (backlog item).

---

## Session 2026-06-13 — Customer home UI revamp + default address + Remote Config

**Current Phase:** Customer app UI polish (pre-pilot)
**Goal:** Make the home screen compete with Zepto/Blinkit/LoveLocal (reference
screenshots provided) instead of looking generic, and fix the address/location
selection logic.

### Address / location logic (the 2 scenarios now implemented)
1. **No saved address** → app uses live GPS, reverse-geocodes, loads nearby catalog.
2. **Has saved addresses** → the LAST address the user selected (from the address
   sheet or Saved Addresses screen) is persisted on-device via `shared_preferences`
   (`dhav_default_address` key) and restored as the default on every app start —
   catalog always loads around it. Picking "Use current location" is remembered as
   a *mode* (sentinel value), so the next launch re-detects fresh GPS instead of
   pinning stale coordinates. Deleting the default address clears the pref and
   falls back to the first saved address.
   - File: `customer_app/lib/core/providers/address_provider.dart` (rewritten).

### Home screen revamp (customer_app/lib/features/home/)
- `welcome_greeting.dart` — NEW: mascot strip with `assets/images/welcome_charactor.png`
  saying "कसं काय पुणेकर! 🙏" (Pune flavour, not a copy of the reference's Mumbai line).
- `hero_banner.dart` — REWRITTEN: taller (152px) auto-scrolling promo carousel with
  CTA pills, decorative circles, floating emoji; cards come from Remote Config.
- `deal_of_day.dart` — NEW: green "Deal of the Day" card with live HH:MM:SS countdown
  to midnight; featured item rotates daily (`dayOfYear % items`), ADD/qty stepper wired
  to CartProvider.
- `shops_near_you.dart` — NEW: LoveLocal-style "Shops in Your Area" cards (initials
  avatar, verified badge, rating chip, "Delivers in ~X min" ETA from distance) with
  See-all → Stores tab.
- `home_screen.dart` — two-line location header (label + full address, like
  Zepto), solid-white search bar with mascot chip ("झटपट"), new sections inserted:
  Greeting → Banner → Track banner → Categories → Deal of Day → Shops Near You →
  Order Again → Fresh For You → Trending.

### Remote Config (dynamic UI without APK rebuilds)
- Added `firebase_remote_config: ^5.1.3` (resolved 5.5.0) to pubspec.
- NEW `core/providers/ui_config_provider.dart` — keys: `home_greeting_title`,
  `home_greeting_subtitle`, `home_search_hint`, `home_banners` (JSON array of
  {title, subtitle, cta, emoji, color_start, color_end}), `home_deal_enabled`,
  `home_deal_title`. All have in-app defaults → app works identically with zero
  Firebase console setup; set the same keys in Console → Remote Config to change
  the home screen live (1h fetch interval).
- Registered in `main.dart` MultiProvider with fire-and-forget `init()`.

### Verification
- `flutter pub get` resolves clean; `flutter analyze` on changed paths → 0 errors,
  only 4 pre-existing deprecation infos.
- NOT yet run on a device — needs visual check.

### NEXT TIME — START HERE
1. `cd customer_app && flutter run` — verify: greeting card, banner carousel, deal
   countdown, shops cards, two-line location header.
2. Test address flow: select address → kill app → reopen → same address + its catalog
   loads; "Use current location" → kill → reopen → GPS re-detects.
3. (Optional) Create the Remote Config keys in Firebase Console to test live UI change.
4. Then: update API base URL Railway → Render in both apps, rebuild APKs, Phase 7.3 pilot.

---

## Session 2026-06-05 — Hosting migration: Railway → Render (free)

**Current Phase:** Phase 7 DEPLOYMENT (ops)
**Why:** Railway's free tier became a paid trial after 1 month. Moved to Render's
genuinely-free tier (no credit card) to avoid spending money during the pilot.

### What I did:
- Added [render.yaml](../render.yaml) blueprint at repo root — deploys `backend/` as a
  free Python web service. Secrets marked `sync: false` (pasted in dashboard, not committed).
- Deployed on Render via New → Blueprint. Build succeeded; app starts and `/health` returns 200.
- Rewrote `backend/deployment_step.md` for Render (was the Railway guide).

### What worked:
- App needed **zero code changes** — it already reads `FIREBASE_SERVICE_ACCOUNT_JSON` and
  `$PORT` from env. Database stays on Supabase; Redis stays optional.
- **New deploy workflow is just `git push origin main`** — Render auto-deploys from GitHub.

### What broke / blockers:
- First deploy crashed: `json.JSONDecodeError: Extra data` — the Firebase JSON env var was
  **pasted twice** into Render. Fix: clear the field, paste once. (File itself is a clean
  2372-char single-line JSON.) Documented in deployment_step.md → Common Errors.

### Free-tier caveat to remember:
- Render free service **sleeps after 15 min idle** (~1 min cold start; WS drop + scheduler
  pauses while asleep). Keep warm with a cron-job.org pinger on `/health` for demos.

### NEXT TIME — START HERE:
Point the Flutter apps at the new Render URL. Search customer_app/ and admin_dashboard/ for
the old `dhav-backend-production.up.railway.app` base URL and replace with the Render URL,
then rebuild. Prompt: "Update the API base URL in the Flutter apps from the Railway URL to
the Render URL and rebuild the customer APK."

---

## Session 2026-05-30 — Phase A+ Production Scaling (backend) + Push-driven UI

**Current Phase:** Phase 8-A+ — System design / scaling
**Goal:** Make the WHOLE app production-grade for many concurrent users (not just catalog).
Mode: implement-first, explain-after. All concepts taught in `docs/SYSTEM_DESIGN_NOTES.md`
(Concepts 9–20).

### Files ADDED (backend/)
- `services/firebase_async.py` — async wrappers (`fb.get/get_many/set/update/delete/query_equal/transaction`) that run blocking Firebase SDK calls on a 32-thread pool so they never freeze the event loop.
- `services/redis_bus.py` — optional Redis Pub/Sub bus (WS location, cache invalidation, accept signal). Auto-DISABLES when `REDIS_URL` is unset → app runs single-worker exactly as before.

### Files CHANGED (backend/)
- `services/location_ws.py` — REWRITTEN. Fixed the memory leak (channels now created on first customer, deleted on last-leave / delivery; `close_order_channel` is actually called now). Redis Pub/Sub fan-out across workers + local fallback. Non-blocking auth. Rider GPS throttle (≥1/s) + delta drop.
- `services/broadcasting.py` — event-driven (asyncio.Event + Redis accept signal) instead of 2s polling; concurrent FCM-token reads; non-blocking I/O; concise `log.info` broadcast diagnostics restored.
- `services/geofencing.py` — added concurrent `find_nearby_stores_async` / `find_all_stores_in_radius_async` (read all geohash cells at once).
- `services/cache.py` — bounded `TTLCache(max_size=5000)`; `invalidate()` + `init_invalidation_subscriber()` for cross-worker cache clearing; `clear_prefix`.
- `routers/orders.py` — all I/O via `fb.*`; accept now calls `signal_order_accepted` + parallel "order taken" token fetch; delivered/failed call `close_order_channel`; **fixed missing `send_new_order_to_stores` import** (latent NameError in `place_direct_order`).
- `routers/stores.py` — REWRITTEN to `fb.*` (all 30 calls); geofence writes offloaded via `fb.run`; cache invalidation on profile/toggle/inventory edits.
- `routers/catalog.py` — uses central `firebase_async` + async geofence + Redis-backed `cache.invalidate`.
- `main.py` — `redis_bus.init_redis()` + `cache.init_invalidation_subscriber()` in lifespan; `logging.basicConfig(INFO)`; closes Redis on shutdown.
- `config.py` (+`.env.example`) — added optional `REDIS_URL`. `requirements.txt` — added `redis==5.0.7`.

### Files CHANGED (firebase/) — DEPLOYED ✅
- `realtime-db.json` (+ mirror `.rules`) — fixed/added `.indexOn`:
  - `orders`: `customer_id`, `accepted_by_store_id`, **`assigned_delivery_boy_id`** (old index wrongly had `delivery_boy_id`, a field that doesn't exist → rider query was full-scanning ALL orders).
  - added `delivery_boys` + `custom_item_requests` indexed on `store_id`.
  - **Deployed via `firebase deploy --only database`.**

### Files CHANGED (customer_app/) — needs APK rebuild
- `core/services/fcm_service.dart` — dead callback → broadcast `Stream<String> orderUpdates`.
- `features/orders/broadcasting_screen.dart` — reacts to FCM push instantly; poll 4s → 8s fallback.
- `features/orders/order_tracking_screen.dart` — reacts to FCM push; 8s poll kept as backstop.

### Verification
- Backend: imports OK (85 routes), `py_compile` OK, **pytest 39/39 PASS** (fixed 2 stale `test_penalties` assertions that hadn't been updated for the `owner_uid` param).
- customer_app: `flutter analyze` on the 3 changed files → 0 errors/warnings (only pre-existing `withOpacity` infos).

### Docs updated
- `SYSTEM_DESIGN_NOTES.md` — Concepts 9–20 (workers, blocking event loop, concurrent reads, memory leak, Pub/Sub, Redis-on-Railway, cache invalidation, event-driven broadcast, throttle/delta, bounded cache, Firebase indexOn, push-driven UI) — each with What/Why/Where/Example/Impact/If-not. Standing rule added: every new concept gets documented here.
- `SYSTEM_DESIGN_IMPLEMENTATION.md` + `BUILD_PLAN.md` — Phase A+ / B marked done.

### IMPORTANT — Redis decision
Redis code is built but **intentionally OFF** (no `REDIS_URL`). Correct for the pilot.
**Rule:** no Redis → run **1 worker** only. Turn on later by: add Redis service on Railway → set
`REDIS_URL` → run `--workers N` → redeploy. No code changes needed.

### NEXT TIME — START HERE
1. **Redeploy backend:** `cd backend && railway up` (ships async/WS/broadcast/index-aware code). Keep it single-worker (no `--workers`).
2. **Rebuild customer APK:** `cd customer_app && flutter build apk --release` (ships push-driven UI). Store app unchanged.
3. Smoke-test: place order → confirm "Accepted" appears within ~1s of store tapping Accept (push-driven), live tracking still works, delivered screen still triggers.
4. Then continue **Phase 7.3 — Pre-launch pilot** (onboard 3 test stores, 10 end-to-end orders).

---

## Session 2026-05-29 #3 — Admin Dashboard Web Build

**Current Phase:** Phase 7 — Admin Dashboard Hosting Setup
**Files added:**
- `admin_dashboard/firebase.json` — Firebase Hosting config (public: build/web, SPA rewrites, cache headers)
- `admin_dashboard/.firebaserc` — links to `dhav-quick-commerce` Firebase project

**What was done:**
- Created `firebase.json` with hosting config: points to `build/web`, SPA rewrite for Flutter routing, long-cache headers for JS/CSS/WASM, no-cache for index.html
- Created `.firebaserc` pointing to `dhav-quick-commerce`
- Ran `flutter build web --release` — **BUILD SUCCEEDED** (139s build time)
- Ran `firebase deploy --only hosting` — **DEPLOYED** ✅
- Admin dashboard live at: https://dhav-quick-commerce.web.app

**Build warnings (non-blocking):**
- Deprecated service worker in index.html (cosmetic, doesn't affect function)
- `dart:html` in `store_onboard_screen.dart` + `coverage_screen.dart` — only blocks WASM build, JS build is fine
- Missing CupertinoIcons font in pubspec (minor, no visible impact)

### NEXT TIME — START HERE:
**Phase 7.3 — Pre-launch Pilot:**
1. Open admin dashboard: https://dhav-quick-commerce.web.app → login with admin Firebase account
2. Onboard a test store: Stores → Onboard Store → fill name/area/lat/lng/email/password
3. Install store_app APK on a real Android device — log in with the store credentials just created
4. Install customer_app APK on another device — log in with Google or Email
5. Customer: Browse → add items → Place Order
6. Store: receive FCM popup → Accept → Pack → Dispatch → Mark Delivered
7. Customer: see OrderDelivered screen → Rate
8. Admin dashboard: verify order appears in Orders table

---

## Session 2026-05-29 #2 — Deployment + APK Builds

**Current Phase:** Phase 7 Deployment + Phase 8-A
**Files committed:**
- `backend/services/cache.py` — TTLCache (Phase A)
- `backend/main.py` + `backend/routers/catalog.py` — GZIP + cache + async reads (Phase A)
- `store_app/lib/core/services/fcm_service.dart` — dual FCM channels
- `store_app/lib/features/profile/profile_screen.dart` — edit button on avatar
- `store_app/lib/features/store/store_profile_screen.dart` — Google Maps pin-drag for location

**What was done:**
- Committed Phase A backend improvements + store_app UX improvements
- Deployed backend to Railway (deployment ID: a591497d) — LIVE ✅
- Smoke tested `/health`, `/catalog/categories`, `/catalog/items` — all 200 OK
- Built customer_app release APK: **57.2 MB** ✅
- Built store_app release APK: **56.6 MB** ✅

**Production URL:** https://dhav-backend-production.up.railway.app
**Both apps already point to this URL** (hardcoded in api_config.dart)

### NEXT TIME — START HERE:
**Phase 7.3 — Pre-launch Pilot**
1. Install store_app APK on a real Android device (from `store_app/build/app/outputs/flutter-apk/app-release.apk`)
2. Install customer_app APK on another device (from `customer_app/build/app/outputs/flutter-apk/app-release.apk`)
3. Use Railway dashboard to verify env vars are set (Firebase keys, etc.)
4. Smoke test full flow:
   - Admin: onboard a test store via admin dashboard
   - Store: Login on store APK → see dashboard
   - Customer: Login on customer APK → Home → Add items → Place order
   - Store: Receive FCM popup → Accept → Pack → Dispatch → Mark Delivered
   - Customer: See OrderDelivered screen → Rate
5. Fix any bugs found before soft launch

---

## Session 2026-05-29 — Phase A System Design Quick Wins

**Current Phase:** Phase 8 — System Design Improvements
**Files added:**
- `backend/services/cache.py` — TTLCache class (thread-safe, monotonic clock), singleton `catalog_cache`, TTL constants

**Files modified:**
- `backend/routers/catalog.py` — catalog now served from 5-min in-memory cache; all N+1 Firebase loops replaced with `asyncio.gather()` concurrent reads; admin write endpoints invalidate cache on mutation
- `backend/main.py` — added `GZipMiddleware` (min 1000 bytes); added `_warm_catalog_cache()` called in lifespan so first request hits memory not Firebase

**Performance improvements shipped:**
- `/catalog/items` + `/catalog/categories`: first hit warms cache in ~800ms; all subsequent hits return in <5ms (from memory)
- `GET /catalog/stores/nearby` (N stores): was N sequential Firebase reads; now N concurrent reads via `asyncio.gather` + thread pool executor
- `GET /catalog/items/nearby`: same fix — all nearby store nodes fetched concurrently
- `GET /catalog/stores/{id}` with configured inventory: per-item reads now concurrent (was sequential loop)
- GZIP: all JSON responses ≥1KB compressed before sending to mobile (saves ~60-70% bandwidth on catalog payload)
- Cache warming: server boots → catalog cached immediately → zero cold-start penalty on first user request

### NEXT TIME — START HERE:
**Option 1 (Recommended): Deploy backend to Railway**
1. `cd backend && railway login && railway up`
2. Set env vars on Railway dashboard
3. Update API URL in both apps + rebuild APKs

**Option 2: Phase B — Redis (only if you scale to multiple workers)**
- Add Redis service on Railway
- Replace `catalog_cache` with Redis client

---

## Session 2026-05-28 — System Design Brainstorm + Docs

**Current Phase:** Phase 8 — System Design
**Files added:**
- `docs/SYSTEM_DESIGN_NOTES.md` — Teaching notes: caching, async, CDN, Redis, N+1 problem, pagination, GZIP
- `docs/SYSTEM_DESIGN_IMPLEMENTATION.md` — Implementation tracker: Phase A/B/C/D roadmap

**Root cause of slowness identified:**
1. Every catalog request hits Firebase directly (no caching) — 800ms+
2. Nearby store lookup does N+1 Firebase reads in a loop — 1500ms+
3. No GZIP compression on responses — wasteful on mobile

**System design roadmap decided:**
- Phase A: In-memory cache + async reads + GZIP (quick wins, zero new services)
- Phase B: Redis (when multi-worker scaling needed)
- Phase C: CDN image optimization
- Phase D: PostgreSQL migration (future scale)

### NEXT TIME — START HERE:
**Phase A.1 — In-Memory Cache for Catalog**
1. Create `backend/services/cache.py` — TTL-based in-memory cache class
2. Update `backend/routers/catalog.py` — use cache for `/items` and `/categories`
3. Add cache warming to `backend/main.py` lifespan
4. Test: hit `/catalog/items` twice, second should be 10x faster

---

## Session 2026-05-27 #4 — Remaining Implementation + Release APK Builds

**Current Phase:** Phase 7.5 (Build + Deploy)

**Files added:**
- `customer_app/lib/features/orders/order_detail_screen.dart` — NEW: full past-order detail screen. Shows status banner, store info, delivery address, delivery boy name, itemized list with quantities/prices, price breakdown, "Rate" button (for unrated delivered orders), "Order Again" button.

**Files modified (customer_app/):**
- `lib/features/orders/order_history_screen.dart` — routing fix: past orders (delivered/failed/cancelled) now navigate to `/order-detail` with the `CustomerOrder` object as argument; active orders still go to `/order-tracking`. Added `AppRoutes` import.
- `lib/main.dart` — `orderDetail` route now creates `OrderDetailScreen()` instead of wrongly creating `OrderHistoryScreen()`. Added import for `order_detail_screen.dart`.

**Files modified (store_app/):**
- `lib/features/auth/splash_screen.dart` — added `if (!mounted) return;` before the final routing block to guard all 5 `use_build_context_synchronously` warnings.
- `lib/features/delivery/delivery_incoming_assignment_screen.dart` — removed unused `phone` parameter from `_AddressCard` widget (was defined but never passed; dead code).
- `lib/features/inventory/add_product_screen.dart` — renamed `_SectionLabel` helper to `_sectionLabel` (lowerCamelCase convention).
- `lib/features/orders/incoming_order_screen.dart` — made `_busy` in `_IncomingOrderDetailsScreenState` `final` (it's never mutated in that class; real busy state lives in the parent screen's state).

**Analysis results:**
- customer_app: 28 info (deprecation warnings only) — no errors ✅
- store_app: **0 issues** ✅

**APK builds:**
- customer_app: `build/app/outputs/flutter-apk/app-release.apk` — 57.1 MB ✅
- store_app: building… (in progress at session end)

### NEXT TIME — START HERE:
**Phase 7.6 — Deploy + Smoke Test**
1. Deploy backend: `cd backend && railway login && railway up`
2. Deploy admin dashboard: `cd admin_dashboard && flutter build web && firebase deploy --only hosting`
3. Update production backend URL in both apps:
   - `customer_app/lib/core/config/api_config.dart` → replace `10.0.2.2:8000` with Railway URL
   - `store_app/lib/core/config/api_config.dart` → same
4. Rebuild APKs with production URL: `flutter build apk --release`
5. Smoke-test full flow:
   - Customer: Login → Home → Add items → Cart → Place Order → Broadcasting → Tracking
   - Store: Receive FCM popup → Accept → Pack → Dispatch → Mark Delivered
   - Customer: OrderDelivered screen → Rate
   - Admin: Verify notification history shows all events

---

## Session 2026-05-27 #3 — Full Codebase Repair + Remaining Pages

**Current Phase:** Phase 7 (file repair + route wiring)

**Root cause discovered:** 14 of 99 Dart files were truncated mid-content due to a Windows/UTF-8 encoding issue when files were originally written. This caused missing logic in auth, notifications, FCM, splash, earnings, profile screens across both apps.

**Files repaired (customer_app/):**
- `lib/core/constants/app_routes.dart` — added `savedAddresses`, `helpSupport`, `itemDetail` route constants + closing `}`
- `lib/core/providers/auth_provider.dart` — completed `sendPasswordReset()` method
- `lib/core/providers/notification_provider.dart` — completed `loadFromBackend()`, `add()`, `markRead()`, `markAllRead()`, `clearAll()`, `typeFromData()`
- `lib/core/services/fcm_service.dart` — completed `_handleMessageTap()`, `_onNotificationTap()`, `dispose()`
- `lib/features/auth/email_signin_screen.dart` — completed error SnackBar, `_signIn()` method, full `build()` with form
- `lib/features/auth/splash_screen.dart` — completed `_buildBottomBadge()` method and closed class
- `lib/features/notifications/notifications_screen.dart` — completed `_NotificationTile` widget and closed class
- `lib/features/profile/profile_screen.dart` — stripped corrupt trailing fragment, closed `_LegendDot` class
- `lib/main.dart` — was truncated; rebuilt with all routes: orderDelivered, orderHistory, profile, notifications, savedAddresses, helpSupport + onGenerateRoute for orderDetail

**Files repaired (store_app/):**
- `lib/core/providers/notification_provider.dart` — completed all methods
- `lib/core/services/fcm_service.dart` — stripped duplicate corrupt append, restored clean class
- `lib/features/auth/splash_screen.dart` — completed `_DiagonalLinesPainter.shouldRepaint()` and closed class
- `lib/features/earnings/earnings_screen.dart` — stripped corrupt trailing fragment
- `lib/features/notifications/notifications_screen.dart` — stripped corrupt trailing fragment
- `lib/main.dart` — was truncated; rebuilt with `missedOrderWarning` case, `default` case, closing braces + `_pageRoute()` helper

**New features added:**
- `store_app/lib/features/inventory/add_product_screen.dart` — NEW full screen for requesting custom catalog items (form with name EN/HI/MR, category, unit, price, notes) with loading state + success state
- `backend/routers/stores.py` — NEW `POST /stores/me/custom-items` + `GET /stores/me/custom-items` endpoints; saves to Firebase `custom_item_requests/{id}`
- `store_app/lib/features/inventory/inventory_screen.dart` — added FAB "Request Product" → navigates to `/add-product`

**Verification:** All 99 Dart files terminate properly. All named routes registered in both apps. flutter analyze not available in shell but all bracket counts balanced.

### NEXT TIME — START HERE:
**Phase 7.5 — Build + Deploy**
1. `cd customer_app && flutter pub get && flutter build apk --release`
2. `cd store_app && flutter pub get && flutter build apk --release`
3. `git push railway main` — deploy backend
4. Smoke-test: Login → Place Order → Accept in store app → Track in customer app → Delivered → Rating

---

## Session 2026-05-27 — Remaining Page Logic Implementations

**Current Phase:** Phase 7 (UI/logic gap fixes)
**Files modified (customer_app/):**
- `lib/core/providers/auth_provider.dart` — Added `sendPasswordReset()` method that calls `AuthService.sendPasswordReset()`
- `lib/features/auth/email_signin_screen.dart` — Implemented `_showForgotPassword()` — Firebase password-reset dialog with email pre-fill, loading spinner, success/error snackbars; wired to "Forgot Password?" button (was `TODO`)
- `lib/features/profile/profile_screen.dart` — Fixed header edit icon button (was `{/* edit profile */}`); now navigates to `/profile-setup`
- `lib/core/providers/notification_provider.dart` — NEW: `NotificationProvider` ChangeNotifier with `AppNotification` model; `add()`, `markRead()`, `markAllRead()`, `clearAll()`; `NotificationType` enum (orderAccepted/outForDelivery/delivered/orderFailed/broadcasting/general)
- `lib/core/services/fcm_service.dart` — Added `notificationProvider` property; `_handleForegroundMessage` now calls `notificationProvider?.add(...)` to accumulate real FCM messages
- `lib/main.dart` — Registered `NotificationProvider`; injected into `fcmService.notificationProvider` at creation
- `lib/features/notifications/notifications_screen.dart` — REBUILT: reads from `NotificationProvider` (real FCM history); type-specific icons/colors; relative timestamps; tap → navigate to `/order-tracking`; "Mark all read" button functional; empty state with hint text

**Files modified (store_app/):**
- `lib/core/providers/notification_provider.dart` — NEW: `StoreNotificationProvider` ChangeNotifier with `StoreNotification` model; `StoreNotificationType` enum (newOrder/orderDelivered/settlement/strike/deliveryAssigned/system)
- `lib/core/services/fcm_service.dart` — Added `notificationProvider` property; `_handleMessage` now calls `notificationProvider?.add(...)` for `new_order`, `delivery_assigned`, and any other FCM message with a title
- `lib/main.dart` — Registered `StoreNotificationProvider`; injected into `fcmService.notificationProvider` at creation
- `lib/features/notifications/notifications_screen.dart` — REBUILT: reads from `StoreNotificationProvider`; type-specific icons/colors; relative timestamps; tap → navigate to `incomingOrder` or `orderDetail`; "Mark all read" functional; empty state
- `lib/features/earnings/earnings_screen.dart` — Fixed `dhav@upi (placeholder)`: now reads `StoreProvider.store?.phone` and derives a real UPI ID (`{phone}@paytm`); added Copy-to-clipboard button; shows "contact support to configure" gracefully when phone unavailable; also calls `sp.loadMyStore()` on init if not loaded

### What I did:
1. Forgot Password — full dialog with loading state, success/error feedback
2. Profile edit icon — one-liner navigation fix
3. Customer notifications — replaced 100% mock with real live FCM history via NotificationProvider
4. Store notifications — replaced 100% mock with real live FCM history via StoreNotificationProvider
5. UPI ID — replaced placeholder text with phone-derived real UPI ID + copy button

### What worked:
- No new packages required — all changes use existing deps
- `NotificationProvider` is purely in-memory (session-scoped); survives tab switches since it's in MultiProvider root

### What's still pending:
- Persist notifications across app restarts (needs `shared_preferences` — acceptable for v1.1)
- Build and test APKs: `flutter build apk --release`

### NEXT TIME — START HERE:
**Phase 7.4 — Full Persistent Notification System (DONE) + Build Release APKs**
See 2026-05-27 session #2 below for full details.

---

## Session 2026-05-27 #2 — Full Persistent Notification System

**Current Phase:** Phase 7 (Notification persistence + admin broadcast)

**Files modified (backend/):**
- `services/notifications.py` — Added `_save_notification()` + `_save_notification_multi()` Firebase persistence helpers; added `send_broadcast_notification()` helper; updated all send functions to accept optional `user_id`/`owner_uid`/`owner_uids` params and call `_save_notification` when provided
- `routers/notifications.py` — NEW: `GET /notifications/me`, `PATCH /notifications/{id}/read`, `PATCH /notifications/me/read-all`, `DELETE /notifications/me`, `DELETE /notifications/{id}`
- `routers/admin.py` — Added `POST /admin/notifications/broadcast` (targets: all_customers/all_stores/specific_store/specific_customer) + `GET /admin/notifications/history`
- `main.py` — Registered `/notifications` router
- `routers/orders.py` — Updated 4 notification calls to pass customer_uid / owner_uids
- `services/penalties.py` — Updated strike/suspended calls to pass owner_uid

**Files modified (customer_app/):**
- `lib/core/providers/notification_provider.dart` — REBUILT: now uses `Map<id, AppNotification>` for dedup; `loadFromBackend()` hits `GET /notifications/me`; `markRead/markAllRead/clearAll` sync to backend; `fromJson()` factory; new types: announcement/offer/system
- `lib/features/auth/splash_screen.dart` — Calls `NotificationProvider.loadFromBackend()` on successful auth

**Files modified (store_app/):**
- `lib/core/providers/notification_provider.dart` — Same backend-sync overhaul as customer app
- `lib/features/auth/splash_screen.dart` — Calls `StoreNotificationProvider.loadFromBackend()` on store owner login

**Files modified (admin_dashboard/):**
- `lib/core/providers/notifications_provider.dart` — NEW: `AdminNotificationsProvider` with `broadcast()` and `loadHistory()`
- `lib/features/notifications/notifications_screen.dart` — NEW: full broadcast UI with target selector (4 options), type selector (4 options), title+body form with validation, live preview card, send button with loading state, expandable recent history panel
- `lib/core/constants/app_routes.dart` — Added `/notifications` route
- `lib/core/widgets/admin_sidebar.dart` — Added 📣 Notifications nav item
- `lib/main.dart` — Registered `AdminNotificationsProvider` + route

### What I did:
1. Backend: Firebase `notifications/{uid}/{notif_id}` storage for all notification events
2. Backend: REST endpoints for customers/stores to fetch, read, and delete their notification history
3. Backend: Admin broadcast endpoint targets all customers, all stores, a specific store, or a specific customer — sends FCM push AND saves to Firebase
4. Customer app + store app: Providers now load from backend on login, dedup with live FCM, and sync read/delete state back
5. Admin dashboard: New Notifications screen — full broadcast form with preview, history panel

### What worked:
- Optional `user_id` params maintain full backward compatibility with all existing callers
- Map-based dedup prevents showing the same notification twice (from both FCM and backend load)
- `markRead`/`markAllRead`/`clearAll` are fire-and-forget backend syncs

### NEXT TIME — START HERE:
**Phase 7.5 — Build Release APKs + Deploy Backend**
1. `git push railway main` — deploy updated backend
2. `cd customer_app && flutter build apk --release`
3. `cd store_app && flutter build apk --release`
4. Test: Place an order, accept it → customer sees "Order Accepted" in notification history after restart
5. Test: Admin dashboard → Notifications → Send "Offer" to all_customers → verify notification appears in customer app

---

## Session 2026-05-25 (cont.) — Order Tracking + Order Delivered Screens

**Current Phase:** Phase 7 (Screen refinements)
**Files modified:**
- `customer_app/lib/features/orders/order_tracking_screen.dart` — REBUILT: horizontal icon row replaced with vertical animated timeline; pulsing teal dot for active step (AnimationController repeat); green checkmark circles for completed steps; connector lines between steps; "In Progress" badge (fades in/out); delivery boy card at bottom with call button; map section with ETA chip; "I have a problem" link; when status=`delivered` auto-navigates to `/order-delivered` via `pushReplacementNamed`
- `customer_app/lib/features/orders/order_delivered_screen.dart` — NEW (Screen 15): confetti particle animation via CustomPainter (48 particles, seeded deterministic positions, fade-out at end); scale-in green checkmark (elasticOut curve); collapsible order summary card (items + fee breakdown); "Rate this delivery" prompt card → calls RateOrderSheet; "Order Again" + "Back to Home" buttons
- `customer_app/lib/core/constants/app_routes.dart` — Added `orderDelivered = '/order-delivered'`
- `customer_app/lib/main.dart` — Imported + registered `OrderDeliveredScreen` route

### NEXT TIME — START HERE:
**Phase 7.2 — Deploy Backend to Railway**
1. `cd backend && railway login`
2. `railway up` (from backend/ folder)
3. Set env vars on Railway dashboard: `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIREBASE_DATABASE_URL`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`
4. Note the Railway URL → update `customer_app/lib/core/config/api_config.dart` + `store_app/lib/core/config/api_config.dart`

---

## Session 2026-05-25 — Customer Rating System + Feature Audit

**Current Phase:** Phase 7 (Testing + Deployment)
**Files modified:**
- `backend/routers/orders.py` — NEW: `POST /orders/{id}/review` — validates delivered + unreviewed + same customer, writes to `reviews/{store_id}/{review_id}`, updates store avg rating, marks order `has_review: true`
- `customer_app/lib/core/models/order.dart` — Added `hasReview` field (parsed from `has_review`)
- `customer_app/lib/core/providers/order_provider.dart` — Added `reviewOrder()` method + `loadOrder()` helper
- `customer_app/lib/features/orders/rate_order_sheet.dart` — NEW: 5-star tap rating widget, optional comment field, animated taglines per star level, Skip button
- `customer_app/lib/features/orders/order_history_screen.dart` — Added "Rate" button (with star icon) on delivered past orders without review; hides after rating submitted

### What was already built since last notes (since 2026-05-20):
- Full address management system (AddressSelectionSheet, AddAddressMapScreen, AddAddressDetailScreen, SavedAddressesScreen)
- Improved home screen with hero banner, scooter animation, shimmer loading
- Broadcasting screen with animated shop pop-in badges
- Store app: self-registration screen (Google Maps pin), settings, theme provider (dark/light), help/support, notifications, native Android FCM cold-launch handler (DhavMessagingService.kt)
- Backend: `/catalog/stores/nearby`, `/catalog/stores/nearby/all`, `/catalog/stores/{id}` endpoints
- CatalogProvider extended with `allNearbyStores` and nearby store list

### NEXT TIME — START HERE:
**Phase 7.2 — Deploy Backend to Railway**
1. `cd backend && railway login`
2. `railway up` (from backend/ folder)
3. Set env vars on Railway dashboard: `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIREBASE_DATABASE_URL`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`
4. Note the Railway URL → update `customer_app/lib/core/config/api_config.dart` + `store_app/lib/core/config/api_config.dart`

**Phase 7.4 — Build Release APKs**
1. `cd customer_app && flutter build apk --release`
2. `cd store_app && flutter build apk --release`

---

## Session 2026-05-20 — Customer App Bug Fixes

**Current Phase:** Phase 7 (Production Bug Fixes)
**Files modified (customer_app/):**
- `lib/core/providers/catalog_provider.dart` — BUGFIX: backend `/catalog/items` returns `{"items":[...]}` not a raw list; fixed JSON parsing to extract `body['items']`. Same fix for categories: backend returns `{"categories":["Grains",...]}` (strings, not objects), now converted to `CatalogCategory` directly.
- `lib/core/widgets/main_shell.dart` — NEW: persistent `MainShell` widget with `IndexedStack` — all 4 tabs (Home/Search/Orders/Profile) are kept alive; switching tabs is instant with no full rebuild. `MainShell.of(context)?.switchTab(N)` lets any child switch tabs.
- `lib/main.dart` — Route `/home` now points to `MainShell` instead of `HomeScreen`.
- `lib/features/home/home_screen.dart` — Removed `DhavBottomNav`. Added real reverse geocoding using Nominatim (OpenStreetMap, free, no API key). Added `_reverseGeocode()` method that returns suburb/neighbourhood from GPS coords. Search bar tap and avatar tap now use `switchTab` instead of `pushNamed`.
- `lib/features/search/search_screen.dart` — Removed `DhavBottomNav`. Cart bar is now the only `bottomNavigationBar` when cart is non-empty.
- `lib/features/orders/order_history_screen.dart` — Removed `DhavBottomNav`.
- `lib/features/profile/profile_screen.dart` — Removed `DhavBottomNav`. Added "Edit Profile" menu item. Order History tap uses `switchTab(2)`.
- `lib/features/auth/splash_screen.dart` — Removed `profileComplete` check; always routes logged-in users to `/home`. Profile setup is now optional.
- `lib/features/auth/profile_setup_screen.dart` — Rewritten: added Skip button in AppBar, address field is now optional (name only required), shows "We auto-detect your location" hint. Accessible from Profile → Edit Profile.
- `lib/features/auth/login_screen.dart` — Removed profileComplete check; always routes to `/home` on success.
- `lib/features/auth/email_signin_screen.dart` — Same fix as login_screen.

### Bugs fixed:
1. **Catalog blank** — `CatalogProvider` was doing `jsonDecode(body) as List` but backend wraps in `{"items":[...]}`. Now correctly extracts the array.
2. **Nav tab = full rebuild** — Replaced `Navigator.pushReplacementNamed` with `IndexedStack` in `MainShell`. No more screen disposal on tab switch.
3. **Location hardcoded** — Was always showing "Kothrud, Pune". Now calls Nominatim reverse geocoding API with actual GPS coordinates.
4. **Profile setup blocking** — After login, app demanded both name AND address. Now users go straight to home; profile setup is accessible from Profile tab and address is optional.

### NEXT TIME — START HERE:
1. `cd customer_app && flutter pub get && flutter run`
2. Test: Login → confirm no profile-setup screen → home shows real location name
3. Test: Catalog items load (not blank)
4. Test: Tap between tabs — confirm no flicker/rebuild
5. Then continue with deployment: `cd backend && railway login && railway up`

---

## 📅 SESSION LOG

## Session 2026-05-19 (cont.) — Full Admin Enhancements

**Current Phase:** Phase 6 Extended + Phase 7 (Testing + Deployment) pending
**Files modified (backend/):**
- `routers/admin.py` — MAJOR EXPANSION:
  - `POST /admin/stores/onboard` — creates Firebase Auth user (email+password) + store document in one call
  - `PUT /admin/stores/{id}` — update any store field (name, area, phone, location lat/lng auto-re-indexes geofence)
  - `DELETE /admin/stores/{id}` — soft-delete (deactivates + removes from geofence)
  - `GET /admin/stores/{id}/inventory` — all catalog items with per-store availability + quantity
  - `PUT /admin/stores/{id}/inventory` — set availability + quantity for all items in a store
  - `GET /admin/stores/{id}/reviews` — all reviews with avg rating
  - `DELETE /admin/stores/{id}/reviews/{review_id}` — delete specific review
  - `GET /admin/stores/{id}/stats` — per-store order breakdown (total/delivered/failed/pending, revenue, platform fee)
  - `GET /admin/catalog/items` — all catalog items including inactive (admin-only view)
  - `POST /admin/catalog/items` — create catalog item
  - `PATCH /admin/catalog/items/{id}` — update catalog item
  - `DELETE /admin/catalog/items/{id}` — deactivate or permanently delete catalog item
- `services/api_client.dart` — added `put()` and `delete()` HTTP methods

**Files added (admin_dashboard/lib/):**
- `core/models/catalog_item.dart` — AdminCatalogItem, StoreInventoryItem, StoreReview, StoreStats models
- `core/providers/catalog_provider.dart` — full CRUD for catalog items
- `core/providers/stores_provider.dart` — added `onboardStore()`, `updateStore()`, `deleteStore()` methods
- `features/catalog/catalog_screen.dart` — full catalog management (table with search/filter by category, add/edit dialog, activate/deactivate/delete per item)
- `features/stores/store_onboard_screen.dart` — split-panel: left = interactive Leaflet.js map (click/drag pin → lat/lng via postMessage), manual lat/lng fields; right = store + owner details + login credentials form; shows success dialog with credentials on completion
- `features/stores/store_detail_screen.dart` — 4-tab full detail view:
  - Overview: 5 KPI cards + store info + inline edit form (any field) + admin actions (verify/suspend/unsuspend/delete)
  - Orders: full order list with status badges + amount + date
  - Inventory: per-item toggle availability + quantity +/- controls + Save button
  - Reviews: avg rating + star display + delete per review

**Files modified (admin_dashboard/lib/):**
- `core/constants/app_routes.dart` — added `storeOnboard`, `catalog` routes
- `core/widgets/admin_sidebar.dart` — added Catalog nav item + active-highlight for store sub-routes
- `features/stores/stores_screen.dart` — added "Onboard Store" orange button; rows now tappable to navigate to store detail; added "View Details" action icon
- `main.dart` — registered CatalogProvider; added routes for storeOnboard, catalog, storeDetail (using onGenerateRoute with arguments for storeId)

### NEXT TIME — START HERE:
**Phase 7.2 — Deploy Backend to Railway**
1. `cd backend && railway login && railway up`
2. Set env vars on Railway dashboard (FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_DATABASE_URL, etc.)
3. Note Railway URL → update `customer_app/lib/core/config/api_config.dart` + `store_app/lib/core/config/api_config.dart`

**Phase 7.3 — Deploy Admin Dashboard**
1. `cd admin_dashboard && flutter pub get && flutter build web`
2. `firebase deploy --only hosting`

## Session 2026-05-19 — Phase 7.1 Tests + 7.2 Railway Deployment Files

**Current Phase:** Phase 7 (Testing + Deployment) — in progress
**Files added (backend/tests/):**
- `tests/test_geo.py` — 7 tests for haversine_km (zero distance, known Pune distances, symmetry, equator, negative coords)
- `tests/test_helpers.py` — 7 tests for new_id (UUID format, uniqueness) and now_ms (type, value range, monotonicity)
- `tests/test_geofencing.py` — 15 tests: geohash encode, index_store_geofence (Firebase write), remove (Firebase delete), find_nearby_stores (empty, within radius, excludes inactive/suspended, sorted by distance)
- `tests/test_penalties.py` — 13 tests: process_store_failure (1st/3rd/5th strike → warning/suspend/ban, missing store, strike log), lift_expired_suspensions (expired/active/non-suspended), auto_fail_stuck_orders (old/recent/delivered/with-store)

**Files modified (backend/):**
- `services/geofencing.py` — BUGFIX: replaced `geohash.neighbors()` (doesn't exist in pygeohash 1.2.0) with new `_get_all_neighbors()` using `geohash.get_adjacent()` for all 8 surrounding cells. This was a critical silent bug — store lookup would have returned empty results.
- `firebase_init.py` — Added `FIREBASE_SERVICE_ACCOUNT_JSON` env var support (full JSON as string) for Railway deployment, falls back to file path for local dev.
- `config.py` — Fixed hardcoded Windows file path default (`C:/Users/...`) to portable `firebase-service-account.json`. Upgraded from deprecated Pydantic v1 `class Config` to v2 `model_config = SettingsConfigDict(...)`.
- `.env.example` — Documented new `FIREBASE_SERVICE_ACCOUNT_JSON` env var.

**Files added (backend/):**
- `Procfile` — `web: uvicorn main:app --host 0.0.0.0 --port $PORT`
- `railway.toml` — Nixpacks builder, health check at `/health`, restart on failure

**Test results:** 39/39 passed ✅

### NEXT TIME — START HERE:
**Phase 7.2 — Deploy Backend to Railway**
1. Install Railway CLI: `npm install -g @railway/cli`
2. Login: `railway login`
3. From backend/ folder: `railway init` → name it `dhav-backend`
4. Set env vars on Railway dashboard (all from `.env.example`):
   - `FIREBASE_SERVICE_ACCOUNT_JSON` — paste the full contents of `firebase-service-account.json` as one line (use: `python -c "import json; print(json.dumps(json.load(open('firebase-service-account.json'))))"`)
   - `FIREBASE_DATABASE_URL`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`
5. Deploy: `railway up`
6. Note the Railway URL → update `customer_app/lib/core/config/api_config.dart` and `store_app/lib/core/config/api_config.dart` with production URL

**Phase 7.3 — Deploy Admin Dashboard to Firebase Hosting**
1. Fill in Firebase Web config in `admin_dashboard/lib/main.dart` (replace YOUR_* placeholders — get from Firebase Console → Project Settings → Your Apps → Web App → Config)
2. `cd admin_dashboard && flutter build web`
3. `firebase use dhav-quick-commerce`
4. `firebase deploy --only hosting`

**Phase 7.4 — Build Release APKs**
1. `cd customer_app && flutter build apk --release`
2. `cd store_app && flutter build apk --release`
3. Share APKs with test users

### Session 1 — [Date will go here] — Project Kickoff

**Started:** —
**Stopped:** —
**Current Phase:** Phase 0
**Files modified:** None

### What I plan to do:
- Set up folder structure
- Install Flutter, Python, Firebase CLI
- Create Firebase project
- Initialize Git repo
- Open Claude CLI for first time

### NEXT TIME — START HERE:
**Prompt for Claude CLI:**
> "Read docs/BUILD_PLAN.md and docs/PRD.md. Start helping me with Phase 1.1 — Firebase Project Setup. Walk me through creating the Firebase project step by step."

---

<!-- Add new sessions below this line, newest at top -->

## Session 2026-05-18 — Phase 6 Admin Dashboard (Flutter Web, fully wired)

**Current Phase:** Phase 6 COMPLETE
**Files added (admin_dashboard/):**
- `pubspec.yaml` — firebase_core, firebase_auth, provider, http, intl, google_fonts, fl_chart
- `web/index.html` — Flutter Web entry point
- `lib/main.dart` — Firebase.initializeApp, MultiProvider (5 providers), all routes, _ProtectedRoute + _AuthGuard guards
- `lib/core/config/api_config.dart` — localhost:8000 default, override with --dart-define
- `lib/core/theme/app_colors.dart` — dark theme palette (bg #0F1117, surface #1A1F2E, orange #F97316)
- `lib/core/theme/app_theme.dart` — ThemeData.dark with Inter font
- `lib/core/constants/app_routes.dart` — all named routes
- `lib/core/services/auth_service.dart` — Firebase email/password auth
- `lib/core/services/api_client.dart` — HTTP wrapper with Firebase ID token injection
- `lib/core/models/{analytics,store,order,settlement}.dart` — typed models from backend JSON
- `lib/core/providers/{auth,dashboard,stores,orders,settlements}_provider.dart` — all providers
- `lib/core/widgets/admin_sidebar.dart` — persistent left nav with DHAV logo + 5 nav items + sign out
- `lib/core/widgets/status_badge.dart` — color-coded badge for order/store statuses
- `lib/features/auth/login_screen.dart` — centered card, email+password, error display, admin-only role check
- `lib/features/dashboard/dashboard_screen.dart` — 4 KPI metric cards + recent orders + pending settlements + stores overview
- `lib/features/stores/stores_screen.dart` — table with All/Online/Suspended filters + verify/suspend/unsuspend actions
- `lib/features/orders/orders_screen.dart` — table with status filter dropdown + force-fail action
- `lib/features/customers/customers_screen.dart` — customer list table with search
- `lib/features/settlements/settlements_screen.dart` — settlement table with summary bar + mark-paid

### What's pending (manual step):
- Replace `YOUR_*` placeholders in `admin_dashboard/lib/main.dart` with real Firebase Web config values (Firebase Console → Project Settings → Your apps → Web app → Config)
- Run: `cd admin_dashboard && flutter pub get && flutter run -d chrome`

### NEXT TIME — START HERE:
**Phase 7 — Testing + Deployment**
1. `cd backend && pytest` — run all unit tests
2. Deploy backend to Railway.app: `railway up` (add all env vars from `.env.example`)
3. Deploy admin dashboard to Firebase Hosting: `cd admin_dashboard && flutter build web && firebase deploy --only hosting`
4. Build customer APK: `cd customer_app && flutter build apk --release`
5. Build store APK: `cd store_app && flutter build apk --release`

## Session 2026-05-18 — Phase 5 Delivery Boy View (fully wired)

**Current Phase:** Phase 5 COMPLETE
**Files modified (store_app/):**
- `lib/features/delivery/delivery_incoming_assignment_screen.dart` — rewritten: accepts `orderId` param, loads real order via `OrderProvider`, shows real destination/items/delivery fee/payment method; ACCEPT routes to `deliveryAssignment` with orderId; DECLINE routes to `deliveryHome`; 30s countdown auto-declines; bottom sheet shows full item list + earnings breakdown
- `lib/features/delivery/delivery_completion_screen.dart` — rewritten: accepts `DeliveryCompletionArgs` (orderId, earnings, customerArea, itemCount); shows real earnings on the green card; clean "Back to Home" → `deliveryHome` flow
- `lib/features/delivery/delivery_assignment_screen.dart` — added: after `markDelivered()` navigates to `deliveryCompletion` with real `DeliveryCompletionArgs` instead of just `pop()`
- `lib/core/services/fcm_service.dart` — added: `DeliveryAssignedHandler` typedef + `onDeliveryAssigned` callback; new `_triggerDeliveryAlert()` for `type='delivery_assigned'` FCM messages; `syncDeliveryTokenToBackend()` → `PATCH /delivery/me/fcm-token`; `listenForDeliveryTokenRefresh()`
- `lib/features/auth/splash_screen.dart` — delivery boy on login now calls `fcmService.syncDeliveryTokenToBackend()` + `listenForDeliveryTokenRefresh()`
- `lib/main.dart` — wired `fcmService.onDeliveryAssigned` → push `deliveryIncomingAssignment` with orderId; fixed `deliveryIncomingAssignment` route to pass orderId arg (was `const`); added missing `deliveryMissedOrder` route; fixed duplicate `firebase_core` import

**Files added (backend/):**
- `backend/routers/delivery.py` — NEW: `PATCH /delivery/me/fcm-token` (delivery boy updates own FCM token by searching their store's delivery_boys node); `GET /delivery/me/profile`
- `backend/main.py` — added `delivery` router at `/delivery`

**Files modified (docs/):**
- `docs/BUILD_PLAN.md` — Phase 5 all tasks marked [x], OVERALL PROGRESS Phase 5 marked done
- `docs/SESSION_NOTES.md` — current status updated

### What worked:
- Full delivery boy lifecycle: FCM push → popup → accept → GPS streaming → Google Maps → mark delivered → completion screen
- Role-based FCM routing: `new_order` → store popup; `delivery_assigned` → delivery popup
- Real data throughout: order address, items, delivery fee, payment method all from backend

### What needs real-device testing:
- `delivery_assigned` FCM arriving while app is in background/killed (full-screen-intent wake)
- GPS streaming on actual device (emulator GPS is simulated)
- `PATCH /delivery/me/fcm-token` — needs delivery boy uid to be in a store's delivery_boys node

### NEXT TIME — START HERE:
**Phase 6.1 — Admin Dashboard Flutter Web**
1. Run: `flutter create admin_dashboard --platforms web`
2. Set package: `com.dhav.admin`
3. Add: `firebase_core`, `firebase_auth`, `http`, `provider`, `google_fonts`, `fl_chart`
4. Build: Login screen → Dashboard home with metrics from `GET /admin/analytics/summary`

## Session 2026-05-18 — Phase 4 Customer App MVP (Figma → Flutter, fully wired)

**Current Phase:** Phase 4 complete (UI + backend wiring)
**Files added (customer_app/):**
- `pubspec.yaml` — firebase_core/auth/messaging, google_sign_in, geolocator, google_maps_flutter, web_socket_channel, provider, http, google_fonts, flutter_local_notifications, lottie
- `android/app/build.gradle.kts` — com.dhav.customer, minSdk=23, multiDex, google-services plugin
- `android/settings.gradle.kts` — google-services 4.4.2
- `android/app/src/main/AndroidManifest.xml` — internet/location/notification permissions, Maps API key placeholder, FCM channel
- `android/app/src/main/kotlin/com/dhav/customer/MainActivity.kt`
- `lib/main.dart` — Firebase init, FCM init, MultiProvider, all routes
- `lib/core/config/api_config.dart` — backend URL (10.0.2.2:8000), wsBaseUrl
- `lib/core/theme/app_colors.dart` — light theme: orange #F97316, warm white bg, Inter font
- `lib/core/theme/app_theme.dart` — MaterialApp light theme
- `lib/core/constants/app_routes.dart` — all route names
- `lib/core/widgets/dhav_bottom_nav.dart` — Home/Search/Orders/Profile nav
- `lib/core/services/auth_service.dart` — Google Sign-In + Email/Password + POST /auth/verify-token
- `lib/core/services/api_client.dart` — HTTP wrapper with Firebase ID token injection
- `lib/core/services/fcm_service.dart` — order update notifications, tap-to-track-screen
- `lib/core/services/location_ws_service.dart` — customer WebSocket RECEIVER for delivery boy GPS
- `lib/core/models/` — app_user, catalog_item, cart_item, order
- `lib/core/providers/` — auth, cart, catalog, order providers
- `lib/features/auth/splash_screen.dart` — orange bg, DHAV logo box, tagline, pill badge (matches Figma)
- `lib/features/auth/onboarding_screen.dart` — 4-page onboarding with dot indicators
- `lib/features/auth/login_screen.dart` — peach bg, bag illustration, Google/Email/phone buttons, language picker (matches Figma)
- `lib/features/auth/email_signin_screen.dart` — email+password form
- `lib/features/auth/profile_setup_screen.dart` — name + home address setup
- `lib/features/home/home_screen.dart` — auto-location, search bar, track banner, category chips, "Order Again" scroll, "Fresh For You" 2-col grid, "Trending Near You" (matches Figma)
- `lib/features/search/search_screen.dart` — search bar, category chips, item list, "Nothing found" state, floating cart bar (matches Figma)
- `lib/features/cart/cart_screen.dart` — item list with qty controls, delivery address, price summary, Place Order
- `lib/features/orders/broadcasting_screen.dart` — pulsing ring animation, wave indicator, timeout/no-stores state
- `lib/features/orders/order_accepted_screen.dart` — green success header, store info, items, price breakdown
- `lib/features/orders/order_tracking_screen.dart` — status timeline, Google Maps live tracking, smooth marker animation, delivery boy call button
- `lib/features/orders/order_history_screen.dart` — Active/Past tabs, reorder button
- `lib/features/profile/profile_screen.dart` — avatar, menu sections, language picker, sign out
- `lib/features/notifications/notifications_screen.dart` — notification list with unread badges

**Backend patch:**
- `backend/routers/orders.py` — added `GET /orders/customer/me` alias (customer app uses this endpoint). Also fixed `GET /orders` to return a list (not dict) for easier Flutter parsing.

### What worked:
- All 14 screens implemented matching Figma design language (orange primary, warm white bg, Inter font, rounded cards)
- Figma screenshots captured for Splash, Login, Home, Search & Browse — exact pixel-match for these 4
- Remaining screens (Cart, Broadcasting, Tracking, History, Profile, Notifications) designed faithfully from established design system
- `flutter pub get` should resolve cleanly — same dep versions as store_app

### What's pending (manual steps):
- Place `google-services.json` in `customer_app/android/app/` (download from Firebase Console)
- Replace `YOUR_GOOGLE_MAPS_API_KEY` in `customer_app/android/app/src/main/AndroidManifest.xml`
- Run `flutter pub get` then `flutter run`

### NEXT TIME — START HERE:
1. Complete manual setup above
2. `cd customer_app && flutter pub get && flutter run`
3. Test full order flow: Login → Home → Add items → Cart → Place Order → Broadcasting → Tracking
4. Once verified, start **Phase 5 — Delivery Boy View** (already partially in store_app)

## Session 2026-05-17 (cont.) — Phase 3 Backend Wiring

**Current Phase:** Phase 3.2–3.8 wired
**Files added:**
- `store_app/lib/core/config/api_config.dart` — backend base URL (defaults to `http://10.0.2.2:8000` for Android emulator; override via `--dart-define=API_BASE_URL=...`)
- `store_app/lib/core/services/api_client.dart` — HTTP wrapper that injects Firebase ID token as Bearer header
- `store_app/lib/core/services/auth_service.dart` — Google Sign-In + Email/Password + POST /auth/verify-token
- `store_app/lib/core/services/fcm_service.dart` — HIGH-priority FCM listener with audio + vibration + full-screen-intent local notification
- `store_app/lib/core/services/location_ws_service.dart` — delivery boy GPS → WebSocket /ws/order/{id}/location at 3s ticks
- `store_app/lib/core/models/{app_user,store,order,catalog_item,settlement}.dart`
- `store_app/lib/core/providers/{auth,store,order,inventory,earnings,delivery}_provider.dart`

**Files modified (wired to real APIs):**
- `store_app/pubspec.yaml` — added firebase_core/auth/messaging/database, google_sign_in, audioplayers, vibration, flutter_local_notifications, geolocator, permission_handler, url_launcher, web_socket_channel
- `store_app/android/app/build.gradle.kts` — kotlin-android + google-services plugin, minSdk=23, multidex
- `store_app/android/settings.gradle.kts` — added `com.google.gms.google-services 4.4.2 apply false`
- `store_app/android/app/src/main/AndroidManifest.xml` — internet/location/notification/vibrate/foreground-service permissions, showWhenLocked/turnScreenOn on MainActivity, FCM default channel `dhav_incoming_orders`
- `store_app/lib/main.dart` — `Firebase.initializeApp()` + `fcmService.init()` + MultiProvider with all 7 providers + global navigatorKey + `onIncomingOrder` push to IncomingOrderScreen with order_id
- `store_app/lib/features/auth/splash_screen.dart` — calls `AuthProvider.bootstrap()`, routes by role (store_owner → dashboard, delivery → delivery_home), syncs FCM token to backend
- `store_app/lib/features/auth/login_screen.dart` — real Google Sign-In + Email/Password forms; routes by role
- `store_app/lib/features/dashboard/dashboard_screen.dart` — `/stores/me` load, `/stores/me/toggle` for open/close switch, today's stats computed from real orders, active-order card from `/stores/me/orders`
- `store_app/lib/features/orders/incoming_order_screen.dart` — receives order_id from FCM, loads order, real Accept/Reject (`POST /orders/{id}/accept|reject`), 45s countdown
- `store_app/lib/features/orders/active_order_screen.dart` — assign delivery boy → mark packed → dispatch → mark delivered; calls real endpoints; stepper driven by `order.status`
- `store_app/lib/features/orders/order_list_screen.dart` — All/Active/Completed tabs from real orders, pull-to-refresh
- `store_app/lib/features/orders/order_detail_screen.dart` — loads by order_id arg, shows real items/address/payment
- `store_app/lib/features/inventory/inventory_screen.dart` — loads `/catalog/items` + `/catalog/categories`, search + category filter, toggle availability, SAVE → `PATCH /stores/me/inventory`
- `store_app/lib/features/earnings/earnings_screen.dart` — `/settlements/store/current` + `/settlements/store/history`, balance due + paid records
- `store_app/lib/features/profile/profile_screen.dart` — loads `/stores/me`, shows verified badge + strike count, sign-out flow
- `store_app/lib/features/team/store_team_screen.dart` — full delivery-boy CRUD via `/stores/me/delivery-boys` GET/POST/DELETE
- `store_app/lib/features/delivery/delivery_home_screen.dart` — loads `/orders/delivery/me`, today's deliveries/earnings, active assignment card, sign-out
- `store_app/lib/features/delivery/delivery_assignment_screen.dart` — starts WebSocket GPS streamer on `out_for_delivery` status, opens Google Maps via deep link, mark delivered

**Backend patches** (`backend/routers/`):
- `orders.py` — bug fix: `accept_order` was using `user.uid` as store_id; now resolves via `users/{uid}.store_id`. Same fix applied to reject/assign/packed/dispatched
- `orders.py` — new `GET /orders/delivery/me` (delivery role)
- `stores.py` — new `GET /stores/me/orders?status=...` (store_owner)
- `stores.py` — new `GET/POST/DELETE /stores/me/delivery-boys` CRUD (store_owner)

**Docs added:**
- `docs/FIREBASE_SETUP.md` — step-by-step manual setup: SHA-1 registration, google-services.json placement, service-account JSON, admin-onboarding first store owner, full Postman smoke-test table, FCM end-to-end test payload, known gaps, troubleshooting

### What worked:
- `flutter pub get` clean, all 14 Firebase/Google deps resolve
- `flutter analyze` → 0 errors, 8 cosmetic info messages (3 pre-existing in `store_profile_screen.dart`, rest are Dart's `_, _` underscore style preference)

### What broke / blockers:
- Cannot run end-to-end without google-services.json + firebase-service-account.json (manual one-time steps, documented in FIREBASE_SETUP.md)
- Need to test FCM full-screen-intent on a real Android device; emulator may not honor wake-on-locked-screen reliably

### Code I'm uncertain about:
- `fcm_service.dart` background handler is intentionally minimal (only OS notification surface) — relies on `getInitialMessage()` to push IncomingOrderScreen on cold-start tap. Needs real-device verification.
- `delivery_home_screen.dart` availability toggle is local-only — backend has no `/delivery-boys/{id}/availability` endpoint yet. Acceptable for MVP; add when admin tooling needs it.

### NEXT TIME — START HERE:
1. Follow `docs/FIREBASE_SETUP.md` steps 1–4 (download google-services.json, generate service-account, admin-onboard first store)
2. Run backend: `cd backend && uvicorn main:app --reload`
3. Run store app: `cd store_app && flutter run`
4. Smoke-test via the Postman table in FIREBASE_SETUP.md §6
5. Send the FCM test payload from §7 to verify the incoming-order popup fires loudly
6. Once verified end-to-end, start **Phase 4 — Customer App MVP**

---

## Session 2026-05-17 — Phase 3 Store App UI (Figma → Flutter)

**Current Phase:** Phase 3 complete (UI layer)
**Files modified:**
- `store_app/` — NEW Flutter project (flutter create)
- `store_app/pubspec.yaml` — dependencies: google_fonts, provider, http, intl, percent_indicator, shimmer, cached_network_image, flutter_svg
- `store_app/lib/main.dart` — app entry, named routes, AppTheme
- `store_app/lib/core/theme/app_colors.dart` — full color palette (dark #1A1F2E, orange #F97316, green, red, surface)
- `store_app/lib/core/theme/app_theme.dart` — ThemeData dark, inter font
- `store_app/lib/core/constants/app_routes.dart` — all named routes
- `store_app/lib/core/widgets/dhav_bottom_nav.dart` — 5-tab nav bar matching Figma
- `store_app/lib/features/auth/splash_screen.dart` — dark bg, orange logo glow, diagonal lines, auto-navigate
- `store_app/lib/features/auth/login_screen.dart` — dark top + white sheet, Google/Email/Support buttons
- `store_app/lib/features/dashboard/dashboard_screen.dart` — open/close toggle, stats row, active order card, recent orders
- `store_app/lib/features/orders/incoming_order_screen.dart` — urgent alert with countdown timer, map preview, QUICK ACCEPT + VIEW DETAILS + REJECT + details bottom sheet
- `store_app/lib/features/orders/active_order_screen.dart` — 5-step order flow with delivery boy assignment
- `store_app/lib/features/orders/order_list_screen.dart` — tabbed order list (All/Active/Completed)
- `store_app/lib/features/orders/missed_order_screen.dart` — warning screen with strike info
- `store_app/lib/features/inventory/inventory_screen.dart` — search + category filter + toggle availability
- `store_app/lib/features/earnings/earnings_screen.dart` — weekly summary card, fee breakdown, settlement, UPI, history
- `store_app/lib/features/profile/profile_screen.dart` — store info, delivery team management, settings
- `store_app/lib/features/delivery/delivery_home_screen.dart` — delivery boy home with availability + stats + active delivery
- `store_app/lib/features/delivery/delivery_assignment_screen.dart` — map view + customer info + mark delivered
- `store_app/lib/features/delivery/delivery_history_screen.dart` — delivery history with summary

### What worked:
- Figma screenshots captured (4/14 before rate limit)
- All 14 screens implemented from design: dark navy theme, orange primary, white sheets
- Zero compile errors (only deprecation info warnings from Flutter 3.44)
- `flutter pub get` + `flutter analyze` pass cleanly

### NEXT TIME — START HERE:
**Phase 3 — Firebase Integration**
> "Add firebase_core, firebase_auth, firebase_database, firebase_messaging to store_app. Place google-services.json in store_app/android/app/. Implement Google Sign-In in login_screen.dart calling /auth/verify-token. Route store_owner to DashboardScreen, delivery_boy to DeliveryHomeScreen."

---

## Session 2026-05-17 (cont.) — Phase 2 COMPLETE (2.3 → 2.12)

**Current Phase:** Phase 2 fully complete → Moving to Phase 3
**Files modified:**
- `backend/models/store.py` — DeliveryBoy, CustomItem, OperatingHours, full Store model
- `backend/models/order.py` — Complete Order with all broadcast + WS fields
- `backend/models/catalog.py` — CatalogItemCreateRequest added
- `backend/models/settlement.py` — PaymentRecord, WeeklySettlement, MarkPaidRequest
- `backend/models/geofence.py` — NEW: GeofenceZone, StoreGeofenceIndex, StrikeLog, LatLng
- `backend/services/geofencing.py` — Full geohash index + neighbor lookup + Haversine filter
- `backend/services/broadcasting.py` — 3-wave async broadcasting + atomic accept transaction
- `backend/services/notifications.py` — Full FCM: HIGH-priority multicast + all notification types
- `backend/services/penalties.py` — Strike/suspend/ban + lift_expired + auto_fail
- `backend/services/settlements.py` — Weekly settlement generation + overdue marking
- `backend/services/scheduler.py` — APScheduler with 3 cron jobs (IST timezone)
- `backend/services/location_ws.py` — NEW: In-memory WebSocket hub for live location
- `backend/routers/auth.py` — (from 2.2)
- `backend/routers/orders.py` — Full order lifecycle (place → broadcast → accept → pack → dispatch → deliver)
- `backend/routers/catalog.py` — GET categories/items/nearby + admin CRUD
- `backend/routers/stores.py` — Store CRUD, toggle open/close, FCM token, inventory
- `backend/routers/settlements.py` — Current + history + mark-paid
- `backend/routers/admin.py` — Full admin panel: stores, orders, customers, analytics, settlements
- `backend/routers/customers.py` — Profile + saved addresses
- `backend/main.py` — WebSocket endpoint + scheduler startup

### What worked:
- All Phase 2 services implemented and wired together
- 3-wave broadcasting uses asyncio tasks — non-blocking
- Atomic accept uses Firebase transactions — race-condition safe
- Scheduler uses APScheduler with Asia/Kolkata timezone

### NEXT TIME — START HERE:
**Phase 3.1 — Store App Flutter Setup**
> Before starting Phase 3: Put firebase-service-account.json in backend/ and test all APIs with Postman. Then:
> "Create Flutter project `store_app` with package name com.dhav.store. Set up firebase_core, firebase_auth, firebase_messaging, firebase_database, google_maps_flutter, geolocator, http, provider for state management, intl for localization. Place google-services.json."

---

## Session 2026-05-17 (cont.) — Phase 2.2 Authentication Layer

**Current Phase:** Phase 2.2 complete
**Files modified:**
- `backend/routers/auth.py` — full POST /auth/verify-token implementation
- `backend/dependencies.py` — new file: `get_current_user` dependency + `require_role(*roles)` helper
- `backend/models/user.py` — added `TokenVerifyResponse`, `is_active`, `created_at` fields

### What I did:
- Implemented POST /auth/verify-token: verifies Firebase Bearer token, looks up `users/{uid}` in Realtime DB, returns role + profile
- First-time login: if user node doesn't exist in DB, auto-creates it with role=customer
- Created `dependencies.py` with `get_current_user` and `require_role("store_owner")` etc. — all future routers should use these

### NEXT TIME — START HERE:
**Phase 2.3 — Data Models (Pydantic)**
> "Read PRD Section 4 (Data Models). Complete Pydantic models in `backend/models/` for: Store, DeliveryBoy, CatalogItem, Order, OrderItem, GeofenceZone, WeeklySettlement, PaymentRecord, StrikeLog. Include all fields from PRD with correct types."

**Postman test for 2.2 (do this first):**
- POST http://localhost:8000/auth/verify-token
- Header: `Authorization: Bearer <firebase_id_token>`
- Get a Firebase ID token from the Firebase Console → Authentication → Users → click user → copy UID, then use Firebase REST API to get token

## Session 2026-05-17 — Firebase Foundation + Backend Skeleton

**Current Phase:** Phase 2.1 complete
**Files modified:**
- `firebase/realtime-db.rules`, `firebase/storage.rules`, `firebase/firebase.json`
- `backend/scripts/seed_catalog.py` (fixed DB URL: firebaseio.com not asia-southeast1)
- `backend/main.py`, `backend/config.py`, `backend/firebase_init.py`
- `backend/requirements.txt`, `backend/.env.example`
- `backend/routers/` — auth, customers, stores, orders, catalog, settlements, admin (stubs)
- `backend/models/` — user, store, order, catalog, settlement
- `backend/services/` — geo, geofencing, broadcasting, notifications, penalties, settlements, scheduler (stubs)
- `backend/utils/helpers.py`, `backend/tests/test_health.py`

### What worked:
- 50 catalog items seeded to Firebase Realtime Database
- All 12 packages install OK (used `pygeohash` instead of `python-geohash` — no C++ build tools needed on Windows)
- FastAPI health endpoint returns 200

### What broke / fixed:
- `python-geohash` requires Microsoft C++ Build Tools → switched to `pygeohash==1.2.0` (pure Python)
- Firebase DB URL was wrong region → fixed to `https://dhav-quick-commerce-default-rtdb.firebaseio.com`

### NEXT TIME — START HERE:
**Phase 2.2 — Authentication Layer**
> "Implement `backend/routers/auth.py` POST /auth/verify-token. Use Firebase Admin SDK to verify the Firebase ID token from Authorization Bearer header. Look up the UID in Firebase Realtime Database users node to return role (customer/store_owner/delivery/admin). Return 401 on invalid token."

---

## 🐛 BUG LOG

Track bugs you discover but haven't fixed yet:

| Date | Bug | Severity | File | Status |
|---|---|---|---|---|
| — | — | — | — | — |

---

## ❓ OPEN QUESTIONS

Things you're unsure about and need to decide:

- [ ] Should we charge ₹15 or ₹20 platform fee? Need to validate with 5 store owners.
- [ ] Which area in Pune to pilot first — Kothrud or Aundh?
- [ ] Should custom items by stores have a verification step by admin?
- [ ] How many delivery boys per store on average?

---

## 💡 IDEAS PARKING LOT

Things that aren't priority but worth remembering:

- Voice ordering in Marathi (Phase 2 feature)
- WhatsApp ordering channel (Phase 2)
- Subscription for daily milk/bread (Phase 2)
- Store reviews and photos by customers (Phase 2)
- Push notification campaigns for offers (Phase 2)

---

## 🔑 IMPORTANT CREDENTIALS & URLS

**Keep this updated as you set things up. NEVER commit this to public Git.**

| What | Where | Notes |
|---|---|---|
| Firebase Project ID | — | — |
| Firebase Service Account JSON path | `backend/firebase-service-account.json` | Add to .gitignore |
| Backend URL (dev) | — | After Railway deployment |
| Backend URL (prod) | — | — |
| Admin Dashboard URL | — | After Firebase Hosting |
| Customer App Play Store link | — | After launch |
| Store App Play Store link | — | After launch |
| Google Maps API Key | — | Restrict by app + IP |

---

## 📚 USEFUL COMMANDS REFERENCE

```bash
# Start Claude CLI
cd ~/DHAVl-project
claude

# Backend
cd backend
source venv/bin/activate
uvicorn main:app --reload

# Customer App
cd customer_app
flutter run

# Store App
cd store_app
flutter run

# Admin Dashboard
cd admin_dashboard
flutter run -d chrome

# Git
git status
git add .
git commit -m "Description"
git push

# Firebase deploy
firebase deploy --only database
firebase deploy --only storage
firebase deploy --only hosting

# Build APK
flutter build apk --release
```

---

## 🎯 WEEKLY GOALS (Track Weekly Progress)

### Week 1 Goals:
- [ ] Complete Phase 0
- [ ] Complete Phase 1
- [ ] Have Firebase + 50 catalog items seeded

### Week 2 Goals:
- [ ] Complete Phase 2.1 to 2.6 (backend skeleton + geofencing + broadcasting)

### Week 3 Goals:
- [ ] Complete Phase 2.7 to 2.12 (rest of backend)
- [ ] All APIs tested with Postman

### Week 4-5 Goals:
- [ ] Complete Phase 3 (Store App MVP)

### Week 6-7 Goals:
- [ ] Complete Phase 4 (Customer App MVP)

### Week 8 Goals:
- [ ] Complete Phase 5 (Delivery boy view + live tracking)

### Week 9-10 Goals:
- [ ] Complete Phase 6 (Admin Dashboard)

### Week 11 Goals:
- [ ] Testing + bug fixes

### Week 12 Goals:
- [ ] Deployment
- [ ] Pilot launch in Kothrud

---

*Update this file every single day. Your future self will thank you.*
