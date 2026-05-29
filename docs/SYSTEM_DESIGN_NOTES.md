# DHAV — System Design Teaching Notes
**Your personal guide to understanding how platforms like Blinkit & Zepto are built**

> This file is YOUR notes. Every time we add a new system design concept, it goes here first.
> Read this before implementation sessions so you understand WHY we're doing what we're doing.

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

*Last updated: 2026-05-28 — Full Blinkit/Zepto HLD + LLD added*
