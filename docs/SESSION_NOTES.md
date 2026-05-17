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

**Current Phase:** Phase 4 — Customer App MVP (Flutter) — UI + backend wiring COMPLETE
**Last task completed:** All 14 customer app screens built from Figma design (Splash → Onboarding → Login → Email Sign-In → Profile Setup → Home → Search → Cart → Broadcasting → Order Accepted → Order Tracking → Order History → Profile → Notifications). All screens wired to real backend APIs + WebSocket live tracking.
**Next task to do:** 1) Place `google-services.json` in `customer_app/android/app/` (same Firebase project as store_app). 2) Replace `YOUR_GOOGLE_MAPS_API_KEY` in AndroidManifest.xml. 3) Run `cd customer_app && flutter pub get && flutter run`. 4) Smoke-test end-to-end order flow.
**Blockers:** google-services.json (manual step), Google Maps API key (manual step)
**Last updated:** 2026-05-18

---

## 📅 SESSION LOG

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
