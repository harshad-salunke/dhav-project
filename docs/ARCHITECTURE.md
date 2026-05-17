# 🏗️ DHAV — Architecture Deep Dive

This document explains HOW the system works internally. Read this when designing new features or debugging complex issues.

---

## 1. SYSTEM OVERVIEW

DHAV is a 4-tier distributed system:

```
┌──────────────────────────────────────────────────────────────┐
│  TIER 1: CLIENT APPS (Flutter)                                │
│  - Customer App (Android/iOS)                                 │
│  - Store App with role-based UI (Owner OR Delivery Boy)       │
│  - Admin Dashboard (Web)                                      │
└──────────────────────────────────────────────────────────────┘
                            │
                            │ HTTPS (REST) + WSS (WebSocket)
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  TIER 2: APPLICATION LAYER (FastAPI Python)                   │
│  - REST API endpoints                                         │
│  - WebSocket server (live location relay)                     │
│  - Background workers (cron jobs)                             │
│  - Business logic (broadcasting, penalties, settlements)      │
└──────────────────────────────────────────────────────────────┘
                            │
                            │ Firebase Admin SDK
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  TIER 3: DATA LAYER (Firebase)                                │
│  - Realtime Database (state of stores, orders, etc.)          │
│  - Storage (images, photos)                                   │
│  - Auth (Google + Email)                                      │
│  - FCM (push notifications)                                   │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  TIER 4: EXTERNAL SERVICES                                    │
│  - Google Maps API (geocoding, navigation)                    │
│  - SMS/Email (Firebase Auth uses these internally)            │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. WHY THIS ARCHITECTURE?

### Why FastAPI instead of direct Firebase from Flutter?

**Without FastAPI:** Flutter would directly write to Firebase. Problem: business logic lives in the client. Bad actor can manipulate orders. Race conditions hard to prevent.

**With FastAPI:** Single source of truth for business logic. Atomic transactions enforced server-side. Easy to swap Firebase for PostgreSQL later. Clean separation of concerns.

### Why Firebase instead of PostgreSQL?

**For MVP/Pilot:** Firebase = zero ops, real-time syncing built-in, FCM included, security rules tight.

**Later (10K+ orders/day):** Migrate to PostgreSQL + Redis. The FastAPI layer makes this swap painless because business logic doesn't know which DB it talks to.

### Why WebSocket for location (not Firebase)?

**Why not Firebase?** Each GPS update = 1 Firebase write. At 1 update/3 seconds × 100 active orders × 20-min average delivery = 400,000 writes per hour just for location. Cost: 💸💸💸

**WebSocket approach:** GPS flows from delivery boy → FastAPI (in memory) → customer. Zero database writes. Free. Exactly how Uber/Zomato do it.

### Why monolithic backend (one FastAPI instead of microservices)?

**For 1-person dev team:** Monolith is faster to build, deploy, debug. Microservices = premature optimization.

**Later (50+ devs):** Split into services (orders, broadcasting, payments). Not now.

---

## 3. CRITICAL DATA FLOWS

### Flow 1: Order Placement

```
Customer (Flutter app)
    │
    │ 1. POST /orders { items, address, lat, lng }
    │    Authorization: Bearer <Firebase ID Token>
    ▼
FastAPI Backend
    │
    │ 2. Verify token → extract user_id
    │ 3. Validate items exist in catalog
    │ 4. Save order to Firebase: status=broadcasting, wave=1
    │ 5. Call geofencing.find_nearby_stores(lat, lng, 1km)
    │
    │    Geofencing internals:
    │    a. Compute geohash of customer location (precision 6)
    │    b. Get 8 neighbor geohash cells
    │    c. For each cell, fetch all store IDs from /geofence_index/{cell}
    │    d. For each candidate, compute exact Haversine distance
    │    e. Filter to those within radius_km
    │    f. Filter by: is_active, is_verified, not_suspended, operating_hours
    │    g. Filter by: has at least 1 ordered item in inventory
    │
    │ 6. Send FCM to all qualifying stores SIMULTANEOUSLY (high priority)
    │ 7. Start async wave-timeout task (45 seconds)
    │
    ▼
Store Phones receive FCM
    │
    │ 8. App in background → system notification (loud ring)
    │ 9. App in foreground → overlay popup (Layer 1)
    │
    ▼
First Store taps "ACCEPT"
    │
    │ 10. POST /orders/{id}/accept?store_id=X
    │
    ▼
FastAPI
    │
    │ 11. Firebase transaction:
    │     IF order.status == 'broadcasting':
    │       order.status = 'accepted'
    │       order.accepted_by_store_id = X
    │       return SUCCESS
    │     ELSE:
    │       return FAILURE (someone else won)
    │
    │ 12. On SUCCESS:
    │     - Notify customer "Order accepted by [Store]"
    │     - Notify other stores "Order taken"
    │     - Cancel wave-timeout task
    │
    ▼
Customer app receives accepted notification
Order moves to tracking screen
```

---

### Flow 2: Live Location Tracking

```
Delivery Boy phone (in motion on bike)
    │
    │ 1. Geolocator.getCurrentPosition() every 3 seconds
    │
    ▼
WebSocket connection (already open since dispatch)
    │
    │ 2. Send JSON: { lat, lng, timestamp }
    │
    ▼
FastAPI WebSocket Server
    │
    │ 3. Receives GPS in async handler
    │ 4. Look up active_channels[order_id]["customers"]
    │ 5. For each customer connection: forward GPS
    │
    │ ⚠️ Note: NO database write. Pure in-memory relay.
    │
    ▼
Customer phone (Flutter app on tracking screen)
    │
    │ 6. Receives GPS via WebSocket
    │ 7. Tween animation: smoothly move marker from old → new position over 2 seconds
    │ 8. Recalculate ETA based on distance to destination
    │
    ▼
Map shows smooth-moving pin (just like Uber/Zomato)
```

---

### Flow 3: Strike & Suspension

```
Trigger: Order auto-fails (out_for_delivery > 3 hours) OR store reports failure
    │
    ▼
FastAPI penalties.py → process_store_failure(order_id, store_id, reason)
    │
    │ 1. Read store from Firebase
    │ 2. Increment strike_count
    │ 3. Log to /strikes/{store_id}/{strike_id}
    │
    │ 4. Decision tree:
    │
    │   IF strike_count == 1 or 2:
    │     - Update warning
    │     - Send FCM: "Strike X of 3"
    │
    │   IF strike_count == 3:
    │     - Set is_suspended = true
    │     - Set suspension_end_date = NOW + 7 days
    │     - Remove from /geofence_index/{geohash}/{store_id}  ← Stops broadcasts!
    │     - Send FCM: "Suspended for 7 days"
    │
    │   IF strike_count >= 5:
    │     - Permanent ban (is_active = false)
    │
    ▼
Store no longer receives broadcasts (gracefully removed from geo lookup)
    │
    ▼
APScheduler cron (daily 6 AM IST)
    │
    │ Checks all suspended stores
    │ If suspension_end_date < now → unsuspend → re-add to geofence index
    │
    ▼
Store reappears in broadcasts after 7 days
```

---

### Flow 4: Weekly Settlement

```
Every Monday 8 AM IST — APScheduler cron job runs
    │
    │ 1. For each active store:
    │    a. Count orders delivered in last 7 days
    │    b. fee_owed = count × ₹15
    │    c. Create WeeklySettlement record in Firebase
    │    d. Send FCM: "Your settlement of ₹X is due by Sunday"
    │
    ▼
Store sees in Earnings screen
    │
    │ 2. Store pays via UPI to DHAV
    │
    ▼
Admin sees payment in bank statement
    │
    │ 3. Admin opens dashboard → Settlements → Pending
    │ 4. Finds store → "Mark as Paid" → enters payment details
    │
    ▼
Settlement status → "settled"
    │
    │ 5. Sunday 11:59 PM — Another cron job runs
    │    Any settlement still "pending" → mark "overdue"
    │    Set store.payment_overdue = true
    │    Remove from /geofence_index (gracefully)
    │
    ▼
Overdue stores hidden from broadcasts until paid
```

---

## 4. KEY ALGORITHMS

### 4.1 Geohash-based Spatial Search

**Problem:** "Find all stores within 1km of customer."

**Naive approach:** SELECT * FROM stores WHERE distance(store, customer) < 1km
→ Requires checking EVERY store. O(N) per query. Slow at scale.

**Our approach:**
1. At store registration, compute geohash (e.g., "tf1r3p" for Kothrud)
2. Index store under that geohash: `/geofence_index/tf1r3p/{store_id}`
3. At customer order, compute customer's geohash
4. Get center cell + 8 neighbor cells (handles boundary)
5. Read only those 9 keys from Firebase
6. Filter exact distance with Haversine
7. Result: O(1) lookup regardless of total store count

**Geohash precision tradeoff:**
- Precision 5 = ~5km × 5km cells (too coarse for 1km searches)
- Precision 6 = ~1.2km × 0.6km cells (perfect for kirana use case)
- Precision 7 = ~150m × 150m cells (too fine, need more neighbors)

We use precision 6.

### 4.2 Atomic Order Acceptance (Race Condition Prevention)

**Problem:** Order broadcast to 5 stores. 2 stores tap "Accept" within 100ms of each other. Both think they got it.

**Naive approach:** Read order → check if accepted → write update.
→ Race condition! Both reads see "broadcasting", both write "accepted".

**Our approach: Firebase transaction**

```python
def accept_transaction(current_order):
    if current_order is None:
        return  # abort
    if current_order.get('status') != 'broadcasting':
        return  # abort — already taken by another store
    current_order['status'] = 'accepted'
    current_order['accepted_by_store_id'] = my_store_id
    return current_order

result = order_ref.transaction(accept_transaction)
```

Firebase serializes transactions. Only one succeeds. Other gets None and knows they lost.

### 4.3 Smooth Marker Animation

**Problem:** Delivery boy GPS updates every 3 seconds. If we just jump the marker, it looks janky.

**Solution: Tween animation between updates**

```dart
class MovingMarker {
  LatLng currentPosition;
  AnimationController controller;

  void onNewGPS(LatLng newPos) {
    final start = currentPosition;
    final end = newPos;

    controller.duration = Duration(seconds: 2);
    controller.addListener(() {
      // Interpolate position based on animation value (0 to 1)
      currentPosition = LatLng(
        start.latitude + (end.latitude - start.latitude) * controller.value,
        start.longitude + (end.longitude - start.longitude) * controller.value,
      );
      updateMarkerOnMap(currentPosition);
    });
    controller.forward(from: 0);
  }
}
```

Marker glides smoothly. Just like Uber.

---

## 5. SECURITY DESIGN

### 5.1 Defense in Depth

**Layer 1: Firebase Auth**
- All users must sign in. Tokens expire in 1 hour.

**Layer 2: Firebase Security Rules**
- Even if someone bypasses Flutter app, they can't directly write to Firebase due to security rules.
- Rules check `auth.uid` matches the resource's owner.

**Layer 3: FastAPI Token Verification**
- Every API call sends Firebase ID Token
- FastAPI verifies with Firebase Admin SDK
- FastAPI looks up role and enforces permissions

**Layer 4: Business Logic**
- FastAPI rejects illegal state transitions (e.g., can't accept already-accepted order)
- Atomic transactions prevent race conditions

### 5.2 Sensitive Data Handling

| Data | Where Stored | Encryption |
|---|---|---|
| User credentials | Firebase Auth (managed) | Yes |
| Customer phone numbers | Firebase Realtime DB | At rest by Firebase |
| Customer addresses | Firebase Realtime DB | At rest by Firebase |
| Order details | Firebase Realtime DB | At rest by Firebase |
| Live GPS coordinates | ⚠️ NEVER STORED — WebSocket only | N/A |
| Payment details | Not stored (cash on delivery) | N/A |

### 5.3 What If Backend Crashes?

- **REST API down:** Apps show error, retry with exponential backoff
- **WebSocket server down:** Customer app falls back to polling /orders/{id}/location every 10s. Delivery boy app caches GPS locally and sends in batch on reconnect
- **Firebase down:** Total outage. Nothing we can do (Firebase has 99.95% SLA)

---

## 6. SCALABILITY PATH

### Current capacity (Phase 1, Pune):
- 100 stores
- 500 orders/day
- 50 concurrent live deliveries
- Single FastAPI instance on Railway
- Firebase Spark plan (free)

### When to scale:
- **500 stores:** Move to Firebase Blaze plan (pay-as-you-go)
- **5,000 orders/day:** Add Redis for caching geofence lookups
- **50,000 orders/day:** Migrate to PostgreSQL + PostGIS (real geo-indexing)
- **500,000 orders/day:** Split into microservices, add Kubernetes

### Performance targets:
- Order broadcast latency: < 3 seconds
- API response time: < 500ms (p99)
- WebSocket message latency: < 500ms
- Map marker animation FPS: 60

---

## 7. DATABASE INDEXES TO ADD

Firebase Realtime DB doesn't have traditional indexes, but you can add `.indexOn` rules for faster queries:

```json
{
  "rules": {
    "orders": {
      ".indexOn": ["customer_id", "accepted_by_store_id", "status", "created_at"]
    },
    "stores": {
      ".indexOn": ["is_active", "is_suspended", "zone_id"]
    }
  }
}
```

---

## 8. DEPLOYMENT TOPOLOGY

### Development:
```
Local Flutter emulator → ngrok tunnel → Local FastAPI → Firebase
```

### Production:
```
Mobile apps (Play Store/App Store) → Railway FastAPI → Firebase
Admin Dashboard (Firebase Hosting) → Railway FastAPI → Firebase
```

### Why Railway over Cloud Run?
- Simpler deployment (push to Git → auto deploy)
- Free tier covers MVP
- Built-in env var management
- Easy logs

When to switch to Cloud Run: > 100K requests/day or need auto-scaling.

---

## 9. MONITORING & OBSERVABILITY

Add these from Day 1:

**Backend:**
- Log every API call with request ID
- Log every Firebase write
- Sentry for error tracking (free tier)

**Apps:**
- Firebase Crashlytics (free)
- Track key events (order placed, accepted, delivered)

**Admin Dashboard:**
- Real-time metrics from /admin/analytics/overview
- Daily email summary to founder

---

## 10. ANTI-PATTERNS TO AVOID

❌ **Storing GPS coordinates in database** — use WebSocket instead

❌ **Direct Firebase writes from Flutter** — always go through FastAPI

❌ **Polling for order status** — use Firebase listeners or WebSocket

❌ **Building location history feature** — privacy risk, performance hit

❌ **Sequential broadcasting** — must be simultaneous to nearby stores

❌ **Charging customer convenience fee** — kills the value prop

❌ **Allowing stores to set delivery fee** — keeps pricing complex

❌ **Adding chat between customer-store** — out of scope for MVP

---

*This architecture is designed for a 12-week build by a small team. It will get you to product-market fit. Scaling beyond requires evolution, not revolution.*
