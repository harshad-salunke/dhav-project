# DHAV — System Design Implementation Tracker
**What we planned, what we built, and why**

> This file tracks every system design improvement we implement.
> Read this to understand what's already been done and what's next.

---

## 🟢 PHASE A — Quick Wins (In-Memory Cache + Async + GZIP)
**Goal:** Make catalog 10x faster with zero new services (no Redis, no new server)
**Status:** ✅ COMPLETE (2026-05-29) — see `routers/catalog.py`, `services/cache.py`, `main.py`

### A.1 — In-Memory Catalog Cache
**Concept:** Store catalog in Python dict on server startup. Serve from dict instead of Firebase.
**Expected gain:** 800ms → 50ms for GET /catalog/items
**Files to change:**
- `backend/services/cache.py` — NEW: simple TTL cache class
- `backend/routers/catalog.py` — use cache for all catalog reads
- `backend/main.py` — warm cache on startup
**Status:** [ ] Not started

### A.2 — Async Concurrent Firebase Reads
**Concept:** Instead of reading stores one-by-one in a loop, read all at once concurrently.
**Expected gain:** 1500ms → 300ms for GET /catalog/stores/nearby
**Files to change:**
- `backend/services/firebase_async.py` — NEW: async Firebase read helper
- `backend/routers/catalog.py` — replace loop reads with concurrent reads
**Status:** [ ] Not started

### A.3 — GZIP Response Compression
**Concept:** Compress JSON responses before sending. 50KB → 8KB on mobile.
**Expected gain:** 40% faster on slow mobile networks
**Files to change:**
- `backend/main.py` — add GZipMiddleware (1 line)
**Status:** [ ] Not started

### A.4 — Background Cache Warming
**Concept:** Load catalog into cache at server startup so first user is also fast.
**Files to change:**
- `backend/main.py` — add warm_cache() in lifespan
- `backend/services/cache.py` — add warm_catalog() function
**Status:** [ ] Not started

---

## 🔵 PHASE B — Redis Shared Cache
**Goal:** Share cache across all worker processes, add cache invalidation
**Status:** FUTURE — after Phase A is working

### B.1 — Add Redis
- Replace Python dict cache with Redis
- Why: Python dict only works for 1 process. If Railway runs 2+ workers, each has its own cache = inconsistent data
- Setup: Add Redis service on Railway (free tier available)
**Status:** [ ] Not started

### B.2 — Cache Invalidation
- When admin updates a catalog item → clear that item from cache
- Pattern: "cache aside" — on write, delete cache entry
**Status:** [ ] Not started

---

## 🟣 PHASE C — CDN + Image Optimization
**Goal:** Product images load fast on slow mobile networks
**Status:** FUTURE

### C.1 — Firebase Storage CDN URLs
- Firebase Storage already uses Google CDN
- But we need to set proper Cache-Control headers
- Also: add thumbnail image fields to catalog items
**Status:** [ ] Not started

---

## 🔴 PHASE D — Database Evolution (Future Scale)
**Goal:** When we have 100+ stores and 10,000 users
**Status:** FUTURE — not needed for MVP

### D.1 — PostgreSQL for Catalog + Orders
- Move catalog from Firebase → PostgreSQL
- Keep Firebase for: auth, real-time WebSocket, notifications
- Use Supabase (free PostgreSQL hosting)
**Status:** [ ] Not started

---

## 🟢 PHASE A+ — Event Loop, WebSocket Scaling & Redis (2026-05-30)
**Goal:** Make the WHOLE backend (not just catalog) scale to many concurrent users,
and make live tracking + cache work across multiple server workers.
**Status:** ✅ COMPLETE — backend implemented & import/compile/test verified.

### A+.1 — Unblock the event loop (BIGGEST WIN)
**Problem:** Every router called the *synchronous* `db.reference(...).get()` directly
inside `async def`. FastAPI runs all async handlers on ONE event-loop thread, so each
blocking Firebase call (50–800 ms) froze the entire server — all other requests AND
all WebSocket location broadcasts stalled with it. This capped real concurrency at ~1.
**Fix:** New `services/firebase_async.py` runs every Firebase call on a thread pool and
`await`s it. `orders.py`, `stores.py`, `catalog.py`, `broadcasting.py`, `location_ws.py`
all converted. `get_many()` reads multiple paths concurrently (kills N+1 loops).
**Gain:** Server stays responsive under load; throughput scales with the pool (32) instead
of being serialized. This is the change that actually makes "thousands of users" possible.

### A+.2 — WebSocket: memory-leak fix + lifecycle
**Problem:** `close_order_channel()` existed but was NEVER called, and `_channels` was a
`defaultdict` that created an entry on mere read. Every delivered order leaked a channel
forever.
**Fix:** Rewrote `services/location_ws.py`: channels are created on first customer and
deleted when the last leaves or the order is delivered. `mark_delivered` / `report-failure`
now call `close_order_channel()`. Added rider-update throttle (≥1/s) + delta drop.

### A+.3 — Event-driven broadcasting (no more polling)
**Problem:** `_run_broadcast` re-read the order every 2 s to notice acceptance — constant
blocking reads per active order.
**Fix:** Accept now *signals* the waiting broadcast via an `asyncio.Event` (same worker)
and a Redis publish (other workers). The broadcast `await`s the event with the wave
timeout — zero polling. Per-store FCM tokens fetched concurrently.

### A+.4 — Redis Pub/Sub bus (horizontal scaling)
**Problem:** In-memory WS hub + cache only work for ONE process. With 2+ Railway workers,
a rider on worker A can't reach a customer on worker B, and caches go stale across workers.
**Fix:** New `services/redis_bus.py`:
- **WS rider location** published to `ws:order:{id}:loc`; each worker subscribes for orders
  it has local customers for and fans out. Works across any number of workers.
- **Cache invalidation** on `cache:invalidate`; an admin edit on one worker clears the L1
  cache on ALL workers (`services/cache.invalidate()`).
- **Accept signal** on `order:{id}:accepted` (see A+.3).
- **Graceful fallback:** if `REDIS_URL` is unset the bus disables itself and the app runs
  exactly as before (single worker). So local dev needs no Redis.
**Setup:** `pip install redis` (added to requirements.txt) + set `REDIS_URL` on Railway.

### A+.5 — Cache hardening
`TTLCache` is now bounded (`max_size=5000`, evicts oldest) so per-request `user:{uid}`
keys can't grow memory without limit.

**Files added:** `services/firebase_async.py`, `services/redis_bus.py`
**Files changed:** `services/cache.py`, `services/location_ws.py`, `services/broadcasting.py`,
`services/geofencing.py` (added concurrent `*_async` variants), `routers/orders.py`,
`routers/stores.py`, `routers/catalog.py`, `main.py`, `config.py`, `requirements.txt`,
`.env.example`

### A+.6 — Firebase `.indexOn` rules ✅ DONE (2026-05-30)
Added/corrected indexes in `firebase/realtime-db.json` (+ mirrored `.rules`):
- `orders`: `customer_id`, `accepted_by_store_id`, `assigned_delivery_boy_id`
- `delivery_boys`, `custom_item_requests`: `store_id`
**Bug found & fixed:** the old `orders` index listed `delivery_boy_id`, a field that doesn't
exist — the real field is `assigned_delivery_boy_id`. The rider "my deliveries" query was
full-scanning the whole `orders` table on every call. Also added the two missing node indexes.
**Deploy step (manual):** `cd firebase && firebase deploy --only database`.

### A+.7 — Push-driven customer UI ✅ DONE (2026-05-30)
Customer app now reacts to FCM order pushes instead of fast-polling:
- `core/services/fcm_service.dart`: dead single callback → broadcast `Stream<String> orderUpdates`.
- `broadcasting_screen.dart`: listens to the stream (instant accept), poll slowed 4 s → 8 s fallback.
- `order_tracking_screen.dart`: listens too (instant packed/out-for-delivery/delivered), 8 s poll kept.
**Why keep polling:** FCM is best-effort; the slow poll is the reliability backstop.
`flutter analyze` on the 3 files: 0 errors/warnings (only pre-existing `withOpacity` infos).
**Note:** needs a customer_app APK rebuild to ship.

### ✅ Phase A+ follow-ups all cleared.

---

## ✅ COMPLETED IMPLEMENTATIONS

- **2026-05-29 — Phase A**: in-memory TTL cache, async catalog reads, GZIP, cache warming.
- **2026-05-30 — Phase A+**: event-loop unblocking (firebase_async), WS memory-leak fix +
  Redis Pub/Sub tracking, event-driven broadcasting, cross-worker cache invalidation.

---

## 📊 Performance Baseline (Measure BEFORE implementing)

To measure current performance, run:
```bash
# From backend folder
python -c "
import time
import firebase_admin
from firebase_admin import db
from firebase_init import init_firebase
init_firebase()
start = time.time()
result = db.reference('catalog').get()
print(f'Catalog read: {(time.time()-start)*1000:.0f}ms, items: {len(result or {})}')
"
```

Record the numbers here before we start:
- GET /catalog/items baseline: ___ ms  (measure and fill in)
- GET /catalog/stores/nearby baseline: ___ ms
- GET /catalog/stores/{id} baseline: ___ ms

---

## 🔧 Technical Decisions Log

| Date | Decision | Why | Alternative Considered |
|------|----------|-----|----------------------|
| 2026-05-28 | Start with in-memory cache, not Redis | Zero setup, works for single process MVP | Redis needs extra server setup |
| 2026-05-28 | Keep Firebase, don't migrate to PostgreSQL | Already built, works for current scale | PostgreSQL would need full migration |
| 2026-05-30 | Wrap blocking Firebase SDK in a thread pool (`firebase_async`) instead of switching to an async DB client | Keeps Firebase + all existing logic; one small module unblocks the whole app | Rewriting every query against an async client = huge, risky |
| 2026-05-30 | Redis as a Pub/Sub *message bus*, keep L1 cache in-memory | Fast local reads + cross-worker correctness; Redis only carries small messages, not big blobs | Putting catalog blobs in Redis adds latency to every read |
| 2026-05-30 | Redis is OPTIONAL (auto-disable when `REDIS_URL` unset) | Local dev + single-worker prod need zero setup; flip one env var to scale | Hard dependency would block local dev without Redis |
| 2026-05-30 | Event/Pub-Sub accept signal instead of 2 s polling | Instant acceptance, no steady read load per active order | Polling wastes reads and adds latency |

---

*Updated: 2026-05-28*
