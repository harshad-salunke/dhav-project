from fastapi import APIRouter, HTTPException, Depends, Query
from firebase_admin import db

from models.user import TokenVerifyResponse
from dependencies import require_role
from services.geofencing import index_store_geofence, remove_store_from_geofence_index
from services.penalties import process_store_failure
from utils.helpers import now_ms

router = APIRouter()

_admin = require_role("admin")


# ── Store Management ───────────────────────────────────────────────────────────

@router.get("/stores")
async def list_stores(
    is_active: bool = Query(None),
    is_suspended: bool = Query(None),
    _: TokenVerifyResponse = Depends(_admin),
):
    stores_node = db.reference("stores").get() or {}
    stores = list(stores_node.values())
    if is_active is not None:
        stores = [s for s in stores if s.get("is_active") == is_active]
    if is_suspended is not None:
        stores = [s for s in stores if s.get("is_suspended") == is_suspended]
    return {"stores": stores, "total": len(stores)}


@router.get("/stores/{store_id}")
async def get_store(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    store = db.reference(f"stores/{store_id}").get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    return store


@router.patch("/stores/{store_id}/verify")
async def verify_store(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    ref = db.reference(f"stores/{store_id}")
    store = ref.get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    ref.update({"is_verified": True})
    loc = store.get("location", {})
    if loc.get("lat") and loc.get("lng"):
        index_store_geofence(store_id, loc["lat"], loc["lng"], is_verified=True)
    return {"status": "verified"}


@router.patch("/stores/{store_id}/suspend")
async def suspend_store(
    store_id: str,
    body: dict,
    _: TokenVerifyResponse = Depends(_admin),
):
    ref = db.reference(f"stores/{store_id}")
    store = ref.get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    days = body.get("days", 7)
    ref.update({
        "is_suspended": True,
        "suspension_end_date": now_ms() + days * 86_400_000,
    })
    loc = store.get("location", {})
    if loc.get("lat") and loc.get("lng"):
        remove_store_from_geofence_index(store_id, loc["lat"], loc["lng"])
    return {"status": "suspended", "days": days}


@router.patch("/stores/{store_id}/unsuspend")
async def unsuspend_store(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    ref = db.reference(f"stores/{store_id}")
    store = ref.get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    ref.update({"is_suspended": False, "suspension_end_date": None, "strike_count": 0})
    loc = store.get("location", {})
    if loc.get("lat") and loc.get("lng"):
        index_store_geofence(store_id, loc["lat"], loc["lng"],
                              is_active=True, is_verified=store.get("is_verified", False))
    return {"status": "unsuspended"}


# ── Order Management ───────────────────────────────────────────────────────────

@router.get("/orders")
async def list_orders(
    status: str = Query(None),
    limit: int = Query(50, le=200),
    _: TokenVerifyResponse = Depends(_admin),
):
    orders_node = db.reference("orders").get() or {}
    orders = list(orders_node.values())
    if status:
        orders = [o for o in orders if o.get("status") == status]
    orders.sort(key=lambda o: o.get("created_at", 0), reverse=True)
    return {"orders": orders[:limit], "total": len(orders)}


@router.post("/orders/{order_id}/force-fail")
async def force_fail_order(
    order_id: str,
    user: TokenVerifyResponse = Depends(_admin),
):
    ref = db.reference(f"orders/{order_id}")
    order = ref.get()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if order["status"] in ("delivered", "failed", "cancelled"):
        raise HTTPException(status_code=409, detail="Order already in terminal state")
    ref.update({"status": "failed", "failure_reason": "admin_forced"})
    store_id = order.get("accepted_by_store_id")
    if store_id:
        process_store_failure(store_id, order_id, reason="admin_forced")
    return {"status": "failed"}


# ── Customer Management ────────────────────────────────────────────────────────

@router.get("/customers")
async def list_customers(
    limit: int = Query(50, le=500),
    _: TokenVerifyResponse = Depends(_admin),
):
    users_node = db.reference("users").get() or {}
    customers = [u for u in users_node.values() if u.get("role") == "customer"]
    return {"customers": customers[:limit], "total": len(customers)}


@router.get("/customers/{uid}")
async def get_customer(uid: str, _: TokenVerifyResponse = Depends(_admin)):
    user = db.reference(f"users/{uid}").get()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ── Analytics ─────────────────────────────────────────────────────────────────

@router.get("/analytics/summary")
async def analytics_summary(_: TokenVerifyResponse = Depends(_admin)):
    stores_node = db.reference("stores").get() or {}
    orders_node = db.reference("orders").get() or {}

    total_stores = len(stores_node)
    active_stores = sum(1 for s in stores_node.values() if s.get("is_active") and not s.get("is_suspended"))
    total_orders = len(orders_node)
    delivered = sum(1 for o in orders_node.values() if o.get("status") == "delivered")
    failed = sum(1 for o in orders_node.values() if o.get("status") == "failed")
    success_rate = round(delivered / total_orders * 100, 1) if total_orders else 0
    platform_fee_collected = sum(
        o.get("platform_fee_amount", 0)
        for o in orders_node.values()
        if o.get("status") == "delivered"
    )

    return {
        "total_stores": total_stores,
        "active_stores": active_stores,
        "total_orders": total_orders,
        "delivered_orders": delivered,
        "failed_orders": failed,
        "success_rate_pct": success_rate,
        "platform_fee_collected": round(platform_fee_collected, 2),
    }


# ── Settlement Management ──────────────────────────────────────────────────────

@router.get("/settlements")
async def list_settlements(
    status: str = Query(None),
    _: TokenVerifyResponse = Depends(_admin),
):
    settlements_node = db.reference("settlements").get() or {}
    settlements = list(settlements_node.values())
    if status:
        settlements = [s for s in settlements if s.get("status") == status]
    settlements.sort(key=lambda s: s.get("created_at", 0), reverse=True)
    return {"settlements": settlements, "total": len(settlements)}
