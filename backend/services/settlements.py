from datetime import date, timedelta
from firebase_admin import db

from utils.helpers import new_id, now_ms


def _week_bounds() -> tuple[str, str]:
    today = date.today()
    monday = today - timedelta(days=today.weekday())
    sunday = monday + timedelta(days=6)
    return monday.isoformat(), sunday.isoformat()


def generate_weekly_settlements() -> int:
    week_start, week_end = _week_bounds()
    stores_node = db.reference("stores").get() or {}
    orders_node = db.reference("orders").get() or {}
    created = 0

    for store_id in stores_node:
        # Skip if settlement already exists for this week
        existing = (
            db.reference("settlements")
            .order_by_child("store_id")
            .equal_to(store_id)
            .get() or {}
        )
        already_exists = any(
            s.get("week_start") == week_start for s in existing.values()
        )
        if already_exists:
            continue

        delivered_orders = [
            o for o in orders_node.values()
            if o.get("accepted_by_store_id") == store_id
            and o.get("status") == "delivered"
            and o.get("delivered_at", 0) >= _week_start_ms(week_start)
        ]

        total_fee_owed = sum(o.get("platform_fee_amount", 0.0) for o in delivered_orders)
        settlement_id = new_id()

        db.reference(f"settlements/{settlement_id}").set({
            "settlement_id": settlement_id,
            "store_id": store_id,
            "week_start": week_start,
            "week_end": week_end,
            "total_orders_delivered": len(delivered_orders),
            "total_platform_fee_owed": round(total_fee_owed, 2),
            "total_fee_paid": 0.0,
            "balance_due": round(total_fee_owed, 2),
            "status": "pending",
            "payment_records": [],
            "is_overdue": False,
            "created_at": now_ms(),
        })
        created += 1

    return created


def mark_overdue_settlements() -> int:
    settlements_node = db.reference("settlements").get() or {}
    marked = 0
    for sid, s in settlements_node.items():
        if s.get("status") == "settled" or s.get("is_overdue"):
            continue
        if s.get("balance_due", 0) > 0:
            week_end_date = date.fromisoformat(s["week_end"])
            if date.today() > week_end_date:
                db.reference(f"settlements/{sid}").update({"is_overdue": True})

                # Hide overdue store from geofence
                from services.geofencing import remove_store_from_geofence_index
                store = db.reference(f"stores/{s['store_id']}").get() or {}
                loc = store.get("location", {})
                if loc.get("lat") and loc.get("lng"):
                    remove_store_from_geofence_index(s["store_id"], loc["lat"], loc["lng"])
                marked += 1
    return marked


def _week_start_ms(week_start: str) -> int:
    from datetime import datetime
    return int(datetime.fromisoformat(week_start).timestamp() * 1000)
