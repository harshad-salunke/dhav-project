from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

from firebase_init import init_firebase
from services.scheduler import start_scheduler
from services.location_ws import location_ws_endpoint
from routers import auth, customers, stores, orders, catalog, settlements, admin


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_firebase()
    start_scheduler()
    yield


app = FastAPI(title="DHAV Backend", version="0.2.0", lifespan=lifespan)

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


@app.websocket("/ws/order/{order_id}/location")
async def ws_location(websocket: WebSocket, order_id: str):
    await location_ws_endpoint(websocket, order_id)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "dhav-backend", "version": "0.2.0"}
