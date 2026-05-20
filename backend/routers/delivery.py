"""
Delivery-boy specific endpoints.
Currently used for:
  - PATCH /delivery/me/fcm-token  — delivery boy updates their own FCM token
  - GET  /delivery/me/profile     — delivery boy fetches their own profile
"""

from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import db
from pydantic import BaseModel

from dependencies import get_current_user, require_role
from models.user import TokenVerifyResponse
from utils.helpers import now_ms

router = APIRouter()


class FcmTokenRequest(BaseModel):
    fcm_token: str


@router.patch("/me/fcm-token")
async def update_delivery_fcm_token(
    body: FcmTokenRequest,
    user: TokenVerifyResponse = Depends(require_role("delivery")),
):
    """
    Delivery boy updates their own FCM token.
    The token is stored under the delivery_boys node inside their store.
    """
    uid = user.uid

    # Look up which store this delivery boy belongs to
    # delivery boys are stored at stores/{store_id}/delivery_boys/{uid}
    stores_ref = db.reference("stores")
    stores_snapshot = stores_ref.get() or {}

    target_store_id = None
    for store_id, store_data in stores_snapshot.items():
        delivery_boys = store_data.get("delivery_boys", {}) if isinstance(store_data, dict) else {}
        if uid in delivery_boys:
            target_store_id = store_id
            break

    if target_store_id is None:
        raise HTTPException(
            status_code=404,
            detail="Delivery boy not found in any store. Ask your store owner to add you.",
        )

    db.reference(f"stores/{target_store_id}/delivery_boys/{uid}").update(
        {"fcm_token": body.fcm_token, "token_updated_at": now_ms()}
    )
    return {"status": "ok"}


@router.get("/me/profile")
async def get_delivery_profile(
    user: TokenVerifyResponse = Depends(require_role("delivery")),
):
    """Returns the delivery boy's own profile from their store's delivery_boys node."""
    uid = user.uid

    stores_snapshot = db.reference("stores").get() or {}
    for store_id, store_data in stores_snapshot.items():
        if not isinstance(store_data, dict):
            continue
        delivery_boys = store_data.get("delivery_boys", {})
        if uid in delivery_boys:
            profile = delivery_boys[uid]
            return {
                "uid": uid,
                "store_id": store_id,
                "store_name": store_data.get("shop_name", ""),
                **profile,
            }

    raise HTTPException(status_code=404, detail="Delivery boy profile not found.")
