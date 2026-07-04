# DHAV — System Design Teaching Notes
**Your personal guide to understanding how platforms like Blinkit & Zepto are built**

> This file is YOUR notes. Every time we add a new system design concept, it goes here first.
> Read this before implementation sessions so you understand WHY we're doing what we're doing.

> 📌 **Reading note (2026-06-13):** the *concepts* below are all still valid and worth
> learning, but the *examples* written before ~2026-06-06 reference Firebase Realtime
> Database — the backend has since migrated ALL data to **Supabase PostgreSQL** (Firebase
> now does Auth + FCM only) and hosting moved Railway → **Render**. In particular,
> Concept 19 (`.indexOn`) is historical — Postgres indexes (`CREATE INDEX` in
> `backend/migrations/`) solve that problem now. Current truth: `docs/ENHANCEMENTS.md`.

---

## 🎯 The Big Picture — What is "System Design"?

System design is simply: **how you architect your software so it works fast, doesn't crash under load, and costs money efficiently.**

Think of it like this: Your DHAV backend right now is like a single shopkeeper who has to run to the godown every time a customer asks for a product price. Blinkit's backend is like a shopkeeper who has a cheatsheet of all prices on the counter — they don't need to run to the godown every time.

---

## 📊 Problem 1: WHY is DHAV Backend Currently Slow?

### What happens when a customer opens the app today:

```
Customer opens app
    → Flutter calls GET /catalog/items
        → FastAPI calls Firebase Realtime DB (network call across the internet)
            → Firebase reads ALL 50+ items from disk
                → Returns to FastAPI
                    → FastAPI sends to Flutter
```

**The problem: Every single user, every single time, makes a round trip to Firebase.**

- Firebase Realtime Database is hosted in the US/Mumbai data center
- Each "read" from Firebase = 1 network round trip = 100-300ms delay
- If 100 customers open the app at the same time = 100 separate Firebase reads
- The catalog data NEVER CHANGES between reads — but we fetch it fresh every time!

### The "N+1 Problem" (a classic system design mistake)

Look at this code in catalog.py:
```python
# GET /catalog/stores/nearby
for store_data in nearby_stores:
    store_node = db.reference(f"stores/{store_data['store_id']}").get()  # Firebase call
    for item_id in store_node.get("available_item_ids"):
        item_data = db.reference(f"catalog/{item_id}").get()  # Firebase call PER ITEM
```

If there are 5 nearby stores with 20 items each = **1 + 5 + 100 = 106 Firebase network calls** for ONE API request!

This is called the **N+1 problem** — doing N database calls in a loop instead of 1 batch call.

---

## 💡 Concept 1: Caching — The Most Important Performance Tool

### What is a Cache?

A **cache** is a place to store data that you'll need again soon, in a location that's faster to access than the original source.

**Real world analogy:** When you're studying, you keep your most-used textbooks on your desk, not in the library. Your desk = cache. Library = database.

### Types of Caches (from fastest to slowest):

| Level | Speed | Where | Example |
|-------|-------|--------|---------|
| L1 Cache | ~1 nanosecond | Inside CPU chip | CPU's built-in memory |
| L2/L3 Cache | ~10 nanoseconds | Near CPU | CPU's built-in memory |
| RAM (In-Memory) | ~100 nanoseconds | Your server's RAM | Python dict, Redis |
| SSD/Disk | ~1 millisecond | Hard drive | SQLite, files |
| Network (Firebase) | ~100 milliseconds | Cloud server | Firebase, Postgres |

**Our goal: Move catalog data from Network (100ms) to In-Memory (100ns) = 1000x faster**

### What is Redis?

Redis = **Re**mote **Di**ctionary **S**erver

It's like a very fast Python dictionary that lives as its own server process:
```
Python Dict (your code): {"item1": {...}, "item2": {...}}  ← only in 1 process, gone on restart
Redis:                    {"item1": {...}, "item2": {...}}  ← shared across all processes, survives restart
```

**Why use Redis over a Python dict?**
- Python dict only works in 1 server process — if you have 4 worker processes, each has its OWN copy
- Redis is a separate service — all 4 workers share the same data
- Redis can expire keys automatically (very useful for "stale" data)
- Redis can handle 100,000 reads per second

### The Simplest Cache: In-Memory (Python dict)

For our MVP, we can start with a simple in-memory cache:
```python
# Simple cache with TTL (Time To Live)
_cache = {}  # {"key": (data, expiry_timestamp)}

def cache_get(key):
    if key in _cache:
        data, expires = _cache[key]
        if time.time() < expires:
            return data  # ← returns in nanoseconds
    return None

def cache_set(key, data, ttl_seconds=300):
    _cache[key] = (data, time.time() + ttl_seconds)
```

**What should we cache for DHAV?**

| Data | Cache Duration | Why |
|------|---------------|-----|
| Catalog items | 5 minutes | Changes rarely (admin edits) |
| Catalog categories | 10 minutes | Almost never changes |
| Store profiles | 2 minutes | Can change (open/close toggle) |
| Nearby stores list | 1 minute | Changes when new stores register |
| Store inventory | 1 minute | Can change when owner edits |

---

## 💡 Concept 2: Async Concurrent Reads

### What is "Async"?

Imagine you're making chai. Without async:
- Boil water (3 min) → WAIT
- Heat milk (2 min) → WAIT  
- Add tea leaves (30 sec)
- Total: 5.5 minutes

With async:
- Start boiling water AND heating milk at the SAME TIME
- Both take time together, not in sequence
- Total: 3 minutes

**In code terms:**
```python
# SLOW (sequential — like waiting for each Firebase call):
store1 = db.reference("stores/s1").get()  # Wait 200ms
store2 = db.reference("stores/s2").get()  # Wait 200ms  
store3 = db.reference("stores/s3").get()  # Wait 200ms
# Total: 600ms

# FAST (concurrent — like starting all at once with asyncio):
import asyncio
store1, store2, store3 = await asyncio.gather(
    fetch_store("s1"),
    fetch_store("s2"),
    fetch_store("s3"),
)
# Total: ~200ms (all happen at the same time)
```

### Why FastAPI is already "async" capable

FastAPI is built on `asyncio` — Python's tool for doing multiple things at once. But Firebase Admin SDK's `.get()` calls are **synchronous** (blocking). We need to use `asyncio.to_thread()` to run them concurrently.

---

## 💡 Concept 3: Database Indexing

### What is an Index?

An index is like the index at the back of a book. Instead of reading every page to find "Redis", you go to the index → "Redis: pages 45, 67, 89".

**Firebase Realtime Database index example:**
```
Without index: "Find all stores in Kothrud"
→ Read ALL stores → Check each one → Filter by area = "Kothrud"

With index (our geohash system): "Find all stores in Kothrud"  
→ Go to geofence_index/te7j → Get list of stores in that geohash cell → Done
```

We already have geohash indexing! The issue is we still do individual Firebase reads per store.

---

## 💡 Concept 4: CDN (Content Delivery Network)

### What is a CDN?

CDN = A network of servers around the world that cache your files close to the user.

**Problem without CDN:**
- Customer in Pune requests product image
- Image is stored on your Railway server in Europe
- Request travels: Pune → Europe → Pune = 300ms

**Problem WITH CDN (like Cloudflare):**
- Customer in Pune requests product image
- CDN has a copy in Mumbai
- Request travels: Pune → Mumbai CDN → Pune = 10ms

**What should go on CDN for DHAV?**
- Product images (catalog photos)
- Category icons
- Store profile photos
- The Flutter APK itself

We're using Firebase Storage already — Firebase Storage integrates with Google's CDN automatically. We just need to use proper URLs.

---

## 💡 Concept 5: Background Pre-warming

### What is "Cache Warming"?

Cache warming = loading data into cache BEFORE users ask for it.

**Problem:** First user after server restart gets slow response (cache is empty, must hit Firebase)

**Solution:** On server startup, load the catalog into cache immediately:
```python
@asynccontextmanager
async def lifespan(app):
    init_firebase()
    start_scheduler()
    await warm_cache()  # ← Load catalog into cache at startup
    yield
```

Now ALL users get fast responses from the very first request.

---

## 💡 Concept 6: HTTP Response Compression (GZIP)

### What is Compression?

When your API returns a large JSON response, it can be compressed (zipped) before sending:

```
Without compression: {"items": [{...}, {...}, ...]} = 50KB transferred
With GZIP:           compressed data                = 8KB transferred
```

Smaller data = faster download = better performance on slow mobile networks (which most kirana users have).

FastAPI supports this with one line:
```python
from fastapi.middleware.gzip import GZipMiddleware
app.add_middleware(GZipMiddleware, minimum_size=1000)
```

---

## 💡 Concept 7: Pagination

### What is Pagination?

Pagination = sending data in "pages" instead of all at once.

**Problem:** If catalog grows to 500 items, sending all 500 every time is wasteful.

**Solution:**
```
GET /catalog/items?page=1&limit=20  → items 1-20
GET /catalog/items?page=2&limit=20  → items 21-40
```

Flutter loads the first 20 items instantly, then loads more as the user scrolls down (called "infinite scroll").

---

## 💡 Concept 8: Database Choice — Firebase vs PostgreSQL vs Redis

### Our current situation:

| Data Type | What we use | Problem |
|-----------|------------|---------|
| User data | Firebase Realtime DB | Good, works fine |
| Catalog | Firebase Realtime DB | Slow for repeated reads |
| Orders | Firebase Realtime DB | Slow for complex queries |
| Cache | Nothing | Should add Redis or in-memory |

### What Zepto/Blinkit likely use:

| Data Type | What they use | Why |
|-----------|--------------|-----|
| Product catalog | PostgreSQL + Redis cache | SQL is fast for queries, Redis for hot data |
| Orders | PostgreSQL | Complex queries, transactions |
| Session/Cache | Redis | Sub-millisecond reads |
| Images | S3/GCS + CDN | Cheap storage, fast delivery |
| Real-time events | Kafka | High-volume order events |

### For DHAV (pragmatic approach):

We DON'T need to replace Firebase right now. We can get 10x faster by just adding:
1. In-memory caching (Python dict, free, zero setup)
2. Async concurrent Firebase reads
3. GZIP compression
4. Background cache warming

These 4 changes alone will make 80% of our slowness go away.

---

## 🗺️ DHAV System Design Roadmap

### Phase A: Quick Wins (1-2 days, no new services) ← START HERE
- [ ] In-memory cache for catalog (TTL-based)
- [ ] Async concurrent reads for nearby store lookups
- [ ] GZIP response compression
- [ ] Background catalog pre-warming on startup

### Phase B: Better Caching (3-5 days, Redis needed)
- [ ] Redis for shared cache across workers
- [ ] Cache invalidation when admin updates catalog
- [ ] Cache warming scheduler

### Phase C: CDN + Images
- [ ] Optimize Firebase Storage image URLs for CDN delivery
- [ ] Add image size hints to catalog items (thumbnail vs full)

### Phase D: Database Evolution (future, when scaling)
- [ ] Move catalog to PostgreSQL for complex queries
- [ ] Keep Firebase for real-time features (WebSocket, notifications)
- [ ] Move orders to PostgreSQL for reporting

---

## 📈 Expected Performance Gains

| Operation | Current | After Phase A |
|-----------|---------|---------------|
| GET /catalog/items | ~800ms | ~50ms (16x faster) |
| GET /catalog/stores/nearby | ~1500ms | ~200ms (7x faster) |
| GET /catalog/stores/{id} | ~600ms | ~30ms (20x faster) |
| Server startup | 2s | 3s (slightly slower — warming) |

---

## 🔍 How to Measure Performance

We can add timing to our API to see exactly how long each part takes:
```python
import time
start = time.time()
result = db.reference("catalog").get()
print(f"Firebase read took: {(time.time() - start)*1000:.1f}ms")
```

---

## 🎓 Vocabulary Glossary

| Term | Simple Definition |
|------|------------------|
| Cache | Fast temporary storage for frequently-used data |
| Redis | Fast key-value store, like a Python dict but shared |
| CDN | Network of servers that put files close to users |
| Async | Doing multiple things at the same time |
| N+1 Problem | Bug where you do N database calls in a loop |
| TTL | Time To Live — how long cached data stays valid |
| Indexing | Organizing data so lookups are faster |
| Pagination | Sending data in pages instead of all at once |
| Cache Warming | Pre-loading cache before users request data |
| Throughput | How many requests a server can handle per second |
| Latency | How long ONE request takes to complete |
| GZIP | Compression algorithm for reducing response size |

---

## 🎓 Vocabulary Glossary — Advanced Terms (Added 2026-05-28)

| Term | Simple Definition |
|------|------------------|
| Microservices | Splitting one big app into many small independent apps (e.g. separate Order Service, Catalog Service) |
| Monolith | One big app that does everything — what DHAV currently is |
| API Gateway | A single front door for all apps — routes requests, checks auth, limits traffic |
| Kafka | A message queue where services publish and subscribe to events — like a newspaper everyone subscribes to |
| Message Queue | A system where services send messages to each other without waiting for a reply |
| Soft Reservation | Temporarily holding an item (e.g. in cart) without selling it yet — has a timeout |
| Hard Reservation | Item is officially sold — inventory permanently decremented |
| Elasticsearch | A search engine database — very fast for text search |
| Kubernetes | A system that manages and auto-scales many Docker containers |
| Docker | Packaging your app + all its dependencies into a portable box |
| Load Balancer | Distributes incoming traffic across multiple servers so no single one is overloaded |
| Read Replica | A copy of a database used only for reading — takes load off the main database |
| Database Sharding | Splitting a database into pieces by some key (e.g. city_id) — each piece on different server |
| Circuit Breaker | A pattern that stops calling a failing service and returns a fallback instead |
| PostGIS | A PostgreSQL extension for location/geospatial queries — faster than our geohash |
| Service Mesh | Infrastructure that manages communication between microservices (e.g. Istio) |
| Dark Store | A warehouse that looks like a store but is only for packing online orders, not walk-in customers |
| Event-Driven Architecture | Services react to events (like "order_placed") instead of calling each other directly |

---

---

# 🏗️ FULL SCALE SYSTEM DESIGN — For When You Have 100+ Engineers
## (How Blinkit & Zepto Actually Work — Your Future Reference)

> This section is your FUTURE roadmap. Read it to understand where DHAV can go.
> You don't need to build this now. But knowing this helps you make RIGHT decisions today
> so you don't have to undo everything tomorrow.

---

## HIGH LEVEL DESIGN (HLD) — The Complete Picture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│   📱 Customer App    📱 Store App    📱 Rider App    💻 Admin   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTPS
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│                      API GATEWAY                                │
│   • Rate Limiting (prevent abuse)                               │
│   • Authentication (verify JWT tokens)                          │
│   • Request Routing (send to right service)                     │
│   • Load Balancing (distribute traffic)                         │
│   • SSL Termination (handle HTTPS)                              │
└──┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬────────────┘
   │      │      │      │      │      │      │      │
   ↓      ↓      ↓      ↓      ↓      ↓      ↓      ↓
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│Order │ │Inven-│ │Cata- │ │Deliv-│ │User  │ │Notif-│ │Pay-  │ │Analy-│
│Svc   │ │tory  │ │log   │ │ery   │ │Svc   │ │ication│ │ment  │ │tics  │
│      │ │Svc   │ │Svc   │ │Svc   │ │      │ │Svc   │ │Svc   │ │Svc   │
└──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘
   │        │        │        │        │        │        │        │
   └────────┴────────┴────────┴────────┴────────┴────────┴────────┘
                                    │
                                    ↓
                    ┌───────────────────────────┐
                    │    KAFKA (Event Bus)       │
                    │  All services publish &    │
                    │  subscribe to events here  │
                    └───────────┬───────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          ↓                     ↓                     ↓
  ┌──────────────┐    ┌──────────────────┐   ┌──────────────┐
  │  PostgreSQL  │    │   Redis Cluster  │   │   MongoDB    │
  │              │    │                  │   │              │
  │  • Orders    │    │  • Inventory     │   │  • Catalog   │
  │  • Users     │    │    counts        │   │  • Reviews   │
  │  • Payments  │    │  • Sessions      │   │  • Flexible  │
  │  • Sharded   │    │  • Cart data     │   │    product   │
  │    by city   │    │  • Cache         │   │    data      │
  └──────────────┘    └──────────────────┘   └──────────────┘
          │
          ↓
  ┌──────────────┐    ┌──────────────────┐   ┌──────────────┐
  │ Elasticsearch│    │   CDN            │   │  Kubernetes  │
  │              │    │ (Cloudflare)     │   │              │
  │  • Product   │    │  • Images        │   │  • Auto-     │
  │    search    │    │  • Static files  │   │    scales    │
  │  • Fast text │    │  • APK files     │   │    services  │
  │    queries   │    │                  │   │  on demand   │
  └──────────────┘    └──────────────────┘   └──────────────┘
```

---

## LOW LEVEL DESIGN (LLD) — How Each Critical System Works

### LLD 1: Order Processing Pipeline (The Core)

```
STEP 1: Customer places order (target: respond in < 200ms)
─────────────────────────────────────────────────────────
  Flutter → POST /orders
      ↓
  API Gateway → validates token
      ↓
  Order Service:
      → Check cart validity
      → Run fraud check (ML model)
      → Reserve inventory (soft lock in Redis, 10 min TTL)
      → Initiate payment
      ↓
  Publish event: "order_placed" to Kafka
      ↓
  Return order_id to user immediately ← USER SEES CONFIRMATION

STEP 2: Background processing (Kafka consumers)
─────────────────────────────────────────────────────────
  "order_placed" event triggers:
      → Inventory Service:  decrement stock in Redis
      → Dark Store Service: assign best store (scoring algorithm)
      → Notification Svc:   send FCM push to customer + store
      → Analytics Svc:      log order event

STEP 3: Store picks & packs (2-3 min window)
─────────────────────────────────────────────────────────
  Store worker gets pick list sorted by physical store location
  (Z-path optimization — minimize walking distance)
  Barcode scan each item → confirms correct item picked

STEP 4: Delivery assignment (pre-staged rider)
─────────────────────────────────────────────────────────
  Rider scoring algorithm:
      Score = (Distance to store × 40%)
            + (Rider rating × 20%)
            + (Current orders × 10%)
            + (Historical on-time % × 30%)
  Highest score wins the order
  Rider is assigned DURING packing (not after) → saves 2-3 min
```

---

### LLD 2: Inventory System — Preventing Overselling

```
Problem: 2 customers buy the last item at the same time
Solution: Atomic operations in Redis

CART ADD (soft reservation):
───────────────────────────
  Customer adds item to cart
      ↓
  Redis atomic script:
      IF stock_count > 0:
          stock_count -= 1
          reserved_for[cart_id] = item_id  (expires in 10 min)
          return SUCCESS
      ELSE:
          return OUT_OF_STOCK
  This happens atomically — no race condition possible

CHECKOUT (hard reservation):
─────────────────────────────
  Payment confirmed
      ↓
  Convert soft → hard reservation
  Write to PostgreSQL: order created, inventory sold
  Remove from Redis reserved pool

CART ABANDONED (auto cleanup):
────────────────────────────────
  Redis TTL expires after 10 min
  stock_count += 1 automatically
  Item back in stock for next customer
```

---

### LLD 3: Store/Dark Store Selection Algorithm

```
When order is placed, which store should fulfill it?

candidates = stores within 3km radius
for each store:
    score = 0
    score += (1 - distance/3km) × 40          # closer = higher score
    score += (has_all_items ? 30 : partial%)   # stock availability
    score += (1 - current_orders/capacity) × 20 # operational load
    score += (has_idle_rider ? 10 : 0)         # rider readiness

pick store with highest score
if no store qualifies → expand to 5km → try again
if still none → order fails with "no stores available"
```

---

### LLD 4: Caching Strategy — 4 Layers

```
Every read request goes through these layers in order:

REQUEST → L1 CDN → L2 Server Memory → L3 Redis → L4 PostgreSQL/Firebase
          (miss)          (miss)          (miss)     (always has it)

L1: CDN (Cloudflare/AWS CloudFront)
    → What: Product images, APK files, static assets
    → TTL: 1 hour to 24 hours
    → Hit rate: ~95% for images
    → Miss cost: goes to Firebase Storage / S3

L2: Server Memory (per-instance Python dict)
    → What: Catalog item details, category list
    → TTL: 30 seconds
    → Hit rate: ~80% for catalog
    → Miss cost: goes to L3 Redis

L3: Redis Cluster (shared across all server instances)
    → What: Inventory counts, user sessions, cart data, store status
    → TTL: 1 second for inventory, 5 min for catalog, 30 min for sessions
    → Hit rate: ~99% for inventory reads
    → Miss cost: goes to L4 database

L4: PostgreSQL / Firebase (source of truth)
    → What: Everything — orders, users, full catalog
    → No TTL — permanent storage
    → Only ~5% of reads reach here

Result: 95% of requests never touch the database
```

---

### LLD 5: Real-Time Delivery Tracking

```
Rider's phone → sends GPS every 3 seconds
      ↓
  POST /location/update
      ↓
  Location Service:
      → Save to Redis (key: "rider:{id}:location", TTL: 30s)
      → Publish to Kafka topic: "location_updates"
      ↓
  Kafka consumer:
      → WebSocket hub receives location
      → Pushes to all customers tracking this order

Customer's app:
      ↓
  WebSocket connection open (persistent)
      ← receives location update every 3 seconds
      → Flutter animates marker on Google Maps smoothly

If WebSocket disconnects (poor network):
      → Flutter falls back to polling GET /orders/{id}/location every 10s
```

---

### LLD 6: Kafka Event System (The Backbone)

```
Every important action publishes an event to Kafka:

TOPIC: order_events
  → order_placed      { order_id, customer_id, store_id, items[], amount }
  → order_accepted    { order_id, store_id, estimated_time }
  → order_packed      { order_id, store_id }
  → order_dispatched  { order_id, rider_id }
  → order_delivered   { order_id, delivery_time }
  → order_failed      { order_id, reason }

TOPIC: inventory_events
  → stock_decremented { store_id, item_id, new_count }
  → stock_replenished { store_id, item_id, new_count }
  → stock_low_alert   { store_id, item_id, count }

TOPIC: rider_events
  → rider_online      { rider_id, location }
  → rider_offline     { rider_id }
  → rider_assigned    { rider_id, order_id }

WHO LISTENS TO WHAT:
  Notification Service  → listens to order_events → sends FCM push
  Analytics Service     → listens to all events   → builds dashboards
  Inventory Service     → listens to order_events → updates stock
  Settlement Service    → listens to order_events → tracks platform fees
```

---

### LLD 7: Database Sharding (For City-Level Scale)

```
Problem: When DHAV is in 10 cities with 1000 orders/second,
         one PostgreSQL server can't handle it.

Solution: Shard by city_id

Pune shard   → all orders, users, stores from Pune
Mumbai shard → all orders, users, stores from Mumbai
Delhi shard  → all orders, users, stores from Delhi

Each shard = independent PostgreSQL server
Shard router (API Gateway) → reads city from request → sends to right shard

Benefits:
  → Pune's heavy load doesn't affect Mumbai
  → Can add new city without touching existing shards
  → Each city can be hosted in regional AWS data center (lower latency)

For DHAV today: single database is fine (only Pune, low traffic)
Shard when: crossing 500 orders/day consistently
```

---

## 🏢 FULL TECH STACK REFERENCE — Blinkit/Zepto Level

### Backend Services
| Service | Tech | Why |
|---------|------|-----|
| API Gateway | Kong / AWS API Gateway | Industry standard, handles auth + routing |
| Core Services | Java Spring Boot / Python FastAPI | High performance, great ecosystem |
| Real-time | Node.js + Socket.io | Non-blocking I/O, best for WebSockets |
| ML/Forecasting | Python + TensorFlow | Demand prediction, personalization |

### Databases
| Database | Use Case | Why |
|----------|----------|-----|
| PostgreSQL | Orders, Users, Payments | ACID transactions, complex queries |
| Redis | Cache, Sessions, Inventory | Sub-millisecond reads, atomic ops |
| MongoDB | Catalog, Reviews | Flexible schema, easy to change |
| Elasticsearch | Product search | Full-text search, typo tolerance |
| Cassandra | Ride tracking, logs | High write throughput, time-series |

### Infrastructure
| Tool | Purpose | Why |
|------|---------|-----|
| Docker | Package apps into containers | Consistent environment everywhere |
| Kubernetes | Manage + auto-scale containers | Handles traffic spikes automatically |
| Kafka | Event streaming between services | Decouples services, never loses events |
| Cloudflare | CDN + DDoS protection | Images & assets delivered fast worldwide |
| AWS | Cloud hosting | Reliable, scales infinitely |
| Prometheus + Grafana | Monitoring dashboards | See what's failing before users do |
| ELK Stack | Log aggregation | Debug issues across microservices |

### Team Structure (For 100 Engineers)
```
Engineering Teams:
  Platform Team (10)     → API Gateway, auth, shared infrastructure
  Catalog Team (8)       → Product catalog, search, categories
  Order Team (12)        → Order flow, state machine, payments
  Inventory Team (10)    → Stock management, reservations, forecasting
  Delivery Team (12)     → Rider assignment, routing, tracking
  Notification Team (6)  → Push, SMS, email, WhatsApp
  Analytics Team (8)     → Dashboards, ML, data pipelines
  Mobile Team (16)       → Customer app, store app, rider app
  DevOps/SRE Team (10)   → Kubernetes, CI/CD, reliability
  Data Science (8)       → Demand forecasting, recommendations
```

---

## 📊 Scale Numbers — What These Systems Handle

| Metric | Blinkit/Zepto Scale | DHAV Today | DHAV Target (Year 1) |
|--------|--------------------|-----------|--------------------|
| Daily orders | 500,000–1,000,000 | < 100 | 500–1,000 |
| Peak orders/sec | 230+ | < 1 | 5–10 |
| Cities | 20+ | 1 (Pune) | 1 (Pune) |
| Dark stores / Kirana stores | 500+ per city | 10–20 | 50–100 |
| Engineers | 200–500 | 1 (you!) | 1–5 |
| Infrastructure cost/month | $50,000+ | ~$50 | ~$200 |

---

## 🔑 Key Lessons From Blinkit/Zepto That Apply to DHAV TODAY

1. **Inventory reservation matters even at small scale** — if 2 customers order the last item, someone gets a cancelled order. Fix this early.
2. **Order state machine must be strict** — every state transition has a timeout. If store doesn't accept in 45s, auto-broadcast next. If no store in 3 min, fail the order. This is already partially built in DHAV.
3. **Notifications are critical to trust** — customer must know every state change instantly. Already built but needs reliability.
4. **Dark store = Kirana store in DHAV** — the algorithms are the same, just different physical setup.
5. **Start monolith, split later** — Zepto started as a monolith too. Split into microservices only when a specific service becomes a bottleneck. Don't split early — it's complexity you don't need yet.

---

---

# 🚀 SESSION 2026-05-30 — Production Scaling Deep Dive

> This whole section was written the day we made DHAV's backend production-grade.
> Every concept below follows the SAME structure so it's easy to study:
> **What it is → Why DHAV needed it → Where in our code → Real order example →
> Impact (what we gained) → If we had NOT done it (the bug that would remain).**
>
> Read this top-to-bottom once. It explains the difference between "an app that works
> in a demo" and "an app that survives thousands of real users like Blinkit/Zepto".

---

## 💡 Concept 9: Workers (running many copies of the backend)

### What it is
Your backend is one Python program: `uvicorn main:app`. When it runs, it's **one process**
— one living copy of your code sitting in the server's RAM. A **worker = one running copy
of your backend.** Running `uvicorn main:app --workers 4` starts **4 identical copies** side
by side, and a built-in load balancer hands each incoming request to whichever copy is free.

**Analogy:** the event loop is one very fast *waiter*. A worker is one waiter. `--workers 4`
means you hired 4 waiters, so 4 customers can be served at the exact same moment.

### Why DHAV needed it
A server machine has several **CPU cores**. One worker only uses **one core**. To use the
whole machine (and serve more people at once) you run several workers — roughly one per core.
More workers = more simultaneous customers + if one crashes the others keep serving.

### Where in our code
This is an **operational setting**, not code: `uvicorn main:app --workers 4` (or set it on
Railway). You don't change Python for it — BUT it exposes a trap (next paragraph) that we
*did* have to fix in code.

### ⚠️ The trap that connects everything in this session
Each worker is a **separate process with its own separate memory**. They cannot see each
other's Python variables:
```
Worker 1 RAM:                 Worker 2 RAM:
  _local_customers = {...}      _local_customers = {...}   ← DIFFERENT objects
  catalog_cache   = {...}       catalog_cache   = {...}    ← DIFFERENT copies
```

### Real order example
A delivery boy for **order #42** opens his app and connects to **Worker 1**. The customer
tracking #42 opens her app and connects to **Worker 2**. The rider's GPS arrives at Worker 1
and is stored in Worker 1's memory. Worker 2 has no idea — so the customer's map **never
moves.** Live tracking is silently broken. (Concept 13 — Redis Pub/Sub — fixes exactly this.)

### Impact / what we gained
Understanding workers is *why* we built the Redis bus and the cross-worker cache. With those
in place, going from 1 → 4 workers becomes a 1-line ops change instead of a rewrite.

### If we had NOT understood this
We'd add `--workers 4` to "go faster", and tracking + cache would break intermittently and
unpredictably in production — the hardest kind of bug to debug.

---

## 💡 Concept 10: The Blocking Event Loop (our #1 hidden bottleneck)

### What it is
FastAPI serves many requests on a **single thread** running an "event loop" (one waiter).
The magic that lets one waiter serve a full restaurant: while a table waits for the kitchen
(a network call), the waiter goes and serves other tables — *but only if you marked that step
as a waiting task with `await`.* A **blocking** call is a step that does NOT release the
waiter: he stands frozen at one table until it finishes.

The Firebase SDK call `db.reference(...).get()` is **blocking**. It takes 100–300 ms (a trip
across the internet to Firebase), and during that whole time the single waiter is frozen —
**no other request, and no live GPS broadcast, gets served.**

### Why DHAV needed the fix
Almost every endpoint (`orders.py`, `stores.py`, broadcasting, the WebSocket hub) called the
blocking Firebase SDK *directly inside `async def`*. At 1 user it's invisible. At 100 users
their waits stack up into multi-second freezes. Real concurrency was effectively **1**.

### Where in our code
New file **`backend/services/firebase_async.py`**. It pushes each blocking call onto a thread
pool and `await`s it, freeing the waiter:
```python
# services/firebase_async.py
async def get(path):
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(_executor, lambda: db.reference(path).get())
```
Then everywhere we replaced `db.reference(path).get()` with `await fb.get(path)`. Converted:
`orders.py`, `stores.py` (all 30 calls), `catalog.py`, `broadcasting.py`, `location_ws.py`.

> **Golden rule to remember forever:** never call a blocking (non-`await`) network/disk
> function directly inside `async def`. Always wrap it with `fb.*` (or `run_in_executor`).

### Real order example
A customer taps **Place Order**. The handler must write the order, then later read store
tokens, etc. **Before:** while that one POST waited ~300 ms on Firebase, a *different*
customer's catalog request and a rider's GPS update were both frozen behind it. **After:**
the waiter starts the Firebase write, immediately serves the other customer's catalog and the
rider's GPS, then comes back when Firebase replies.

### Impact / what we gained
The server now stays responsive under load; throughput scales with the thread pool (32) instead
of being serialized to ~1 at a time. **This is the single change that makes "thousands of
concurrent users" possible** — no amount of caching could have fixed it, because caching
doesn't help writes or the live-tracking path.

### If we had NOT done this
The app would feel fine in your solo testing and then fall over the moment 50–100 real users
in Kothrud used it at once — exactly when you can least afford it. Tracking would stutter and
APIs would time out under mild load.

---

## 💡 Concept 11: Concurrent Reads — killing the N+1 problem for real

### What it is
"N+1" = doing N database calls **one after another in a loop** instead of all at once.
Because each Firebase read is now `await`-able (Concept 10), we can fire many at the same time
and wait for all of them together.

### Why DHAV needed it
Accepting an order had to notify all the *other* stores that the order was taken — the old code
fetched each store's FCM token in a sequential loop (read store 1, wait; read store 2, wait…).
With 8 nearby stores that's 8 × 200 ms = **1.6 s** of waiting.

### Where in our code
`fb.get_many([...])` in `firebase_async.py`, used in `broadcasting.py` (token fetch),
`orders.py` (accept → notify others), and `catalog.py` (store inventory items):
```python
# all reads happen at the same time, total ≈ the time of ONE read
nodes = await fb.get_many([f"stores/{sid}/fcm_token" for sid in store_ids])
```

### Real order example
Store A accepts order #42. We must tell stores B, C, D, E, F, G, H "too late, it's taken".
**Before:** 7 reads in a row ≈ 1.4 s. **After:** 7 reads at once ≈ 0.2 s. The accepting store
owner gets their confirmation almost instantly instead of watching a spinner.

### Impact / what we gained
The broadcast/accept path went from "seconds" to "fraction of a second", and it no longer
scales linearly with the number of nearby stores.

### If we had NOT done this
Every order in a dense area (many nearby stores) would be sluggish to accept, and the slowness
would get *worse* as you onboard more stores — the opposite of what you want.

---

## 💡 Concept 12: Memory Leak (where ours was, and how we killed it)

### What it is
A **memory leak** is when a program keeps adding things to memory and never removes them, even
after they're no longer needed. RAM usage creeps up forever until the server slows down,
crashes, or gets killed by the host (Railway will restart it — dropping all live connections).

### Why/where DHAV had one
The live-location WebSocket hub stored each order's watchers in a dictionary `_channels`. Two
real bugs:
1. The cleanup function `close_order_channel()` **existed but was never called** — so every
   delivered order left its entry in memory **forever**.
2. `_channels` was a `defaultdict`, which **creates an entry the moment you even read a key**.
   So merely *checking* a channel created permanent junk.

Over a week of deliveries, thousands of dead order-channels would pile up in RAM.

### Where in our code (the fix)
Rewrote **`backend/services/location_ws.py`**:
- A channel is **created** only when the first customer subscribes, and **deleted** when the
  last customer leaves *or* the order is delivered.
- `mark_delivered` and `report-failure` in `orders.py` now actually call
  `await close_order_channel(order_id)`.
- Replaced the leaky `defaultdict` with explicit, locked create/remove logic.

### Real order example
Order #42 is delivered. **Before:** its channel sits in `_channels` for the lifetime of the
server, joined by #43, #44, #45… forever. **After:** the moment #42 is marked delivered, we
close its watchers and delete the entry — RAM goes back down.

### Impact / what we gained
Backend memory now stays **flat** over days/weeks of orders instead of climbing. No mysterious
slow-down-then-restart cycle.

### If we had NOT fixed this
After enough real orders the Railway instance would balloon in memory and get force-restarted
— and **a restart drops every open WebSocket**, so every customer mid-delivery would lose
live tracking at once. Classic "works in demo, dies in production after a few days" bug.

---

## 💡 Concept 13: Pub/Sub & the Redis bus (making many workers act as ONE)

### What it is
**Pub/Sub = Publish / Subscribe.** It's a messaging pattern: a sender **publishes** a message
to a named *channel*; anyone who **subscribed** to that channel receives it. The sender doesn't
know or care who's listening — like a **radio station**: the DJ broadcasts on 98.3 FM, and
every radio tuned to 98.3 hears it.

**Redis** is a tiny, very fast separate service that, among other things, provides Pub/Sub
channels that *all your workers can share*. Picture a **whiteboard on the wall** every waiter
can write on and read from.

### Why DHAV needed it
Remember Concept 9's trap: workers can't see each other's memory. Pub/Sub gives them a shared
channel so a message produced on Worker 1 reaches Worker 2.

### Where in our code
New file **`backend/services/redis_bus.py`** with `publish(channel, data)` and
`subscribe(channel, handler)`. We use it for three things:
- **Rider GPS** → channel `ws:order:{id}:loc`
- **Cache invalidation** → channel `cache:invalidate`
- **Order-accepted signal** → channel `order:{id}:accepted`

### Real order example (the one that was broken in Concept 9)
Rider for order #42 is on Worker 1; customer is on Worker 2.
1. Rider's GPS hits Worker 1 → Worker 1 does `publish("ws:order:42:loc", {lat,lng})`.
2. Worker 2 had `subscribe("ws:order:42:loc", …)` when the customer connected.
3. Redis delivers the message to Worker 2 → Worker 2 pushes it down the customer's WebSocket.
4. The map marker moves. **Tracking now works regardless of which worker each person is on.**

### Impact / what we gained
DHAV can run on any number of workers and still behave like one logical server for tracking,
cache, and the accept signal — the real unlock for horizontal scaling.

### If we had NOT done this
We'd be permanently stuck on **one worker** (using one CPU core). The day traffic needs more
workers, tracking and cache would break (Concept 9). We'd hit a hard ceiling with no safe way up.

---

## 💡 Concept 14: "Redis service on Railway" (what that phrase actually means)

### What it is
Two things in one phrase:
- **Redis** = the shared whiteboard/radio-station service from Concept 13.
- **Railway** = the hosting company where your backend already lives
  (`dhav-backend-production.up.railway.app`). Railway lets you click to add extra **services**
  (databases, Redis) next to your app.

So **"add a Redis service on Railway"** = spin up a Redis instance inside your Railway project
so your backend can use it.

### How you actually do it (save this for the scaling day)
1. Open your Railway project dashboard.
2. Click **"+ New" → "Database" → "Add Redis"**. Railway creates it and gives a connection
   string like `redis://default:<password>@<host>:6379`.
3. Copy that string into an environment variable named **`REDIS_URL`** on your backend service.
4. Redeploy. Our code sees `REDIS_URL` is set and **automatically switches the bus on**.
5. (Optional) bump workers: run with `--workers 2` (or more) now that the bus is shared.

### The "optional dependency / graceful fallback" trick (important!)
Our `redis_bus.py` checks for `REDIS_URL`. If it's **missing**, the bus quietly disables itself
and the whole app runs exactly as before, in single-worker mode. That means:
- **Local development needs no Redis at all** — nothing to install or run.
- Production scaling is **one env var**, not a code change.

### Real example
Today (Kothrud pilot, `REDIS_URL` unset): the bus is asleep, the app runs single-worker, GPS is
delivered straight from memory — perfectly fine for a handful of users. Launch day next year
with thousands of users: add Redis on Railway, set `REDIS_URL`, set `--workers 4`, redeploy.
Same code, now horizontally scalable.

### Impact / what we gained
Zero friction now, a 5-minute upgrade path later. You never have to rip out and rewrite the
tracking/cache system under pressure.

### If we had NOT done it this way
Either (a) local dev would require everyone to install and run Redis just to start the app, or
(b) you'd have to do a risky rewrite during a traffic spike — the worst possible time.

---

## 💡 Concept 15: Cross-worker cache invalidation

### What it is
"Invalidate" = throw away a cached copy because the real data changed. Across many workers,
**all** of them must throw it away, or some keep serving stale data.

### Why DHAV needed it
Each worker keeps its own fast in-memory catalog cache (5 min). If an admin edits a price on
Worker 1, Worker 1 clears its cache — but Workers 2, 3, 4 would keep showing the old price for
up to 5 minutes. Customers on those workers see wrong prices.

### Where in our code
`services/cache.py` → `await cache.invalidate("catalog")`. It clears the local copy **and**
publishes on `cache:invalidate` (Concept 13) so every other worker clears the same key. Called
from the admin catalog write endpoints and from store profile/inventory/toggle updates.

### Real order example
Admin marks "Tata Salt" inactive on Worker 1. `invalidate("catalog")` fires → Redis tells
Workers 2–4 → all of them drop their cached catalog → the next customer on any worker sees the
correct, updated list. No one orders a discontinued item.

### Impact / what we gained
Catalog/store data stays **consistent across all workers** within milliseconds of an edit,
while still being served from microsecond-fast memory the rest of the time.

### If we had NOT done this
Multi-worker deployments would intermittently show stale prices/availability depending on which
worker served you — confusing for customers and a support nightmare to reproduce.

---

## 💡 Concept 16: Event-driven vs polling (broadcasting)

### What it is
**Polling** = repeatedly asking "are we there yet?" on a timer. **Event-driven** = sitting
quietly and being *woken up* the instant the thing happens. Event-driven is faster and wastes
no work.

### Why DHAV needed it
The order broadcast loop used to **poll** Firebase every 2 seconds to check "has a store
accepted yet?". Every active order = a steady stream of Firebase reads, and acceptance was
noticed up to 2 s late.

### Where in our code
`services/broadcasting.py`. The broadcast now `await`s an `asyncio.Event` with the wave timeout.
When a store accepts (`orders.py` → `accept`), we call `signal_order_accepted()` which:
- sets the Event in the **same** worker (instant), and
- publishes on `order:{id}:accepted` so a broadcast running on **another** worker wakes too.

No 2-second polling loop at all.

### Real order example
Order #42 broadcasts to wave-1 stores. Store A taps **Accept** at second 7. **Before:** the loop
wouldn't notice until its next 2 s poll (up to second 8), after an extra Firebase read. **After:**
accept fires the event → the broadcast wakes at second 7 *immediately*, stops bothering other
stores, and the customer sees "Accepted ✅" right away.

### Impact / what we gained
Instant acceptance, and **zero** idle Firebase reads per active order. Scales cleanly when many
orders broadcast at once.

### If we had NOT done this
With hundreds of simultaneous orders you'd have hundreds of 2-second polling loops hammering
Firebase continuously — wasted cost and load, plus a laggy "Accepted" experience.

---

## 💡 Concept 17: Throttling & delta updates (WebSocket traffic control)

### What it is
- **Throttling** = capping how often you send something (e.g. "at most once per second").
- **Delta update** = only send when something *changed* (skip "same location again").

### Why DHAV needed it
A rider streams GPS every ~3 s, but bursts or a parked rider sending identical coordinates waste
bandwidth and battery — multiplied across thousands of riders it's real network load.

### Where in our code
`services/location_ws.py` → `_forward_rider_update()` drops an update if it arrives <1 s after
the last one **and** the position hasn't changed.

### Real order example
The rider for #42 stops at a traffic signal and his phone keeps sending the same lat/lng every
3 s. We forward the first one, then **skip the unchanged repeats** until he moves again — the
customer's marker is already correct, so nothing is lost.

### Impact / what we gained
Less bandwidth and fewer needless WebSocket pushes, especially at scale, with no loss of tracking
accuracy.

### If we had NOT done this
At thousands of concurrent riders the server would push a constant stream of redundant messages —
higher bandwidth bills and more load for zero benefit.

---

## 💡 Concept 18: Bounded cache (a second, subtler memory-leak guard)

### What it is
A cache with a **maximum size** that evicts the oldest entry when full, so it can never grow
without limit.

### Why DHAV needed it
We cache each logged-in user's profile by `user:{uid}` to save a Firebase read per request.
Over time, with many users, that dictionary could grow unbounded — a slow memory leak.

### Where in our code
`services/cache.py` → `TTLCache(max_size=5000)`; when full it drops the oldest inserted key.

### Real example
Across a busy week 50,000 different users log in. **Before:** 50,000 profile entries linger in
RAM. **After:** the cache holds at most 5,000 recent ones; older entries are evicted (and simply
re-fetched if that user returns).

### Impact / what we gained
Predictable, capped memory for caches — pairs with Concept 12 so the backend's RAM stays steady.

### If we had NOT done this
A gradual memory climb over weeks → eventual restart → dropped connections (same failure mode as
Concept 12, just slower to show up).

---

## 💡 Concept 19: Firebase `.indexOn` — making "find by field" fast (and the bug we found)

### What it is
When you ask Firebase "give me all orders **where** `customer_id == me`" (an `order_by_child`
query), Firebase needs an **index** on that field — the back-of-the-book index from Concept 3,
but for a database. In Firebase Realtime Database you declare indexes in the security-rules
file with `.indexOn`. Without it, Firebase has to **download the entire node and filter in
memory**, and it prints a warning: *"Using an unspecified index. Consider adding .indexOn".*

### Why DHAV needed it
This session I converted several endpoints to use `order_by_child` queries instead of pulling
a whole node. Those queries are only fast **if** the field is indexed:
- customer's orders → `orders` by `customer_id`
- store's orders → `orders` by `accepted_by_store_id`
- rider's assignments → `orders` by `assigned_delivery_boy_id`
- store's delivery boys → `delivery_boys` by `store_id`
- store's custom-item requests → `custom_item_requests` by `store_id`

### The real bug we caught
The `orders` index already existed but listed **`delivery_boy_id`** — a field that **doesn't
exist** in our order data. The actual field is **`assigned_delivery_boy_id`**. So the rider's
"my deliveries" query was silently doing a **full scan of every order in the system** on each
call. We fixed the index to the correct field names, and added the two missing indexes for
`delivery_boys` and `custom_item_requests`.

### Where in our code
`firebase/realtime-db.json` (the file `firebase.json` actually deploys) and its twin
`firebase/realtime-db.rules`. Deployed with `firebase deploy --only database`.

### Real order example
A delivery boy opens his app → it calls `GET /orders/delivery/me` → backend runs
`orders order_by_child("assigned_delivery_boy_id") == his_id`. **Before:** Firebase downloads
**all** orders ever placed and filters them — slow, and gets slower every day as orders pile up.
**After:** Firebase jumps straight to his orders via the index — fast and constant, even with a
million orders in the table.

### Impact / what we gained
The "list by owner" queries now scale with the number of *matching* rows, not the *total* table
size — and the noisy index warnings disappear from the logs.

### If we had NOT done this
Every store/rider/customer "my list" screen would get progressively slower as total orders grow,
and Firebase would keep shipping the entire `orders` table over the network on each call —
expensive and eventually unusable at scale. This is a "fine in week 1, painful by month 3" trap.

> ⚠️ **Action required (you):** these index changes only take effect after you deploy them:
> `cd firebase && firebase deploy --only database`. Until then the new queries still work but
> remain unindexed.

---

## 💡 Concept 20: Push-driven UI — the frontend version of event-driven (vs polling)

### What it is
Same idea as Concept 16 (event-driven vs polling), but on the **phone** instead of the server.
**Polling:** the app asks the backend "any update yet?" every few seconds. **Push-driven:** the
app sits quietly and the backend *pushes* it a notification (FCM) the moment something changes;
the app reacts instantly.

### Why DHAV needed it
The customer's **broadcasting screen** (the "finding a store…" pulse) polled `GET /orders/{id}`
**every 4 seconds**. Two costs: (1) up to a 4 s lag before "Accepted ✅" appears, and (2) every
waiting customer hammers the backend continuously. Multiply by thousands of customers and that's
a lot of pointless requests. Yet the backend *already* sends an "order accepted" FCM push — we
just weren't using it to drive the screen.

### Where in our code
- `core/services/fcm_service.dart` — turned the old dead single callback into a **broadcast
  `Stream<String> orderUpdates`** that emits the `order_id` of any incoming order push. "Broadcast"
  means many screens can listen at once.
- `features/orders/broadcasting_screen.dart` — listens to `fcmService.orderUpdates`; the instant a
  push for its order arrives it fetches once and navigates. The poll is kept but **slowed to 8 s as
  a safety net** (in case a push is delayed/dropped).
- `features/orders/order_tracking_screen.dart` — same: a push refreshes the status (packed →
  out-for-delivery → delivered) immediately instead of waiting for its 8 s poll.

### Real order example
Customer places order #42 → broadcasting screen appears. A store taps **Accept** at second 6.
**Before:** the screen wouldn't notice until its next 4 s poll (up to second 8) → spinner lingers.
**After:** the backend's "Order Accepted" FCM arrives in ~1 s → the stream fires → the screen jumps
straight to the "Order Accepted" page. Feels instant, like Blinkit.

### Why keep the poll at all?
Push notifications are **best-effort**, not guaranteed — a flaky network or a throttled device can
drop or delay one. So we use **push for speed + a slow poll for reliability**. Belt and suspenders.

### Impact / what we gained
Near-instant status updates on the customer's screen, and far fewer backend requests (one push beats
~15 polls over a minute). Better UX *and* less load at the same time.

### If we had NOT done this
Every customer would feel a 4 s lag at the most exciting moment (store accepting), and at scale the
constant polling from thousands of waiting screens would add avoidable load to the backend.

---

## 🧾 Session 2026-05-30 — one-line recap of each change

| # | Concept | New/changed file | One-line impact |
|---|---------|------------------|-----------------|
| 9  | Workers | (ops: `--workers`) | Use all CPU cores = serve more users at once |
| 10 | Unblock event loop | `services/firebase_async.py` | Server no longer freezes on every Firebase call |
| 11 | Concurrent reads | `firebase_async.get_many` | N reads at once, not N in a row |
| 12 | Memory-leak fix | `services/location_ws.py` | RAM stays flat; channels cleaned up on delivery |
| 13 | Pub/Sub bus | `services/redis_bus.py` | Many workers act as one (tracking + cache) |
| 14 | Redis on Railway | `config.py`, `.env.example` | Scale by setting one env var; off = single-worker |
| 15 | Cache invalidation | `services/cache.py` | All workers drop stale catalog together |
| 16 | Event-driven broadcast | `services/broadcasting.py` | Instant accept, no 2 s polling |
| 17 | Throttle + delta | `services/location_ws.py` | No redundant GPS pushes |
| 18 | Bounded cache | `services/cache.py` | Profile cache can't grow forever |
| 19 | Firebase `.indexOn` | `firebase/realtime-db.json` | "List by owner" queries stop full-scanning the orders table |
| 20 | Push-driven UI | `fcm_service.dart`, `broadcasting_screen.dart`, `order_tracking_screen.dart` | Instant status updates via FCM stream; poll slowed to an 8s safety net |

---

## 🎓 Vocabulary Glossary — Session 2026-05-30 additions

| Term | Simple Definition |
|------|------------------|
| Worker | One running copy of your backend process; `--workers N` runs N copies |
| Event loop | The single thread that serves requests by switching between `await`-ing tasks |
| Blocking call | A step that freezes the event loop until it finishes (e.g. sync Firebase `.get()`) |
| Thread pool | A set of helper threads where we run blocking calls so the event loop stays free |
| Concurrent | Multiple things in flight at the same time (vs sequential, one after another) |
| Memory leak | Program keeps allocating memory it never frees → RAM climbs → crash/restart |
| Pub/Sub | Publish/Subscribe messaging — senders publish to a channel, subscribers receive |
| Redis | Fast in-memory service used here as a shared Pub/Sub bus across workers |
| Channel (Pub/Sub) | A named "radio frequency" messages are published to and subscribed from |
| Invalidate (cache) | Discard a cached copy because the real data changed |
| Polling | Repeatedly asking "is it done yet?" on a timer (wasteful) |
| Event-driven | Being woken the instant something happens (efficient) |
| Throttling | Limiting how often an action can happen (rate cap) |
| Delta update | Only sending data that actually changed |
| Graceful fallback | If an optional dependency (Redis) is missing, run fine without it |
| Horizontal scaling | Handling more load by adding more workers/servers (vs a bigger single one) |

---

## 💡 Concept 21: Firebase Remote Config — changing the app WITHOUT shipping an APK

### What it is
**Remote Config** is a Firebase service that works like a **settings drawer in the cloud** for
your app. The app ships with a set of **in-app default values** baked into the code. On launch
it quietly asks Firebase "any overrides for me?" — if you've set values in the Firebase Console,
they replace the defaults; if you've set nothing (or the phone is offline), the defaults are used
and the app behaves exactly as shipped. Think of it as a restaurant menu where the printed prices
are the defaults, but the manager can clip a "today's special" card over any item without
reprinting the whole menu.

### Why DHAV needed it
Apps like Zepto/Blinkit change their home screen constantly — festival banners, new greetings,
seasonal deals. If every text change required `flutter build apk` + re-distributing the APK to
every customer, the home screen would be frozen for weeks at a time. Remote Config lets us change
the greeting, banner carousel, search hint, and deal section **from the Firebase Console in
seconds**, and every customer's app picks it up within an hour.

### Where in our code
- `customer_app/pubspec.yaml` → `firebase_remote_config: ^5.1.3`
- **`customer_app/lib/core/providers/ui_config_provider.dart`** — the wrapper. Keys:
  `home_greeting_title`, `home_greeting_subtitle`, `home_search_hint`,
  `home_banners` (JSON array of `{title, subtitle, cta, emoji, color_start, color_end}`),
  `home_deal_enabled`, `home_deal_title`.
- Consumed by `welcome_greeting.dart`, `hero_banner.dart`, `deal_of_day.dart`, and the home
  search bar via `context.watch<UiConfigProvider>()`.
- Registered in `main.dart` with a fire-and-forget `init()` — fetch failures are swallowed.

### Real example
Ganeshotsav week: open Firebase Console → Remote Config → set `home_greeting_title` to
"गणपती बाप्पा मोरया! 🙏" and add an orange "Modak essentials" banner to `home_banners` → Publish.
Every customer sees the festive home screen on their next app open. After the festival, delete
the overrides — the app falls back to "कसं काय पुणेकर!" automatically. Zero builds, zero installs.

### The graceful-fallback trick (same philosophy as Concept 14)
Every key has an in-app default, and every parse is wrapped in try/catch falling back to those
defaults. So: no console setup needed, offline phones work, and a typo in console JSON can never
blank the home screen — worst case the defaults show.

### Impact / what we gained
Marketing-speed control over the home screen with engineering-grade safety. The UI is now
**data**, not code.

### If we had NOT done this
Every banner/text tweak = rebuild + redistribute an APK that users may never update to. During a
festival rush you'd be stuck with a stale, generic home screen — exactly what we're trying to
compete against.

---

## 💡 Concept 22: On-device persistence (SharedPreferences) — the "default address" memory

### What it is
**SharedPreferences** is a tiny key-value store **on the phone itself** (Android backs it with an
XML/DataStore file). It survives app restarts but lives only on that device. It's the right home
for small *preferences* — "which address did this user last pick?" — as opposed to *data* (the
addresses themselves), which live on the backend.

### Why DHAV needed it
The address rules we wanted (same as Zepto/Blinkit):
1. **No saved address** → detect GPS, load the catalog around the phone's live location.
2. **Has saved addresses** → whatever address the user **last selected** becomes the default:
   every app start loads the catalog around it, until they pick another.
3. **"Use current location"** picked explicitly → remember the *choice* but not the coordinates,
   so next launch re-detects fresh GPS (people move; stale coordinates would be wrong).

Rule 2 and 3 need memory **across restarts**. Keeping it in a provider (RAM) dies with the app;
storing "last selected" on the backend would cost a network round-trip before the very first
paint and break weirdly across two devices sharing one account. On-device prefs are instant,
offline-safe, and per-device — exactly right.

### Where in our code
`customer_app/lib/core/providers/address_provider.dart`:
- key `dhav_default_address` stores the selected address as JSON; the sentinel string
  `__current_location__` stores the "live GPS" mode.
- `selectAddress()` persists on every selection; `loadAddresses()` →
  `_restoreDefaultSelection()` re-matches the stored JSON against the freshly fetched address
  list (so a deleted/edited address can't resurrect); delete/add/edit keep the pref in sync.
- `home_screen.dart` then loads the catalog around `selected` — or falls back to GPS when
  nothing is selected.

### Real example
You add "Home — Kothrud" and "Work — Hinjawadi", select Work on Monday morning, and kill the
app. Tuesday you open it at home in Kothrud: the app still shows **Work — Hinjawadi** and loads
Hinjawadi stores, because the default is your *choice*, not your GPS. You tap the header, pick
"Use current location" → Kothrud catalog loads, and *that mode* is remembered — Wednesday it
re-detects wherever you are.

### Impact / what we gained
The app "remembers" the user like the big apps do — no re-picking the address every launch, no
flash of wrong-location catalog, works offline-first.

### If we had NOT done this
Every launch would silently reset to the first saved address (or GPS), so a user who orders to
their office would get their home catalog every morning — wrong stores, wrong availability, and
an "ugh, this app forgets everything" feeling.

---

## 💡 Concept 23: Editing Remote Config from OUR OWN admin app (REST API + OAuth token minting)

### What it is
Concept 21 let Firebase Remote Config *drive* the app, but you still had to open the **Firebase
console** to change a value. This concept closes the loop: our **admin dashboard** edits the home
top-section itself. The trick is that Remote Config has a **REST API**
(`firebaseremoteconfig.googleapis.com/v1/projects/{id}/remoteConfig`, GET to read, PUT to publish),
and our FastAPI backend can call it — it just needs a Google **OAuth2 access token** with the
`firebase.remoteconfig` scope, which it mints from the **same service-account JSON** it already
uses for Auth/FCM.

### Why DHAV needed it
Harshad wanted to recolour and rewrite the whole home top-section (header gradient, greeting,
search hint, promo banners) from the admin portal — *not* hand-edit JSON in the Firebase console.
The console is fine for a developer but wrong for running a business day-to-day (festival banner,
new discount photo, etc.).

### How the pieces fit (end to end)
```
Admin web (Home UI screen)  ──PUT /admin/home-config {values}──▶  FastAPI
        ▲                                                            │
        │ GET /admin/home-config                                     │ mint OAuth token
        │                                                            ▼
        └────────────  reads ────────────  Firebase Remote Config REST API
                                                  ▲
Customer app ──fetchAndActivate() (≤1 h)──────────┘
```

### Where in our code
- `backend/services/remote_config.py` — `get_home_config()` / `update_home_config()`. Mints the
  token with `google.oauth2.service_account.Credentials.from_service_account_info(info,
  scopes=[firebase.remoteconfig])` then `creds.refresh()`. **update reads the live template first**
  (for its `ETag`) and only overwrites the 8 home keys, so it never clobbers other parameters; it
  publishes with `If-Match: <etag>` (optimistic concurrency — fails loudly if someone else changed
  it meanwhile).
  - **Cached like the catalog (Concept 9):** the read is served from the shared `TTLCache`
    (`cache.HOME_CONFIG_KEY`, 5-min TTL), so the admin Home UI screen loads instantly instead of
    paying an OAuth mint + REST round-trip every open. On publish we **write-through** the freshly
    published values onto this worker AND call `cache.invalidate("home_config")` so every *other*
    worker drops its copy (Concept 17). Net effect: "set a new value from the backend → the cache
    updates immediately", and Firebase is only hit on a cold cache or a Firebase-console edit.
- `backend/firebase_init.py` — new `get_service_account_info()` shares the SA JSON with the token mint.
- `backend/routers/admin.py` — `GET/PUT /admin/home-config` (admin-only).
- `admin_dashboard/.../home_config_screen.dart` + `home_config_provider.dart` — the visual editor
  with a live phone preview; banners are decoded from / re-encoded to the `home_banners` JSON string.
- `customer_app/.../ui_config_provider.dart` — added `home_header_color_start/_end` keys so even the
  header gradient is remote-driven (default = DHAV teal).

### Real example
Admin opens **Home UI**, drags the header colour to maroon, sets banner 1's image to a Diwali photo
with badge "up to 30% OFF", clicks **Publish**. Backend mints a token, PUTs the merged template.
Within the customer app's 1 h fetch window (or next cold start) every phone shows the new top section
— no APK rebuild, no Play Store update.

### One-time setup gotcha (IAM)
The service account must be allowed to write Remote Config. If `PUT` returns **403**, enable the
**Firebase Remote Config API** in Google Cloud and grant the service account the
**Firebase Remote Config Admin** role (permission `cloudconfig.configs.update`). Reading may work
before writing does — 403 on publish is almost always this.

### Impact / what we gained
Non-developers can run the storefront's hero section like a CMS. The app stays a thin renderer of
whatever Remote Config says; marketing changes are now a 10-second admin action.

### If we had NOT done this
Every banner/greeting/colour tweak means opening the Firebase console and editing raw JSON by hand —
error-prone, developer-only, and impossible to delegate. Or worse: rebuild + re-upload the APK.

---

## 💡 Concept 24: One app, four marketplaces — the `marketplace_type` discriminator + type-correct order routing

### What it is
DHAV went from a single grocery app to **four isolated marketplaces in one app**: `grocery`,
`fruits`, `electronics`, `pharmacy`. We did NOT build four apps or four databases. Instead we added
one small **discriminator column**, `marketplace_type` (and its store-side twin `store_type`), to the
tables that already existed, and we **filter by it everywhere**. A discriminator is just a column
whose value says "which sub-world does this row belong to" — the cheapest way to partition data that
shares the same shape.

### Why DHAV needed it
A fruits buyer must never see a laptop; an electronics order must never ring a kirana store's phone.
But grocery, fruits, electronics and pharmacy products are all "a thing with a name, price, image,
unit, brand, stock" — identical shape. Four separate `products_*` tables (or four databases) would
duplicate every query, endpoint, and index for no reason. One column + a `WHERE marketplace_type = $1`
gives full isolation with one codebase.

### Where in our code
- **Schema** (`backend/migrations/004_marketplace_taxonomy.sql`): `marketplace_type` on
  `catalog_items` + `orders`, `store_type` on `stores`, all defaulting to `'grocery'` so every
  pre-existing row is valid. Plus two genuinely new tables — **`categories`** and **`subcategories`**
  — each carrying its own `marketplace_type`, `image_url`, `sort_order`, `is_enabled`.
- **Reads** (`backend/routers/catalog.py`): every catalog endpoint takes an optional
  `marketplace_type` query param and skips rows that don't match. The app passes its active tab.
- **The important one — order routing** (`backend/services/geofencing.py` +
  `services/broadcasting.py` + `routers/orders.py`): an order now stores its `marketplace_type`, and
  `find_nearby_stores_async(..., store_type=...)` adds `AND store_type = $X` to the nearby-stores SQL.
  So when an electronics order broadcasts, the 3-wave search only ever finds **electronics** stores —
  a grocery store is never even queried, let alone notified. Same column, four behaviours.

### The DB-driven category CMS (the other half)
Before, "categories" were a **derived list** — `SELECT DISTINCT category FROM catalog_items`. That
meant the admin could not add an empty category, set its image, reorder it, or disable it. Now
`/catalog/categories` reads the real `categories` table (admin-managed via `/admin/categories` CRUD +
`/admin/subcategories`), ordered by `sort_order`, filtered by marketplace. The old derived behaviour
survives only as a fallback when the table is empty, so older clients don't break.

### Image upload (Supabase Storage REST)
`POST /admin/upload-image` streams a multipart file straight to a Supabase Storage bucket
(`dhav-images`) via its REST API (`POST /storage/v1/object/{bucket}/{path}` with the service-role
bearer token), then returns the public URL. So admins **upload** category/product images instead of
hunting for a hosted URL — and every image lives in our own storage, referenced by URL in the DB
(never a hardcoded asset path).

### Real example
A customer taps the **Electronics** tab. The app calls
`/catalog/categories?marketplace_type=electronics` → "Mobiles", "Audio", "Laptops"… (the grocery
"Atta, Rice & Dal" never appears). They add earbuds and checkout; `POST /orders` carries
`marketplace_type: "electronics"`; broadcasting's wave search runs `… AND store_type='electronics'`,
so only the electronics store down the road is pinged — the grocery store two doors away never hears
about it.

### Impact / what we gained
Four storefronts, four themes, four catalogs, correct order routing — on **one** codebase, one DB,
one deploy. Adding a fifth marketplace later is "add an enum value + seed some rows", not "build a new
app". Categories/products/images are now 100% admin-managed data, zero hardcoding.

### If we had NOT done this
Either four separate apps/databases (4× the build, deploy and maintenance), or one mixed feed where a
pharmacy search returns power banks and an electronics order rings a vegetable vendor — which is
exactly the cross-wiring the whole change exists to prevent.

---

## 💡 Concept 25: Call masking — letting two people talk without sharing their phone numbers

### What it is
**Call masking** (a.k.a. number masking / call bridging) lets a deliverer and a customer phone each
other while **neither sees the other's real number**. A cloud-telephony provider places **two call
legs** and joins them through a **virtual number** (an "ExoPhone"). Both phones show that virtual
number as the caller ID — the real numbers are never revealed to the other party. This is exactly how
Blinkit/Swiggy/Zomato/Ola hide numbers in their delivery calls.

```
deliverer ──leg A──►  [ Exotel ]  ──leg B──►  customer
                    CallerId = +91-VIRTUAL
   both sides see +91-VIRTUAL, never each other's real number
```

### Why DHAV needed it
A store owner (or assigned delivery partner) often needs to call the customer ("I'm at your gate, which
floor?") and vice-versa. Putting the real mobile number on the order screen is a **privacy and safety
leak** — customers get spam/harassment calls after delivery; riders get their personal number saved by
strangers. Masking keeps coordination working while protecting both people. We also **log every call**
so spend is auditable and "they never called" disputes can be checked.

### Why a *provider-agnostic* service (not "just call Exotel")
Telephony is a commodity with many India-registered vendors (Exotel, Servetel, Knowlarity, …) — and
**Twilio/Plivo can't legally do domestic Indian masking** (TRAI requires an India-registered provider;
foreign caller-ID on Indian numbers gets blocked). So we hide the vendor behind a small interface,
`CallService` (`backend/services/call_masking.py`), with two implementations:
- **`ExotelCallService`** — real masked calls via Exotel's "Connect two numbers" API. Chosen because
  it's **pay-per-use in INR** (cheapest at our low volume — no fixed monthly fee like Servetel's
  ₹999/mo) and the most mature masking API.
- **`MockCallService`** — logs and returns a stub. The factory `get_call_service()` falls back to it
  when Exotel credentials aren't set, so the **whole feature is build-and-test-able before we have an
  account** and a half-configured deploy degrades to a no-op instead of crashing.

Switching vendors later = one new subclass + flip `call_provider` in config. Routers and apps don't change.

### Where in our code
- **Service** `backend/services/call_masking.py`: the `CallService` interface, `ExotelCallService`
  (POSTs `From`/`To`/`CallerId` to `…/Calls/connect.json` with basic auth), `MockCallService`, the
  `get_call_service()` factory, `normalize_in_phone()` (→ E.164 `+91…`), `pick_virtual_number()` (picks
  from the `CALL_VIRTUAL_NUMBERS` pool).
- **Endpoint** `backend/routers/calls.py`: `POST /calls/order/{order_id}` — resolves **both** real
  numbers server-side from the order (leg A = the *initiator*, who rings first; leg B = the other
  party), authorises the caller against that order, bridges them, and writes a `call_logs` row. The
  apps get back only `{ ok, status, virtual_number }` — **never** the real numbers.
- **Provider callback** `POST /calls/provider/callback`: public (Exotel can't send our bearer token);
  matches by the provider's `CallSid` and fills in final `status` + billed `duration_seconds`.
- **Audit** `GET /calls/logs` (admin-only) + the `call_logs` table (migration `010_call_masking.sql`).
- **Config** (`config.py`): `call_provider`, `exotel_*`, `call_virtual_numbers`, `backend_public_url`.

### How the two legs are resolved (the clever reuse)
The order **already** carries `delivery_boy_phone`, stamped on dispatch as the **store phone** when
self-delivering or the **partner phone** when assigned (Concept from the 2026-06-21 self-delivery work).
So masking doesn't care *which* delivery mode is in play — the deliverer leg is just
`order.delivery_boy_phone` (falling back to the store's own phone before dispatch). The customer leg is
`users.phone` for `order.customer_id`. The **prerequisite gap** we had to fill: customers sign up with
Google/email, which never captures a phone — so "add your number" is now required before the
customer-side call works.

### Real example
A self-delivering store owner is outside the customer's building and taps **Call customer**. The app
calls `POST /calls/order/{id}`. Backend reads leg A = the shop's phone, leg B = the customer's phone,
picks the ExoPhone, and asks Exotel to connect them. The **owner's** phone rings first (showing
`+91-VIRTUAL`); when he answers, the **customer's** phone rings (also `+91-VIRTUAL`). They talk; neither
saw the other's real number. When the call ends Exotel POSTs the duration to our callback, and the
`call_logs` row is completed.

### Impact / what we gained
Customer and rider can coordinate deliveries with **zero exposure of personal numbers**, on the cheapest
compliant option for our volume, behind an abstraction we can re-price/re-vendor in one file. Every call
is logged for spend and dispute auditing.

### If we had NOT done this
Either we'd print real phone numbers on the order screen (privacy/safety leak → spam, harassment, riders'
numbers harvested), or delivery coordination would rely on guessing the address with no way to call —
more failed deliveries. Hardcoding one vendor's SDK would also lock us into its pricing and risk illegal
foreign-origin masking under TRAI rules.

---

## 💡 Concept 26: Checkpointing an ephemeral real-time stream — the "last-known position" pattern

**What:** live delivery tracking has two jobs that pull in opposite directions. (1) *Be real-time* —
the rider's GPS must reach the watching customer in well under a second, so the fan-out is **in-memory**
over a WebSocket (no DB in the hot path). (2) *Be durable* — but a purely in-memory stream forgets
everything the instant it's not flowing: a customer who opens tracking **between** two rider pings sees a
**blank map**, and a backend restart loses the position entirely. The fix is a **checkpoint**: alongside
the live stream, write the latest point to the DB **on a throttle** (every ~15 s, not every 3 s ping),
and **seed** any newly-connected customer with that stored point immediately.

**Why throttle the write:** the rider pings ~every 3 s. Writing each ping = 20 DB writes/minute/order for
data that's already being delivered live — pure waste. The live socket is the source of truth for
"right now"; the DB row is just a **periodic snapshot** for "what was the last thing we knew." 15 s is
plenty fresh for a seed and cuts the write rate ~5×.

**Why a freshness gate on the seed:** a stored point is only shown to a fresh customer if it was written
in the last **5 minutes**. Otherwise an order that paused (rider offline, app backgrounded) would show a
stale marker *as if it were live* — worse than showing nothing. Old checkpoint → no seed → blank map
until the next real ping (honest).

**Where:** `backend/services/location_ws.py` — `_persist_location()` (throttled `UPDATE orders SET
last_lat/last_lng/last_location_at`), called from `_forward_rider_update()`; `_seed_point()` builds the
initial frame on customer connect from `orders.last_*`. Columns added in migration
`011_order_location_persist.sql`.

**Real example:** rider goes out_for_delivery, streams GPS. The customer closes the app at a red light
and reopens it 40 s later. Old behaviour: blank map for up to 3 s until the next ping. New behaviour: the
socket connects, the backend instantly sends the 15 s-old checkpoint, the marker appears at once, then
the next live ping glides it forward.

**Impact / if NOT implemented:** every reconnect (and there are many — app backgrounding, network blips,
the 5 s auto-reconnect) shows a blank map until a fresh ping lands, which on a parked or slow rider can be
seconds of "is it even working?" anxiety. And nothing about the delivery's path survives a worker restart.
The pattern is the standard way Zomato/Swiggy-style trackers feel instant on open without paying for a DB
write on every GPS tick.

---

## 💡 Concept 27: Typo-tolerant search with pg_trgm — trigram similarity in Postgres

**What:** the customer Search tab used to filter the in-memory catalog with `String.contains` — no typo
tolerance, no ranking, and it could only "see" whatever slice of the catalog the app had downloaded.
`GET /catalog/search` now runs **in Postgres** with the **pg_trgm extension**: every string is broken
into overlapping 3-letter chunks ("milk" → `mil`, `ilk`, …), and `similarity(a, b)` scores how many
trigrams two strings share (0..1). "mlik" and "Milk" share most of their trigrams → high score → match,
even though `LIKE '%mlik%'` finds nothing.

**Why ranked bands:** results are ordered by (1) prefix match — typing "mil" should put *Milk* above
*Buttermilk*; (2) substring match across name/brand/hindi/marathi; (3) trigram similarity for typos; then
product rating as a tiebreak. One SQL `ORDER BY is_prefix DESC, is_substr DESC, sim DESC, rating DESC`.

**Why GIN indexes:** `similarity()` on every row is a full scan. A **GIN index with `gin_trgm_ops`**
stores which rows contain which trigrams, so Postgres jumps straight to candidate rows. Migration
`015_search_trgm.sql` creates them on `catalog_items.name` and `.brand`.

**Where:** `backend/routers/catalog.py` `/catalog/search` + `/catalog/popular`;
`customer_app/features/search/search_screen.dart` (300 ms debounce, stale-response guard via a sequence
number, recent searches in SharedPreferences, offline fallback to the old local filter).

**Real example:** a customer types "aata" — no product is named that, but trigram similarity to "Atta"
clears the 0.25 threshold and every atta product ranks up. The response also carries `category_matches`,
so a "Browse Atta, Rice & Dal" chip appears above the products.

**Impact / if NOT implemented:** search on phones is dominated by typos and partial words; substring-only
search reads as "broken" the first time "no results" shows for an obvious product. pg_trgm ships free
with Supabase — much of the effect of an external search engine at zero extra infra.

---

## 💡 Concept 28: Barcode product onboarding — free public product DBs + an approval queue

**What:** a store owner adds a product by **scanning its barcode** (EAN/UPC). The backend resolves the
code in three steps: (1) already in OUR catalog? → the app just stocks the existing item (the `barcode`
column is UNIQUE, so the same physical product can never enter the catalog twice); (2) else ask **free
public product databases** — Open Food Facts → Open Beauty Facts → Open Products Facts (identical API
shape, one client with a base-URL list; UPCitemdb optional behind a config flag) — and prefill
name/brand/description/images; (3) nothing found → manual form. The submission then goes to an **admin
approval queue** (`custom_item_requests.status: pending → approved | rejected`) before it becomes a
global catalog item.

**Why an approval queue:** the catalog is shared by every store. If any store could publish directly,
one typo or junk photo pollutes every other store's inventory picker and the customer app. The queue
makes the admin the quality gate, and approval **auto-stocks the submitting store** so the owner still
gets fast gratification.

**Why sideload images at approval:** barcode APIs return image URLs on *their* CDNs — hot-linking makes
our catalog depend on someone else's uptime. On approve, the backend downloads each external image
(≤2 MB, content-type checked) and re-uploads it to our Supabase Storage bucket. Doing it at approval
(not submission) keeps rejected requests out of the bucket.

**Why cache lookups:** the public APIs are rate-limited and slow-ish. Store owners in one area scan the
same FMCG barcodes repeatedly, so lookups (hits AND misses) are cached in the TTLCache for 24 h under
`barcode:{code}`.

**Where:** backend `services/barcode_lookup.py`, `services/image_sideload.py`, `services/storage.py`
(shared Supabase upload core), `routers/catalog.py` `/catalog/barcode/{code}`, `routers/admin.py`
`/admin/product-requests*`; store_app `barcode_scanner_screen.dart` (mobile_scanner),
`barcode_onboarding_flow.dart`, rewritten `add_product_screen.dart` (image_picker + multipart upload),
`my_submissions_screen.dart`; admin `features/product_requests/`. Migration `014_barcode_approval.sql`.

**Real example:** a kirana owner scans a Britannia pack → Open Food Facts returns name, brand and two
pack-shots → the owner sets ₹30, picks *Bakery & Biscuits*, snaps one photo → submits. The admin fixes
the name casing and hits Approve → the item (with re-hosted images) lands in the global catalog AND that
store's inventory, and the owner's phone pings "Product Approved ✅" on the quiet channel.

**Impact / if NOT implemented:** manual product entry is the #1 onboarding friction for small stores —
minutes of typing per SKU with inconsistent results. Scan-to-prefill cuts it to seconds, and barcode
dedup keeps ONE canonical product per pack across all stores.

---

## 💡 Concept 29: Android foreground services — GPS that survives backgrounding

**What:** Android aggressively freezes backgrounded apps: timers stall, GPS callbacks stop. That's why
live tracking died the moment a deliverer switched to Google Maps or locked the screen. The sanctioned
escape hatch is a **foreground service** — a service tied to a *persistent, user-visible notification*
("Delivering order… sharing your live location"). While that notification shows, Android keeps the
process alive and location updates flowing.

**Why no new package:** geolocator (already in the app) does this natively — pass
`AndroidSettings(foregroundNotificationConfig: ForegroundNotificationConfig(...))` to
`getPositionStream` and the plugin starts a location-type foreground service with the stream. Cancelling
the stream subscription stops the service and removes the notification.

**Why no ACCESS_BACKGROUND_LOCATION:** that scary "allow all the time" permission is only needed to
*start* location access while already backgrounded. A `location`-type foreground service **started while
the app is in the foreground** (we start it on "Start Delivery") may keep using location under the
normal while-in-use permission — Android 10+ policy; the manifest already declared
`FOREGROUND_SERVICE_LOCATION`.

**Where:** `store_app/core/services/location_ws_service.dart` (`_locationSettings()`), used by both
deliverer entry points (delivery partner + self-delivering owner). The same file gained WebSocket
**reconnect-with-backoff** (2→4→8→16→30 s) because a moving rider hops cell towers and drops sockets.
Also fixed: `ApiConfig.wsBaseUrl` was `https://…` — `WebSocketChannel.connect` needs `wss://`, so the
store-side stream could never connect in release config.

**Real example:** owner taps "Start Delivery & Share Location", switches to Google Maps to navigate,
pockets the phone. The persistent notification stays; GPS keeps streaming every 3 s; the customer's map
keeps gliding. Swipe-killing the app still stops it — accepted limitation, same as rider apps generally.

**Impact / if NOT implemented:** tracking only works while the deliverer stares at the DHAV app — which
is never, because they navigate with Maps. In practice every customer map froze ~30 s into the ride.

---

## 💡 Concept 30: Idempotent money jobs — settlement sweeps that tag their rows

**What:** the weekly settlement job used to recompute "fees this week" from a **time window** (orders
delivered since Monday). Windows are fragile for money: the Monday-08:00 cron summed orders delivered
since… that same Monday 00:00 → **always ₹0**, and its per-week idempotency guard then locked the ₹0 row
in forever — the exact "settlement shows zero" bug. The rewrite flips the model: every delivered order
starts **unsettled** (`orders.settlement_id IS NULL`); the sweep picks *all unsettled orders delivered
before this Monday*, creates one settlement per store, and **stamps each order with the settlement id**
in the same transaction.

**Why tagging beats windows:** the data itself records what has been settled. Re-running finds nothing
unsettled → naturally idempotent (there's even a manual `POST /admin/settlements/run` button now).
Stragglers from prior weeks are swept automatically. And per-order breakdowns come free:
`SELECT … WHERE settlement_id = $1`.

**Also in this change:** the platform fee became a **flat ₹10 per order** (was 5% of product total),
paid by the customer as a visible bill line and owed by the store to DHAV; `total_customer_amount` is
now recomputed from ALL components on store-accept (the old code dropped handling/donation/fee);
delivery stays ₹0 behind a configurable `delivery_fee_mode` ("free" | "flat" | "per_km").

**Where:** `backend/services/settlements.py` (sweep + IST week bounds + overdue grace),
`routers/settlements.py` (`/store/current` returns `unsettled_orders` — the live accruing week — and
`/{id}/orders` the historical breakdown), `routers/orders.py` `_order_totals()`, `GET /catalog/fees`
(public fee card so apps never hardcode amounts), migration `012_flat_fee_settlements.sql`.

**Real example:** three orders delivered this week → the store's Earnings tab immediately shows
"THIS WEEK — NOT YET SETTLED · ₹30" with the three order rows. Monday 08:00 IST the sweep creates one
₹30 settlement and tags the orders; the admin drills into exactly which orders make it up and records
the UPI payment against it.

**Impact / if NOT implemented:** money code that reads its state from the clock instead of from data
produces exactly the class of silent wrongness DHAV had: ₹0 settlements, uncollectable fees, and no way
to answer "which orders is this bill for?"

---

## 🎓 Vocabulary Glossary — Session 2026-06-13 additions

| Term | Simple Definition |
|------|------------------|
| Remote Config | Firebase's cloud "settings drawer" — override app values from the console, no APK rebuild |
| In-app defaults | Values baked into the code that apply when Remote Config has nothing / is unreachable |
| fetchAndActivate | The Remote Config call that downloads overrides and switches them on |
| Minimum fetch interval | How often the app is allowed to re-ask Firebase for new config (we use 1 h) |
| SharedPreferences | Tiny on-device key-value store that survives app restarts (per device, not synced) |
| Sentinel value | A special marker string stored in place of data to encode a *mode* (our `__current_location__`) |
| Reverse geocoding | Turning GPS coordinates into a human area name ("Kothrud, Pune") |
| Remote Config REST API | The HTTP endpoint that lets a backend read/publish the RC template (vs the console UI) |
| OAuth2 access token | Short-lived bearer token minted from a service account to call a Google API with a given scope |
| Scope | The permission a token is limited to (we use `firebase.remoteconfig`) |
| ETag / If-Match | A version fingerprint + the header that publishes only if the template hasn't changed since you read it |
| Optimistic concurrency | "Assume no conflict, but the write fails if someone else edited meanwhile" — safer than blind overwrite |
| Mascot / brand character | A recognizable character used across the UI to give the app personality |
| Discriminator column | A single column whose value says which sub-world a row belongs to (our `marketplace_type`) — partitions identically-shaped data without separate tables |
| Marketplace type | grocery / fruits / electronics / pharmacy — the four isolated storefronts in one app |
| Type-correct routing | Restricting an order's store search to stores of the same marketplace (`AND store_type = $X`) |
| DB-driven CMS | Categories/subcategories/products stored as editable DB rows (admin-managed), not derived or hardcoded |
| Multipart upload | Sending a file's bytes in an HTTP form field (how the admin image upload reaches Supabase Storage) |
| Object storage public URL | A stable web URL to a stored file; we keep the URL in the DB rather than baking image paths into the app |
| Call masking / number masking | Connecting two people through a virtual number so neither sees the other's real phone |
| Call leg | One side of a bridged call (leg A = initiator, rings first; leg B = the other party) |
| Virtual number / ExoPhone | The provider-owned number both callers see as caller ID, hiding the real numbers |
| Cloud telephony (CPaaS) | A provider (Exotel, etc.) that places/bridges phone calls via an HTTP API |
| Provider-agnostic abstraction | Hiding a vendor behind an interface so it can be swapped without changing callers |
| Status callback (webhook) | A URL the provider POSTs to when a call ends, carrying final status + billed duration |
| E.164 | The international phone-number format (`+91XXXXXXXXXX`) we normalise to before calling |

---

*Last updated: 2026-06-27 (#2) — Added Concept 26 (checkpointing an ephemeral real-time stream:
throttled `orders.last_*` writes + freshness-gated late-join seed for live tracking).
Earlier 2026-06-27 — Added Concept 25 (call masking: provider-agnostic `CallService`, Exotel
connect-two-numbers bridging, `call_logs` audit, customer-phone prerequisite).
Earlier: 2026-06-21 — Added Concept 24 (one app / four marketplaces: `marketplace_type`
discriminator, type-correct order routing, DB-driven category CMS, Supabase Storage image upload).
Earlier: 2026-06-13 — Added Concepts 21–22 (Firebase Remote Config for dynamic home UI,
SharedPreferences for the persistent default address) from the customer-app home revamp session.
Earlier: 2026-05-30 Production Scaling Deep Dive (Concepts 9–20). Implementation status lives in
SYSTEM_DESIGN_IMPLEMENTATION.md.*

> 📌 **Standing rule for future sessions:** whenever we introduce a NEW technology, service,
> or system-design concept, add it here first using the same template
> (What → Why → Where → Real example → Impact → If not implemented).
