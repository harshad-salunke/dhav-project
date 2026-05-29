import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from firebase_admin import db
from firebase_init import init_firebase
from services.scheduler import start_scheduler
from services.location_ws import location_ws_endpoint
from services.cache import catalog_cache, CATALOG_TTL
from routers import auth, customers, stores, orders, catalog, settlements, admin, delivery, notifications


async def _warm_catalog_cache():
    """Pre-load catalog into memory so the first real request is fast."""
    loop = asyncio.get_event_loop()
    data = await loop.run_in_executor(None, lambda: db.reference("catalog").get() or {})
    catalog_cache.set("catalog_all", data, ttl=CATALOG_TTL)
    categories = sorted({v["category"] for v in data.values() if v.get("is_active")})
    catalog_cache.set("catalog_categories", categories, ttl=CATALOG_TTL * 2)


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_firebase()
    start_scheduler()
    await _warm_catalog_cache()
    yield


app = FastAPI(title="DHAV Backend", version="0.2.0", lifespan=lifespan)

app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(customers.router, prefix="/customers", tags=["customers"])
app.include_router(stores.router, prefix="/stores", tags=["stores"])
app.include_router(orders.router, prefix="/orders", tags=["orders"])
app.include_router(catalog.router, prefix="/catalog", tags=["catalog"])
app.include_router(settlements.router, prefix="/settlements", tags=["settlements"])
app.include_router(admin.router, prefix="/admin", tags=["admin"])
app.include_router(delivery.router, prefix="/delivery", tags=["delivery"])
app.include_router(notifications.router, prefix="/notifications", tags=["notifications"])


@app.websocket("/ws/order/{order_id}/location")
async def ws_location(websocket: WebSocket, order_id: str):
    await location_ws_endpoint(websocket, order_id)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "dhav-backend", "version": "0.2.0"}
