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

---

## ✅ ENHANCEMENT LOG (newest first)

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

- [ ] **Deploy backend** (`git push origin main` → Render) to ship the `/stores/me` `store_id`
      alias + `/stores/register` operating_hours fixes from 2026-06-14 (#2).
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
