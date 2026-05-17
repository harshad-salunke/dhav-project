# 🛠️ DHAV — Build Plan & Progress Tracker

**Purpose:** This is your master roadmap. Every time you sit down to work with Claude CLI, open this file FIRST. It tells you exactly where you are and what to build next.

**How to use:** When a task is done, mark `[x]`. When you stop a session, note where you stopped in `SESSION_NOTES.md`.

---

## 📊 OVERALL PROGRESS

- [x] Phase 0: Project Setup (Week 1)
- [x] Phase 1: Firebase Foundation (Week 1-2)
- [x] Phase 2: FastAPI Backend Core (Week 2-4)
- [ ] Phase 3: Store App MVP (Week 4-6)
- [ ] Phase 4: Customer App MVP (Week 6-8)
- [ ] Phase 5: Live Location + Delivery Boy (Week 8-9)
- [ ] Phase 6: Admin Dashboard (Week 9-11)
- [ ] Phase 7: Testing + Deployment (Week 11-12)

**Total estimated time:** 12 weeks for solo developer

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

### 0.3 Claude CLI Setup
- [ ] Install Claude CLI: follow https://docs.claude.com/claude-code
- [ ] Inside root project folder, run: `claude`
- [ ] When CLI opens, first command should be: "Read all files in /docs and BUILD_PLAN.md. Confirm you understand the project."

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
**Claude CLI prompt:**
> "Create a Python script `backend/scripts/seed_catalog.py` that seeds the Firebase Realtime Database with 50 common kirana items across categories: Grains, Oil & Ghee, Dairy, Snacks, Personal Care, Cleaning, Baby Care. Each item should have name, name_hindi, name_marathi, category, unit, and image_url. Use placeholder images for now."

- [ ] Run the seed script
- [ ] Verify 50 items appear in Firebase Console

**END OF PHASE 1 — Firebase is ready, security rules deployed, catalog seeded.**

---

## PHASE 2 — FASTAPI BACKEND CORE (Week 2-4)

### 2.1 Project Skeleton
**Claude CLI prompt:**
> "Read PRD Section 16 (Folder Structure). Create the complete FastAPI backend skeleton in `backend/` with all folders, empty Python files, requirements.txt, and config.py. Use Pydantic v2 models. Initialize Firebase Admin SDK in firebase_init.py."

- [x] All folders/files created
- [x] `requirements.txt` includes: fastapi, uvicorn, firebase-admin, pygeohash, apscheduler, websockets, python-dotenv, pytest
- [x] `.env.example` has all variables from PRD Section 17
- [x] `pip install -r requirements.txt` works
- [x] `uvicorn main:app --reload` runs without error

### 2.2 Authentication Layer
**Claude CLI prompt:**
> "Implement `backend/routers/auth.py` with POST /auth/verify-token endpoint. Use Firebase Admin SDK to verify Firebase ID token from Authorization header. Return user role (customer/store/delivery_boy/admin) by looking up the UID in the database."

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
**Claude CLI prompt:**
> "Create Flutter project `store_app` with package name com.DHAVl.store. Set up firebase_core, firebase_auth, firebase_messaging, firebase_database, google_maps_flutter, geolocator, http, provider (or riverpod) for state management, intl for localization."

- [ ] Project runs on emulator
- [ ] Firebase connected (`google-services.json` placed)

### 3.2 Authentication
**Claude CLI prompt:**
> "Implement Google Sign-In in `store_app/lib/features/auth/`. After login, call backend /auth/verify-token. If role is 'store' show owner dashboard, if 'delivery_boy' show delivery boy home."

- [ ] Google Sign-In works
- [ ] Role-based routing works

### 3.3 Store Owner Dashboard
**Claude CLI prompt:**
> "Read PRD Section 6.2. Build store dashboard with: Big Open/Closed toggle, today's stats card, active order card, recent orders list."

- [ ] Toggle works and updates backend
- [ ] Stats display correctly

### 3.4 Incoming Order Popup ⭐ MOST CRITICAL UI
**Claude CLI prompt:**
> "Read PRD Section 6.3 carefully. Build the incoming order popup system:
> - High-priority FCM listener that opens overlay even when app is in background
> - Loud sound (use audioplayers package + custom mp3)
> - Continuous vibration until action
> - 45-second countdown bar
> - Three buttons: Quick Accept, View Order Details, Reject
> - View Order Details opens bottom sheet without stopping timer
> - Bottom sheet shows items with inventory check, distance, payment, accept/reject"

- [ ] FCM ring sound plays even in silent mode (test thoroughly!)
- [ ] Popup shows when app backgrounded
- [ ] Timer accurate to second
- [ ] All 3 buttons work correctly
- [ ] Test the "two stores accept at same time" scenario

### 3.5 Active Order Management
**Claude CLI prompt:**
> "Read PRD Section 6.4. Build active order screen with sequential step buttons: Assign Delivery Boy (dropdown of registered delivery boys), Mark Packed, Confirm Dispatch (opens WebSocket), Mark Delivered."

- [ ] Step sequence enforced
- [ ] Delivery boy assignment notifies their app
- [ ] WebSocket opens on dispatch

### 3.6 Inventory Management
**Claude CLI prompt:**
> "Build inventory screen — show catalog with tick toggles. Search bar. Custom items section. Persist to backend."

- [ ] Toggling items syncs with backend
- [ ] Search works

### 3.7 Earnings & Settlement Screen
**Claude CLI prompt:**
> "Read PRD Section 6.6. Build earnings screen showing this week's orders, gross earnings, platform fee owed, net earnings, settlement status, history."

- [ ] Numbers calculate correctly
- [ ] Pay DHAV button shows UPI ID

### 3.8 Store Profile + Manage Delivery Boys
- [ ] Profile screen with edit
- [ ] Add/remove delivery boys
- [ ] Strike count display

**END OF PHASE 3 — Store owner can receive orders and manage entire delivery flow.**

---

## PHASE 4 — CUSTOMER APP MVP (Week 6-8)

### 4.1 Flutter Project Setup
- [ ] Create `customer_app` Flutter project, package com.DHAVl.customer
- [ ] Same Firebase + Google Maps + Geolocator setup

### 4.2 Authentication & Profile
- [ ] Google Sign-In + Email
- [ ] Profile setup with map picker for home address

### 4.3 Home Screen with Auto-Location ⭐
**Claude CLI prompt:**
> "Read PRD Section 5.2. Build home screen with auto-location fetch on open using Geolocator. Reverse geocode to area name. Show category chips, featured items, search bar."

- [ ] Location auto-fetches
- [ ] Area name shows correctly
- [ ] Permission denied handled gracefully

### 4.4 Catalog Browse & Cart
- [ ] Browse by category
- [ ] Search items
- [ ] Add to cart with quantity selector
- [ ] Cart screen with address + place order

### 4.5 Order Broadcasting Screen
**Claude CLI prompt:**
> "Read PRD Section 5.5. Build broadcasting animation screen with pulsing rings on map. Listen to Firebase for order status changes. Show success → accepted screen, fail → no stores message."

- [ ] Animation smooth
- [ ] Status updates real-time
- [ ] Wave escalation reflected in UI

### 4.6 Order Tracking with Live Map ⭐ MOST CRITICAL
**Claude CLI prompt:**
> "Read PRD Section 5.7 and 5.7a thoroughly. Build order tracking screen with status timeline + Google Map. When status = out_for_delivery, open WebSocket to backend, receive delivery boy GPS, animate marker smoothly using Tween animation over 2 seconds per update."

- [ ] Map shows correctly
- [ ] WebSocket connects with token
- [ ] Marker animates smoothly (no jumps)
- [ ] ETA calculates correctly
- [ ] WebSocket reconnects on drop

### 4.7 Order History & Profile
- [ ] Past orders list
- [ ] Reorder button
- [ ] Saved addresses CRUD
- [ ] Language preference

**END OF PHASE 4 — Customer can place orders and track live delivery.**

---

## PHASE 5 — DELIVERY BOY VIEW (Week 8-9)

### 5.1 Delivery Boy Mode in Store App
**Claude CLI prompt:**
> "Read PRD Section 6B thoroughly. Inside the same store_app, add delivery boy role views: Home screen with available toggle, incoming assignment popup, active delivery screen with Google Map + option to launch external Google Maps, mark delivered."

- [ ] Role detection works on login
- [ ] Delivery boy ONLY sees delivery screens, never store data
- [ ] WebSocket GPS streams every 3 seconds

### 5.2 External Google Maps Launch
**Claude CLI prompt:**
> "Use url_launcher to open Google Maps with navigation when delivery boy taps 'Open in Google Maps'. Use deep link format: https://www.google.com/maps/dir/?api=1&destination=LAT,LNG&travelmode=two_wheeler"

- [ ] Google Maps app launches
- [ ] WebSocket continues streaming in background

**END OF PHASE 5 — Delivery boy role complete, live tracking working end-to-end.**

---

## PHASE 6 — ADMIN DASHBOARD (Week 9-11)

### 6.1 Flutter Web Project Setup
- [ ] Create `admin_dashboard` Flutter Web project
- [ ] Firebase integration
- [ ] Responsive design for desktop

### 6.2 Login + Dashboard Home
**Claude CLI prompt:**
> "Read PRD Section 7. Build admin login (email/password Firebase Auth). Dashboard home with key metrics: total stores, total orders today/week/month, success rate, platform fee collected, map of all stores."

- [ ] Login works
- [ ] Metrics calculate correctly
- [ ] Map shows all stores

### 6.3 Store Management
- [ ] Store list with filters
- [ ] Store detail view
- [ ] Onboard new store form
- [ ] Suspend/verify actions

### 6.4 Order Management
- [ ] Real-time order list (Firebase listener)
- [ ] Order detail with timeline
- [ ] Manual override actions

### 6.5 Customer + Catalog + Settlement Management
- [ ] Customer list/detail
- [ ] Catalog CRUD
- [ ] Settlement dashboard with mark-paid

### 6.6 Analytics
- [ ] Order volume by zone heatmap
- [ ] Peak hours chart
- [ ] Most ordered items
- [ ] Store performance rankings

**END OF PHASE 6 — Admin can fully manage operations.**

---

## PHASE 7 — TESTING + DEPLOYMENT (Week 11-12)

### 7.1 Testing
- [ ] Run all unit tests (backend)
- [ ] Run all widget tests (Flutter)
- [ ] Manual QA checklist from PRD Section 24.4
- [ ] End-to-end test all 15 Use Cases from PRD Section 26

### 7.2 Deployment
**Claude CLI prompt:**
> "Read PRD Section 25. Help me deploy: 1) Backend to Railway.app with all environment variables 2) Admin dashboard to Firebase Hosting 3) Customer + Store apps build APK release"

- [ ] Backend deployed (note URL)
- [ ] Admin dashboard deployed
- [ ] Customer app APK built
- [ ] Store app APK built
- [ ] Update apps to point to production backend URL

### 7.3 Pre-Launch Pilot
- [ ] Personally onboard 3 test stores in Kothrud
- [ ] Test 10 end-to-end orders
- [ ] Fix any bugs found
- [ ] Get 3 friends to test customer experience

### 7.4 Soft Launch
- [ ] Onboard 20 stores in Kothrud
- [ ] Distribute flyers
- [ ] Monitor closely for first week
- [ ] Daily standup with yourself — what worked, what broke

**END OF PHASE 7 — DHAV is LIVE in Kothrud, Pune! 🎉**

---

## 📌 HOW TO WORK WITH CLAUDE CLI EVERY DAY

### Starting a Session:
1. Open terminal in project root
2. Run: `claude`
3. First prompt: **"Read docs/BUILD_PLAN.md and docs/SESSION_NOTES.md. Tell me where I stopped and what to do next."**
4. Claude will see your progress and continue from there

### During a Session:
- Work on ONE task at a time (one checkbox)
- After each task: ask Claude to **"Update BUILD_PLAN.md to mark [task] as complete"**
- If you get stuck, write the issue in SESSION_NOTES.md

### Ending a Session:
- Always ask Claude: **"Update SESSION_NOTES.md with what we did today, what's blocking, and exactly where to resume tomorrow"**
- Commit code to Git: `git add . && git commit -m "Phase X.Y complete"`
- Push to GitHub: `git push`

### If Token Limit Hits Mid-Session:
- Claude CLI session ends → no problem
- Start fresh session next day
- Your code is on disk, BUILD_PLAN.md and SESSION_NOTES.md tell Claude where you were
- Just re-prompt: "Read BUILD_PLAN.md and SESSION_NOTES.md, continue from where we stopped"

---

## 🚨 GOLDEN RULES

1. **NEVER skip phases.** Backend must work before Flutter apps. Don't build UI for APIs that don't exist.
2. **ONE feature at a time.** Don't ask Claude to build 5 screens in one prompt — break it down.
3. **TEST as you build.** Don't write all code then test at the end.
4. **COMMIT often.** After every working feature: `git commit`. Easy rollback if something breaks.
5. **WRITE in SESSION_NOTES.md.** This is your memory across days. Treat it as your dev journal.
6. **READ the PRD section** before asking Claude to build that part. Reference the section number in your prompt.

---

*This BUILD_PLAN is your single source of truth. Update it as you build. Good luck! 🚀*
