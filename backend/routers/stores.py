from fastapi import APIRouter, HTTPException, Depends, Query
from firebase_admin import db

from models.store import (
    StoreCreateRequest,
    StoreSelfRegisterRequest,
    StoreToggleRequest,
    StoreFCMTokenRequest,
)
from models.user import TokenVerifyResponse
from dependencies import get_current_user, require_role
from services.geofencing import index_store_geofence, remove_store_from_geofence_index
from utils.helpers import new_id, now_ms
import pygeohash as geohash

router = APIRouter()


@router.post("", status_code=201)
async def create_store(
    body: StoreCreateRequest,
    user: TokenVerifyResponse = Depends(require_role("admin")),
):
    store_id = new_id()
    gh = geohash.encode(body.lat, body.lng, precision=6)
    store_data = {
        "store_id": store_id,
        "owner_uid": body.owner_uid,
        "owner_name": body.owner_name,
        "shop_name": body.shop_name,
        "phone": body.phone,
        "email": body.email,
        "address": body.address,
        "location": {"lat": body.lat, "lng": body.lng, "geohash": gh},
        "is_open": False,
        "is_active": True,
        "is_verified": False,
        "is_suspended": False,
        "strike_count": 0,
        "total_strikes": 0,
        "available_item_ids": [],
        "total_orders_accepted": 0,
        "total_orders_failed": 0,
        "onboarded_by": user.uid,
        "rating": 0.0,
        "fcm_token": None,
        "created_at": now_ms(),
    }
    if body.operating_hours:
        store_data["operating_hours"] = body.operating_hours.model_dump()

    db.reference(f"stores/{store_id}").set(store_data)

    # Update user role to store_owner
    db.reference(f"users/{body.owner_uid}").update({"role": "store_owner", "store_id": store_id})

    # Index in geofence
    index_store_geofence(store_id, body.lat, body.lng)
    return {"store_id": store_id}


@router.post("/register", status_code=201)
async def register_store(
    body: StoreSelfRegisterRequest,
    user: TokenVerifyResponse = Depends(get_current_user),
):
    """Self-onboarding: any authenticated user can register a store for themselves.
    The store starts unverified — admin must verify before it can go live."""
    user_node = db.reference(f"users/{user.uid}").get() or {}
    if user_node.get("store_id"):
        raise HTTPException(status_code=409, detail="User already owns a store")

    store_id = new_id()
    gh = geohash.encode(body.lat, body.lng, precision=6)
    store_data = {
        "store_id": store_id,
        "owner_uid": user.uid,
        "owner_name": body.owner_name,
        "shop_name": body.shop_name,
        "phone": body.phone,
        "email": user.email,
        "address": body.address,
        "location": {"lat": body.lat, "lng": body.lng, "geohash": gh},
        "is_open": False,
        "is_active": True,
        "is_verified": False,
        "is_suspended": False,
        "strike_count": 0,
        "total_strikes": 0,
        "available_item_ids": [],
        "total_orders_accepted": 0,
        "total_orders_failed": 0,
        "onboarded_by": user.uid,  # self-onboarded
        "rating": 0.0,
        "fcm_token": None,
        "created_at": now_ms(),
        "onboarding_date": now_ms(),
    }
    if body.operating_hours:
        store_data["operating_hours"] = body.operating_hours.model_dump()

    db.reference(f"stores/{store_id}").set(store_data)

    db.reference(f"users/{user.uid}").update(
        {"role": "store_owner", "store_id": store_id}
    )

    # Do NOT index in geofence — store is unverified. Indexing happens when admin verifies
    # and owner toggles open.
    return {"store_id": store_id, "is_verified": False}


@router.get("/me")
async def get_my_store(user: TokenVerifyResponse = Depends(require_role("store_owner"))):
    user_node = db.reference(f"users/{user.uid}").get() or {}
    store_id = user_node.get("store_id")
    if not store_id:
        raise HTTPException(status_code=404, detail="Store not found for this user")
    store = db.reference(f"stores/{store_id}").get()
    if not store:
        raise HTTPException(status_code=404, detail="Store profile not found")
    return store


@router.patch("/me/toggle")
async def toggle_store(
    body: StoreToggleRequest,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    user_node = db.reference(f"users/{user.uid}").get() or {}
    store_id = user_node.get("store_id")
    if not store_id:
        raise HTTPException(status_code=404, detail="Store not found")
    store = db.reference(f"stores/{store_id}").get() or {}

    if store.get("is_suspended"):
        raise HTTPException(status_code=403, detail="Store is suspended")

    if body.is_open and not store.get("is_verified", False):
        raise HTTPException(
            status_code=403,
            detail="Store is pending admin verification. You cannot accept orders yet.",
        )

    db.reference(f"stores/{store_id}").update({"is_open": body.is_open})

    # Sync geofence: only index when open and active
    lat = store["location"]["lat"]
    lng = store["location"]["lng"]
    if body.is_open:
        index_store_geofence(store_id, lat, lng,
                              is_active=True,
                              is_verified=store.get("is_verified", False))
    else:
        remove_store_from_geofence_index(store_id, lat, lng)

    return {"is_open": body.is_open}


@router.patch("/me/fcm-token")
async def update_fcm_token(
    body: StoreFCMTokenRequest,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    user_node = db.reference(f"users/{user.uid}").get() or {}
    store_id = user_node.get("store_id")
    if not store_id:
        raise HTTPException(status_code=404, detail="Store not found")
    db.reference(f"stores/{store_id}").update({"fcm_token": body.fcm_token})
    return {"status": "updated"}


@router.patch("/me/inventory")
async def update_inventory(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    """body: { "available_item_ids": ["id1", "id2", ...] }"""
    user_node = db.reference(f"users/{user.uid}").get() or {}
    store_id = user_node.get("store_id")
    if not store_id:
        raise HTTPException(status_code=404, detail="Store not found")
    ids = body.get("available_item_ids", [])
    db.reference(f"stores/{store_id}").update({"available_item_ids": ids})
    return {"available_item_ids": ids}


@router.get("/me/orders")
async def get_my_orders(
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
    status: str = Query(None, description="Filter: accepted | packed | out_for_delivery | delivered | failed"),
    limit: int = Query(50, le=200),
):
    user_node = db.reference(f"users/{user.uid}").get() or {}
    store_id = user_node.get("store_id")
    if not store_id:
        raise HTTPException(status_code=404, detail="Store not found")
    all_orders = (
        db.reference("orders")
        .order_by_child("accepted_by_store_id")
        .equal_to(store_id)
        .get()
        or {}
    )
    orders = list(all_orders.values())
    if status:
        orders = [o for o in orders if o.get("status") == status]
    orders.sort(key=lambda o: o.get("created_at", 0), reverse=True)
    return {"orders": orders[:limit]}


# ── Delivery Boy CRUD (store_owner) ────────────────────────────────────────────

@router.get("/me/delivery-boys")
async def list_my_delivery_boys(
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    user_node = db.reference(f"users/{user.uid}").get() or {}
    store_id = user_node.get("store_id")
    if not store_id:
        raise HTTPException(status_code=404, detail="Store not found")
    all_boys = db.reference("delivery_boys").get() or {}
    boys = [b for b in all_boys.values() if b.get("store_id") == store_id]
    return {"delivery_boys": boys}


@router.post("/me/delivery-boys", status_code=201)
async def add_delivery_boy(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    """body: { name, phone, google_account_email }"""
    user_node = db.reference(f"users/{user.uid}").get() or {}
    store_id = user_node.get("store_id")
    if not store_id:
        raise HTTPException(status_code=404, detail="Store not found")
    boy_id = new_id()
    boy_data = {
        "delivery_boy_id": boy_id,
        "store_id": store_id,
        "name": body.get("name", ""),
        "phone": body.get("phone", ""),
        "google_account_email": body.get("google_account_email", ""),
        "is_active": True,
        "current_order_id": None,
        "created_at": now_ms(),
    }
    db.reference(f"delivery_boys/{boy_id}").set(boy_data)
    return {"delivery_boy_id": boy_id}


@router.delete("/me/delivery-boys/{delivery_boy_id}")
async def remove_delivery_boy(
    delivery_boy_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    user_node = db.reference(f"users/{user.uid}").get() or {}
    store_id = user_node.get("store_id")
    boy = db.reference(f"delivery_boys/{delivery_boy_id}").get()
    if not boy or boy.get("store_id") != store_id:
        raise HTTPException(status_code=404, detail="Delivery boy not found")
    db.reference(f"delivery_boys/{delivery_boy_id}").delete()
    return {"status": "removed"}


@router.get("/{store_id}")
async def get_store(
    store_id: str,
    _: TokenVerifyResponse = Depends(get_current_user),
):
    store = db.reference(f"stores/{store_id}").get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    return store
