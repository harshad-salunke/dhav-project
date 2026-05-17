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

**Current Phase:** Phase 3 — Store App MVP (Flutter) — UI COMPLETE
**Last task completed:** Phase 3.1–3.8 — Full Flutter Store App UI built from Figma design
**Next task to do:** Phase 3 — Wire Firebase Auth (Google Sign-In), connect APIs to backend
**Blockers:** Need google-services.json placed in store_app/android/app/. Need firebase-service-account.json in backend/. Test all APIs with Postman.
**Last updated:** 2026-05-17

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
