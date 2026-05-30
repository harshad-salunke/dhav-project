import asyncio

from fastapi import APIRouter, HTTPException, Depends
from firebase_admin import db

from models.user import TokenVerifyResponse
from dependencies import require_role
from utils.helpers import now_ms

router = APIRouter()

_pool_ref = None  # uses catalog.py's shared pool via run_in_executor default


async def _fb_get_async(path: str):
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, lambda: db.reference(path).get())


async def _fb_set_async(path: str, data):
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, lambda: db.reference(path).set(data))


async def _fb_update_async(path: str, data: dict):
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, lambda: db.reference(path).update(data))


@router.get("/me")
async def get_profile(user: TokenVerifyResponse = Depends(require_role("customer"))):
    profile = await _fb_get_async(f"users/{user.uid}")
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
    await _fb_update_async(f"users/{user.uid}", update)
    return {"status": "updated"}


@router.post("/me/addresses")
async def add_address(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    addresses = await _fb_get_async(f"users/{user.uid}/saved_addresses") or []
    body["created_at"] = now_ms()
    addresses.append(body)
    await _fb_set_async(f"users/{user.uid}/saved_addresses", addresses)
    return {"status": "added", "total": len(addresses)}


@router.patch("/me/addresses/{index}")
async def update_address(
    index: int,
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    addresses = await _fb_get_async(f"users/{user.uid}/saved_addresses") or []
    if index < 0 or index >= len(addresses):
        raise HTTPException(status_code=404, detail="Address index out of range")
    allowed = {"label", "flat_building", "floor", "area", "landmark", "city", "pincode"}
    for key in allowed:
        if key in body:
            addresses[index][key] = body[key]
    await _fb_set_async(f"users/{user.uid}/saved_addresses", addresses)
    return {"status": "updated"}


@router.delete("/me/addresses/{index}")
async def delete_address(
    index: int,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    addresses = await _fb_get_async(f"users/{user.uid}/saved_addresses") or []
    if index < 0 or index >= len(addresses):
        raise HTTPException(status_code=404, detail="Address index out of range")
    addresses.pop(index)
    await _fb_set_async(f"users/{user.uid}/saved_addresses", addresses)
    return {"status": "deleted"}
