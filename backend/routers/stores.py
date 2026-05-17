from fastapi import APIRouter, HTTPException, Depends, Query
from firebase_admin import db

from models.store import StoreCreateRequest, StoreToggleRequest, StoreFCMTokenRequest
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


@router.get("/{store_id}")
async def get_store(
    store_id: str,
    _: TokenVerifyResponse = Depends(get_current_user),
):
    store = db.reference(f"stores/{store_id}").get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    return store
