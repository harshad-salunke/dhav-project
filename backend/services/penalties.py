"""
Store penalty logic — PostgreSQL edition.

All functions are now async coroutines because they use the asyncpg pool.
Callers in routers must await them. The scheduler uses AsyncIOScheduler
which supports async jobs natively.
"""
import logging

from services.db import pool
from services.geofencing import remove_store_from_geofence_index
from services.notifications import send_strike_warning, send_store_suspended
from config import get_settings
from utils.helpers import new_id, now_ms

settings = get_settings()
MS_PER_DAY = 86_400_000
log = logging.getLogger("penalties")


async def process_store_failure(store_id: str, order_id: str, reason: str) -> None:
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM stores WHERE id = $1", store_id)
    if not row:
        return
    store = dict(row)

    strike_count = store.get("strike_count", 0) + 1
    total_strikes = store.get("total_strikes", 0) + 1
    action = "warning"
    updates: dict = {"strike_count": strike_count, "total_strikes": total_strikes}

    if total_strikes >= settings.max_total_strikes_before_ban:
        action = "permanent_ban"
        updates["is_active"] = False
        updates["is_suspended"] = True
        updates["suspension_end_date"] = None
    elif strike_count >= settings.max_strikes_before_suspend:
        action = "suspended_7_days"
        updates["is_suspended"] = True
        updates["strike_count"] = 0
        updates["suspension_end_date"] = now_ms() + settings.suspension_days * MS_PER_DAY

    # Build dynamic UPDATE
    fields, vals = [], [store_id]
    for k, v in updates.items():
        vals.append(v)
        fields.append(f"{k} = ${len(vals)}")
    async with pool().acquire() as conn:
        await conn.execute(
            f"UPDATE stores SET {', '.join(fields)} WHERE id = $1", *vals
        )

    # Write strike log
    strike_id = new_id()
    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO strike_logs (id, store_id, order_id, reason, strike_number, action_taken, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
        """, strike_id, store_id, order_id, reason, total_strikes, action, now_ms())

    if action in ("suspended_7_days", "permanent_ban"):
        loc = store.get("location") or {}
        if loc.get("lat") and loc.get("lng"):
            remove_store_from_geofence_index(store_id, loc["lat"], loc["lng"])

    fcm_token = store.get("fcm_token", "") or ""
    owner_uid = store.get("owner_uid", "") or ""
    if action == "warning":
        send_strike_warning(fcm_token, total_strikes, order_id, owner_uid=owner_uid or None)
    elif action in ("suspended_7_days", "permanent_ban"):
        days = settings.suspension_days if action == "suspended_7_days" else 0
        send_store_suspended(fcm_token, days, owner_uid=owner_uid or None)


async def lift_expired_suspensions() -> int:
    now = now_ms()
    async with pool().acquire() as conn:
        rows = await conn.fetch("""
            SELECT id FROM stores
            WHERE is_suspended = true
              AND suspension_end_date IS NOT NULL
              AND suspension_end_date <= $1
        """, now)
        if rows:
            ids = [r["id"] for r in rows]
            await conn.execute("""
                UPDATE stores
                SET is_suspended = false, suspension_end_date = NULL
                WHERE id = ANY($1)
            """, ids)
    lifted = len(rows)
    if lifted:
        log.info("lifted %d expired suspensions", lifted)
    return lifted


async def auto_fail_stuck_orders(max_hours: int) -> int:
    now = now_ms()
    cutoff_ms = max_hours * 3_600_000
    async with pool().acquire() as conn:
        rows = await conn.fetch("""
            SELECT id, accepted_by_store_id FROM orders
            WHERE status IN ('pending', 'broadcasting', 'accepted', 'packed')
              AND created_at > 0
              AND ($1 - created_at) > $2
        """, now, cutoff_ms)

        if rows:
            ids = [r["id"] for r in rows]
            await conn.execute("""
                UPDATE orders
                SET status = 'failed', failure_reason = 'auto_failed_timeout'
                WHERE id = ANY($1)
            """, ids)

    for row in rows:
        if row["accepted_by_store_id"]:
            await process_store_failure(
                row["accepted_by_store_id"], row["id"], reason="auto_failed_timeout"
            )

    failed = len(rows)
    if failed:
        log.info("auto-failed %d stuck orders", failed)
    return failed
