"""
Weekly settlement generation — PostgreSQL edition.

How it works (rewritten 2026-07-04 — the old version summed orders delivered
since *the current* Monday, so the Monday-08:00 cron always produced ₹0 rows,
and its per-week idempotency guard then locked those ₹0 rows in forever):

  • Every delivered order carries `platform_fee_amount` (flat ₹, set at
    placement) and starts with `settlement_id = NULL` (= not yet swept).
  • The weekly sweep (Mon 08:00 IST) picks, per store, ALL unsettled delivered
    orders that were delivered BEFORE this week's Monday 00:00 IST — i.e. the
    just-finished week plus any stragglers older sweeps missed — creates ONE
    settlement row for them, and stamps those orders with the settlement id.
  • Tagging makes the sweep idempotent (re-runs find nothing unsettled), gives
    per-order lineage for the breakdown endpoints, and never creates empty
    ₹0 settlements (stores with no unsettled orders are skipped).
"""
import logging
from datetime import datetime, timedelta, timezone

from services.db import pool
from utils.helpers import new_id, now_ms

log = logging.getLogger("settlements")

IST = timezone(timedelta(hours=5, minutes=30))

# A settlement is payable during the week after its period; overdue after that.
OVERDUE_GRACE_DAYS = 7


def _sweep_bounds() -> tuple[str, str, int]:
    """Returns (week_start_iso, week_end_iso, cutoff_ms) for the week being
    settled = the week that just ENDED (previous Mon..Sun, IST). cutoff_ms is
    this week's Monday 00:00 IST — orders delivered before it get swept."""
    now_ist = datetime.now(IST)
    this_monday = (now_ist - timedelta(days=now_ist.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0)
    prev_monday = this_monday - timedelta(days=7)
    prev_sunday = this_monday - timedelta(days=1)
    return (prev_monday.date().isoformat(), prev_sunday.date().isoformat(),
            int(this_monday.timestamp() * 1000))


async def generate_weekly_settlements() -> int:
    week_start, week_end, cutoff_ms = _sweep_bounds()

    async with pool().acquire() as conn:
        store_rows = await conn.fetch("SELECT id FROM stores WHERE is_active = true")

    created = 0
    for store_row in store_rows:
        store_id = store_row["id"]

        async with pool().acquire() as conn:
            order_rows = await conn.fetch("""
                SELECT id, platform_fee_amount FROM orders
                WHERE accepted_by_store_id = $1
                  AND status = 'delivered'
                  AND settlement_id IS NULL
                  AND delivered_at > 0
                  AND delivered_at < $2
            """, store_id, cutoff_ms)

        if not order_rows:
            continue  # nothing to settle — no empty ₹0 rows

        total_fee_owed = round(sum(r["platform_fee_amount"] or 0.0 for r in order_rows), 2)
        order_ids = [r["id"] for r in order_rows]
        settlement_id = new_id()

        async with pool().acquire() as conn:
            async with conn.transaction():
                await conn.execute("""
                    INSERT INTO settlements (
                        id, store_id, week_start, week_end,
                        total_orders_delivered, total_platform_fee_owed,
                        total_fee_paid, balance_due, status,
                        is_overdue, payment_records, created_at
                    ) VALUES ($1,$2,$3,$4,$5,$6,0,$7,'pending',false,'[]',$8)
                """, settlement_id, store_id, week_start, week_end,
                    len(order_rows), total_fee_owed, total_fee_owed, now_ms())
                await conn.execute(
                    "UPDATE orders SET settlement_id = $1 WHERE id = ANY($2)",
                    settlement_id, order_ids)
        created += 1

    log.info("generated %d settlements for week %s..%s", created, week_start, week_end)
    return created


async def mark_overdue_settlements() -> int:
    today = datetime.now(IST).date()
    async with pool().acquire() as conn:
        rows = await conn.fetch("""
            SELECT id, store_id, week_end, balance_due FROM settlements
            WHERE status != 'settled'
              AND is_overdue = false
              AND balance_due > 0
        """)

    marked_ids = []
    for row in rows:
        try:
            week_end_date = datetime.fromisoformat(row["week_end"]).date()
        except (ValueError, TypeError):
            continue
        # Settlements are created AFTER their week ends, so the store gets the
        # following week (grace) to pay before being flagged overdue.
        if today > week_end_date + timedelta(days=OVERDUE_GRACE_DAYS):
            marked_ids.append(row["id"])

    if marked_ids:
        async with pool().acquire() as conn:
            await conn.execute(
                "UPDATE settlements SET is_overdue = true WHERE id = ANY($1)",
                marked_ids,
            )

    marked = len(marked_ids)
    if marked:
        log.info("marked %d settlements as overdue", marked)
    return marked
