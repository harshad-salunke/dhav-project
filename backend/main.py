import logging
from contextlib import asynccontextmanager

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from firebase_init import init_firebase
from services.scheduler import start_scheduler
from services.location_ws import location_ws_endpoint
from services import redis_bus, cache, db as database
from services.cache import catalog_cache, CATALOG_TTL
from config import get_settings
from routers import auth, customers, stores, orders, catalog, settlements, admin, delivery, notifications, calls


async def _warm_catalog_cache():
    """Pre-load catalog into memory so the first real request is fast."""
    async with database.pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM catalog_items WHERE is_active = true ORDER BY category, name"
        )
    data = {row["id"]: dict(row) for row in rows}
    catalog_cache.set("catalog_all", data, ttl=CATALOG_TTL)
    categories = sorted({row["category"] for row in rows if row.get("category")})
    catalog_cache.set("catalog_categories", categories, ttl=CATALOG_TTL * 2)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    init_firebase()
    await database.init_pool(settings.database_url)
    await redis_bus.init_redis()
    await cache.init_invalidation_subscriber()
    start_scheduler()
    await _warm_catalog_cache()
    yield
    await database.close_pool()
    await redis_bus.close_redis()


app = FastAPI(title="DHAV Backend", version="0.3.0", lifespan=lifespan)

app.add_middleware(GZipMiddleware, minimum_size=500)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,          prefix="/auth")
app.include_router(customers.router,     prefix="/customers")
app.include_router(stores.router,        prefix="/stores")
app.include_router(orders.router,        prefix="/orders")
app.include_router(catalog.router,       prefix="/catalog")
app.include_router(settlements.router,   prefix="/settlements")
app.include_router(admin.router,         prefix="/admin")
app.include_router(delivery.router,      prefix="/delivery")
app.include_router(notifications.router, prefix="/notifications")
app.include_router(calls.router,         prefix="/calls")


# Canonical path used by both Flutter apps + API_REFERENCE.md.
# (was "/ws/location/{order_id}" — a mismatch that silently broke all live tracking.)
@app.websocket("/ws/order/{order_id}/location")
async def location_ws(websocket: WebSocket, order_id: str):
    await location_ws_endpoint(websocket, order_id)


@app.get("/health")
async def health():
    return {"status": "ok", "version": "0.3.0", "db": "supabase_postgresql"}
