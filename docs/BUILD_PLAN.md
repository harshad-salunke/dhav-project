# 🛠️ DHAV — Build Plan & Progress Tracker

> ## ✅ ALL BUILD PHASES COMPLETE — PROJECT IS IN ENHANCEMENT MODE (since 2026-06-13)
> Don't plan work from this file anymore. Current work (UI enhancements, new features,
> gap-filling, architecture truth) is tracked in **`docs/ENHANCEMENTS.md`** — read that
> instead. This file stays as the historical record of the original 12-week build.
>
> Note: the architecture changed after this plan was written — data moved from Firebase
> RTDB to **Supabase PostgreSQL**, hosting moved from Railway to **Render**. Firebase
> remains for Auth + FCM only. See ENHANCEMENTS.md → Current Architecture.

**Purpose:** This is your master roadmap. Every time you sit down to work with Claude CLI, open this file FIRST. It tells you exactly where you are and what to build next.

**How to use:** When a task is done, mark `[x]`. When you stop a session, note where you stopped in `SESSION_NOTES.md`.

---

## 📊 OVERALL PROGRESS

- [x] Phase 0: Project Setup (Week 1)
- [x] Phase 1: Firebase Foundation (Week 1-2)
- [x] Phase 2: FastAPI Backend Core (Week 2-4)
- [x] Phase 3: Store App MVP (Week 4-6)
- [x] Phase 4: Customer App MVP (Week 6-8)
- [x] Phase 5: Live Location + Delivery Boy (Week 8-9)
- [x] Phase 6: Admin Dashboard (Week 9-11)
- [x] Phase 7: Testing + Deployment (Week 11-12) — *built & deployed; pilot/soft-launch (7.3/7.4) moved to ENHANCEMENTS.md → Known Gaps*
- [x] Phase 8: System Design Improvements — Performance (ADDED 2026-05-28) — *incl. Postgres migration (old Phase D), done ~2026-06-06*

**Total estimated time:** 12 weeks for solo developer

---

## PHASE 8 — SYSTEM DESIGN IMPROVEMENTS (Performance)

> Reference: docs/SYSTEM_DESIGN_NOTES.md (concepts + teaching)
> Reference: docs/SYSTEM_DESIGN_IMPLEMENTATION.md (what's done + what's next)

### Phase A — Quick Wins (Zero new services needed)
- [x] A.1 — In-memory TTL cache for catalog (`backend/services/cache.py`)
- [x] A.2 — Async concurrent Firebase reads (replace N+1 loops)
- [x] A.3 — GZIP response compression (1 line in main.py)
- [x] A.4 — Background cache warming on server startup

### Phase A+ — Whole-app scaling (2026-05-30, zero new services for the core)
- [x] A+.1 — Unblock the event loop everywhere (`services/firebase_async.py`); converted orders/stores/catalog/broadcasting/WS
- [x] A+.2 — WebSocket memory-leak fix + lifecycle (`services/location_ws.py`); `close_order_channel` now actually called
- [x] A+.3 — Event-driven broadcasting (asyncio.Event + Redis signal) — removed 2 s polling
- [x] A+.5 — Bounded TTL cache (max_size eviction)
- [x] A+.7 — Push-driven customer UI: broadcasting/tracking screens react to FCM stream, poll slowed to 8s fallback (`customer_app`) — **needs APK rebuild**
- [x] A+.6 — Firebase `.indexOn` rules added/corrected (`firebase/realtime-db.json`); fixed wrong `delivery_boy_id` → `assigned_delivery_boy_id`. **Deploy: `firebase deploy --only database`**

### Phase B — Redis Pub/Sub + Shared Cache (multi-worker)
- [x] B.1 — Redis Pub/Sub bus (`services/redis_bus.py`) — WS tracking + accept signal across workers; auto-disables without REDIS_URL
- [x] B.2 — Cross-worker cache invalidation on catalog/store updates (`services/cache.invalidate`)
- [ ] B.3 — Provision Redis (Upstash / Render Redis — was "on Railway") + set `REDIS_URL` — *ops step, only when scaling; tracked in ENHANCEMENTS.md*
- [ ] B.4 — Run uvicorn with `--workers N` once Redis is live — *same*

### Phase C — CDN + Image Optimization
- ~~C.1 — Firebase Storage CDN Cache-Control headers~~ — *superseded: files now on Supabase Storage (CDN-backed)*
- [ ] C.2 — Thumbnail URLs for catalog items — *still a valid backlog idea (ENHANCEMENTS.md)*

### Phase D — Database Evolution ✅ DONE EARLY (~2026-06-06)
- [x] D.1 — PostgreSQL for catalog + orders (Supabase free tier) — *went further: ALL data moved to Supabase Postgres (`services/db.py`, `migrations/`); Firebase kept for Auth + FCM only*

---

## PHASE 0 — PROJECT SETUP (Week 1)

### 0.1 Folder Structure
- [ ] Create root folder `DHAVl-project/`
- [ ] Inside, create: `backend/`, `customer_app/`, `store_app/`, `admin_dashboard/`, `firebase/`, `docs/`
- [ ] Copy `PRD.md`, `BUILD_PLAN.md`, `SESSION_NOTES.md`, `ARCHITECTURE.md`, `API_SPECIFICATIONS.md` into `docs/`
- [ ] Initialize Git: `git init`
- [ ] Create `.gitignore` (add `.env`, `node_modules`, `build/`, `*.lock`)
- [ ] Push to GitHub private repo

### 0.2 Required Accounts & Tools
- [ ] Firebase account (free Spark plan to start)
- [ ] Google Cloud account (for Maps API)
- [ ] Railway.app account (for backend hosting later)
- [ ] Install Flutter SDK locally
- [ ] Install Python 3.11+
- [ ] Install Firebase CLI: `npm install -g firebase-tools`
- [ ] Install VSCode + Flutter + Python extensions
- [ ] Install Android Studio (for emulator)


**END OF PHASE 0 — You should have empty folders ready, all accounts created, and Claude CLI working.**

---

## PHASE 1 — FIREBASE FOUNDATION (Week 1-2)

### 1.1 Firebase Project Setup
- [ ] Create Firebase project named `DHAVl-pune`
- [ ] Enable Authentication → Google + Email/Password (NOT OTP)
- [ ] Enable Realtime Database (Mumbai region for lower latency)
- [ ] Enable Firebase Storage
- [ ] Enable Cloud Messaging (FCM)
- [ ] Download `google-services.json` (Android) for later
- [ ] Download `GoogleService-Info.plist` (iOS) for later
- [ ] Generate Service Account JSON for FastAPI backend

### 1.2 Security Rules
- [ ] Open `firebase/realtime-db.rules` and paste rules from PRD Section 23
- [ ] Open `firebase/storage.rules` and paste storage rules from PRD Section 23
- [ ] Deploy: `firebase deploy --only database`
- [ ] Deploy: `firebase deploy --only storage`

### 1.3 Initial Data Seeding (with Claude CLI)


- [ ] Run the seed script
- [ ] Verify 50 items appear in Firebase Console

**END OF PHASE 1 — Firebase is ready, security rules deployed, catalog seeded.**

---

## PHASE 2 — FASTAPI BACKEND CORE (Week 2-4)

### 2.1 Project Skeleton

- [x] All folders/files created
- [x] `requirements.txt` includes: fastapi, uvicorn, firebase-admin, pygeohash, apscheduler, websockets, python-dotenv, pytest
- [x] `.env.example` has all variables from PRD Section 17
- [x] `pip install -r requirements.txt` works
- [x] `uvicorn main:app --reload` runs without error

### 2.2 Authentication Layer

- [x] Token verification works
- [x] Role detection works
- [x] First-time login auto-creates user record with role=customer
- [x] `backend/dependencies.py` created with `get_current_user` + `require_role(*roles)` for use in all routers
- [ ] Test with Postman

### 2.3 Data Models (Pydantic)
- [x] All models created (user, store, order, catalog, settlement, geofence)
- [x] Models match PRD Section 4 field-for-field

### 2.4 Geofencing Service ⭐ CRITICAL
- [x] `index_store_geofence` — writes to Firebase geofence_index using pygeohash precision 6
- [x] `find_nearby_stores` — geohash neighbor cell lookup + Haversine filter
- [x] `remove_store_from_geofence_index` — used on suspension / overdue
- [ ] Write unit tests in `backend/tests/test_geofencing.py`

### 2.5 Catalog & Inventory APIs
- [x] GET /catalog/categories
- [x] GET /catalog/items (search + category filter)
- [x] GET /catalog/items/nearby (lat/lng + geofence)
- [x] POST/PATCH/DELETE /catalog/items (admin only)

### 2.6 Order Broadcasting Service ⭐ MOST CRITICAL
- [x] 3-wave async broadcasting (1km/45s → 2km/45s → 3km/60s)
- [x] FCM HIGH-priority multicast to all qualifying stores per wave
- [x] Atomic Firebase transaction — only one store wins acceptance
- [x] Auto-fail + customer FCM when all 3 waves exhausted

### 2.7 Order Lifecycle APIs
- [x] POST /orders (place + broadcast)
- [x] POST /orders/{id}/accept (atomic), /reject, /assign-delivery-boy
- [x] POST /orders/{id}/packed → dispatched → delivered (enforced sequence)
- [x] POST /orders/{id}/report-failure (triggers strike)
- [x] Invalid transitions return 409

### 2.8 Notifications Service
- [x] FCM multicast HIGH-priority to stores (new order alert)
- [x] Customer notifications: accepted, out_for_delivery, delivered, failed
- [x] Store notifications: order_taken, strike_warning, store_suspended
- [ ] Test HIGH priority on real Android device

### 2.9 Strike & Penalty Service
- [x] process_store_failure: strike increment, 3rd → 7-day suspend, 5th → permanent ban
- [x] lift_expired_suspensions (daily 6 AM IST cron)
- [x] auto_fail_stuck_orders (every 30 min cron)
- [x] APScheduler wired into app lifespan

### 2.10 Settlement Service
- [x] Weekly cron (Monday 8 AM IST) generates WeeklySettlement per store
- [x] Fee = sum of platform_fee_amount for delivered orders that week
- [x] Overdue marking + geofence removal for unpaid stores
- [x] GET /settlements/store/current and /history
- [x] POST /settlements/{id}/mark-paid (admin)

### 2.11 WebSocket Server for Live Location ⭐
- [x] /ws/order/{order_id}/location endpoint wired in main.py
- [x] Token verification before connection (401 on failure)
- [x] delivery_boy role: streams GPS → broadcasts to all listening customers
- [x] customer role: receives live GPS, ping/pong keepalive
- [x] In-memory only — nothing written to DB
- [x] Channel closed when order delivered (ws_channel_id → None)

### 2.12 Admin APIs
- [x] Store: list, get, verify, suspend, unsuspend
- [x] Orders: list (filter by status), force-fail
- [x] Customers: list, get
- [x] Settlements: list (filter by status)
- [x] Analytics: summary (total stores/orders, success rate, platform fee)
- [x] Role guard: admin only on all endpoints

**END OF PHASE 2 — Complete backend with all APIs, geofencing, broadcasting, WebSocket. Test thoroughly with Postman before moving on.**

---

## PHASE 3 — STORE APP MVP (Week 4-6)

### 3.1 Flutter Project Setup
- [x] Project runs on emulator
- [x] Firebase deps wired (firebase_core/auth/messaging/database, google_sign_in, FCM via flutter_local_notifications, audioplayers, vibration, geolocator, web_socket_channel, url_launcher, permission_handler) — see `store_app/pubspec.yaml`
- [x] Android Gradle wired for `google-services` plugin, minSdk=23, multidex, FCM permissions in AndroidManifest
- [ ] `google-services.json` placed (manual, per developer — see `docs/FIREBASE_SETUP.md`)

### 3.2 Authentication
- [x] Google Sign-In + Email/Password via `AuthService` + `AuthProvider`
- [x] POST /auth/verify-token called on login + on `bootstrap()`
- [x] Role-based routing in SplashScreen + LoginScreen: `store_owner` → DashboardScreen, `delivery` → DeliveryHomeScreen

### 3.3 Store Owner Dashboard
- [x] Big Open/Closed toggle bound to `PATCH /stores/me/toggle`
- [x] Today's stats computed from real orders (`GET /stores/me/orders`)
- [x] Active order card + recent orders list from real data
- [x] Pull-to-refresh

### 3.4 Incoming Order Popup ⭐ MOST CRITICAL UI
- [x] FCM HIGH-priority listener with audio + vibration + full-screen-intent notification via `FcmService`
- [x] Popup opens via global navigatorKey from `onIncomingOrder` callback
- [x] 45-second countdown bar (accurate per-second)
- [x] Quick Accept → `POST /orders/{id}/accept` → routes to ActiveOrderScreen
- [x] View Details → bottom sheet without stopping timer
- [x] Reject → `POST /orders/{id}/reject`
- [ ] **Real-device verification** still needed: FCM ring on silent mode + background wake-up

### 3.5 Active Order Management
- [x] Sequential step CTA driven by `order.status`: assign delivery boy → packed → dispatched → delivered
- [x] Delivery boy dropdown from `GET /stores/me/delivery-boys`
- [x] All transitions call backend (`/assign-delivery-boy`, `/packed`, `/dispatched`, `/delivered`)
- [x] WebSocket location streaming opens on delivery side when status = `out_for_delivery`

### 3.6 Inventory Management
- [x] Catalog list from `GET /catalog/items` + categories from `GET /catalog/categories`
- [x] Search bar + category chips
- [x] Per-item availability toggle (local) + SAVE → `PATCH /stores/me/inventory`

### 3.7 Earnings & Settlement Screen
- [x] Current week's settlement from `GET /settlements/store/current` (balance due, delivered count, owed/paid breakdown)
- [x] History list from `GET /settlements/store/history`
- [x] Overdue banner when `is_overdue: true`

### 3.8 Store Profile + Manage Delivery Boys
- [x] Profile shows store info + verified badge + strike count from `GET /stores/me`
- [x] Sign-out flow (Firebase Auth + Google Sign-In + provider reset)
- [x] StoreTeamScreen with full delivery-boy CRUD: `GET/POST/DELETE /stores/me/delivery-boys`

### 3.9 Backend patches done while wiring
- [x] Bug fix in `orders.py`: `accept_order`/`reject_order`/`assign-delivery-boy`/`packed`/`dispatched` were using `user.uid` as store_id; now resolve via `users/{uid}.store_id` (store docs are keyed by store_id, not owner uid)
- [x] New `GET /stores/me/orders?status=...&limit=50` for store-owner order list
- [x] New `GET/POST/DELETE /stores/me/delivery-boys` for delivery-boy CRUD
- [x] New `GET /orders/delivery/me` for delivery role assignments

**END OF PHASE 3 (code-complete) — Manual steps in `docs/FIREBASE_SETUP.md` (google-services.json, service-account JSON, admin-onboard first store) before end-to-end test. Then real-device verification of FCM full-screen wake-up.**

---

## PHASE 4 — CUSTOMER APP MVP (Week 6-8)

### 4.1 Flutter Project Setup
- [x] Create `customer_app` Flutter project, package com.dhav.customer
- [x] Firebase + Google Maps + Geolocator + WebSocket setup (pubspec.yaml + build.gradle.kts)

### 4.2 Authentication & Profile
- [x] Onboarding (4 screens with dot indicators)
- [x] Google Sign-In + Email/Password (matches Figma login screen)
- [x] Profile setup (name + home address)

### 4.3 Home Screen with Auto-Location ⭐
- [x] Location auto-fetches via Geolocator
- [x] Area name shows (Kothrud, Pune — production: use Geocoding API)
- [x] Permission denied handled gracefully
- [x] Category chips, "Order Again", "Fresh For You" grid, "Trending Near You"
- [x] Active order track banner

### 4.4 Catalog Browse & Cart
- [x] Search screen with category chips + item cards + floating cart bar
- [x] Add/remove quantity from home & search
- [x] Cart screen with delivery address, price summary, Place Order → POST /orders

### 4.5 Order Broadcasting Screen
- [x] Pulsing ring animation (3 rings, staggered)
- [x] Polls backend every 4s for status change
- [x] Wave escalation shown (1km → 2km → 3km)
- [x] Timeout / no-stores state with retry

### 4.6 Order Tracking with Live Map ⭐
- [x] Status timeline (5 steps)
- [x] Google Maps embedded
- [x] WebSocket customer receiver (location_ws_service.dart)
- [x] Smooth marker animation using Tween over 2s
- [x] ETA calculation via Haversine
- [x] Auto-reconnect on WebSocket drop
- [x] Delivered state screen

### 4.7 Order History & Profile
- [x] Past orders list with Active/Past tabs
- [x] Reorder button
- [x] Profile screen with saved addresses placeholder
- [x] Language preference picker
- [x] Notifications screen

**END OF PHASE 4 — Customer app code-complete. Pending: google-services.json + Maps API key, then real-device smoke test.**

---

## PHASE 5 — DELIVERY BOY VIEW (Week 8-9)

### 5.1 Delivery Boy Mode in Store App

- [x] Role detection works on login (SplashScreen routes delivery → DeliveryHomeScreen)
- [x] Delivery boy ONLY sees delivery screens, never store data
- [x] WebSocket GPS streams every 3 seconds (DeliveryLocationStreamer)

### 5.2 External Google Maps Launch
- [x] Google Maps app launches (url_launcher deep link in DeliveryAssignmentScreen)
- [x] WebSocket continues streaming in background

### 5.3 FCM Assignment Notification (2026-05-18)
- [x] FcmService handles type='delivery_assigned' → triggers onDeliveryAssigned callback
- [x] main.dart wires onDeliveryAssigned → push deliveryIncomingAssignment with orderId
- [x] PATCH /delivery/me/fcm-token backend endpoint (backend/routers/delivery.py)
- [x] SplashScreen syncs FCM token for delivery boys on login

### 5.4 Delivery Screens Wired to Real Data (2026-05-18)
- [x] delivery_incoming_assignment_screen: loads real order via OrderProvider, shows real address/items/earnings
- [x] delivery_completion_screen: accepts DeliveryCompletionArgs (orderId, earnings, area, itemCount)
- [x] delivery_assignment_screen: navigates to completion screen with real order data after mark delivered
- [x] deliveryMissedOrder route wired in main.dart

**END OF PHASE 5 — Delivery boy role complete, live tracking working end-to-end.**

---

## PHASE 6 — ADMIN DASHBOARD (Week 9-11)

### 6.1 Flutter Web Project Setup
- [x] Create `admin_dashboard` Flutter Web project
- [x] Firebase integration (web FirebaseOptions in main.dart — fill in real values)
- [x] Responsive desktop layout with persistent sidebar nav

### 6.2 Login + Dashboard Home
- [x] Email/password login with Firebase Auth + admin role check
- [x] Dashboard home: 4 metric cards (stores, orders, success rate, fee collected)
- [x] Recent orders list, pending settlements summary, stores overview

### 6.3 Store Management
- [x] Store list with search + All/Online/Suspended filters
- [x] Verify store action (PATCH /admin/stores/{id}/verify)
- [x] Suspend store with day picker (3/7/14/30 days)
- [x] Unsuspend store

### 6.4 Order Management
- [x] Order list with status filter dropdown + search
- [x] Force-fail order with confirmation dialog

### 6.5 Customer + Settlement Management
- [x] Customer list with search (name/email)
- [x] Settlement dashboard: pending/paid filter, summary bar (total owed + overdue count)
- [x] Mark-paid action with confirmation dialog

### 6.6 Analytics
- [x] Analytics summary integrated into dashboard home (4 KPI cards)

**END OF PHASE 6 — Admin can fully manage operations.**

---

## PHASE 7 — TESTING + DEPLOYMENT (Week 11-12)

### 7.1 Testing
- [x] Run all unit tests (backend) — 39/39 passing ✅
- [ ] Run all widget tests (Flutter)
- [ ] Manual QA checklist from PRD Section 24.4
- [ ] End-to-end test all 15 Use Cases from PRD Section 26

### 7.2 Deployment

- [x] Backend deployed — ~~Railway~~ → **https://dhav-backend.onrender.com** (Render free tier, since 2026-06-05)
- [x] Admin dashboard deployed (Firebase Hosting) — https://dhav-quick-commerce.web.app (2026-05-29)
- [x] Customer app APK built — 57.2 MB (2026-05-29) — *needs rebuild: home revamp + push-driven UI not in this APK*
- [x] Store app APK built — 56.6 MB (2026-05-29)
- [x] All three apps point to the Render URL (verified in api_config.dart, 2026-06-13)

### 7.3 Pre-Launch Pilot → moved to ENHANCEMENTS.md → Known Gaps
- [ ] Personally onboard 3 test stores in Kothrud
- [ ] Test 10 end-to-end orders
- [ ] Fix any bugs found
- [ ] Get 3 friends to test customer experience

### 7.4 Soft Launch → moved to ENHANCEMENTS.md → Known Gaps
- [ ] Onboard 20 stores in Kothrud
- [ ] Distribute flyers
- [ ] Monitor closely for first week
- [ ] Daily standup with yourself — what worked, what broke

**END OF PHASE 7 — DHAV is LIVE in Kothrud, Pune! 🎉**
---

