"""
Weekly settlement generation — PostgreSQL edition.
"""
import logging
from datetime import date, datetime, timedelta

from services.db import pool
from utils.helpers import new_id, now_ms

log = logging.getLogger("settlements")


def _week_bounds() -> tuple[str, str]:
    today = date.today()
    monday = today - timedelta(days=today.weekday())
    sunday = monday + timedelta(days=6)
    return monday.isoformat(), sunday.isoformat()


def _week_start_ms(week_start: str) -> int:
    return int(datetime.fromisoformat(week_start).timestamp() * 1000)


async def generate_weekly_settlements() -> int:
    week_start, week_end = _week_bounds()
    week_start_ms = _week_start_ms(week_start)

    async with pool().acquire() as conn:
        store_rows = await conn.fetch("SELECT id FROM stores WHERE is_active = true")

    created = 0
    for store_row in store_rows:
        store_id = store_row["id"]

        async with pool().acquire() as conn:
            existing = await conn.fetchrow(
                "SELECT id FROM settlements WHERE store_id = $1 AND week_start = $2",
                store_id, week_start,
            )
        if existing:
            continue

        async with pool().acquire() as conn:
            order_rows = await conn.fetch("""
                SELECT platform_fee_amount FROM orders
                WHERE accepted_by_store_id = $1
                  AND status = 'delivered'
                  AND delivered_at >= $2
            """, store_id, week_start_ms)

        total_fee_owed = sum(r["platform_fee_amount"] or 0.0 for r in order_rows)
        settlement_id = new_id()

        async with pool().acquire() as conn:
            await conn.execute("""
                INSERT INTO settlements (
                    id, store_id, week_start, week_end,
                    total_orders_delivered, total_platform_fee_owed,
                    total_fee_paid, balance_due, status,
                    is_overdue, payment_records, created_at
                ) VALUES ($1,$2,$3,$4,$5,$6,0,$7,'pending',false,'[]',$8)
            """, settlement_id, store_id, week_start, week_end,
                len(order_rows), round(total_fee_owed, 2),
                round(total_fee_owed, 2), now_ms())
        created += 1

    log.info("generated %d settlements for week %s", created, week_start)
    return created


async def mark_overdue_settlements() -> int:
    today = date.today()
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
            week_end_date = date.fromisoformat(row["week_end"])
        except (ValueError, TypeError):
            continue
        if today > week_end_date:
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
