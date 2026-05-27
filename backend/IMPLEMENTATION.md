# DHAV Backend — Deep Implementation Guide

> This document explains **how** things work internally — algorithms, data flows, edge cases, design decisions, and where to change specific behaviors.

---

## 1. Project Structure

```
backend/
├── main.py                     # App entry point, router registration, lifespan
├── config.py                   # All tunable parameters via pydantic-settings
├── dependencies.py             # get_current_user(), require_role() middleware
├── firebase_init.py            # Firebase app initialization (file path + env var support)
│
├── routers/
│   ├── auth.py                 # /auth/verify-token (first login bootstrap)
│   ├── customers.py            # /customers/me (profile, addresses)
│   ├── stores.py               # /stores (CRUD, toggle, inventory, delivery boys)
│   ├── orders.py               # /orders (place, accept, lifecycle transitions)
│   ├── catalog.py              # /catalog (items, nearby stores, store catalog)
│   ├── admin.py                # /admin (store mgmt, catalog, analytics, broadcasts)
│   ├── delivery.py             # /delivery (delivery boy FCM, profile)
│   ├── notifications.py        # /notifications (read, mark-read, clear)
│   └── settlements.py          # /settlements (weekly settlement records)
│
├── services/
│   ├── geo.py                  # Haversine distance formula
│   ├── geofencing.py           # Geohash index + grid-walk store lookup
│   ├── broadcasting.py         # Wave-based order broadcast + atomic accept
│   ├── notifications.py        # FCM send + Firebase persistence
│   ├── penalties.py            # Strike system + suspension + auto-fail
│   ├── settlements.py          # Weekly settlement generation
│   ├── scheduler.py            # APScheduler job definitions
│   └── location_ws.py          # In-memory WebSocket hub for live delivery location
│
├── models/
│   ├── user.py                 # TokenVerifyResponse Pydantic model
│   ├── store.py                # Store, StoreCreateRequest, OperatingHours, etc.
│   ├── order.py                # Order, PlaceOrderRequest, OrderItem, etc.
│   ├── catalog.py              # CatalogItem, CatalogItemCreateRequest
│   ├── geofence.py             # Geofence zone model
│   └── settlement.py           # Settlement model
│
└── utils/
    └── helpers.py              # new_id(), now_ms()
```

---

## 2. Application Startup Sequence

```
uvicorn main:app --host 0.0.0.0 --port 8000
                │
                ▼
@asynccontextmanager lifespan(app):
    1. init_firebase()
       ├─ Check env var FIREBASE_SERVICE_ACCOUNT_JSON (Railway deployment)
       ├─ OR read file path from settings.firebase_service_account (local dev)
       └─ firebase_admin.initialize_app(cred, {databaseURL, storageBucket})
    
    2. start_scheduler()
       ├─ AsyncIOScheduler(timezone="Asia/Kolkata")
       ├─ add_job: auto_fail every 30 min
       ├─ add_job: lift_suspensions daily at 06:00
       ├─ add_job: weekly_settlements every Monday 08:00
       └─ scheduler.start()
    
    3. yield  ← app is now serving requests
    
    (on shutdown: scheduler stops cleanly)
```

---

## 3. Geolocation Deep Dive

### 3.1 What is Geohash? (The Concept)

Geohash is a **hierarchical spatial indexing system** invented by Gustavo Niemeyer in 2008. It converts a 2D coordinate (lat, lng) into a 1D string.

**The encoding algorithm (conceptually):**

```
World is a rectangle. Split it recursively:

1. First bit: Is longitude < 0 (West) or ≥ 0 (East)? → bit 0 or 1
2. Second bit: Is latitude < 0 (South) or ≥ 0 (North)? → bit 0 or 1
3. Third bit: Split the East/West half again → longitude bit
4. ...alternate E-W and N-S...

After 30 bits (5 characters × 6 bits → but geohash uses base32):
  Group bits into 5-bit chunks
  Map each chunk to base32 alphabet: 0123456789bcdefghjkmnpqrstuvwxyz

Precision 6 = 30 bits = ~1.2 km × 0.6 km cells
```

**Why is this useful for databases?**
- Pune (18.5204, 73.8567) → `"tfe6qe"` at precision 6
- All stores within that cell share the key `tfe6qe`
- Firebase RTDB read: `geofence_index/tfe6qe` → O(1), no scanning

**Key property:** Nearby locations share a prefix. `tfe6qe` and `tfe6qf` are adjacent cells. This is why checking neighboring cells finds nearby stores.

### 3.2 The Haversine Formula Explained

```python
def haversine_km(lat1, lng1, lat2, lng2):
    R = 6371.0          # Earth mean radius in km (WGS84 approximation)
    
    phi1 = radians(lat1)
    phi2 = radians(lat2)
    dphi = radians(lat2 - lat1)    # Δlat
    dlambda = radians(lng2 - lng1) # Δlng
    
    # Central angle formula (spherical law of cosines variant)
    a = sin²(dphi/2) + cos(phi1) × cos(phi2) × sin²(dlambda/2)
    
    # Arc length
    distance = 2R × atan2(√a, √(1-a))
    return distance  # in km
```

**Why Haversine vs. simpler formulas?**

| Formula | Accuracy | Use case |
|---------|----------|---------|
| Euclidean (2D) | ❌ Wrong near poles, off by 10-20% | Never for geo |
| Flat-Earth approx | ⚠️ OK for <100m | Not suitable here |
| Haversine | ✅ <0.5% error for <20,000 km | Perfect for hyperlocal |
| Vincenty | ✅✅ <0.00005% error | Overkill for kirana delivery |

### 3.3 Why Two Algorithms Together?

**Geohash alone is not enough:**  
A geohash cell is a rectangle. A radius is a circle. Stores in the corner of a cell are farther than `radius_km` but still in the same cell.

**Haversine alone is not enough:**  
You'd have to compute distance to every store in Firebase — O(n) full table scan.

**Together:**
```
Geohash:   coarse filter  → "which cells to check"  (eliminates 99% of data)
Haversine: precise filter → "which stores in those cells are within radius_km"
```

This is called a **two-phase spatial query** — the same technique used by PostGIS, Google Maps, and Uber.

### 3.4 Grid Walk vs. Fixed 3×3 Neighbors

**The old naive approach (3×3 = 8 neighbors):**
```
Checks exactly 9 cells (center + 8 surrounding cells).
Works only when radius_km ≤ 1 cell width.
For radius_km = 3.0, a 3×3 block misses 60% of coverage area.
```

**DHAV's dynamic grid walk approach:**
```python
steps_lat = ceil(radius_km / cell_h_km) + 1  # e.g., ceil(3.0 / 1.2) + 1 = 4
steps_lng = ceil(radius_km / cell_w_km) + 1  # e.g., ceil(3.0 / 0.6) + 1 = 6

# Walk -4 to +4 in lat direction, -6 to +6 in lng direction
# = (4*2+1) × (6*2+1) = 9 × 13 = 117 cells checked for 3km radius
# Then Haversine eliminates the corner cells → exact circle
```

**The +1 slack:** Ensures stores sitting exactly on the far edge of a cell (due to floating-point precision) still get included.

### 3.5 Why Geohash Precision 6?

| Precision | Cell Size (approx) | Tradeoff |
|-----------|-------------------|----------|
| 5 | 4.9 km × 4.9 km | Too large → too many false positives |
| 6 | 1.2 km × 0.6 km | ✅ Good balance for hyperlocal 1-5km queries |
| 7 | 152 m × 152 m | Too small → too many cells to check for large radius |
| 8 | 38 m × 19 m | Overkill |

**At precision 6:**
- For wave 1 (1km radius): ~4-9 cells checked
- For wave 3 (3km radius): ~30-50 cells checked
- Each Firebase read is very fast (keyed access)

---

## 4. Broadcasting Implementation Details

### 4.1 asyncio Task Management

```python
# In-memory task tracker
_active_broadcasts: dict[str, asyncio.Task] = {}

def start_broadcast(order_id, ...):
    loop = asyncio.get_event_loop()
    task = loop.create_task(_run_broadcast(...))
    _active_broadcasts[order_id] = task
    task.add_done_callback(lambda _: _active_broadcasts.pop(order_id, None))
```

Each order gets its own `asyncio.Task`. This allows:
- Multiple orders broadcasting simultaneously
- Cancellation when a store accepts (`cancel_broadcast`)
- Automatic cleanup via `done_callback`

### 4.2 Polling vs. Push-Back

During each wave, the broadcaster doesn't get notified when a store accepts. Instead:

```python
deadline = asyncio.get_event_loop().time() + timeout_sec
while asyncio.get_event_loop().time() < deadline:
    await asyncio.sleep(2)  # yield to event loop
    fresh = order_ref.get()  # read current status from Firebase
    if fresh and fresh.get("status") == "accepted":
        return  # early exit
```

**Why polling?** Firebase RTDB real-time listeners require a long-lived connection per listener. For a stateless API server, polling every 2 seconds is simpler and acceptable within 45-60s timeouts.

**Why `asyncio.sleep(2)` and not `asyncio.sleep(0)`?** Sleeping 2s yields the event loop for 2 seconds, allowing other requests to run. Zero sleep would busy-wait and starve other requests.

### 4.3 Firebase Transaction (Atomic Accept)

```python
def _txn(current_data):
    if current_data.get("status") != "broadcasting":
        raise db.AbortTransaction("order_not_broadcasting")  # lost the race
    current_data["status"] = "accepted"
    current_data["accepted_by_store_id"] = store_id
    current_data["accepted_at"] = now_ms()
    return current_data  # commit if node unchanged since read

result = order_ref.transaction(_txn)
return result is not None and result.get("accepted_by_store_id") == store_id
```

**How Firebase transactions work:**
1. Read current value
2. Run `_txn` function
3. Try to write result back with an optimistic lock
4. If another client wrote in the meantime → Firebase re-runs `_txn` with new value
5. If `_txn` raises `AbortTransaction` → transaction fails cleanly

**Race condition scenario:**
- Store A and Store B both tap "Accept" at t=0ms
- Both read status="broadcasting"
- Firebase transaction: only one write succeeds
- The other gets `AbortTransaction` → returns `False` → HTTP 409

### 4.4 FCM for Order Alerts — Data-Only Messages

```python
# Note: No "notification" field in the MulticastMessage
msg = messaging.MulticastMessage(
    data=payload,   # ← only data, no notification
    tokens=valid_tokens,
    android=messaging.AndroidConfig(
        priority="high",
        ttl=timedelta(seconds=180),
        collapse_key=f"order_{order_id}",
    ),
)
```

**Why data-only?**
- FCM SDK auto-displays a notification for `notification` field messages
- We want custom full-screen popup UI in the store app
- Flutter's `_backgroundHandler` reads `data` fields and shows a custom notification
- Prevents double-notification (SDK one + custom one)

**TTL = 180 seconds:**
- Matches total broadcast time (45 + 45 + 60 + slack = ~150s)
- After TTL, FCM drops the message instead of delivering it when device comes back online
- Prevents store owners from seeing stale "New Order" popups hours later

**Collapse Key = `"order_{order_id}"`:**
- If store phone is offline and waves 1, 2, 3 all try to notify the same store about the same order, FCM deduplicates → delivers only the latest message
- Prevents 3 "New Order" popups for the same order

---

## 5. Fee Calculation — Where and How

### 5.1 Platform Fee (set at order creation)

```python
# routers/orders.py → place_order()
total_product = sum(item.total_price for item in body.items)
platform_fee_amount = round(total_product * settings.platform_fee_percentage / 100, 2)
```

- Calculated **at order creation** from `total_product_amount`
- Stored in the order document immediately
- `platform_fee_percentage` comes from `config.py` → env var `PLATFORM_FEE_PERCENTAGE`
- **To change platform fee:** Update `PLATFORM_FEE_PERCENTAGE` in `.env` or Railway env vars

### 5.2 Delivery Fee (set at acceptance)

```python
# routers/orders.py → _delivery_fee() → called at accept_order()
def _delivery_fee(store_lat, store_lng, customer_lat, customer_lng):
    dist = haversine_km(store_lat, store_lng, customer_lat, customer_lng)
    return round(settings.base_delivery_fee + dist * settings.delivery_fee_per_km, 2)
```

**Example:** Store at Kothrud, customer at Aundh, distance = 4.5 km  
`delivery_fee = 10 + 4.5 × 5 = ₹32.50`

**Why at acceptance and not order creation?**  
The accepting store is unknown when the order is placed (any nearby store could win). The delivery fee depends on which store actually accepts — so it's calculated once the store is known.

**To change fees:**
```
.env file:
  BASE_DELIVERY_FEE=15.0       # Flat base fee
  DELIVERY_FEE_PER_KM=6.0      # Per-km rate
  PLATFORM_FEE_PERCENTAGE=4.5  # Platform cut
```

---

## 6. Penalty System — Detailed Logic

### 6.1 Strike Counter Design (Two-Counter System)

```python
strike_count   = store.get("strike_count", 0) + 1    # rolling, resets after suspension
total_strikes  = store.get("total_strikes", 0) + 1   # permanent, never resets
```

**Why two counters?**

Single counter: A store could accumulate 2 strikes, get suspended, reset to 0, accumulate 2 more, get suspended again — infinitely, never permanently banned.

Two-counter system prevents this:
- `strike_count`: "strikes since last suspension" — used to detect "time to suspend again"
- `total_strikes`: "strikes ever" — used to detect "time for permanent ban"

### 6.2 Decision Tree

```python
if total_strikes >= 5:       # PERMANENT BAN
    is_active = False
    is_suspended = True
    suspension_end_date = None  # no end date = permanent

elif strike_count >= 3:      # 7-DAY SUSPENSION
    is_suspended = True
    strike_count = 0           # ← reset rolling counter!
    suspension_end_date = now + 7 days

else:                        # WARNING ONLY
    # just record the strike
```

**Key point:** `strike_count` resets to 0 after suspension. A store could be suspended multiple times but gets permanently banned after 5 total strikes across its lifetime.

### 6.3 Auto-Fail Stuck Orders

```python
# services/penalties.py → auto_fail_stuck_orders()
# Runs every 30 minutes via scheduler

for order in orders:
    if status not in ("pending", "broadcasting", "accepted", "packed"):
        continue
    if (now - created_at) > (auto_fail_hours × 3,600,000 ms):
        → status = "failed"
        → if accepted: process_store_failure(store_id, ...)
```

**Default: 3 hours** (`AUTO_FAIL_HOURS=3`)

This catches:
- Orders stuck in `broadcasting` when broadcast task crashed
- Orders accepted but store never packed
- Orders packed but store never dispatched

### 6.4 Suspension Lift

```python
# services/penalties.py → lift_expired_suspensions()
# Runs daily at 06:00 IST via scheduler

for store in suspended_stores:
    end_date = store.get("suspension_end_date")
    if end_date and now >= end_date:
        is_suspended = False
        suspension_end_date = None
        # store is now unsuspended but NOT re-indexed in geofence
        # store owner must manually toggle is_open to get indexed
```

**Note:** Lifting suspension doesn't auto-open the store. Store owner must use `PATCH /stores/me/toggle` to toggle `is_open=true`, which re-indexes into geofence.

---

## 7. WebSocket Implementation

### 7.1 In-Memory Channel Hub

```python
# services/location_ws.py
_channels: dict[str, dict] = defaultdict(lambda: {"delivery": None, "customers": []})
```

**Key design decisions:**

1. **Not stored in Firebase:** Location data is ephemeral. Writing to Firebase every 3 seconds would be expensive (~20 writes/min per active delivery). WebSocket keeps it in-memory.

2. **One channel per order:** `channel_id = f"order_{order_id}_location"`. Multiple customers can watch the same order simultaneously (the `customers` list).

3. **Dead connection cleanup:** When delivery broadcasts location, if sending to a customer fails (they disconnected), they're removed from the list.

4. **Auth at connection time:** Firebase token verified once when WebSocket connects, not on every message.

### 7.2 Message Flow

```
Delivery Boy Phone                Backend Server               Customer Phone
      │                                │                              │
      │──────────────────────────────►│                              │
      │  WS connect                    │                              │
      │  { token, role: "delivery_boy"}│                              │
      │◄──────────────────────────────│                              │
      │  { status: "connected" }       │◄─────────────────────────────│
      │                                │  { token, role: "customer" } │
      │                                │─────────────────────────────►│
      │                                │  { status: "connected" }     │
      │                                │                              │
      │──────────────────────────────►│                              │
      │  { lat, lng, ts }             │──────────────────────────────►│
      │  (every 3 seconds)            │  { lat, lng, ts }            │
      │                                │  (fan-out to all customers)   │
```

---

## 8. Settlement System

### 8.1 Weekly Settlement Generation

```
Every Monday 08:00 IST:
  For each store:
    1. Calculate week bounds (last Monday → last Sunday)
    2. Check: settlement for this week already exists? (idempotent)
    3. Collect all orders: accepted_by_store_id == store_id AND status == "delivered"
       AND delivered_at >= week_start_ms
    4. total_platform_fee_owed = Σ(order.platform_fee_amount)
    5. Create settlement document with status="pending"
```

**What "settling" means:**  
Admin or store owner records payment via `/settlements/{id}/pay`. The platform fee (5% of product total) is owed by the store to DHAV.

### 8.2 Overdue Settlement = Store Hidden

```python
# mark_overdue_settlements() runs same Monday job
if settlement.balance_due > 0 and date.today() > week_end_date:
    is_overdue = True
    remove_store_from_geofence_index(store_id, lat, lng)
```

Once overdue, the store is removed from `geofence_index`. Customers can no longer find it. The store is re-indexed only when:
1. Admin marks the settlement as settled
2. Store owner pays and balance_due becomes 0

---

## 9. Role-Based Access Control

```python
# dependencies.py
def require_role(*roles: str):
    def _checker(user = Depends(get_current_user)):
        if user.role not in roles:
            raise HTTPException(403, "Access denied")
        if not user.is_active:
            raise HTTPException(403, "Account inactive")
        return user
    return _checker

# Usage examples:
Depends(require_role("admin"))                    # admin only
Depends(require_role("store_owner"))              # store owners only
Depends(require_role("store_owner", "delivery"))  # either role
Depends(get_current_user)                         # any authenticated user
```

**Role hierarchy:**
```
admin       → full access to everything
store_owner → manage own store, accept orders
delivery    → view assigned orders, update FCM token
customer    → place orders, view own orders, manage profile
```

---

## 10. First-Login Delivery Boy Flow

This is a unique pattern that allows store owners to pre-register delivery boys by email before they ever open the app:

```
Step 1: Store owner calls POST /stores/me/delivery-boys
        Body: { name, phone, google_account_email: "suresh@gmail.com" }
        → Creates delivery_boys/{boy_id} with google_account_email stored

Step 2: Suresh installs the store app and logs in with suresh@gmail.com

Step 3: App calls POST /auth/verify-token
        → Backend: user_data = db.reference(f"users/{uid}").get() → None (first time)
        → Backend scans all delivery_boys for matching google_account_email
        → Found! role_on_create = "delivery", store_id_on_create = "store123"
        → Creates users/{uid} with role="delivery"
        → Updates delivery_boys/{boy_id}/uid = uid  (links Firebase UID)
        
Step 4: Suresh now has role="delivery" and can use delivery endpoints
```

---

## 11. Unique Concepts & Algorithms Used

| Concept | Used In | Purpose |
|---------|---------|---------|
| **Geohash Spatial Index** | `services/geofencing.py` | O(1) spatial key → Firebase lookup |
| **Haversine Formula** | `services/geo.py` | Great-circle distance on Earth's surface |
| **Dynamic Grid Walk** | `geofencing._cells_covering_radius()` | Correct cell coverage for any radius |
| **Two-Phase Spatial Query** | `find_nearby_stores()` | Geohash coarse filter + Haversine precise filter |
| **Wave-Based Broadcasting** | `services/broadcasting.py` | Progressive radius expansion for order matching |
| **Optimistic Concurrency (Firebase Transaction)** | `atomic_accept_order()` | Race-condition safe order acceptance |
| **Two-Counter Strike System** | `services/penalties.py` | Rolling reset + lifetime permanent ban |
| **Dual-Delivery Notifications** | `services/notifications.py` | FCM push + Firebase persistence = reliable delivery |
| **Ephemeral WebSocket Hub** | `services/location_ws.py` | Real-time location without Firebase writes |
| **Collapse Key + TTL** | FCM multicast messages | Prevents stale notifications + deduplication |
| **Pre-Registration Role Bootstrapping** | `routers/auth.py` | Delivery boy email matching on first login |
| **Geofence Settlement Gate** | `services/settlements.py` | Overdue payers removed from marketplace |

---

## 12. Where to Change Things

### Change Platform Fee
```
config.py → platform_fee_percentage (default: 5.0)
.env → PLATFORM_FEE_PERCENTAGE=5.0
```

### Change Delivery Pricing
```
config.py → base_delivery_fee (default: 10.0)
           delivery_fee_per_km (default: 5.0)
.env → BASE_DELIVERY_FEE=10.0
       DELIVERY_FEE_PER_KM=5.0
```

### Change Broadcasting Radii / Timeouts
```
config.py → broadcast_wave{1,2,3}_radius_km
            broadcast_wave{1,2,3}_timeout_seconds
.env → BROADCAST_WAVE1_RADIUS_KM=1.0
       BROADCAST_WAVE1_TIMEOUT_SECONDS=45
       (and wave 2, wave 3)
```

### Change Strike/Suspension Rules
```
config.py → max_strikes_before_suspend (default: 3)
            max_total_strikes_before_ban (default: 5)
            suspension_days (default: 7)
.env → MAX_STRIKES_BEFORE_SUSPEND=3
       MAX_TOTAL_STRIKES_BEFORE_BAN=5
       SUSPENSION_DAYS=7
```

### Change Auto-Fail Timeout
```
config.py → auto_fail_hours (default: 3)
.env → AUTO_FAIL_HOURS=3
```

### Change Geohash Precision
```
config.py → geohash_precision (default: 6)
.env → GEOHASH_PRECISION=6
```
⚠️ WARNING: Changing precision requires re-indexing all stores in geofence_index!

### Change Settlement Day
```
config.py → settlement_day (default: "MONDAY")
services/scheduler.py → CronTrigger(day_of_week="mon", ...)
```

---

## 13. Known Limitations & Future Improvements

| Limitation | Impact | Suggested Fix |
|-----------|--------|--------------|
| Firebase Admin SDK is synchronous | Blocks event loop on each call | Use `asyncio.run_in_executor` with thread pool |
| Broadcast polling every 2s | Firebase read per order per 2s | Firebase RTDB real-time listener |
| In-memory broadcast tasks | Lost on server restart | Redis-backed task queue (Celery/RQ) |
| In-memory WebSocket channels | Cannot scale horizontally | Redis pub/sub for multi-instance |
| COD-only payments | No digital payments | Razorpay/Stripe integration |
| No geofence zones | All stores share same area | Zone-based routing (geofence.py model exists) |
| Settlement manual only | Admin must mark paid | Razorpay webhook → auto-settle |

---

## 14. Local Development Setup

```bash
# 1. Create virtual environment
cd backend
python -m venv .venv
.venv\Scripts\activate   # Windows
source .venv/bin/activate  # Linux/Mac

# 2. Install dependencies
pip install -r requirements.txt

# 3. Create .env file
cp .env.example .env
# Edit .env with Firebase settings

# 4. Run
uvicorn main:app --reload --port 8000

# 5. View auto-docs
# http://localhost:8000/docs  (Swagger UI)
# http://localhost:8000/redoc (ReDoc)
```

### Environment Variables Needed

```
FIREBASE_SERVICE_ACCOUNT=firebase-service-account.json  # local
# OR for production:
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}  # Railway

FIREBASE_DATABASE_URL=https://dhav-quick-commerce-default-rtdb.firebaseio.com
FIREBASE_PROJECT_ID=dhav-quick-commerce

# Optional overrides (all have defaults in config.py):
PLATFORM_FEE_PERCENTAGE=5.0
BASE_DELIVERY_FEE=10.0
DELIVERY_FEE_PER_KM=5.0
BROADCAST_WAVE1_RADIUS_KM=1.0
MAX_STRIKES_BEFORE_SUSPEND=3
```
