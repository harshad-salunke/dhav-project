from fastapi import APIRouter, HTTPException, Depends
from firebase_admin import db

from models.settlement import MarkPaidRequest
from models.user import TokenVerifyResponse
from dependencies import get_current_user, require_role
from utils.helpers import new_id, now_ms

router = APIRouter()


@router.get("/store/current")
async def get_current_settlement(user: TokenVerifyResponse = Depends(require_role("store_owner"))):
    settlements = (
        db.reference("settlements").order_by_child("store_id").equal_to(user.uid).get() or {}
    )
    if not settlements:
        return {"settlement": None}
    latest = max(settlements.values(), key=lambda s: s.get("created_at", 0))
    return {"settlement": latest}


@router.get("/store/history")
async def get_settlement_history(user: TokenVerifyResponse = Depends(require_role("store_owner"))):
    settlements = (
        db.reference("settlements").order_by_child("store_id").equal_to(user.uid).get() or {}
    )
    history = sorted(settlements.values(), key=lambda s: s.get("created_at", 0), reverse=True)
    return {"settlements": history}


@router.post("/{settlement_id}/mark-paid")
async def mark_paid(
    settlement_id: str,
    body: MarkPaidRequest,
    user: TokenVerifyResponse = Depends(require_role("admin")),
):
    ref = db.reference(f"settlements/{settlement_id}")
    settlement = ref.get()
    if not settlement:
        raise HTTPException(status_code=404, detail="Settlement not found")

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

    existing_records = settlement.get("payment_records", [])
    existing_records.append(payment)
    total_paid = settlement.get("total_fee_paid", 0.0) + body.amount
    balance_due = max(0.0, settlement.get("total_platform_fee_owed", 0.0) - total_paid)
    status = "settled" if balance_due == 0 else "partially_paid"

    ref.update({
        "payment_records": existing_records,
        "total_fee_paid": round(total_paid, 2),
        "balance_due": round(balance_due, 2),
        "status": status,
        "is_overdue": False,
    })
    return {"payment_id": payment_id, "status": status, "balance_due": balance_due}
