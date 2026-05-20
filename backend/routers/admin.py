from fastapi import APIRouter, HTTPException, Depends, Query
from firebase_admin import db, auth as firebase_auth

from models.user import TokenVerifyResponse
from dependencies import require_role
from services.geofencing import index_store_geofence, remove_store_from_geofence_index
from services.penalties import process_store_failure
from utils.helpers import now_ms, new_id

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


@router.post("/stores/onboard", status_code=201)
async def onboard_store(
    body: dict,
    _: TokenVerifyResponse = Depends(_admin),
):
    """
    Admin creates a new store and its owner account.
    Body: { name, area, owner_name, phone, email, password, lat, lng, address }
    Creates Firebase Auth user + store document + user document.
    """
    required = ["name", "area", "owner_name", "phone", "email", "password", "lat", "lng"]
    for field in required:
        if not body.get(field):
            raise HTTPException(status_code=422, detail=f"Missing required field: {field}")

    email = body["email"]
    password = body["password"]
    owner_name = body["owner_name"]

    # Create Firebase Auth user for store owner
    try:
        user_record = firebase_auth.create_user(
            email=email,
            password=password,
            display_name=owner_name,
        )
        owner_uid = user_record.uid
    except firebase_auth.EmailAlreadyExistsError:
        raise HTTPException(status_code=409, detail="Email already registered")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create user: {str(e)}")

    store_id = new_id()
    lat = float(body["lat"])
    lng = float(body["lng"])
    ts = now_ms()

    # Create store document
    store_data = {
        "store_id": store_id,
        "owner_uid": owner_uid,
        "name": body["name"],
        "area": body["area"],
        "owner_name": owner_name,
        "phone": body["phone"],
        "email": email,
        "address": body.get("address", ""),
        "location": {"lat": lat, "lng": lng},
        "is_active": False,
        "is_verified": False,
        "is_suspended": False,
        "strike_count": 0,
        "suspension_end_date": None,
        "created_at": ts,
        "available_item_ids": [],
        "inventory": {},
        "operating_hours": body.get("operating_hours", {}),
        "delivery_boys": {},
        "custom_items": {},
    }
    db.reference(f"stores/{store_id}").set(store_data)

    # Create user document with store_owner role
    user_data = {
        "uid": owner_uid,
        "email": email,
        "name": owner_name,
        "role": "store_owner",
        "store_id": store_id,
        "is_active": True,
        "created_at": ts,
    }
    db.reference(f"users/{owner_uid}").set(user_data)

    # Index in geofence (not verified yet, so won't receive orders until verified)
    index_store_geofence(store_id, lat, lng, is_verified=False)

    return {
        "store_id": store_id,
        "owner_uid": owner_uid,
        "email": email,
        "message": "Store onboarded. Owner can now log in with the provided credentials.",
    }


@router.put("/stores/{store_id}")
async def update_store(
    store_id: str,
    body: dict,
    _: TokenVerifyResponse = Depends(_admin),
):
    """Admin can update any store field: name, area, phone, location, etc."""
    ref = db.reference(f"stores/{store_id}")
    store = ref.get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")

    # If location changed, re-index geofence
    new_lat = body.get("lat")
    new_lng = body.get("lng")
    if new_lat is not None and new_lng is not None:
        body["location"] = {"lat": float(new_lat), "lng": float(new_lng)}
        body.pop("lat", None)
        body.pop("lng", None)
        old_loc = store.get("location", {})
        if old_loc.get("lat") and old_loc.get("lng"):
            remove_store_from_geofence_index(store_id, old_loc["lat"], old_loc["lng"])
        index_store_geofence(
            store_id,
            float(new_lat), float(new_lng),
            is_active=store.get("is_active", False),
            is_verified=store.get("is_verified", False),
        )

    body["updated_at"] = now_ms()
    ref.update(body)
    return {"status": "updated"}


@router.delete("/stores/{store_id}")
async def delete_store(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    """Soft-delete: deactivates and removes from geofence."""
    ref = db.reference(f"stores/{store_id}")
    store = ref.get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    ref.update({"is_active": False, "is_suspended": True, "deleted_at": now_ms()})
    loc = store.get("location", {})
    if loc.get("lat") and loc.get("lng"):
        remove_store_from_geofence_index(store_id, loc["lat"], loc["lng"])
    return {"status": "deleted"}


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


# ── Store Inventory Management ─────────────────────────────────────────────────

@router.get("/stores/{store_id}/inventory")
async def get_store_inventory(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    """Returns all catalog items with this store's availability and quantity."""
    store = db.reference(f"stores/{store_id}").get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")

    catalog_node = db.reference("catalog").get() or {}
    store_inventory = store.get("inventory", {})  # {item_id: {qty, is_available}}
    available_ids = set(store.get("available_item_ids", []))

    items = []
    for item_id, item_data in catalog_node.items():
        if not item_data.get("is_active", True):
            continue
        inv_entry = store_inventory.get(item_id, {})
        items.append({
            **item_data,
            "item_id": item_id,
            "is_available": item_id in available_ids,
            "quantity": inv_entry.get("quantity", 0),
        })

    return {"items": items, "total": len(items)}


@router.put("/stores/{store_id}/inventory")
async def update_store_inventory(
    store_id: str,
    body: dict,
    _: TokenVerifyResponse = Depends(_admin),
):
    """
    Update inventory for a store.
    Body: { items: [{ item_id, is_available, quantity }] }
    """
    ref = db.reference(f"stores/{store_id}")
    store = ref.get()
    if not store:
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

    ref.update({
        "inventory": inventory_update,
        "available_item_ids": available_ids,
        "updated_at": now_ms(),
    })
    return {"status": "updated", "items_updated": len(items)}


# ── Store Reviews ──────────────────────────────────────────────────────────────

@router.get("/stores/{store_id}/reviews")
async def get_store_reviews(
    store_id: str,
    limit: int = Query(50, le=200),
    _: TokenVerifyResponse = Depends(_admin),
):
    store = db.reference(f"stores/{store_id}").get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")

    reviews_node = db.reference(f"reviews/{store_id}").get() or {}
    reviews = list(reviews_node.values())
    reviews.sort(key=lambda r: r.get("created_at", 0), reverse=True)

    total = len(reviews)
    avg_rating = (
        round(sum(r.get("rating", 0) for r in reviews) / total, 1)
        if total else 0
    )
    return {"reviews": reviews[:limit], "total": total, "avg_rating": avg_rating}


@router.delete("/stores/{store_id}/reviews/{review_id}")
async def delete_review(
    store_id: str,
    review_id: str,
    _: TokenVerifyResponse = Depends(_admin),
):
    ref = db.reference(f"reviews/{store_id}/{review_id}")
    if not ref.get():
        raise HTTPException(status_code=404, detail="Review not found")
    ref.delete()
    return {"status": "deleted"}


# ── Store Stats ────────────────────────────────────────────────────────────────

@router.get("/stores/{store_id}/stats")
async def get_store_stats(store_id: str, _: TokenVerifyResponse = Depends(_admin)):
    """Per-store order breakdown: total, delivered, failed, pending, revenue."""
    store = db.reference(f"stores/{store_id}").get()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")

    orders_node = db.reference("orders").get() or {}
    store_orders = [
        o for o in orders_node.values()
        if o.get("accepted_by_store_id") == store_id
        or o.get("store_id") == store_id
    ]

    total = len(store_orders)
    delivered = sum(1 for o in store_orders if o.get("status") == "delivered")
    failed = sum(1 for o in store_orders if o.get("status") == "failed")
    pending = sum(1 for o in store_orders if o.get("status") not in ("delivered", "failed", "cancelled"))
    revenue = sum(o.get("total_amount", 0) for o in store_orders if o.get("status") == "delivered")
    platform_fee = sum(o.get("platform_fee_amount", 0) for o in store_orders if o.get("status") == "delivered")

    # Recent orders sorted newest first
    store_orders.sort(key=lambda o: o.get("created_at", 0), reverse=True)

    return {
        "store_id": store_id,
        "store_name": store.get("name", ""),
        "total_orders": total,
        "delivered_orders": delivered,
        "failed_orders": failed,
        "pending_orders": pending,
        "success_rate_pct": round(delivered / total * 100, 1) if total else 0,
        "total_revenue": round(revenue, 2),
        "platform_fee_collected": round(platform_fee, 2),
        "recent_orders": store_orders[:20],
    }


# ── Catalog Management (Admin) ─────────────────────────────────────────────────

@router.get("/catalog/items")
async def admin_list_catalog(
    include_inactive: bool = Query(False),
    category: str = Query(None),
    search: str = Query(None),
    _: TokenVerifyResponse = Depends(_admin),
):
    """Returns all catalog items (including inactive) for admin management."""
    items_node = db.reference("catalog").get() or {}
    results = []
    for item_id, data in items_node.items():
        if not include_inactive and not data.get("is_active", True):
            continue
        if category and data.get("category") != category:
            continue
        if search:
            q = search.lower()
            if (q not in data.get("name", "").lower()
                    and q not in data.get("name_hindi", "").lower()
                    and q not in data.get("name_marathi", "").lower()):
                continue
        results.append({**data, "item_id": item_id})
    results.sort(key=lambda x: x.get("category", "") + x.get("name", ""))
    return {"items": results, "total": len(results)}


@router.post("/catalog/items", status_code=201)
async def admin_create_catalog_item(
    body: dict,
    _: TokenVerifyResponse = Depends(_admin),
):
    required = ["name", "category", "unit"]
    for field in required:
        if not body.get(field):
            raise HTTPException(status_code=422, detail=f"Missing required field: {field}")

    item_id = new_id()
    item_data = {
        "item_id": item_id,
        "name": body["name"],
        "name_hindi": body.get("name_hindi", ""),
        "name_marathi": body.get("name_marathi", ""),
        "category": body["category"],
        "unit": body["unit"],
        "image_url": body.get("image_url", ""),
        "is_active": True,
        "created_at": now_ms(),
    }
    db.reference(f"catalog/{item_id}").set(item_data)
    return {"item_id": item_id, "status": "created"}


@router.patch("/catalog/items/{item_id}")
async def admin_update_catalog_item(
    item_id: str,
    body: dict,
    _: TokenVerifyResponse = Depends(_admin),
):
    ref = db.reference(f"catalog/{item_id}")
    if not ref.get():
        raise HTTPException(status_code=404, detail="Item not found")
    body["updated_at"] = now_ms()
    ref.update(body)
    return {"status": "updated"}


@router.delete("/catalog/items/{item_id}")
async def admin_delete_catalog_item(
    item_id: str,
    permanent: bool = Query(False),
    _: TokenVerifyResponse = Depends(_admin),
):
    ref = db.reference(f"catalog/{item_id}")
    if not ref.get():
        raise HTTPException(status_code=404, detail="Item not found")
    if permanent:
        ref.delete()
        return {"status": "permanently_deleted"}
    else:
        ref.update({"is_active": False})
        return {"status": "deactivated"}


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
