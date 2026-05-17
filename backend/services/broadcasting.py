import asyncio
from firebase_admin import db

from services.geofencing import find_nearby_stores
from services.notifications import (
    send_new_order_to_stores,
    send_order_taken_to_others,
    send_order_failed_to_customer,
)
from config import get_settings
from utils.helpers import now_ms

settings = get_settings()

WAVES = [
    (settings.broadcast_wave1_radius_km, settings.broadcast_wave1_timeout_seconds),
    (settings.broadcast_wave2_radius_km, settings.broadcast_wave2_timeout_seconds),
    (settings.broadcast_wave3_radius_km, settings.broadcast_wave3_timeout_seconds),
]

# Tracks active broadcast tasks: order_id → asyncio.Task
_active_broadcasts: dict[str, asyncio.Task] = {}


def _get_store_fcm_tokens(store_ids: list[str]) -> dict[str, str]:
    tokens: dict[str, str] = {}
    for sid in store_ids:
        node = db.reference(f"stores/{sid}/fcm_token").get()
        if node:
            tokens[sid] = node
    return tokens


def _get_customer_fcm_token(customer_id: str) -> str:
    return db.reference(f"users/{customer_id}/fcm_token").get() or ""


async def _run_broadcast(order_id: str, customer_lat: float, customer_lng: float,
                          item_count: int, total: float, customer_id: str) -> None:
    order_ref = db.reference(f"orders/{order_id}")

    for wave_num, (radius_km, timeout_sec) in enumerate(WAVES, start=1):
        current = order_ref.get()
        if not current or current.get("status") not in ("pending", "broadcasting"):
            return  # Already accepted or cancelled

        nearby = find_nearby_stores(customer_lat, customer_lng, radius_km)
        already_notified: set = set(current.get("broadcast_store_ids", []))
        new_stores = [s for s in nearby if s["store_id"] not in already_notified
                      and not s.get("is_suspended")]

        store_ids = [s["store_id"] for s in new_stores]
        all_store_ids = list(already_notified) + store_ids
        tokens_map = _get_store_fcm_tokens(store_ids)
        tokens = list(tokens_map.values())

        order_ref.update({
            "status": "broadcasting",
            "broadcast_wave": wave_num,
            "broadcast_radius_km": radius_km,
            "broadcast_store_ids": all_store_ids,
            "broadcast_started_at": now_ms(),
        })

        if tokens:
            send_new_order_to_stores(tokens, order_id, item_count, total)

        # Wait for store acceptance or timeout
        deadline = asyncio.get_event_loop().time() + timeout_sec
        while asyncio.get_event_loop().time() < deadline:
            await asyncio.sleep(2)
            fresh = order_ref.get()
            if fresh and fresh.get("status") == "accepted":
                return

    # All 3 waves exhausted — mark failed
    order_ref.update({"status": "failed", "failure_reason": "no_stores_available"})
    customer_token = _get_customer_fcm_token(customer_id)
    send_order_failed_to_customer(customer_token, order_id)


def start_broadcast(order_id: str, customer_lat: float, customer_lng: float,
                     item_count: int, total: float, customer_id: str) -> None:
    loop = asyncio.get_event_loop()
    task = loop.create_task(
        _run_broadcast(order_id, customer_lat, customer_lng, item_count, total, customer_id)
    )
    _active_broadcasts[order_id] = task
    task.add_done_callback(lambda _: _active_broadcasts.pop(order_id, None))


def atomic_accept_order(order_id: str, store_id: str) -> bool:
    """
    Firebase transaction: only the first store wins.
    Returns True if this store won, False if another store already accepted.
    """
    order_ref = db.reference(f"orders/{order_id}")

    def _txn(current_data):
        if current_data is None:
            return None
        if current_data.get("status") != "broadcasting":
            raise db.AbortTransaction("order_not_broadcasting")
        current_data["status"] = "accepted"
        current_data["accepted_by_store_id"] = store_id
        current_data["accepted_at"] = now_ms()
        return current_data

    try:
        result = order_ref.transaction(_txn)
        return result is not None and result.get("accepted_by_store_id") == store_id
    except Exception:
        return False


def cancel_broadcast(order_id: str) -> None:
    task = _active_broadcasts.pop(order_id, None)
    if task:
        task.cancel()
