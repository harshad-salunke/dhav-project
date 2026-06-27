"""
Call masking router — privacy-preserving deliverer <-> customer calls.

A masked call is placed against an ORDER. The initiator (the customer, or the
deliverer — store owner self-delivering / assigned delivery partner) taps "Call"
in their app; we resolve BOTH real phone numbers server-side, bridge them
through a virtual number via the configured provider (see services/call_masking),
and log the call. The apps never receive the other party's real number.
"""
import logging

from fastapi import APIRouter, Depends, HTTPException, Request

from models.call import CallInitiateResponse
from models.user import TokenVerifyResponse
from dependencies import get_current_user, require_role
from services.db import pool
from services.call_masking import (
    get_call_service, pick_virtual_number, normalize_in_phone,
)
from config import get_settings
from utils.helpers import new_id, now_ms

router = APIRouter()
settings = get_settings()
log = logging.getLogger("calls")

# Order states in which a deliverer/customer call makes sense. Before a store
# accepts there's no counterparty; after a terminal state there's nothing to talk
# about.
_CALLABLE_STATES = {"accepted", "packed", "out_for_delivery"}


async def _get_order_or_404(order_id: str) -> dict:
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM orders WHERE id = $1", order_id)
    if not row:
        raise HTTPException(status_code=404, detail="Order not found")
    return dict(row)


async def _customer_phone(uid: str) -> str | None:
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT phone FROM users WHERE uid = $1", uid)
    return (row["phone"] if row else None)


async def _store_for_user(uid: str) -> dict | None:
    async with pool().acquire() as conn:
        urow = await conn.fetchrow("SELECT store_id FROM users WHERE uid = $1", uid)
        if not urow or not urow["store_id"]:
            return None
        srow = await conn.fetchrow("SELECT * FROM stores WHERE id = $1", urow["store_id"])
    return dict(srow) if srow else None


# ── Initiate a masked call ─────────────────────────────────────────────────────

@router.post("/order/{order_id}", response_model=CallInitiateResponse)
async def call_for_order(
    order_id: str,
    user: TokenVerifyResponse = Depends(get_current_user),
):
    if not settings.call_masking_enabled:
        return CallInitiateResponse(ok=False, status="disabled",
                                    message="Calling is currently disabled.")

    order = await _get_order_or_404(order_id)
    if order.get("status") not in _CALLABLE_STATES:
        raise HTTPException(status_code=409,
                            detail="Calling is only available for an active order.")

    deliverer_phone = order.get("delivery_boy_phone")  # store phone (self-deliver) or partner phone

    # Resolve the two legs + authorise the caller against THIS order.
    if user.role == "customer":
        if order.get("customer_id") != user.uid:
            raise HTTPException(status_code=403, detail="Not your order")
        caller = await _customer_phone(user.uid)
        callee = deliverer_phone
        direction = "customer_to_deliverer"
        missing_caller_msg = "Add your phone number in Profile to call the delivery agent."
        missing_callee_msg = "The delivery agent's number isn't available yet."

    elif user.role in ("store_owner", "delivery"):
        store = await _store_for_user(user.uid)
        is_owner_of_order = bool(store) and order.get("accepted_by_store_id") == store.get("id")
        is_assigned_rider = order.get("assigned_delivery_boy_id") == user.uid
        if not (is_owner_of_order or is_assigned_rider):
            raise HTTPException(status_code=403, detail="This order is not assigned to you")
        # Deliverer leg: the stamped delivery_boy_phone; before dispatch it may be
        # empty for a self-delivering store, so fall back to the store's own phone.
        caller = deliverer_phone or (store.get("phone") if store else None)
        callee = await _customer_phone(order.get("customer_id"))
        direction = "deliverer_to_customer"
        missing_caller_msg = "Your store/delivery phone number isn't set."
        missing_callee_msg = "The customer hasn't added a phone number."

    else:
        raise HTTPException(status_code=403, detail="Not allowed to place this call")

    caller_n = normalize_in_phone(caller)
    callee_n = normalize_in_phone(callee)
    if not caller_n:
        raise HTTPException(status_code=422, detail=missing_caller_msg)
    if not callee_n:
        raise HTTPException(status_code=422, detail=missing_callee_msg)

    service = get_call_service()
    virtual_number = pick_virtual_number()
    if service.provider_name == "exotel" and not virtual_number:
        raise HTTPException(status_code=503,
                            detail="No masking number configured. Set CALL_VIRTUAL_NUMBERS.")
    # Mock provider doesn't need a real number for the audit row.
    virtual_number = virtual_number or "MOCK_VIRTUAL"

    callback_url = f"{settings.backend_public_url.rstrip('/')}/calls/provider/callback"
    result = await service.connect(
        caller_phone=caller_n,
        callee_phone=callee_n,
        virtual_number=virtual_number,
        status_callback_url=callback_url,
        order_id=order_id,
    )

    call_id = new_id()
    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO call_logs (
                id, order_id, initiator_uid, initiator_role, direction,
                caller_phone, callee_phone, virtual_number,
                provider, provider_call_sid, status, error_detail, created_at
            ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
        """, call_id, order_id, user.uid, user.role, direction,
            caller_n, callee_n, result.virtual_number or virtual_number,
            result.provider, result.call_sid,
            ("initiated" if result.ok else "failed"), result.error, now_ms())

    if not result.ok:
        # Surface a clean error; the row is kept for diagnostics.
        raise HTTPException(status_code=502,
                            detail="Couldn't place the call right now. Please try again.")

    return CallInitiateResponse(
        ok=True, status=result.status, masked=True,
        call_id=call_id, virtual_number=result.virtual_number,
    )


# ── Provider status callback (Exotel posts here — NOT app-facing) ──────────────

@router.post("/provider/callback")
async def provider_callback(request: Request):
    """Exotel posts call status here when the call ends. Public (Exotel can't send
    our bearer token); we match the call by the provider's CallSid. Updates status
    + billed duration so spend and delivery disputes are auditable.

    Parsed from the raw urlencoded body (+ query string) so it needs no
    `python-multipart` dependency."""
    from urllib.parse import parse_qs

    form: dict[str, str] = {}
    try:
        raw = (await request.body()).decode("utf-8", "ignore")
        for k, v in parse_qs(raw).items():
            form[k] = v[0] if v else ""
    except Exception:
        pass
    for k, v in request.query_params.items():
        form.setdefault(k, v)

    call_sid = form.get("CallSid") or form.get("Sid")
    status = (form.get("Status") or form.get("DialCallStatus") or "").lower() or None
    duration = form.get("ConversationDuration") or form.get("DialCallDuration") or "0"
    try:
        duration_s = int(float(duration))
    except (TypeError, ValueError):
        duration_s = 0

    if not call_sid:
        return {"ok": False}

    async with pool().acquire() as conn:
        await conn.execute("""
            UPDATE call_logs
               SET status = COALESCE($2, status),
                   duration_seconds = $3,
                   ended_at = $4
             WHERE provider_call_sid = $1
        """, call_sid, status, duration_s, now_ms())
    return {"ok": True}


# ── Admin: call audit log ──────────────────────────────────────────────────────

@router.get("/logs")
async def list_call_logs(
    order_id: str | None = None,
    limit: int = 100,
    _admin: TokenVerifyResponse = Depends(require_role("admin")),
):
    limit = max(1, min(limit, 500))
    async with pool().acquire() as conn:
        if order_id:
            rows = await conn.fetch(
                "SELECT * FROM call_logs WHERE order_id=$1 ORDER BY created_at DESC LIMIT $2",
                order_id, limit,
            )
        else:
            rows = await conn.fetch(
                "SELECT * FROM call_logs ORDER BY created_at DESC LIMIT $1", limit,
            )
    return {"calls": [dict(r) for r in rows]}
