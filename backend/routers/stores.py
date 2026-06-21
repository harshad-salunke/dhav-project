from fastapi import APIRouter, HTTPException, Depends, Query

from models.store import (
    StoreCreateRequest,
    StoreSelfRegisterRequest,
    StoreProfileUpdateRequest,
    StoreToggleRequest,
    StoreFCMTokenRequest,
)
from models.user import TokenVerifyResponse
from dependencies import get_current_user, require_role
from services.db import pool
from services import cache
from utils.helpers import new_id, now_ms
import pygeohash as geohash

router = APIRouter()


async def _store_id_for_user(uid: str) -> str:
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT store_id FROM users WHERE uid=$1", uid)
    if not row or not row["store_id"]:
        raise HTTPException(status_code=404, detail="Store not found")
    return row["store_id"]


@router.post("", status_code=201)
async def create_store(
    body: StoreCreateRequest,
    user: TokenVerifyResponse = Depends(require_role("admin")),
):
    store_id = new_id()
    gh = geohash.encode(body.lat, body.lng, precision=6)
    location = {"lat": body.lat, "lng": body.lng, "geohash": gh}
    ts = now_ms()

    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO stores (
                id, owner_uid, owner_name, shop_name, phone, email, address,
                geohash6, location, is_open, is_active, is_verified, is_suspended,
                strike_count, total_strikes, available_item_ids, total_orders_accepted,
                total_orders_failed, onboarded_by, rating, created_at
            ) VALUES (
                $1,$2,$3,$4,$5,$6,$7,
                $8,$9::jsonb,false,true,false,false,
                0,0,'[]'::jsonb,0,
                0,$10,0,$11
            )
        """, store_id, body.owner_uid, body.owner_name, body.shop_name,
            body.phone, body.email, body.address,
            gh, location, user.uid, ts)

        await conn.execute(
            "UPDATE users SET role='store_owner', store_id=$2 WHERE uid=$1",
            body.owner_uid, store_id,
        )
    return {"store_id": store_id}


@router.post("/register", status_code=201)
async def register_store(
    body: StoreSelfRegisterRequest,
    user: TokenVerifyResponse = Depends(get_current_user),
):
    if user.role == "delivery":
        raise HTTPException(status_code=403, detail="Delivery partners cannot register a store")

    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT store_id FROM users WHERE uid=$1", user.uid)
    if row and row["store_id"]:
        raise HTTPException(status_code=409, detail="User already owns a store")

    store_id = new_id()
    gh = geohash.encode(body.lat, body.lng, precision=6)
    location = {"lat": body.lat, "lng": body.lng, "geohash": gh}
    operating_hours = (
        body.operating_hours.model_dump()
        if body.operating_hours
        else {"open": "09:00", "close": "22:00"}
    )
    ts = now_ms()

    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO stores (
                id, owner_uid, owner_name, shop_name, store_type, phone, email, address,
                geohash6, location, operating_hours, self_delivery, is_open, is_active, is_verified, is_suspended,
                strike_count, total_strikes, available_item_ids, total_orders_accepted,
                total_orders_failed, onboarded_by, rating, onboarding_date, created_at
            ) VALUES (
                $1,$2,$3,$4,$12,$5,$6,$7,
                $8,$9::jsonb,$11::jsonb,$13,false,true,false,false,
                0,0,'[]'::jsonb,0,
                0,$2,0,$10,$10
            )
        """, store_id, user.uid, body.owner_name, body.shop_name,
            body.phone, user.email, body.address,
            gh, location, ts, operating_hours, body.store_type, body.self_delivery)

        await conn.execute(
            "UPDATE users SET role='store_owner', store_id=$2 WHERE uid=$1",
            user.uid, store_id,
        )
    return {"store_id": store_id, "is_verified": False}


@router.get("/me")
async def get_my_store(user: TokenVerifyResponse = Depends(require_role("store_owner"))):
    store_id = await _store_id_for_user(user.uid)
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store profile not found")
    data = dict(row)
    # The stores table PK column is `id`, but the app's Store model keys on
    # `store_id` (matching the /register + /create responses). Expose both so
    # the client parses the row instead of failing on a missing `store_id`.
    data["store_id"] = data["id"]
    return data


@router.patch("/me/profile")
async def update_my_profile(
    body: StoreProfileUpdateRequest,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    store_id = await _store_id_for_user(user.uid)

    updates: dict = {}
    if body.shop_name is not None:
        updates["shop_name"] = body.shop_name
        # Keep `name` (admin-onboard alias) in sync so the store's name shows
        # consistently in the admin dashboard and coverage map.
        updates["name"] = body.shop_name
    if body.owner_name is not None:
        updates["owner_name"] = body.owner_name
    if body.phone is not None:
        updates["phone"] = body.phone
    if body.address is not None:
        updates["address"] = body.address
    if body.operating_hours is not None:
        updates["operating_hours"] = body.operating_hours.model_dump()
    if body.self_delivery is not None:
        updates["self_delivery"] = body.self_delivery

    if body.lat is not None or body.lng is not None:
        async with pool().acquire() as conn:
            row = await conn.fetchrow("SELECT location FROM stores WHERE id=$1", store_id)
        current_loc = (row["location"] if row else {}) or {}
        new_lat = body.lat if body.lat is not None else current_loc.get("lat", 0)
        new_lng = body.lng if body.lng is not None else current_loc.get("lng", 0)
        new_gh = geohash.encode(new_lat, new_lng, precision=6)
        updates["location"] = {"lat": new_lat, "lng": new_lng, "geohash": new_gh}
        updates["geohash6"] = new_gh

    if not updates:
        return {"status": "no_changes"}

    fields, vals = [], [store_id]
    for k, v in updates.items():
        vals.append(v)
        col_cast = f"${len(vals)}::jsonb" if isinstance(v, dict) else f"${len(vals)}"
        fields.append(f"{k} = {col_cast}")

    async with pool().acquire() as conn:
        await conn.execute(
            f"UPDATE stores SET {', '.join(fields)} WHERE id = $1", *vals
        )
    await cache.invalidate(f"store:{store_id}")
    return {"status": "updated", "updated_fields": list(updates.keys())}


@router.patch("/me/toggle")
async def toggle_store(
    body: StoreToggleRequest,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    store_id = await _store_id_for_user(user.uid)
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store not found")
    store = dict(row)

    if store.get("is_suspended"):
        raise HTTPException(status_code=403, detail="Store is suspended")
    if body.is_open and not store.get("is_verified", False):
        raise HTTPException(
            status_code=403,
            detail="Store is pending admin verification. You cannot accept orders yet.",
        )

    async with pool().acquire() as conn:
        await conn.execute("UPDATE stores SET is_open=$2 WHERE id=$1", store_id, body.is_open)

    await cache.invalidate(f"store:{store_id}")
    return {"is_open": body.is_open}


@router.patch("/me/fcm-token")
async def update_fcm_token(
    body: StoreFCMTokenRequest,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    store_id = await _store_id_for_user(user.uid)
    async with pool().acquire() as conn:
        await conn.execute("UPDATE stores SET fcm_token=$2 WHERE id=$1", store_id, body.fcm_token)
    return {"status": "updated"}


@router.patch("/me/inventory")
async def update_inventory(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    store_id = await _store_id_for_user(user.uid)
    ids = body.get("available_item_ids", [])
    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE stores SET available_item_ids=$2::jsonb WHERE id=$1",
            store_id, ids,
        )
    await cache.invalidate(f"store:{store_id}")
    return {"available_item_ids": ids}


@router.get("/me/orders")
async def get_my_orders(
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
    status: str = Query(None),
    limit: int = Query(50, le=200),
):
    store_id = await _store_id_for_user(user.uid)
    if status:
        async with pool().acquire() as conn:
            rows = await conn.fetch("""
                SELECT * FROM orders
                WHERE accepted_by_store_id=$1 AND status=$2
                ORDER BY created_at DESC LIMIT $3
            """, store_id, status, limit)
    else:
        async with pool().acquire() as conn:
            rows = await conn.fetch("""
                SELECT * FROM orders WHERE accepted_by_store_id=$1
                ORDER BY created_at DESC LIMIT $2
            """, store_id, limit)
    return {"orders": [dict(r) for r in rows]}


# ── Delivery Boys ──────────────────────────────────────────────────────────────

@router.get("/me/delivery-boys")
async def list_my_delivery_boys(user: TokenVerifyResponse = Depends(require_role("store_owner"))):
    store_id = await _store_id_for_user(user.uid)
    async with pool().acquire() as conn:
        rows = await conn.fetch("SELECT * FROM delivery_boys WHERE store_id=$1", store_id)
    return {"delivery_boys": [dict(r) for r in rows]}


@router.post("/me/delivery-boys", status_code=201)
async def add_delivery_boy(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    store_id = await _store_id_for_user(user.uid)
    boy_id = new_id()
    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO delivery_boys (id, store_id, name, phone, google_account_email, is_active, created_at)
            VALUES ($1,$2,$3,$4,$5,true,$6)
        """, boy_id, store_id,
            body.get("name", ""), body.get("phone", ""),
            body.get("google_account_email", ""), now_ms())
    return {"delivery_boy_id": boy_id}


@router.delete("/me/delivery-boys/{delivery_boy_id}")
async def remove_delivery_boy(
    delivery_boy_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    store_id = await _store_id_for_user(user.uid)
    async with pool().acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id FROM delivery_boys WHERE id=$1 AND store_id=$2",
            delivery_boy_id, store_id,
        )
    if not row:
        raise HTTPException(status_code=404, detail="Delivery boy not found")
    async with pool().acquire() as conn:
        await conn.execute("DELETE FROM delivery_boys WHERE id=$1", delivery_boy_id)
    return {"status": "removed"}


# ── Custom Item Requests ───────────────────────────────────────────────────────

@router.post("/me/custom-items", status_code=201)
async def request_custom_item(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    store_id = await _store_id_for_user(user.uid)
    item_name = (body.get("name") or "").strip()
    if not item_name:
        raise HTTPException(status_code=422, detail="Item name is required")

    request_id = new_id()
    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO custom_item_requests (
                id, store_id, requested_by_uid, name, name_hindi, name_marathi,
                category, unit, price, notes, status, created_at
            ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'pending',$11)
        """, request_id, store_id, user.uid,
            item_name,
            body.get("name_hindi", ""), body.get("name_marathi", ""),
            body.get("category", "Other"), body.get("unit", "piece"),
            float(body.get("price") or 0),
            body.get("notes", ""), now_ms())
    return {"request_id": request_id, "status": "pending"}


@router.get("/me/custom-items")
async def list_custom_item_requests(user: TokenVerifyResponse = Depends(require_role("store_owner"))):
    store_id = await _store_id_for_user(user.uid)
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM custom_item_requests WHERE store_id=$1 ORDER BY created_at DESC",
            store_id,
        )
    return {"requests": [dict(r) for r in rows]}


@router.get("/{store_id}")
async def get_store(
    store_id: str,
    _: TokenVerifyResponse = Depends(get_current_user),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store not found")
    return dict(row)
