# DHAV Backend — System Architecture

> ⚠️ **PARTIALLY OUTDATED (as of 2026-06-13).** Data layer migrated to **Supabase
> PostgreSQL** (`services/db.py` + `migrations/`), files to Supabase Storage, hosting to
> **Render** (`https://dhav-backend.onrender.com`). Firebase = Auth + FCM only now.
> Read "Firebase Realtime Database" as "Postgres" and "Railway" as "Render" below.
> Current truth: **`docs/ENHANCEMENTS.md` → Current Architecture**.

> **Project:** DHAV — Hyperlocal Kirana Delivery App, Pune  
> **Backend Version:** 0.2.0  
> **Stack (historical):** FastAPI · Firebase Realtime Database · Firebase Auth · Firebase FCM · APScheduler  

---

## 1. High-Level System Diagram

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                       │
│                                                                                  │
│   ┌─────────────────┐   ┌─────────────────┐   ┌──────────────────────────────┐│
│   │  Customer App   │   │   Store App     │   │    Admin Dashboard (Flutter) ││
│   │  (Flutter)      │   │   (Flutter)     │   │    + Web Browser             ││
│   └────────┬────────┘   └────────┬────────┘   └──────────────┬───────────────┘│
│            │ HTTPS + Firebase ID Token        │              │                  │
│            └──────────────────┬───────────────┘              │                  │
└───────────────────────────────┼──────────────────────────────┼──────────────────┘
                                │                              │
                                ▼                              ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                          FASTAPI BACKEND (Railway)                              │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                    main.py  (Application Entry Point)                    │   │
│  │  ┌───────────────┐  ┌─────────────────────────────────────────────────┐ │   │
│  │  │  CORS Middle  │  │            Lifespan Context Manager             │ │   │
│  │  │     ware      │  │   init_firebase()  +  start_scheduler()         │ │   │
│  │  └───────────────┘  └─────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ┌──────────────────────────────────── ROUTERS ───────────────────────────────┐│
│  │ /auth      /customers  /stores   /orders   /catalog                        ││
│  │ /admin     /delivery   /notifications  /settlements                        ││
│  │ WS: /ws/order/{id}/location                                                ││
│  └───────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌──────────────────────────────────── SERVICES ──────────────────────────────┐│
│  │ geo.py        geofencing.py    broadcasting.py   notifications.py          ││
│  │ penalties.py  settlements.py  scheduler.py       location_ws.py            ││
│  └───────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌──────────────── DEPENDENCIES ──────────────────────────────────────────────┐│
│  │ get_current_user()   require_role(*roles)   Firebase token verification    ││
│  └───────────────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────┬──────────────────────────────────┬──────────┘
                                   │                                  │
                ┌──────────────────┘                  ┌──────────────┘
                ▼                                      ▼
┌─────────────────────────────────┐    ┌──────────────────────────────────────┐
│    FIREBASE REALTIME DATABASE   │    │      FIREBASE CLOUD MESSAGING        │
│                                 │    │                                       │
│  /users/{uid}                   │    │  Multicast (stores — new order alert) │
│  /stores/{store_id}             │    │  Unicast   (customer — status updates)│
│  /orders/{order_id}             │    │  Data-only messages (custom popup UI) │
│  /catalog/{item_id}             │    │  High-priority Android config         │
│  /geofence_index/{geohash}/...  │    │  TTL = 180s for incoming order msgs   │
│  /notifications/{uid}/{id}      │    │  Collapse key per order_id            │
│  /reviews/{store_id}/{id}       │    └──────────────────────────────────────┘
│  /settlements/{id}              │
│  /strike_logs/{id}              │    ┌──────────────────────────────────────┐
│  /delivery_boys/{id}            │    │      APSCHEDULER (IST timezone)      │
│  /custom_item_requests/{id}     │    │                                       │
│                                 │    │  Every 30 min: auto_fail_stuck_orders │
└─────────────────────────────────┘    │  Daily 06:00: lift_expired_suspensions│
                                       │  Monday 08:00: generate_weekly_       │
                                       │               settlements             │
                                       └──────────────────────────────────────┘
```

---

## 2. Request Authentication Flow

```
Client App
    │
    │  Authorization: Bearer <Firebase ID Token>
    ▼
FastAPI (dependencies.py)
    │
    ├─► firebase_auth.verify_id_token(token, clock_skew_seconds=60)
    │              ▼
    │        Firebase Auth SDK (validates JWT signature, expiry, project)
    │              ▼
    │         decoded = { uid, email, name, ... }
    │
    ├─► db.reference(f"users/{uid}").get()
    │              ▼
    │         user_data = { role, is_active, store_id?, ... }
    │
    └─► returns TokenVerifyResponse(uid, email, role, is_active)
              │
              ├─ get_current_user()    → any valid Firebase user
              └─ require_role("X")    → only users with role == "X"

Roles: customer | store_owner | delivery | admin
```

**First Login Special Case (auth.py):**  
When a user logs in for the first time (`user_data is None`), the system scans `delivery_boys` collection for a matching `google_account_email`. If found → role is set to `delivery`. Otherwise → role defaults to `customer`. This allows store owners to pre-register delivery boys before they ever open the app.

---

## 3. Geolocation Architecture (Core System)

### 3.1 The Two-Algorithm Approach

DHAV uses **two complementary algorithms** for geolocation:

#### Algorithm 1: Geohash (Spatial Indexing)
- **Library:** `pygeohash`  
- **Precision Used:** 6 characters  
- **Cell Size at Precision 6:** ≈ 1.2 km × 0.6 km per cell  
- **Purpose:** O(1) spatial lookup — convert lat/lng to a base32 string key that maps directly to a Firebase RTDB path

```
Geohash Encoding Formula:
  lat, lng → encode(lat, lng, precision=6) → "tfe6qe" (example for Pune)

How it works:
  1. Divide world into 2 halves (East/West), encode 1 bit
  2. Divide into 2 halves (North/South), encode 1 bit
  3. Alternate E-W and N-S until precision bits reached
  4. Group bits into 5-bit chunks → base32 encode
  → Result: nearby locations share a common prefix
```

#### Algorithm 2: Haversine Formula (Precise Distance)
- **File:** `services/geo.py`  
- **Purpose:** Exact great-circle distance between two points on Earth's surface

```python
Haversine Formula:
  R = 6371.0 km  (Earth's mean radius)
  
  a = sin²(Δlat/2) + cos(lat1) · cos(lat2) · sin²(Δlng/2)
  distance = 2R · atan2(√a, √(1−a))

Why Haversine?
  → Accurate for short to medium distances (<100 km)
  → Accounts for Earth's curvature (unlike Euclidean)
  → Computationally cheap (no trigonometric iterative solving)
  → Used for: delivery fee calculation, store proximity filtering
```

### 3.2 Geofence Index — Firebase Data Structure

```
geofence_index/
  ├── tfe6qe/                        ← geohash cell (precision 6)
  │   ├── store_abc123/
  │   │   ├── store_id: "store_abc123"
  │   │   ├── lat: 18.5204
  │   │   ├── lng: 73.8567
  │   │   ├── is_active: true
  │   │   ├── is_verified: true
  │   │   ├── is_suspended: false
  │   │   └── zone_id: ""
  │   └── store_xyz789/
  │       └── ...
  ├── tfe6qf/
  │   └── ...
  └── tfe6qd/
      └── ...
```

**Why Firebase as the geofence index?**  
Firebase RTDB provides O(1) reads by key. Since geohash converts coordinates into a string key, we can read `geofence_index/{geohash}` directly — no table scan, no SQL query.

### 3.3 Finding Nearby Stores — The Grid Walk Algorithm

```
geofencing.py → _cells_covering_radius(lat, lng, radius_km)

Step 1: Encode center point → get center geohash
Step 2: Decode center geohash → get lat_err, lng_err (cell half-dimensions)
Step 3: Calculate cell dimensions in km:
          cell_h_km = 2 × lat_err × 111.0       (1° lat ≈ 111 km)
          cell_w_km = 2 × lng_err × 111.0 × cos(lat)   (longitude shrinks toward poles)
Step 4: Calculate number of steps:
          steps_lat = ceil(radius_km / cell_h_km) + 1  (+ 1 slack for edge stores)
          steps_lng = ceil(radius_km / cell_w_km) + 1
Step 5: Walk the grid:
          for dy in range(-steps_lat, steps_lat + 1):
              for dx in range(-steps_lng, steps_lng + 1):
                  encode(lat + dy × cell_height, lng + dx × cell_width)

Step 6: For each cell → read geofence_index/{cell} from Firebase
Step 7: For each store in cell → run Haversine check: dist ≤ radius_km
Step 8: Return stores sorted by distance_km ascending
```

**Why not just check 8 neighbors (3×3 grid)?**  
At radius_km > 2.0 km, a fixed 3×3 grid misses stores in the outer cells. The dynamic grid walk ensures the correct number of cells are checked regardless of the requested radius.

### 3.4 Geofence Index Lifecycle

```
Store Created (admin/self-register)
    → geohash encoded at precision=6
    → NOT indexed if unverified (self-register)
    → Indexed (unverified flag) if admin creates

Admin Verifies Store
    → index_store_geofence(store_id, lat, lng, is_verified=True)

Store Opens (is_open toggle)
    → index_store_geofence(..., is_active=True, is_verified=True)

Store Closes (is_open toggle)
    → remove_store_from_geofence_index(store_id, lat, lng)

Store Suspended
    → remove_store_from_geofence_index(...)

Store Moves (location update)
    → remove old geohash entry
    → add new geohash entry

Settlement Overdue
    → remove_store_from_geofence_index(...)  (store hidden from customers)
```

---

## 4. Order Broadcasting Architecture

### 4.1 Wave-Based Broadcasting

```
Customer Places Order
        │
        ▼
POST /orders → order created (status: "pending")
        │
        ▼
start_broadcast() → creates asyncio.Task (_run_broadcast coroutine)
        │
        ├── Wave 1 (radius=1.0 km, timeout=45s)
        │      │
        │      ├─ find_nearby_stores(lat, lng, 1.0 km)
        │      ├─ filter: not already notified, not suspended
        │      ├─ update order: status="broadcasting", broadcast_wave=1
        │      ├─ FCM Multicast → store owners (high_priority=True, TTL=180s)
        │      └─ wait 45s polling every 2s for "accepted" status
        │
        ├── Wave 2 (radius=2.0 km, timeout=45s) [if not accepted]
        │      └─ same flow, wider radius, skips already-notified stores
        │
        └── Wave 3 (radius=3.0 km, timeout=60s) [if not accepted]
               └─ same flow, widest radius
                       │
                       ▼
              All waves exhausted?
                       │
                       ▼
              status="failed", failure_reason="no_stores_available"
              FCM to customer: "No stores available"
```

### 4.2 Atomic Order Acceptance (Concurrency Safety)

```
Multiple stores receive the same FCM notification.
Multiple store owners tap "Accept" simultaneously.

PROBLEM: Race condition — two stores could both read status="broadcasting"
         and both mark themselves as the winner.

SOLUTION: Firebase Transaction (optimistic concurrency)

atomic_accept_order(order_id, store_id):
    Firebase Transaction:
        current_data = read order node
        if status != "broadcasting":
            raise AbortTransaction  → returns False (lost the race)
        current_data["status"] = "accepted"
        current_data["accepted_by_store_id"] = store_id
        current_data["accepted_at"] = now_ms()
        return current_data  → Firebase commits only if node unchanged since read

Only ONE store wins. The others receive HTTP 409 "Order already accepted".
```

### 4.3 Order Status State Machine

```
pending
   │ (broadcast starts)
   ▼
broadcasting ──────────────────────────────────────────────────► failed
   │ (store accepts via atomic transaction)                      (no stores / all waves exhausted)
   ▼
accepted
   │ (store marks packed)
   ▼
packed
   │ (store dispatches)
   ▼
out_for_delivery ←──── WebSocket channel opened (ws_channel_id set)
   │ (delivery confirms)
   ▼
delivered ──── WebSocket channel closed, store counter incremented

Any state can go to:
  failed     ← store reports failure / admin force-fails / scheduler auto-fails
  cancelled  ← (future)
```

---

## 5. Fee Calculation Architecture

All fee parameters live in `config.py` and are loaded via `pydantic_settings` (reads `.env` file):

```
Order Total Breakdown:
┌─────────────────────────────────────────────────────────────┐
│ total_product_amount = Σ(item.quantity × item.price_per_unit)│
│                                                              │
│ platform_fee_amount  = total_product × (platform_fee_pct/100)│
│   → platform_fee_percentage = 5.0%  (configurable in .env)  │
│                                                              │
│ delivery_fee = base_delivery_fee + dist_km × fee_per_km     │
│   → base_delivery_fee     = ₹10.00  (configurable in .env)  │
│   → delivery_fee_per_km   = ₹5.00   (configurable in .env)  │
│   → dist_km = Haversine(store_lat/lng, customer_lat/lng)     │
│   → Calculated at ACCEPTANCE time (store location known)     │
│                                                              │
│ total_customer_amount = total_product + delivery_fee         │
│   (platform_fee is deducted from store, not added to customer)│
└─────────────────────────────────────────────────────────────┘

HOW TO CHANGE FEES:
  Edit .env file (or Railway environment variables):
    PLATFORM_FEE_PERCENTAGE=5.0
    BASE_DELIVERY_FEE=10.0
    DELIVERY_FEE_PER_KM=5.0
```

---

## 6. Penalty System Architecture

```
Store Failure Event (triggered by):
  → POST /orders/{id}/report-failure  (store self-reports)
  → POST /admin/orders/{id}/force-fail (admin forces)
  → Scheduler: auto_fail_stuck_orders (orders stuck > 3 hours)

process_store_failure(store_id, order_id, reason):
    │
    ├─ increment strike_count  (+1 rolling)
    ├─ increment total_strikes (+1 permanent)
    ├─ write strike_logs/{id} record
    │
    ├─ if total_strikes >= 5 (max_total_strikes_before_ban):
    │       → is_active = False
    │       → is_suspended = True
    │       → suspension_end_date = None (PERMANENT)
    │       → remove from geofence_index
    │       → FCM: "Account Permanently Banned"
    │
    ├─ elif strike_count >= 3 (max_strikes_before_suspend):
    │       → is_suspended = True
    │       → strike_count = 0  (RESET after suspension)
    │       → suspension_end_date = now + 7 days
    │       → remove from geofence_index
    │       → FCM: "Suspended for 7 days"
    │
    └─ else:
            → FCM: "Strike {n} issued"

Strike Counter Design:
  strike_count   = rolling counter, resets to 0 after each suspension
  total_strikes  = lifetime counter, never resets → used for permanent ban

CONFIG (edit .env to change):
  MAX_STRIKES_BEFORE_SUSPEND = 3
  MAX_TOTAL_STRIKES_BEFORE_BAN = 5
  SUSPENSION_DAYS = 7
```

---

## 7. WebSocket Live Location Architecture

```
WebSocket endpoint: /ws/order/{order_id}/location

In-memory channel store (NOT Firebase):
  _channels = {
    "order_{order_id}_location": {
      "delivery": WebSocket | None,
      "customers": [WebSocket, ...]
    }
  }

Delivery Boy connects:
  1. Send: {"token": "...", "role": "delivery_boy"}
  2. Server verifies Firebase token
  3. Server checks order status == "out_for_delivery"
  4. Server validates uid == assigned_delivery_boy_id OR store_owner
  5. Registered as channel["delivery"]
  6. Every 3 seconds sends: {"lat": 18.52, "lng": 73.85, "ts": 1234567890}

Customer connects:
  1. Send: {"token": "...", "role": "customer"}
  2. Server validates uid == order.customer_id
  3. Appended to channel["customers"]
  4. Receives location updates in real-time (push model)
  5. Sends ping messages to keep connection alive

Dead connection cleanup:
  → On each delivery broadcast, failed sends are removed from customers list
  → On WebSocketDisconnect, delivery slot cleared

Key design: location is EPHEMERAL (never written to Firebase).
This avoids Firebase write costs and privacy concerns.
```

---

## 8. Notification Architecture

### 8.1 Dual-Delivery Pattern

Every notification uses a **dual delivery** approach:

```
1. FCM Push (device notification) — real-time but unreliable
   → Android high-priority, TTL=180s for order alerts
   → Data-only messages (no notification field) → Flutter renders custom UI
   → Collapse key: "order_{order_id}" → prevents notification stacking

2. Firebase Persistence — guaranteed delivery even if device offline
   → Stored at: notifications/{uid}/{notif_id}
   → Fields: title, body, type, order_id, is_read, created_at, sender
   → Fetched by GET /notifications/me on app startup
```

### 8.2 FCM Message Types

| Type | Priority | TTL | Audience | Collapse Key |
|------|----------|-----|----------|-------------|
| `new_order` | HIGH | 180s | Stores (multicast) | `order_{id}` |
| `order_taken` | NORMAL | none | Other stores | `order_{id}` |
| `order_accepted` | NORMAL | none | Customer | — |
| `out_for_delivery` | NORMAL | none | Customer | — |
| `order_delivered` | NORMAL | none | Customer | — |
| `order_failed` | NORMAL | none | Customer | — |
| `strike_warning` | NORMAL | none | Store owner | — |
| `store_suspended` | NORMAL | none | Store owner | — |
| `announcement` | NORMAL | none | All (admin broadcast) | title |

---

## 9. Settlement Architecture

```
Weekly Settlement Generation (every Monday 08:00 IST via APScheduler):

generate_weekly_settlements():
  For each store:
    1. Check if settlement already exists for this week (idempotent)
    2. Collect all delivered orders for this store in the week
    3. total_platform_fee_owed = Σ(order.platform_fee_amount)
    4. Create settlement document:
       status: "pending"
       balance_due: total_platform_fee_owed

mark_overdue_settlements() (same job):
  For each pending settlement where week_end < today:
    → is_overdue = True
    → remove_store_from_geofence_index()  ← store hidden until paid!

Store cannot receive orders when:
  → is_suspended = True
  → OR overdue settlement exists (removed from geofence_index)
```

---

## 10. Background Scheduler Jobs

```
APScheduler (AsyncIOScheduler, timezone="Asia/Kolkata")
Starts at app startup via lifespan context manager.

┌─────────────────────┬────────────────────────────┬───────────────────────────┐
│   Job ID            │   Schedule                 │   What it does            │
├─────────────────────┼────────────────────────────┼───────────────────────────┤
│ auto_fail           │ Every 30 minutes            │ Scans all non-terminal    │
│                     │ CronTrigger(minute="*/30")  │ orders. If created_at >   │
│                     │                            │ 3h ago → mark failed +    │
│                     │                            │ issue strike to store     │
├─────────────────────┼────────────────────────────┼───────────────────────────┤
│ lift_suspensions    │ Daily at 06:00 IST          │ Scans suspended stores.   │
│                     │ CronTrigger(hour=6,min=0)   │ If suspension_end_date ≤  │
│                     │                            │ now → lift suspension     │
├─────────────────────┼────────────────────────────┼───────────────────────────┤
│ weekly_settlements  │ Every Monday 08:00 IST      │ generate_weekly_          │
│                     │ CronTrigger(day_of_week=    │ settlements() +           │
│                     │ "mon",hour=8,minute=0)      │ mark_overdue_settlements()│
└─────────────────────┴────────────────────────────┴───────────────────────────┘
```

---

## 11. Firebase Database Schema

```
Firebase Realtime Database: dhav-quick-commerce-default-rtdb

Root
├── users/
│   └── {uid}/
│       ├── uid, email, display_name, role, is_active, created_at
│       ├── store_id?          (for store_owner / delivery roles)
│       ├── fcm_token?         (customer push notifications)
│       └── saved_addresses[]  (customer saved addresses)
│
├── stores/
│   └── {store_id}/
│       ├── store_id, owner_uid, owner_name, shop_name, phone, email
│       ├── address, location: {lat, lng, geohash}
│       ├── is_open, is_active, is_verified, is_suspended
│       ├── suspension_end_date (epoch ms | null)
│       ├── strike_count (rolling, resets after suspension)
│       ├── total_strikes (lifetime, never resets)
│       ├── available_item_ids[]
│       ├── inventory: {item_id: {qty, is_available}}
│       ├── operating_hours: {open, close}
│       ├── total_orders_accepted, total_orders_failed
│       ├── rating (float, recalculated on each review)
│       ├── fcm_token
│       └── created_at
│
├── orders/
│   └── {order_id}/
│       ├── order_id, customer_id, customer_address: {lat, lng, area, ...}
│       ├── items[]: {item_id, item_name, quantity, unit, price_per_unit, total_price}
│       ├── total_product_amount, delivery_fee, total_customer_amount
│       ├── platform_fee_percentage, platform_fee_amount, platform_fee_settled
│       ├── payment_method ("cod")
│       ├── status (pending|broadcasting|accepted|packed|out_for_delivery|delivered|failed)
│       ├── broadcast_wave (1|2|3), broadcast_radius_km, broadcast_store_ids[]
│       ├── rejected_store_ids[], timed_out_store_ids[]
│       ├── accepted_by_store_id, accepted_at
│       ├── assigned_delivery_boy_id, delivery_boy_name, delivery_boy_phone
│       ├── ws_channel_id (for live location WebSocket)
│       ├── estimated_delivery_minutes
│       ├── delivered_at, failure_reason
│       └── created_at
│
├── catalog/
│   └── {item_id}/
│       ├── item_id, name, name_hindi, name_marathi
│       ├── category, unit, image_url
│       └── is_active
│
├── geofence_index/
│   └── {geohash_6char}/
│       └── {store_id}/
│           ├── store_id, lat, lng
│           ├── is_active, is_verified, is_suspended
│           └── zone_id
│
├── notifications/
│   └── {uid}/
│       └── {notif_id}/
│           ├── notif_id, title, body, type
│           ├── order_id?, is_read, created_at
│           └── sender ("system" | "admin")
│
├── reviews/
│   └── {store_id}/
│       └── {review_id}/
│           ├── review_id, order_id, store_id, customer_id
│           ├── rating (1-5), comment
│           └── created_at
│
├── settlements/
│   └── {settlement_id}/
│       ├── settlement_id, store_id
│       ├── week_start, week_end (ISO dates)
│       ├── total_orders_delivered, total_platform_fee_owed
│       ├── total_fee_paid, balance_due
│       ├── status ("pending" | "settled")
│       ├── payment_records[], is_overdue
│       └── created_at
│
├── strike_logs/
│   └── {strike_id}/
│       ├── strike_id, store_id, order_id, reason
│       ├── strike_number, action_taken
│       └── created_at
│
├── delivery_boys/
│   └── {boy_id}/
│       ├── delivery_boy_id, store_id, name, phone
│       ├── google_account_email, is_active
│       ├── current_order_id, uid (Firebase UID, set on first login)
│       └── created_at
│
└── custom_item_requests/
    └── {request_id}/
        ├── request_id, store_id, requested_by_uid
        ├── name, name_hindi, name_marathi, category, unit, price, notes
        ├── status ("pending" | "approved" | "rejected")
        └── created_at
```

---

## 12. Configuration Reference (config.py)

All configurable via environment variables or `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `FIREBASE_DATABASE_URL` | `https://dhav-quick-commerce-default-rtdb.firebaseio.com` | Firebase RTDB URL |
| `BROADCAST_WAVE1_RADIUS_KM` | `1.0` | Wave 1 search radius |
| `BROADCAST_WAVE1_TIMEOUT_SECONDS` | `45` | Wave 1 store response timeout |
| `BROADCAST_WAVE2_RADIUS_KM` | `2.0` | Wave 2 search radius |
| `BROADCAST_WAVE2_TIMEOUT_SECONDS` | `45` | Wave 2 store response timeout |
| `BROADCAST_WAVE3_RADIUS_KM` | `3.0` | Wave 3 search radius |
| `BROADCAST_WAVE3_TIMEOUT_SECONDS` | `60` | Wave 3 store response timeout |
| `GEOHASH_PRECISION` | `6` | Geohash cell size (~1.2 km × 0.6 km) |
| `PLATFORM_FEE_PERCENTAGE` | `5.0` | % of product total charged as platform fee |
| `BASE_DELIVERY_FEE` | `10.0` | Flat delivery fee in ₹ |
| `DELIVERY_FEE_PER_KM` | `5.0` | Per-km delivery charge in ₹ |
| `MAX_STRIKES_BEFORE_SUSPEND` | `3` | Rolling strikes before 7-day suspension |
| `MAX_TOTAL_STRIKES_BEFORE_BAN` | `5` | Lifetime strikes before permanent ban |
| `SUSPENSION_DAYS` | `7` | Days for temporary suspension |
| `AUTO_FAIL_HOURS` | `3` | Hours before stuck order is auto-failed |
| `SETTLEMENT_DAY` | `MONDAY` | Day of week for settlement generation |

---

## 13. Concurrency Model

FastAPI runs on **Uvicorn** (ASGI). The concurrency model:

- **HTTP requests:** async/await — handled concurrently by the event loop
- **Broadcasting:** `asyncio.Task` per order — runs concurrently within the same event loop; tracked in `_active_broadcasts: dict[str, asyncio.Task]`
- **WebSocket connections:** persistent coroutines on the event loop; in-memory channel store (not thread-safe but safe because single-threaded async)
- **Firebase calls:** Synchronous Firebase Admin SDK — these are blocking I/O calls that block the event loop. For the current scale (Pune hyperlocal), this is acceptable. At higher scale, a thread pool executor would be needed.
- **APScheduler:** `AsyncIOScheduler` — jobs run as coroutines on the same event loop

**Multiple request handling:**  
FastAPI + Uvicorn handles concurrent requests via async I/O. When one request awaits a Firebase call, the event loop processes other requests in the meantime. Broadcasting tasks run as background asyncio tasks — they don't block HTTP handlers.
