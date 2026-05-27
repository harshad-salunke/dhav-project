from fastapi import APIRouter, HTTPException, Depends
from firebase_admin import db

from models.order import (
    PlaceOrderRequest, DirectOrderRequest,
    RejectOrderRequest, AssignDeliveryBoyRequest, ORDER_TRANSITIONS
)
from models.user import TokenVerifyResponse
from dependencies import get_current_user, require_role
from services.broadcasting import start_broadcast, atomic_accept_order, cancel_broadcast
from services.notifications import (
    send_order_accepted_to_customer,
    send_order_out_for_delivery,
    send_order_delivered,
    send_order_taken_to_others,
)
from config import get_settings
from utils.helpers import new_id, now_ms
from services.geo import haversine_km

router = APIRouter()
settings = get_settings()


def _get_order_or_404(order_id: str) -> dict:
    data = db.reference(f"orders/{order_id}").get()
    if not data:
        raise HTTPException(status_code=404, detail="Order not found")
    return data


def _store_id_for_user(uid: str) -> str:
    """Resolve store_id from the user node (stores are keyed by store_id,
    not owner uid)."""
    user_node = db.reference(f"users/{uid}").get() or {}
    store_id = user_node.get("store_id")
    if not store_id:
        raise HTTPException(status_code=404, detail="Store not found for this user")
    return store_id


def _delivery_fee(store_lat: float, store_lng: float,
                  customer_lat: float, customer_lng: float) -> float:
    dist = haversine_km(store_lat, store_lng, customer_lat, customer_lng)
    return round(settings.base_delivery_fee + dist * settings.delivery_fee_per_km, 2)


# ── Place Order ────────────────────────────────────────────────────────────────

@router.post("", status_code=201)
async def place_order(
    body: PlaceOrderRequest,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    total_product = sum(item.total_price for item in body.items)
    platform_fee_amount = round(total_product * settings.platform_fee_percentage / 100, 2)
    order_id = new_id()

    order_data = {
        "order_id": order_id,
        "customer_id": user.uid,
        "customer_address": body.customer_address.model_dump(),
        "items": [i.model_dump() for i in body.items],
        "total_product_amount": total_product,
        "delivery_fee": 0.0,            # recalculated on acceptance
        "total_customer_amount": total_product,
        "platform_fee_percentage": settings.platform_fee_percentage,
        "platform_fee_amount": platform_fee_amount,
        "platform_fee_settled": False,
        "payment_method": "cod",
        "status": "pending",
        "broadcast_wave": 0,
        "broadcast_radius_km": 0.0,
        "broadcast_store_ids": [],
        "rejected_store_ids": [],
        "timed_out_store_ids": [],
        "accepted_by_store_id": None,
        "accepted_at": None,
        "assigned_delivery_boy_id": None,
        "delivery_boy_name": None,
        "delivery_boy_phone": None,
        "ws_channel_id": None,
        "estimated_delivery_minutes": 30,
        "delivered_at": None,
        "failure_reason": None,
        "created_at": now_ms(),
    }
    db.reference(f"orders/{order_id}").set(order_data)

    start_broadcast(
        order_id=order_id,
        customer_lat=body.customer_address.lat,
        customer_lng=body.customer_address.lng,
        item_count=len(body.items),
        total=total_product,
        customer_id=user.uid,
    )
    return {"order_id": order_id, "status": "broadcasting"}


# ── Place Direct Order (specific store) ────────────────────────────────────────

@router.post("/direct", status_code=201)
async def place_direct_order(
    body: DirectOrderRequest,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    """Customer orders directly from a chosen store — no broadcast waves."""
    store_node = db.reference(f"stores/{body.store_id}").get()
    if not store_node:
        raise HTTPException(status_code=404, detail="Store not found")
    if not store_node.get("is_active"):
        raise HTTPException(status_code=400, detail="Store is not currently active")
    if store_node.get("is_suspended"):
        raise HTTPException(status_code=400, detail="Store is suspended")

    total_product = sum(item.total_price for item in body.items)
    platform_fee_amount = round(total_product * settings.platform_fee_percentage / 100, 2)
    order_id = new_id()

    order_data = {
        "order_id": order_id,
        "customer_id": user.uid,
        "customer_address": body.customer_address.model_dump(),
        "items": [i.model_dump() for i in body.items],
        "total_product_amount": total_product,
        "delivery_fee": 0.0,
        "total_customer_amount": total_product,
        "platform_fee_percentage": settings.platform_fee_percentage,
        "platform_fee_amount": platform_fee_amount,
        "platform_fee_settled": False,
        "payment_method": "cod",
        "status": "broadcasting",
        "broadcast_wave": 1,
        "broadcast_radius_km": 0.0,
        "broadcast_store_ids": [body.store_id],
        "rejected_store_ids": [],
        "timed_out_store_ids": [],
        "accepted_by_store_id": None,
        "accepted_at": None,
        "assigned_delivery_boy_id": None,
        "delivery_boy_name": None,
        "delivery_boy_phone": None,
        "ws_channel_id": None,
        "estimated_delivery_minutes": 30,
        "delivered_at": None,
        "failure_reason": None,
        "created_at": now_ms(),
        "is_direct_order": True,
    }
    db.reference(f"orders/{order_id}").set(order_data)

    fcm_token = store_node.get("fcm_token")
    owner_uid = store_node.get("owner_uid", "")
    if fcm_token:
        send_new_order_to_stores(
            [fcm_token], order_id, len(body.items), total_product,
            owner_uids=[owner_uid] if owner_uid else None,
        )

    return {"order_id": order_id, "status": "broadcasting", "store_id": body.store_id}


# ── Get Order ──────────────────────────────────────────────────────────────────

@router.get("/{order_id}")
async def get_order(
    order_id: str,
    user: TokenVerifyResponse = Depends(get_current_user),
):
    order = _get_order_or_404(order_id)
    if user.role == "customer" and order["customer_id"] != user.uid:
        raise HTTPException(status_code=403, detail="Not your order")
    return order


# ── Store: Accept ──────────────────────────────────────────────────────────────

@router.post("/{order_id}/accept")
async def accept_order(
    order_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    order = _get_order_or_404(order_id)
    if order["status"] != "broadcasting":
        raise HTTPException(status_code=409, detail="Order is no longer available")

    store_id = _store_id_for_user(user.uid)
    store_node = db.reference(f"stores/{store_id}").get()
    if not store_node:
        raise HTTPException(status_code=404, detail="Store profile not found")

    won = atomic_accept_order(order_id, store_id)
    if not won:
        raise HTTPException(status_code=409, detail="Order already accepted by another store")

    cancel_broadcast(order_id)

    # Update delivery fee based on store-customer distance
    store_lat = store_node["location"]["lat"]
    store_lng = store_node["location"]["lng"]
    fee = _delivery_fee(store_lat, store_lng,
                        order["customer_address"]["lat"],
                        order["customer_address"]["lng"])
    total = order["total_product_amount"] + fee
    db.reference(f"orders/{order_id}").update({"delivery_fee": fee, "total_customer_amount": total})

    # Notify customer
    customer_token = db.reference(f"users/{order['customer_id']}/fcm_token").get() or ""
    send_order_accepted_to_customer(
        customer_token, order_id, store_node.get("shop_name", "Store"),
        customer_uid=order["customer_id"],
    )

    # Notify other stores that order is taken
    remaining = [sid for sid in order.get("broadcast_store_ids", []) if sid != store_id]
    other_tokens = []
    for sid in remaining:
        t = db.reference(f"stores/{sid}/fcm_token").get()
        if t:
            other_tokens.append(t)
    if other_tokens:
        send_order_taken_to_others(other_tokens, order_id)

    return {"status": "accepted"}


# ── Store: Reject ──────────────────────────────────────────────────────────────

@router.post("/{order_id}/reject")
async def reject_order(
    order_id: str,
    body: RejectOrderRequest,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    order = _get_order_or_404(order_id)
    store_id = _store_id_for_user(user.uid)
    rejected = order.get("rejected_store_ids", [])
    if store_id not in rejected:
        rejected.append(store_id)
    db.reference(f"orders/{order_id}").update({"rejected_store_ids": rejected})
    return {"status": "rejected"}


# ── Store: Assign Delivery Boy ─────────────────────────────────────────────────

@router.post("/{order_id}/assign-delivery-boy")
async def assign_delivery_boy(
    order_id: str,
    body: AssignDeliveryBoyRequest,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    order = _get_order_or_404(order_id)
    store_id = _store_id_for_user(user.uid)
    if order.get("accepted_by_store_id") != store_id:
        raise HTTPException(status_code=403, detail="This order was not accepted by your store")
    if order["status"] != "accepted":
        raise HTTPException(status_code=409, detail="Order must be in 'accepted' state")

    boy_node = db.reference(f"delivery_boys/{body.delivery_boy_id}").get()
    if not boy_node or boy_node.get("store_id") != store_id:
        raise HTTPException(status_code=404, detail="Delivery boy not found in your store")

    db.reference(f"orders/{order_id}").update({
        "assigned_delivery_boy_id": body.delivery_boy_id,
        "delivery_boy_name": boy_node.get("name", ""),
        "delivery_boy_phone": boy_node.get("phone", ""),
    })
    return {"status": "assigned"}


# ── Store: Mark Packed ─────────────────────────────────────────────────────────

@router.post("/{order_id}/packed")
async def mark_packed(
    order_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    order = _get_order_or_404(order_id)
    store_id = _store_id_for_user(user.uid)
    if order.get("accepted_by_store_id") != store_id:
        raise HTTPException(status_code=403, detail="Not your order")
    if order["status"] != "accepted":
        raise HTTPException(status_code=409, detail="Order must be 'accepted' before packing")
    db.reference(f"orders/{order_id}").update({"status": "packed"})
    return {"status": "packed"}


# ── Store: Dispatch (Out for Delivery) ────────────────────────────────────────

@router.post("/{order_id}/dispatched")
async def dispatch_order(
    order_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    order = _get_order_or_404(order_id)
    store_id = _store_id_for_user(user.uid)
    if order.get("accepted_by_store_id") != store_id:
        raise HTTPException(status_code=403, detail="Not your order")
    if order["status"] != "packed":
        raise HTTPException(status_code=409, detail="Order must be 'packed' before dispatch")

    ws_channel_id = f"order_{order_id}_location"
    db.reference(f"orders/{order_id}").update({
        "status": "out_for_delivery",
        "ws_channel_id": ws_channel_id,
    })

    customer_token = db.reference(f"users/{order['customer_id']}/fcm_token").get() or ""
    send_order_out_for_delivery(customer_token, order_id, customer_uid=order["customer_id"])
    return {"status": "out_for_delivery", "ws_channel_id": ws_channel_id}


# ── Store/Delivery: Mark Delivered ────────────────────────────────────────────

@router.post("/{order_id}/delivered")
async def mark_delivered(
    order_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner", "delivery")),
):
    order = _get_order_or_404(order_id)
    if order["status"] != "out_for_delivery":
        raise HTTPException(status_code=409, detail="Order must be 'out_for_delivery'")

    delivered_at = now_ms()
    db.reference(f"orders/{order_id}").update({
        "status": "delivered",
        "delivered_at": delivered_at,
        "ws_channel_id": None,  # close the live location channel
    })

    store_ref = db.reference(f"stores/{order['accepted_by_store_id']}")
    store_ref.update({"total_orders_accepted": (store_ref.get() or {}).get("total_orders_accepted", 0) + 1})

    customer_token = db.reference(f"users/{order['customer_id']}/fcm_token").get() or ""
    send_order_delivered(customer_token, order_id, customer_uid=order["customer_id"])
    return {"status": "delivered"}


# ── Report Failure ─────────────────────────────────────────────────────────────

@router.post("/{order_id}/report-failure")
async def report_failure(
    order_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner", "admin")),
):
    from services.penalties import process_store_failure

    order = _get_order_or_404(order_id)
    if order["status"] in ("delivered", "failed", "cancelled"):
        raise HTTPException(status_code=409, detail="Order already in terminal state")

    store_id = order.get("accepted_by_store_id")
    db.reference(f"orders/{order_id}").update({
        "status": "failed",
        "failure_reason": "store_reported_failure",
    })

    if store_id:
        process_store_failure(store_id, order_id, reason="store_reported_failure")

    return {"status": "failed"}


# ── Customer: My Orders ────────────────────────────────────────────────────────

@router.get("")
async def my_orders(
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    all_orders = db.reference("orders").order_by_child("customer_id").equal_to(user.uid).get() or {}
    orders = sorted(all_orders.values(), key=lambda o: o.get("created_at", 0), reverse=True)
    return orders


@router.get("/customer/me")
async def my_orders_alias(
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    """Alias used by the customer Flutter app."""
    all_orders = db.reference("orders").order_by_child("customer_id").equal_to(user.uid).get() or {}
    orders = sorted(all_orders.values(), key=lambda o: o.get("created_at", 0), reverse=True)
    return orders


# ── Delivery Boy: My Assignments ───────────────────────────────────────────────

@router.get("/delivery/me")
async def my_delivery_assignments(
    user: TokenVerifyResponse = Depends(require_role("delivery")),
):
    all_orders = (
        db.reference("orders")
        .order_by_child("assigned_delivery_boy_id")
        .equal_to(user.uid)
        .get()
        or {}
    )
    orders = sorted(all_orders.values(),
                    key=lambda o: o.get("created_at", 0), reverse=True)
    return {"orders": orders}


# ── Customer: Rate delivered order ────────────────────────────────────────────

@router.post("/{order_id}/review", status_code=201)
async def review_order(
    order_id: str,
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    """Submit a 1–5 star rating (+ optional comment) for a delivered order."""
    rating = body.get("rating")
    if not isinstance(rating, (int, float)) or not (1 <= rating <= 5):
        raise HTTPException(status_code=422, detail="rating must be 1–5")

    order = _get_order_or_404(order_id)
    if order.get("customer_id") != user.uid:
        raise HTTPException(status_code=403, detail="Not your order")
    if order.get("status") != "delivered":
        raise HTTPException(status_code=409, detail="Order not yet delivered")
    if order.get("has_review"):
        raise HTTPException(status_code=409, detail="Order already reviewed")

    store_id = order.get("accepted_by_store_id")
    if not store_id:
        raise HTTPException(status_code=409, detail="No store assigned to this order")

    review_id = new_id()
    review_data = {
        "review_id": review_id,
        "order_id": order_id,
        "store_id": store_id,
        "customer_id": user.uid,
        "rating": int(rating),
        "comment": (body.get("comment") or "").strip()[:500],
        "created_at": now_ms(),
    }
    db.reference(f"reviews/{store_id}/{review_id}").set(review_data)
    db.reference(f"orders/{order_id}").update({"has_review": True})

    # Recalculate store avg rating.
    reviews_node = db.reference(f"reviews/{store_id}").get() or {}
    all_ratings = [r.get("rating", 0) for r in reviews_node.values() if r.get("rating")]
    if all_ratings:
        avg = round(sum(all_ratings) / len(all_ratings), 1)
        db.reference(f"stores/{store_id}").update({"rating": avg})

    return {"review_id": review_id, "avg_rating": avg if all_ratings else rating}
