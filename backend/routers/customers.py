from fastapi import APIRouter, HTTPException, Depends
from firebase_admin import db

from models.user import TokenVerifyResponse
from dependencies import require_role
from utils.helpers import now_ms

router = APIRouter()


@router.get("/me")
async def get_profile(user: TokenVerifyResponse = Depends(require_role("customer"))):
    profile = db.reference(f"users/{user.uid}").get()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return profile


@router.patch("/me")
async def update_profile(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    allowed = {"display_name", "phone", "default_address", "fcm_token", "language"}
    update = {k: v for k, v in body.items() if k in allowed}
    if not update:
        raise HTTPException(status_code=400, detail="No valid fields to update")
    db.reference(f"users/{user.uid}").update(update)
    return {"status": "updated"}


@router.post("/me/addresses")
async def add_address(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    addresses = db.reference(f"users/{user.uid}/saved_addresses").get() or []
    body["created_at"] = now_ms()
    addresses.append(body)
    db.reference(f"users/{user.uid}/saved_addresses").set(addresses)
    return {"status": "added", "total": len(addresses)}


@router.delete("/me/addresses/{index}")
async def delete_address(
    index: int,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    addresses = db.reference(f"users/{user.uid}/saved_addresses").get() or []
    if index < 0 or index >= len(addresses):
        raise HTTPException(status_code=404, detail="Address index out of range")
    addresses.pop(index)
    db.reference(f"users/{user.uid}/saved_addresses").set(addresses)
    return {"status": "deleted"}
