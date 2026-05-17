from firebase_admin import db

from config import get_settings
from services.notifications import send_strike_warning, send_store_suspended
from services.geofencing import remove_store_from_geofence_index
from utils.helpers import new_id, now_ms

settings = get_settings()

MS_PER_DAY = 86_400_000


def process_store_failure(store_id: str, order_id: str, reason: str) -> None:
    store_ref = db.reference(f"stores/{store_id}")
    store = store_ref.get()
    if not store:
        return

    strike_count = store.get("strike_count", 0) + 1
    total_strikes = store.get("total_strikes", 0) + 1

    action = "warning"
    updates: dict = {
        "strike_count": strike_count,
        "total_strikes": total_strikes,
    }

    if total_strikes >= settings.max_total_strikes_before_ban:
        action = "permanent_ban"
        updates["is_active"] = False
        updates["is_suspended"] = True
        updates["suspension_end_date"] = None
    elif strike_count >= settings.max_strikes_before_suspend:
        action = "suspended_7_days"
        updates["is_suspended"] = True
        updates["strike_count"] = 0  # reset counter after suspension
        updates["suspension_end_date"] = now_ms() + settings.suspension_days * MS_PER_DAY

    store_ref.update(updates)

    # Write strike log
    strike_id = new_id()
    db.reference(f"strike_logs/{strike_id}").set({
        "strike_id": strike_id,
        "store_id": store_id,
        "order_id": order_id,
        "reason": reason,
        "strike_number": total_strikes,
        "action_taken": action,
        "created_at": now_ms(),
    })

    # Remove from geofence if suspended / banned
    if action in ("suspended_7_days", "permanent_ban"):
        loc = store.get("location", {})
        if loc.get("lat") and loc.get("lng"):
            remove_store_from_geofence_index(store_id, loc["lat"], loc["lng"])

    # Send FCM
    fcm_token = store.get("fcm_token", "")
    if action == "warning":
        send_strike_warning(fcm_token, total_strikes, order_id)
    elif action == "suspended_7_days":
        send_store_suspended(fcm_token, settings.suspension_days)
    elif action == "permanent_ban":
        send_store_suspended(fcm_token, 0)


def lift_expired_suspensions() -> int:
    stores_node = db.reference("stores").get() or {}
    now = now_ms()
    lifted = 0
    for store_id, store in stores_node.items():
        if not store.get("is_suspended"):
            continue
        end_date = store.get("suspension_end_date")
        if end_date and now >= end_date:
            db.reference(f"stores/{store_id}").update({
                "is_suspended": False,
                "suspension_end_date": None,
            })
            lifted += 1
    return lifted


def auto_fail_stuck_orders(max_hours: int) -> int:
    orders_node = db.reference("orders").get() or {}
    now = now_ms()
    cutoff_ms = max_hours * 3_600_000
    failed = 0
    for order_id, order in orders_node.items():
        if order.get("status") not in ("pending", "broadcasting", "accepted", "packed"):
            continue
        created = order.get("created_at", now)
        if now - created > cutoff_ms:
            db.reference(f"orders/{order_id}").update({
                "status": "failed",
                "failure_reason": "auto_failed_timeout",
            })
            store_id = order.get("accepted_by_store_id")
            if store_id:
                process_store_failure(store_id, order_id, reason="auto_failed_timeout")
            failed += 1
    return failed
