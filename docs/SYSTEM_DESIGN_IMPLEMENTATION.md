# DHAV — System Design Implementation Tracker
**What we planned, what we built, and why**

> This file tracks every system design improvement we implement.
> Read this to understand what's already been done and what's next.

---

## 🟡 PHASE A — Quick Wins (In-Memory Cache + Async + GZIP)
**Goal:** Make catalog 10x faster with zero new services (no Redis, no new server)
**Status:** PLANNED — not yet implemented

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

## ✅ COMPLETED IMPLEMENTATIONS

*(Nothing yet — we're starting Phase A next)*

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

---

*Updated: 2026-05-28*
