from fastapi import APIRouter, HTTPException, Depends

from models.settlement import MarkPaidRequest
from models.user import TokenVerifyResponse
from dependencies import require_role
from services.db import pool
from utils.helpers import new_id, now_ms

router = APIRouter()


async def _store_id_for_user(uid: str) -> str:
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT store_id FROM users WHERE uid=$1", uid)
    if not row or not row["store_id"]:
        raise HTTPException(status_code=404, detail="Store not found for this user")
    return row["store_id"]


# Per-order fields returned by the breakdown endpoints — the store app renders
# these as "order total | platform fee ₹10 | delivery ₹0" rows.
_BREAKDOWN_COLS = """
    id AS order_id, delivered_at, total_product_amount,
    platform_fee_amount, delivery_fee, total_customer_amount
"""


@router.get("/store/current")
async def get_current_settlement(user: TokenVerifyResponse = Depends(require_role("store_owner"))):
    store_id = await _store_id_for_user(user.uid)
    async with pool().acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM settlements WHERE store_id=$1 ORDER BY created_at DESC LIMIT 1",
            store_id,
        )
        # Live accruing view: delivered orders not yet swept into any settlement.
        unsettled = await conn.fetch(f"""
            SELECT {_BREAKDOWN_COLS} FROM orders
            WHERE accepted_by_store_id = $1
              AND status = 'delivered'
              AND settlement_id IS NULL
            ORDER BY delivered_at DESC
        """, store_id)
    unsettled_orders = [dict(r) for r in unsettled]
    return {
        "settlement": dict(row) if row else None,
        "unsettled_orders": unsettled_orders,
        "unsettled_fee_total": round(sum(o["platform_fee_amount"] or 0.0
                                         for o in unsettled_orders), 2),
    }


@router.get("/{settlement_id}/orders")
async def get_settlement_orders(
    settlement_id: str,
    user: TokenVerifyResponse = Depends(require_role("store_owner", "admin")),
):
    """Order-wise breakdown of a settlement (owning store or admin)."""
    async with pool().acquire() as conn:
        srow = await conn.fetchrow("SELECT * FROM settlements WHERE id=$1", settlement_id)
    if not srow:
        raise HTTPException(status_code=404, detail="Settlement not found")
    if user.role == "store_owner":
        store_id = await _store_id_for_user(user.uid)
        if srow["store_id"] != store_id:
            raise HTTPException(status_code=403, detail="Not your settlement")
    async with pool().acquire() as conn:
        rows = await conn.fetch(f"""
            SELECT {_BREAKDOWN_COLS} FROM orders
            WHERE settlement_id = $1
            ORDER BY delivered_at DESC
        """, settlement_id)
    return {"settlement_id": settlement_id, "orders": [dict(r) for r in rows]}


@router.get("/store/history")
async def get_settlement_history(user: TokenVerifyResponse = Depends(require_role("store_owner"))):
    store_id = await _store_id_for_user(user.uid)
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM settlements WHERE store_id=$1 ORDER BY created_at DESC",
            store_id,
        )
    return {"settlements": [dict(r) for r in rows]}


@router.post("/{settlement_id}/mark-paid")
async def mark_paid(
    settlement_id: str,
    body: MarkPaidRequest,
    user: TokenVerifyResponse = Depends(require_role("admin")),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM settlements WHERE id=$1", settlement_id)
    if not row:
        raise HTTPException(status_code=404, detail="Settlement not found")
    settlement = dict(row)

    payment_id = new_id()
    payment = {
        "payment_id": payment_id,
        "settlement_id": settlement_id,
        "store_id": settlement["store_id"],
        "amount": body.amount,
        "payment_mode": body.payment_mode,
        "payment_date": now_ms(),
        "recorded_by": user.uid,
        "notes": body.notes or "",
    }

    existing_records = list(settlement.get("payment_records") or [])
    existing_records.append(payment)
    total_paid = (settlement.get("total_fee_paid") or 0.0) + body.amount
    balance_due = max(0.0, (settlement.get("total_platform_fee_owed") or 0.0) - total_paid)
    status = "settled" if balance_due == 0 else "partially_paid"

    async with pool().acquire() as conn:
        await conn.execute("""
            UPDATE settlements SET
                payment_records=$2::jsonb,
                total_fee_paid=$3,
                balance_due=$4,
                status=$5,
                is_overdue=false
            WHERE id=$1
        """, settlement_id,
            existing_records, round(total_paid, 2),
            round(balance_due, 2), status)

    return {"payment_id": payment_id, "status": status, "balance_due": balance_due}
