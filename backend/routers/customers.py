from fastapi import APIRouter, HTTPException, Depends

from models.user import TokenVerifyResponse
from dependencies import require_role
from services.db import pool
from services.cache import catalog_cache
from utils.helpers import now_ms, new_id

router = APIRouter()


@router.get("/me")
async def get_profile(user: TokenVerifyResponse = Depends(require_role("customer"))):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM users WHERE uid=$1", user.uid)
    if not row:
        raise HTTPException(status_code=404, detail="Profile not found")
    return dict(row)


@router.patch("/me")
async def update_profile(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    allowed = {"name", "phone", "default_address", "fcm_token", "language"}
    # map legacy field name
    if "display_name" in body:
        body["name"] = body.pop("display_name")
    updates = {k: v for k, v in body.items() if k in allowed}
    if not updates:
        raise HTTPException(status_code=400, detail="No valid fields to update")

    fields, vals = [], [user.uid]
    for k, v in updates.items():
        vals.append(v)
        col_cast = f"${len(vals)}::jsonb" if isinstance(v, dict) else f"${len(vals)}"
        fields.append(f"{k} = {col_cast}")

    async with pool().acquire() as conn:
        await conn.execute(f"UPDATE users SET {', '.join(fields)} WHERE uid=$1", *vals)

    # Invalidate cached user profile so next request reads fresh role/data
    catalog_cache.delete(f"user:{user.uid}")
    return {"status": "updated"}


@router.post("/notify-waitlist")
async def notify_waitlist(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    """Record a 'Notify me' request from a customer whose spot has no store in
    delivery range yet. Idempotent per (uid, area): re-tapping refreshes the row
    (and resets `notified`) rather than creating duplicates."""
    area = (body.get("area") or "").strip()
    lat = body.get("lat")
    lng = body.get("lng")
    async with pool().acquire() as conn:
        await conn.execute(
            """
            INSERT INTO coming_soon_waitlist (id, uid, area, lat, lng, notified, created_at)
            VALUES ($1, $2, $3, $4, $5, false, $6)
            ON CONFLICT (uid, area) DO UPDATE
                SET lat = EXCLUDED.lat,
                    lng = EXCLUDED.lng,
                    notified = false,
                    created_at = EXCLUDED.created_at
            """,
            new_id(), user.uid, area, lat, lng, now_ms(),
        )
    return {"status": "ok"}


@router.post("/me/addresses")
async def add_address(
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT saved_addresses FROM users WHERE uid=$1", user.uid)
    addresses = list(row["saved_addresses"] or []) if row else []
    body["created_at"] = now_ms()

    # Idempotent: the client retries this POST on a cold-start timeout/5xx, so a
    # duplicate request must NOT create a duplicate address. De-dupe by pinned
    # location (lat/lng) + flat_building — if it already exists, return success
    # without appending again.
    def _same(a: dict, b: dict) -> bool:
        try:
            return (
                abs(float(a.get("lat") or 0) - float(b.get("lat") or 0)) < 1e-6
                and abs(float(a.get("lng") or 0) - float(b.get("lng") or 0)) < 1e-6
                and (a.get("flat_building") or "") == (b.get("flat_building") or "")
            )
        except (TypeError, ValueError):
            return False

    if not any(_same(existing, body) for existing in addresses):
        addresses.append(body)
        async with pool().acquire() as conn:
            await conn.execute(
                "UPDATE users SET saved_addresses=$2::jsonb WHERE uid=$1",
                user.uid, addresses,
            )
    return {"status": "added", "total": len(addresses)}


@router.patch("/me/addresses/{index}")
async def update_address(
    index: int,
    body: dict,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT saved_addresses FROM users WHERE uid=$1", user.uid)
    addresses = list(row["saved_addresses"] or []) if row else []
    if index < 0 or index >= len(addresses):
        raise HTTPException(status_code=404, detail="Address index out of range")

    allowed = {"label", "flat_building", "floor", "area", "landmark", "city", "pincode"}
    for key in allowed:
        if key in body:
            addresses[index][key] = body[key]

    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE users SET saved_addresses=$2::jsonb WHERE uid=$1",
            user.uid, addresses,
        )
    return {"status": "updated"}


@router.delete("/me/addresses/{index}")
async def delete_address(
    index: int,
    user: TokenVerifyResponse = Depends(require_role("customer")),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT saved_addresses FROM users WHERE uid=$1", user.uid)
    addresses = list(row["saved_addresses"] or []) if row else []
    if index < 0 or index >= len(addresses):
        raise HTTPException(status_code=404, detail="Address index out of range")
    addresses.pop(index)
    async with pool().acquire() as conn:
        await conn.execute(
            "UPDATE users SET saved_addresses=$2::jsonb WHERE uid=$1",
            user.uid, addresses,
        )
    return {"status": "deleted"}
