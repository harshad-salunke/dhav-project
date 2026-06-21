from fastapi import APIRouter, HTTPException, Depends

from models.order import (
    PlaceOrderRequest, DirectOrderRequest,
    RejectOrderRequest, AssignDeliveryBoyRequest,
)
from models.user import TokenVerifyResponse
from dependencies import get_current_user, require_role
from services.db import pool
from services.broadcasting import (
    start_broadcast, atomic_accept_order, cancel_broadcast, signal_order_accepted,
)
from services.location_ws import close_order_channel
from services.notifications import (
    send_new_order_to_stores,
    send_order_accepted_to_customer,
    send_order_out_for_delivery,
    send_order_delivered,
    send_order_taken_to_others,
)
from services.penalties import process_store_failure
from config import get_settings
from utils.helpers import new_id, now_ms
from services.geo import haversine_km

router = APIRouter()
settings = get_settings()


async def _get_order_or_404(order_id: str) -> dict:
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM orders WHERE id = $1", order_id)
    if not row:
        raise HTTPException(status_code=404, detail="Order not found")
    return dict(row)


async def _store_id_for_user(uid: str) -> str:
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT store_id FROM users WHERE uid = $1", uid)
    if not row or not row["store_id"]:
        raise HTTPException(status_code=404, detail="Store not found for this user")
    return row["store_id"]


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
    handling = max(0.0, body.handling_charge)
    donation = max(0.0, body.donation_amount)
    total_customer = total_product + handling + donation
    platform_fee_amount = round(total_product * settings.platform_fee_percentage / 100, 2)
    order_id = new_id()
    ts = now_ms()

    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO orders (
                id, order_id, customer_id, customer_address, items,
                total_product_amount, delivery_fee, total_customer_amount,
                platform_fee_percentage, platform_fee_amount, platform_fee_settled,
                payment_method, status, broadcast_wave, broadcast_radius_km,
                broadcast_store_ids, rejected_store_ids, timed_out_store_ids,
                is_direct_order, estimated_delivery_minutes, marketplace_type,
                gstin, donation_amount, handling_charge, delivery_instructions, created_at
            ) VALUES (
                $1,$1,$2,$3::jsonb,$4::jsonb,
                $5,0,$6,
                $7,$8,false,
                'cod','pending',0,0,
                '[]'::jsonb,'[]'::jsonb,'[]'::jsonb,
                false,30,$9,
                $10,$11,$12,$13::jsonb,$14
            )
        """, order_id, user.uid,
            body.customer_address.model_dump(),
            [i.model_dump() for i in body.items],
            total_product, total_customer,
            settings.platform_fee_percentage, platform_fee_amount,
            body.marketplace_type,
            body.gstin, donation, handling, body.delivery_instructions, ts)

    start_broadcast(
        order_id=order_id,
        customer_lat=body.customer_address.lat,
        customer_lng=body.customer_address.lng,
        item_count=len(body.items),
        total=total_product,
        customer_id=user.uid,
        marketplace_type=body.marketplace_type,
    )
    return {"order_id": order_id, "status": "broadcasting"}


# ── Place Direct Order ─────────────────────────────────────────────────────────

@router.post("/direct", status_code=201)
async def place_direct_order(
    body: DirectOrderRequest,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    async with pool().acquire() as conn:
        store_row = await conn.fetchrow("SELECT * FROM stores WHERE id = $1", body.store_id)
    if not store_row:
        raise HTTPException(status_code=404, detail="Store not found")
    store = dict(store_row)
    if not store.get("is_active"):
        raise HTTPException(status_code=400, detail="Store is not currently active")
    if store.get("is_suspended"):
        raise HTTPException(status_code=400, detail="Store is suspended")

    total_product = sum(item.total_price for item in body.items)
    handling = max(0.0, body.handling_charge)
    donation = max(0.0, body.donation_amount)
    total_customer = total_product + handling + donation
    platform_fee_amount = round(total_product * settings.platform_fee_percentage / 100, 2)
    order_id = new_id()

    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO orders (
                id, order_id, customer_id, accepted_by_store_id, customer_address, items,
                total_product_amount, delivery_fee, total_customer_amount,
                platform_fee_percentage, platform_fee_amount, platform_fee_settled,
                payment_method, status, broadcast_wave, broadcast_radius_km,
                broadcast_store_ids, rejected_store_ids, timed_out_store_ids,
                is_direct_order, estimated_delivery_minutes,
                gstin, donation_amount, handling_charge, delivery_instructions, created_at
            ) VALUES (
                $1,$1,$2,$3,$4::jsonb,$5::jsonb,
                $6,0,$7,
                $8,$9,false,
                'cod','broadcasting',1,0,
                $10::jsonb,'[]'::jsonb,'[]'::jsonb,
                true,30,
                $11,$12,$13,$14::jsonb,$15
            )
        """, order_id, user.uid, body.store_id,
            body.customer_address.model_dump(),
            [i.model_dump() for i in body.items],
            total_product, total_customer,
            settings.platform_fee_percentage, platform_fee_amount,
            [body.store_id],
            body.gstin, donation, handling, body.delivery_instructions,
            now_ms())

    fcm_token = store.get("fcm_token")
    owner_uid = store.get("owner_uid", "")
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
    order = await _get_order_or_404(order_id)
    if user.role == "customer" and order["customer_id"] != user.uid:
        raise HTTPException(status_code=403, detail="Not your order")
    return order


# ── Store: Accept ──────────────────────────────────────────────────────────────

@router.post("/{order_id}/accept")
async def accept_order(
    order_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    order = await _get_order_or_404(order_id)
    if order["status"] != "broadcasting":
        raise HTTPException(status_code=409, detail="Order is no longer available")

    store_id = await _store_id_for_user(user.uid)
    async with pool().acquire() as conn:
        store_row = await conn.fetchrow("SELECT * FROM stores WHERE id = $1", store_id)
    if not store_row:
        raise HTTPException(status_code=404, detail="Store profile not found")
    store = dict(store_row)

    won = await atomic_accept_order(order_id, store_id)
    if not won:
        raise HTTPException(status_code=409, detail="Order already accepted by another store")

    cancel_broadcast(order_id)
    await signal_order_accepted(order_id)

    loc = store.get("location") or {}
    fee = _delivery_fee(
        loc.get("lat", 0), loc.get("lng", 0),
        order["customer_address"]["lat"], order["customer_address"]["lng"],
    )
    total = (order["total_product_amount"] or 0) + fee
    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE orders SET delivery_fee=$2, total_customer_amount=$3 WHERE id=$1",
            order_id, fee, total,
        )

    async with pool().acquire() as conn:
        cust_row = await conn.fetchrow("SELECT fcm_token FROM users WHERE uid=$1", order["customer_id"])
    customer_token = (cust_row["fcm_token"] if cust_row else "") or ""
    send_order_accepted_to_customer(
        customer_token, order_id,
        store.get("shop_name") or store.get("name", "Store"),
        customer_uid=order["customer_id"],
    )

    remaining = [sid for sid in (order.get("broadcast_store_ids") or []) if sid != store_id]
    if remaining:
        async with pool().acquire() as conn:
            rows = await conn.fetch(
                "SELECT fcm_token FROM stores WHERE id = ANY($1) AND fcm_token IS NOT NULL",
                remaining,
            )
        other_tokens = [r["fcm_token"] for r in rows]
        if other_tokens:
            send_order_taken_to_others(other_tokens, order_id)

    return {"status": "accepted"}


# ── Store: Reject ──────────────────────────────────────────────────────────────

@router.post("/{order_id}/reject")
async def reject_order(
    order_id: str,
    _body: RejectOrderRequest,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    order = await _get_order_or_404(order_id)
    store_id = await _store_id_for_user(user.uid)
    rejected = list(order.get("rejected_store_ids") or [])
    if store_id not in rejected:
        rejected.append(store_id)
    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE orders SET rejected_store_ids=$2::jsonb WHERE id=$1",
            order_id, rejected,
        )
    return {"status": "rejected"}


# ── Store: Assign Delivery Boy ─────────────────────────────────────────────────

@router.post("/{order_id}/assign-delivery-boy")
async def assign_delivery_boy(
    order_id: str,
    body: AssignDeliveryBoyRequest,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    order = await _get_order_or_404(order_id)
    store_id = await _store_id_for_user(user.uid)
    if order.get("accepted_by_store_id") != store_id:
        raise HTTPException(status_code=403, detail="This order was not accepted by your store")
    if order["status"] != "accepted":
        raise HTTPException(status_code=409, detail="Order must be in 'accepted' state")

    async with pool().acquire() as conn:
        boy_row = await conn.fetchrow(
            "SELECT * FROM delivery_boys WHERE id=$1 AND store_id=$2",
            body.delivery_boy_id, store_id,
        )
    if not boy_row:
        raise HTTPException(status_code=404, detail="Delivery boy not found in your store")
    boy = dict(boy_row)

    async with pool().acquire() as conn:
        await conn.execute("""
            UPDATE orders SET
                assigned_delivery_boy_id=$2,
                delivery_boy_name=$3,
                delivery_boy_phone=$4
            WHERE id=$1
        """, order_id, body.delivery_boy_id, boy.get("name", ""), boy.get("phone", ""))
    return {"status": "assigned"}


# ── Store: Mark Packed ─────────────────────────────────────────────────────────

@router.post("/{order_id}/packed")
async def mark_packed(
    order_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    order = await _get_order_or_404(order_id)
    store_id = await _store_id_for_user(user.uid)
    if order.get("accepted_by_store_id") != store_id:
        raise HTTPException(status_code=403, detail="Not your order")
    if order["status"] != "accepted":
        raise HTTPException(status_code=409, detail="Order must be 'accepted' before packing")
    async with pool().acquire() as conn:
        await conn.execute("UPDATE orders SET status='packed' WHERE id=$1", order_id)
    return {"status": "packed"}


# ── Store: Dispatch ────────────────────────────────────────────────────────────

@router.post("/{order_id}/dispatched")
async def dispatch_order(
    order_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner")),
):
    order = await _get_order_or_404(order_id)
    store_id = await _store_id_for_user(user.uid)
    if order.get("accepted_by_store_id") != store_id:
        raise HTTPException(status_code=403, detail="Not your order")
    if order["status"] != "packed":
        raise HTTPException(status_code=409, detail="Order must be 'packed' before dispatch")

    ws_channel_id = f"order_{order_id}_location"

    # Self-delivery: the OWNER rides this order and shares live GPS (no delivery
    # partner). Stamp the deliverer fields with the store so (a) the live-location
    # WebSocket authorizes the owner's uid as the rider (`assigned_delivery_boy_id`)
    # and (b) the customer's tracking card shows the shop as the deliverer.
    async with pool().acquire() as conn:
        store_row = await conn.fetchrow(
            "SELECT self_delivery, owner_uid, shop_name, name, phone FROM stores WHERE id=$1",
            store_id,
        )
    store = dict(store_row) if store_row else {}
    self_delivery = bool(store.get("self_delivery")) and not order.get("assigned_delivery_boy_id")

    async with pool().acquire() as conn:
        if self_delivery:
            await conn.execute("""
                UPDATE orders SET
                    status='out_for_delivery', ws_channel_id=$2,
                    assigned_delivery_boy_id=$3, delivery_boy_name=$4, delivery_boy_phone=$5
                WHERE id=$1
            """, order_id, ws_channel_id,
                store.get("owner_uid"),
                store.get("shop_name") or store.get("name") or "Store",
                store.get("phone") or "")
        else:
            await conn.execute(
                "UPDATE orders SET status='out_for_delivery', ws_channel_id=$2 WHERE id=$1",
                order_id, ws_channel_id,
            )

    async with pool().acquire() as conn:
        cust_row = await conn.fetchrow("SELECT fcm_token FROM users WHERE uid=$1", order["customer_id"])
    customer_token = (cust_row["fcm_token"] if cust_row else "") or ""
    send_order_out_for_delivery(customer_token, order_id, customer_uid=order["customer_id"])
    return {"status": "out_for_delivery", "ws_channel_id": ws_channel_id}


# ── Mark Delivered ─────────────────────────────────────────────────────────────

@router.post("/{order_id}/delivered")
async def mark_delivered(
    order_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner", "delivery")),
):
    order = await _get_order_or_404(order_id)
    if order["status"] != "out_for_delivery":
        raise HTTPException(status_code=409, detail="Order must be 'out_for_delivery'")

    delivered_at = now_ms()
    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE orders SET status='delivered', delivered_at=$2, ws_channel_id=NULL WHERE id=$1",
            order_id, delivered_at,
        )

    await close_order_channel(order_id)

    store_id = order.get("accepted_by_store_id")
    if store_id:
        async with pool().acquire() as conn:
            await conn.execute(
                "UPDATE stores SET total_orders_accepted = total_orders_accepted + 1 WHERE id=$1",
                store_id,
            )

    async with pool().acquire() as conn:
        cust_row = await conn.fetchrow("SELECT fcm_token FROM users WHERE uid=$1", order["customer_id"])
    customer_token = (cust_row["fcm_token"] if cust_row else "") or ""
    send_order_delivered(customer_token, order_id, customer_uid=order["customer_id"])
    return {"status": "delivered"}


# ── Report Failure ─────────────────────────────────────────────────────────────

@router.post("/{order_id}/report-failure")
async def report_failure(
    order_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner", "admin")),
):
    order = await _get_order_or_404(order_id)
    if order["status"] in ("delivered", "failed", "cancelled"):
        raise HTTPException(status_code=409, detail="Order already in terminal state")

    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE orders SET status='failed', failure_reason='store_reported_failure' WHERE id=$1",
            order_id,
        )
    await close_order_channel(order_id)

    store_id = order.get("accepted_by_store_id")
    if store_id:
        await process_store_failure(store_id, order_id, reason="store_reported_failure")
    return {"status": "failed"}


# ── Customer: My Orders ────────────────────────────────────────────────────────

@router.get("")
async def my_orders(user: TokenVerifyResponse = Depends(require_role("customer"))):
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM orders WHERE customer_id=$1 ORDER BY created_at DESC",
            user.uid,
        )
    return [dict(r) for r in rows]


@router.get("/customer/me")
async def my_orders_alias(user: TokenVerifyResponse = Depends(require_role("customer"))):
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM orders WHERE customer_id=$1 ORDER BY created_at DESC",
            user.uid,
        )
    return [dict(r) for r in rows]


# ── Delivery: My Assignments ───────────────────────────────────────────────────

@router.get("/delivery/me")
async def my_delivery_assignments(user: TokenVerifyResponse = Depends(require_role("delivery"))):
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM orders WHERE assigned_delivery_boy_id=$1 ORDER BY created_at DESC",
            user.uid,
        )
    return {"orders": [dict(r) for r in rows]}


# ── Customer: Rate Order ───────────────────────────────────────────────────────

@router.post("/{order_id}/review", status_code=201)
async def review_order(
    order_id: str,
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    rating = body.get("rating")
    if not isinstance(rating, (int, float)) or not (1 <= rating <= 5):
        raise HTTPException(status_code=422, detail="rating must be 1–5")

    order = await _get_order_or_404(order_id)
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
    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO reviews (id, order_id, store_id, customer_id, rating, comment, created_at)
            VALUES ($1,$2,$3,$4,$5,$6,$7)
        """, review_id, order_id, store_id, user.uid, int(rating),
            (body.get("comment") or "").strip()[:500], now_ms())

        await conn.execute("UPDATE orders SET has_review=true WHERE id=$1", order_id)

        rows = await conn.fetch(
            "SELECT rating FROM reviews WHERE store_id=$1 AND rating IS NOT NULL",
            store_id,
        )

    all_ratings = [r["rating"] for r in rows]
    avg = round(sum(all_ratings) / len(all_ratings), 1) if all_ratings else rating
    async with pool().acquire() as conn:
        await conn.execute("UPDATE stores SET rating=$2 WHERE id=$1", store_id, avg)

    return {"review_id": review_id, "avg_rating": avg}
