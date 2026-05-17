from pydantic import BaseModel
from typing import Optional, List


class PaymentRecord(BaseModel):
    payment_id: str
    settlement_id: str
    store_id: str
    amount: float
    payment_mode: str   # upi | cash | bank_transfer
    payment_date: int   # epoch ms
    recorded_by: str    # admin uid
    notes: Optional[str] = None


class WeeklySettlement(BaseModel):
    settlement_id: str
    store_id: str
    week_start: str     # "YYYY-MM-DD" (Monday)
    week_end: str       # "YYYY-MM-DD" (Sunday)
    total_orders_delivered: int = 0
    total_platform_fee_owed: float = 0.0
    total_fee_paid: float = 0.0
    balance_due: float = 0.0
    status: str = "pending"     # pending | partially_paid | settled
    payment_records: List[PaymentRecord] = []
    is_overdue: bool = False
    created_at: Optional[int] = None


class MarkPaidRequest(BaseModel):
    amount: float
    payment_mode: str
    notes: Optional[str] = None
