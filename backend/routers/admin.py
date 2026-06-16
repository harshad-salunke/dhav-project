from fastapi import APIRouter, HTTPException, Depends, Query
from firebase_admin import auth as firebase_auth

from models.user import TokenVerifyResponse
from dependencies import require_role
from services.db import pool
from services import cache
from services.geofencing import index_store_geofence
from services.penalties import process_store_failure
from services.notifications import send_broadcast_notification
from services import remote_config
from utils.helpers import now_ms, new_id

router = APIRouter()
_admin = require_role("admin")


# ── Coming-soon waitlist (demand for unserved spots) ───────────────────────────

@router.get("/waitlist")
async def list_waitlist(_: TokenVerifyResponse = Depends(_admin)):
    """Demand from customers whose spot has no store in range yet, aggregated by
    area (most-wanted first) so the team can prioritise where to onboard stores.
    Also returns the raw rows (newest first) for map plotting."""
    async with pool().acquire() as conn:
        by_area = await conn.fetch(
            """
            SELECT COALESCE(NULLIF(area, ''), 'Unknown') AS area,
                   COUNT(*)            AS requests,
                   AVG(lat)            AS avg_lat,
                   AVG(lng)            AS avg_lng,
                   MAX(created_at)     AS last_request
            FROM coming_soon_waitlist
            GROUP BY 1
            ORDER BY requests DESC
            """
        )
        rows = await conn.fetch(
            "SELECT * FROM coming_soon_waitlist ORDER BY created_at DESC LIMIT 500"
        )
    return {
        "by_area": [dict(r) for r in by_area],
        "entries": [dict(r) for r in rows],
        "total": len(rows),
    }


# ── Store Management ───────────────────────────────────────────────────────────

@router.get("/stores")
async def list_stores(
    is_active: bool = Query(None),
    is_suspended: bool = Query(None),
    _: TokenVerifyResponse = Depends(_admin),
):
    conditions = ["1=1"]
    vals = []
    if is_active is not None:
        vals.append(is_active)
        conditions.append(f"is_active=${len(vals)}")
    if is_suspended is not None:
        vals.append(is_suspended)
        conditions.append(f"is_suspended=${len(vals)}")
    where = " AND ".join(conditions)
    async with pool().acquire() as conn:
        rows = await conn.fetch(f"SELECT * FROM stores WHERE {where} ORDER BY created_at DESC", *vals)
    stores = [dict(r) for r in rows]
    return {"stores": stores, "total": len(stores)}


@router.get("/stores/{store_id}")
async def get_store(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store not found")
    return dict(row)


@router.post("/stores/onboard", status_code=201)
async def onboard_store(body: dict, _: TokenVerifyResponse = Depends(_admin)):
    required = ["name", "area", "owner_name", "phone", "email", "password", "lat", "lng"]
    for field in required:
        if not body.get(field):
            raise HTTPException(status_code=422, detail=f"Missing required field: {field}")

    try:
        user_record = firebase_auth.create_user(
            email=body["email"],
            password=body["password"],
            display_name=body["owner_name"],
        )
        owner_uid = user_record.uid
    except firebase_auth.EmailAlreadyExistsError:
        raise HTTPException(status_code=409, detail="Email already registered")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create user: {e}")

    store_id = new_id()
    lat, lng = float(body["lat"]), float(body["lng"])
    import pygeohash as geohash
    gh = geohash.encode(lat, lng, precision=6)
    location = {"lat": lat, "lng": lng}
    ts = now_ms()

    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO users (uid, email, name, role, store_id, is_active, created_at)
            VALUES ($1,$2,$3,'store_owner',$4,true,$5)
            ON CONFLICT (uid) DO NOTHING
        """, owner_uid, body["email"], body["owner_name"], store_id, ts)

        await conn.execute("""
            INSERT INTO stores (
                id, owner_uid, owner_name, name, area, phone, email, address,
                geohash6, location, is_open, is_active, is_verified, is_suspended,
                strike_count, total_strikes, available_item_ids, created_at
            ) VALUES (
                $1,$2,$3,$4,$5,$6,$7,$8,
                $9,$10::jsonb,false,false,false,false,
                0,0,'[]'::jsonb,$11
            )
        """, store_id, owner_uid, body["owner_name"], body["name"], body["area"],
            body["phone"], body["email"], body.get("address", ""),
            gh, location, ts)

    return {
        "store_id": store_id,
        "owner_uid": owner_uid,
        "email": body["email"],
        "message": "Store onboarded. Owner can now log in with the provided credentials.",
    }


@router.put("/stores/{store_id}")
async def update_store(store_id: str, body: dict, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store not found")

    allowed = {"name", "shop_name", "area", "phone", "email", "address",
               "is_active", "is_verified", "operating_hours", "image_url"}
    updates = {k: v for k, v in body.items() if k in allowed}

    # `name` (admin-onboard flow) and `shop_name` (store self-register flow)
    # are two names for the same field. Keep both columns in sync so a rename
    # from either app shows consistently everywhere.
    if "name" in updates and "shop_name" not in updates:
        updates["shop_name"] = updates["name"]
    elif "shop_name" in updates and "name" not in updates:
        updates["name"] = updates["shop_name"]

    new_lat = body.get("lat")
    new_lng = body.get("lng")
    if new_lat is not None and new_lng is not None:
        import pygeohash as geohash
        gh = geohash.encode(float(new_lat), float(new_lng), precision=6)
        updates["location"] = {"lat": float(new_lat), "lng": float(new_lng)}
        updates["geohash6"] = gh

    updates["updated_at"] = now_ms()

    if updates:
        fields, vals = [], [store_id]
        for k, v in updates.items():
            vals.append(v)
            col_cast = f"${len(vals)}::jsonb" if isinstance(v, dict) else f"${len(vals)}"
            fields.append(f"{k} = {col_cast}")
        async with pool().acquire() as conn:
            await conn.execute(f"UPDATE stores SET {', '.join(fields)} WHERE id=$1", *vals)

    await cache.invalidate(f"store:{store_id}")
    return {"status": "updated"}


@router.delete("/stores/{store_id}")
async def delete_store(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT id FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store not found")
    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE stores SET is_active=false, is_suspended=true, deleted_at=$2 WHERE id=$1",
            store_id, now_ms(),
        )
    await cache.invalidate(f"store:{store_id}")
    return {"status": "deleted"}


@router.patch("/stores/{store_id}/verify")
async def verify_store(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store not found")
    async with pool().acquire() as conn:
        await conn.execute("UPDATE stores SET is_verified=true WHERE id=$1", store_id)
    await cache.invalidate(f"store:{store_id}")
    return {"status": "verified"}


@router.patch("/stores/{store_id}/suspend")
async def suspend_store(store_id: str, body: dict, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT id FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store not found")
    days = body.get("days", 7)
    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE stores SET is_suspended=true, suspension_end_date=$2 WHERE id=$1",
            store_id, now_ms() + days * 86_400_000,
        )
    await cache.invalidate(f"store:{store_id}")
    return {"status": "suspended", "days": days}


@router.patch("/stores/{store_id}/unsuspend")
async def unsuspend_store(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store not found")
    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE stores SET is_suspended=false, suspension_end_date=NULL, strike_count=0 WHERE id=$1",
            store_id,
        )
    await cache.invalidate(f"store:{store_id}")
    return {"status": "unsuspended"}


# ── Store Inventory ────────────────────────────────────────────────────────────

@router.get("/stores/{store_id}/inventory")
async def get_store_inventory(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        store_row = await conn.fetchrow("SELECT * FROM stores WHERE id=$1", store_id)
    if not store_row:
        raise HTTPException(status_code=404, detail="Store not found")
    store = dict(store_row)

    async with pool().acquire() as conn:
        catalog_rows = await conn.fetch("SELECT * FROM catalog_items WHERE is_active=true")

    available_ids = set(store.get("available_item_ids") or [])
    inventory = store.get("inventory") or {}

    items = []
    for row in catalog_rows:
        item_id = row["id"]
        inv_entry = inventory.get(item_id, {}) if isinstance(inventory, dict) else {}
        items.append({
            **dict(row),
            "item_id": item_id,
            "is_available": item_id in available_ids,
            "quantity": inv_entry.get("quantity", 0) if isinstance(inv_entry, dict) else 0,
        })
    return {"items": items, "total": len(items)}


@router.put("/stores/{store_id}/inventory")
async def update_store_inventory(store_id: str, body: dict, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT id FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store not found")

    items = body.get("items", [])
    inventory_update = {}
    available_ids = []
    for item in items:
        item_id = item.get("item_id")
        if not item_id:
            continue
        is_available = item.get("is_available", False)
        quantity = item.get("quantity", 0)
        inventory_update[item_id] = {"quantity": quantity, "is_available": is_available}
        if is_available:
            available_ids.append(item_id)

    async with pool().acquire() as conn:
        await conn.execute("""
            UPDATE stores SET
                inventory=$2::jsonb,
                available_item_ids=$3::jsonb,
                updated_at=$4
            WHERE id=$1
        """, store_id, inventory_update, available_ids, now_ms())
    await cache.invalidate(f"store:{store_id}")
    return {"status": "updated", "items_updated": len(items)}


# ── Store Reviews ──────────────────────────────────────────────────────────────

@router.get("/stores/{store_id}/reviews")
async def get_store_reviews(
    store_id: str,
    limit: int = Query(50, le=200),
    _: TokenVerifyResponse = Depends(_admin),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT id FROM stores WHERE id=$1", store_id)
    if not row:
        raise HTTPException(status_code=404, detail="Store not found")
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM reviews WHERE store_id=$1 ORDER BY created_at DESC LIMIT $2",
            store_id, limit,
        )
    reviews = [dict(r) for r in rows]
    total = len(reviews)
    avg_rating = round(sum(r["rating"] for r in reviews if r.get("rating")) / total, 1) if total else 0
    return {"reviews": reviews, "total": total, "avg_rating": avg_rating}


@router.delete("/stores/{store_id}/reviews/{review_id}")
async def delete_review(store_id: str, review_id: str, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id FROM reviews WHERE id=$1 AND store_id=$2", review_id, store_id
        )
    if not row:
        raise HTTPException(status_code=404, detail="Review not found")
    async with pool().acquire() as conn:
        await conn.execute("DELETE FROM reviews WHERE id=$1", review_id)
    return {"status": "deleted"}


# ── Store Stats ────────────────────────────────────────────────────────────────

@router.get("/stores/{store_id}/stats")
async def get_store_stats(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        store_row = await conn.fetchrow("SELECT * FROM stores WHERE id=$1", store_id)
    if not store_row:
        raise HTTPException(status_code=404, detail="Store not found")

    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM orders WHERE accepted_by_store_id=$1 ORDER BY created_at DESC",
            store_id,
        )
    orders = [dict(r) for r in rows]
    total = len(orders)
    delivered = sum(1 for o in orders if o.get("status") == "delivered")
    failed = sum(1 for o in orders if o.get("status") == "failed")
    pending = sum(1 for o in orders if o.get("status") not in ("delivered", "failed", "cancelled"))
    revenue = sum(o.get("total_customer_amount", 0) for o in orders if o.get("status") == "delivered")
    platform_fee = sum(o.get("platform_fee_amount", 0) for o in orders if o.get("status") == "delivered")

    return {
        "store_id": store_id,
        "store_name": dict(store_row).get("shop_name") or dict(store_row).get("name", ""),
        "total_orders": total,
        "delivered_orders": delivered,
        "failed_orders": failed,
        "pending_orders": pending,
        "success_rate_pct": round(delivered / total * 100, 1) if total else 0,
        "total_revenue": round(revenue, 2),
        "platform_fee_collected": round(platform_fee, 2),
        "recent_orders": orders[:20],
    }


# ── Catalog Management ─────────────────────────────────────────────────────────

@router.get("/catalog/items")
async def admin_list_catalog(
    include_inactive: bool = Query(False),
    category: str = Query(None),
    search: str = Query(None),
    _: TokenVerifyResponse = Depends(_admin),
):
    conditions = ["1=1"]
    vals = []
    if not include_inactive:
        conditions.append("is_active=true")
    if category:
        vals.append(category)
        conditions.append(f"category=${len(vals)}")
    where = " AND ".join(conditions)
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            f"SELECT * FROM catalog_items WHERE {where} ORDER BY category, name", *vals
        )
    results = [dict(r) for r in rows]
    if search:
        q = search.lower()
        results = [r for r in results if
                   q in (r.get("name") or "").lower()
                   or q in (r.get("name_hindi") or "").lower()
                   or q in (r.get("name_marathi") or "").lower()]
    return {"items": results, "total": len(results)}


@router.post("/catalog/items", status_code=201)
async def admin_create_catalog_item(body: dict, _: TokenVerifyResponse = Depends(_admin)):
    for field in ["name", "category", "unit"]:
        if not body.get(field):
            raise HTTPException(status_code=422, detail=f"Missing required field: {field}")
    item_id = new_id()
    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO catalog_items (id, name, name_hindi, name_marathi, category, unit, image_url, is_active, created_at)
            VALUES ($1,$2,$3,$4,$5,$6,$7,true,$8)
        """, item_id, body["name"],
            body.get("name_hindi", ""), body.get("name_marathi", ""),
            body["category"], body["unit"], body.get("image_url", ""), now_ms())
    return {"item_id": item_id, "status": "created"}


@router.patch("/catalog/items/{item_id}")
async def admin_update_catalog_item(item_id: str, body: dict, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT id FROM catalog_items WHERE id=$1", item_id)
    if not row:
        raise HTTPException(status_code=404, detail="Item not found")
    allowed = {"name", "name_hindi", "name_marathi", "category", "unit", "image_url", "is_active", "price"}
    updates = {k: v for k, v in body.items() if k in allowed}
    if updates:
        fields, vals = [], [item_id]
        for k, v in updates.items():
            vals.append(v)
            fields.append(f"{k}=${len(vals)}")
        vals.append(now_ms())
        fields.append(f"updated_at=${len(vals)}")
        async with pool().acquire() as conn:
            await conn.execute(f"UPDATE catalog_items SET {', '.join(fields)} WHERE id=$1", *vals)
    return {"status": "updated"}


@router.delete("/catalog/items/{item_id}")
async def admin_delete_catalog_item(
    item_id: str,
    permanent: bool = Query(False),
    _: TokenVerifyResponse = Depends(_admin),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT id FROM catalog_items WHERE id=$1", item_id)
    if not row:
        raise HTTPException(status_code=404, detail="Item not found")
    async with pool().acquire() as conn:
        if permanent:
            await conn.execute("DELETE FROM catalog_items WHERE id=$1", item_id)
        else:
            await conn.execute("UPDATE catalog_items SET is_active=false WHERE id=$1", item_id)
    return {"status": "permanently_deleted" if permanent else "deactivated"}


# ── Order Management ───────────────────────────────────────────────────────────

@router.get("/orders")
async def list_orders(
    status: str = Query(None),
    limit: int = Query(50, le=200),
    _: TokenVerifyResponse = Depends(_admin),
):
    if status:
        async with pool().acquire() as conn:
            rows = await conn.fetch(
                "SELECT * FROM orders WHERE status=$1 ORDER BY created_at DESC LIMIT $2",
                status, limit,
            )
    else:
        async with pool().acquire() as conn:
            rows = await conn.fetch(
                "SELECT * FROM orders ORDER BY created_at DESC LIMIT $1", limit
            )
    orders = [dict(r) for r in rows]
    return {"orders": orders, "total": len(orders)}


@router.post("/orders/{order_id}/force-fail")
async def force_fail_order(order_id: str, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM orders WHERE id=$1", order_id)
    if not row:
        raise HTTPException(status_code=404, detail="Order not found")
    order = dict(row)
    if order["status"] in ("delivered", "failed", "cancelled"):
        raise HTTPException(status_code=409, detail="Order already in terminal state")
    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE orders SET status='failed', failure_reason='admin_forced' WHERE id=$1",
            order_id,
        )
    store_id = order.get("accepted_by_store_id")
    if store_id:
        await process_store_failure(store_id, order_id, reason="admin_forced")
    return {"status": "failed"}


# ── Customer Management ────────────────────────────────────────────────────────

@router.get("/customers")
async def list_customers(
    limit: int = Query(50, le=500),
    _: TokenVerifyResponse = Depends(_admin),
):
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM users WHERE role='customer' ORDER BY created_at DESC LIMIT $1", limit
        )
    customers = [dict(r) for r in rows]
    return {"customers": customers, "total": len(customers)}


@router.get("/customers/{uid}")
async def get_customer(uid: str, _: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM users WHERE uid=$1", uid)
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    return dict(row)


@router.get("/customers/{uid}/orders")
async def get_customer_orders(
    uid: str,
    limit: int = Query(50, le=200),
    _: TokenVerifyResponse = Depends(_admin),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT uid FROM users WHERE uid=$1", uid)
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM orders WHERE customer_id=$1 ORDER BY created_at DESC LIMIT $2",
            uid, limit,
        )
    orders = [dict(r) for r in rows]
    total = len(orders)
    delivered = sum(1 for o in orders if o.get("status") == "delivered")
    total_spent = sum(o.get("total_customer_amount", 0) for o in orders if o.get("status") == "delivered")
    return {"orders": orders, "total": total, "delivered": delivered, "total_spent": round(total_spent, 2)}


# ── Analytics ─────────────────────────────────────────────────────────────────

@router.get("/analytics/summary")
async def analytics_summary(_: TokenVerifyResponse = Depends(_admin)):
    async with pool().acquire() as conn:
        total_stores = await conn.fetchval("SELECT COUNT(*) FROM stores")
        active_stores = await conn.fetchval(
            "SELECT COUNT(*) FROM stores WHERE is_active=true AND NOT COALESCE(is_suspended,false)"
        )
        total_orders = await conn.fetchval("SELECT COUNT(*) FROM orders")
        delivered = await conn.fetchval("SELECT COUNT(*) FROM orders WHERE status='delivered'")
        failed = await conn.fetchval("SELECT COUNT(*) FROM orders WHERE status='failed'")
        platform_fee = await conn.fetchval(
            "SELECT COALESCE(SUM(platform_fee_amount),0) FROM orders WHERE status='delivered'"
        )
    success_rate = round(delivered / total_orders * 100, 1) if total_orders else 0
    return {
        "total_stores": total_stores,
        "active_stores": active_stores,
        "total_orders": total_orders,
        "delivered_orders": delivered,
        "failed_orders": failed,
        "success_rate_pct": success_rate,
        "platform_fee_collected": round(float(platform_fee), 2),
    }


# ── Settlement Management ──────────────────────────────────────────────────────

@router.get("/settlements")
async def list_settlements(
    status: str = Query(None),
    _: TokenVerifyResponse = Depends(_admin),
):
    if status:
        async with pool().acquire() as conn:
            rows = await conn.fetch(
                "SELECT * FROM settlements WHERE status=$1 ORDER BY created_at DESC", status
            )
    else:
        async with pool().acquire() as conn:
            rows = await conn.fetch("SELECT * FROM settlements ORDER BY created_at DESC")
    settlements = [dict(r) for r in rows]
    return {"settlements": settlements, "total": len(settlements)}


# ── Broadcast Notifications ────────────────────────────────────────────────────

@router.post("/notifications/broadcast", status_code=200)
async def broadcast_notification(body: dict, _: TokenVerifyResponse = Depends(_admin)):
    target = body.get("target")
    title = (body.get("title") or "").strip()
    message = (body.get("message") or "").strip()
    notif_type = body.get("type", "announcement")

    if not title or not message:
        raise HTTPException(status_code=422, detail="title and message are required")
    valid_targets = ("all_customers", "all_stores", "specific_store", "specific_customer")
    if target not in valid_targets:
        raise HTTPException(status_code=422, detail=f"target must be one of: {valid_targets}")

    tokens: list[str] = []
    user_ids: list[str] = []

    if target == "all_customers":
        async with pool().acquire() as conn:
            rows = await conn.fetch(
                "SELECT uid, fcm_token FROM users WHERE role='customer' AND fcm_token IS NOT NULL"
            )
        for r in rows:
            user_ids.append(r["uid"])
            tokens.append(r["fcm_token"])

    elif target == "all_stores":
        async with pool().acquire() as conn:
            rows = await conn.fetch(
                "SELECT owner_uid, fcm_token FROM stores WHERE fcm_token IS NOT NULL"
            )
        for r in rows:
            if r["owner_uid"]:
                user_ids.append(r["owner_uid"])
            tokens.append(r["fcm_token"])

    elif target == "specific_store":
        store_id = body.get("store_id")
        if not store_id:
            raise HTTPException(status_code=422, detail="store_id required")
        async with pool().acquire() as conn:
            row = await conn.fetchrow("SELECT owner_uid, fcm_token FROM stores WHERE id=$1", store_id)
        if not row:
            raise HTTPException(status_code=404, detail="Store not found")
        if row["owner_uid"]:
            user_ids.append(row["owner_uid"])
        if row["fcm_token"]:
            tokens.append(row["fcm_token"])

    elif target == "specific_customer":
        customer_uid = body.get("customer_uid")
        if not customer_uid:
            raise HTTPException(status_code=422, detail="customer_uid required")
        async with pool().acquire() as conn:
            row = await conn.fetchrow("SELECT uid, fcm_token FROM users WHERE uid=$1", customer_uid)
        if not row:
            raise HTTPException(status_code=404, detail="Customer not found")
        user_ids.append(row["uid"])
        if row["fcm_token"]:
            tokens.append(row["fcm_token"])

    result = send_broadcast_notification(
        tokens=tokens, user_ids=user_ids, title=title,
        body=message, notif_type=notif_type, sender="admin",
    )
    return {"status": "sent", "target": target, "recipients": len(user_ids), **result}


@router.get("/notifications/history")
async def get_notification_history(
    uid: str = Query(None),
    limit: int = Query(50, le=200),
    _: TokenVerifyResponse = Depends(_admin),
):
    if uid:
        async with pool().acquire() as conn:
            rows = await conn.fetch(
                "SELECT * FROM notifications WHERE uid=$1 ORDER BY created_at DESC LIMIT $2",
                uid, limit,
            )
        notifs = [dict(r) for r in rows]
        return {"uid": uid, "notifications": notifs, "total": len(notifs)}

    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM notifications ORDER BY created_at DESC LIMIT $1", limit
        )
    return {"notifications": [dict(r) for r in rows], "total": len(rows)}


# ── Customer-App Home UI (Firebase Remote Config) ──────────────────────────────
# Read / publish the customer app's home top-section (header colours, greeting,
# search hint, promo banners) without opening the Firebase console. The customer
# app picks up changes on its next Remote Config fetch (1h interval).

@router.get("/home-config")
async def get_home_config(_: TokenVerifyResponse = Depends(_admin)):
    try:
        return await remote_config.get_home_config()
    except Exception as e:
        raise HTTPException(
            status_code=502, detail=f"Remote Config read failed: {e}"
        )


@router.put("/home-config")
async def update_home_config(body: dict, _: TokenVerifyResponse = Depends(_admin)):
    # Accept either {"values": {...}} or a bare {...} of keys.
    values = body.get("values", body)
    if not isinstance(values, dict):
        raise HTTPException(status_code=422, detail="Expected a 'values' object")
    filtered = {k: v for k, v in values.items() if k in remote_config.HOME_KEYS}
    if not filtered:
        raise HTTPException(
            status_code=422, detail="No valid home-config keys provided"
        )
    try:
        result = await remote_config.update_home_config(filtered)
    except Exception as e:
        raise HTTPException(
            status_code=502, detail=f"Remote Config publish failed: {e}"
        )
    return {"ok": True, **result}
