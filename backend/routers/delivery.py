"""
Delivery-boy specific endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from dependencies import require_role
from models.user import TokenVerifyResponse
from services.db import pool
from utils.helpers import now_ms

router = APIRouter()


class FcmTokenRequest(BaseModel):
    fcm_token: str


@router.patch("/me/fcm-token")
async def update_delivery_fcm_token(
    body: FcmTokenRequest,
    user: TokenVerifyResponse = Depends(require_role("delivery")),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, store_id FROM delivery_boys WHERE uid=$1 LIMIT 1", user.uid
        )
    if not row:
        raise HTTPException(
            status_code=404,
            detail="Delivery boy not found. Ask your store owner to add you.",
        )
    # Store FCM token on the user record (used for notifications)
    async with pool().acquire() as conn:
        await conn.execute("UPDATE users SET fcm_token=$2 WHERE uid=$1", user.uid, body.fcm_token)
    return {"status": "ok"}


@router.get("/me/profile")
async def get_delivery_profile(
    user: TokenVerifyResponse = Depends(require_role("delivery")),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("""
            SELECT db.*, s.shop_name AS store_name
            FROM delivery_boys db
            LEFT JOIN stores s ON db.store_id = s.id
            WHERE db.uid = $1
            LIMIT 1
        """, user.uid)
    if not row:
        raise HTTPException(status_code=404, detail="Delivery boy profile not found.")
    return {"uid": user.uid, **dict(row)}
