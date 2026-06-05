"""
Notification endpoints — authenticated users read and manage their own notifications.
"""
from fastapi import APIRouter, HTTPException, Depends

from models.user import TokenVerifyResponse
from dependencies import get_current_user
from services.db import pool
from utils.helpers import now_ms

router = APIRouter()


@router.get("/me")
async def get_my_notifications(
    user: TokenVerifyResponse = Depends(get_current_user),
    limit: int = 100,
):
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM notifications WHERE uid=$1 ORDER BY created_at DESC LIMIT $2",
            user.uid, limit,
        )
    notifs = [dict(r) for r in rows]
    unread = sum(1 for n in notifs if not n.get("is_read", False))
    return {"notifications": notifs, "total": len(notifs), "unread": unread}


@router.patch("/{notif_id}/read")
async def mark_notification_read(
    notif_id: str,
    user: TokenVerifyResponse = Depends(get_current_user),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id FROM notifications WHERE id=$1 AND uid=$2", notif_id, user.uid
        )
    if not row:
        raise HTTPException(status_code=404, detail="Notification not found")
    async with pool().acquire() as conn:
        await conn.execute("UPDATE notifications SET is_read=true WHERE id=$1", notif_id)
    return {"status": "read"}


@router.patch("/me/read-all")
async def mark_all_notifications_read(user: TokenVerifyResponse = Depends(get_current_user)):
    async with pool().acquire() as conn:
        result = await conn.execute(
            "UPDATE notifications SET is_read=true WHERE uid=$1 AND is_read=false",
            user.uid,
        )
    # asyncpg returns "UPDATE N" — extract count
    updated = int(result.split()[-1]) if result else 0
    return {"status": "all_read", "updated": updated}


@router.delete("/me")
async def clear_my_notifications(user: TokenVerifyResponse = Depends(get_current_user)):
    async with pool().acquire() as conn:
        await conn.execute("DELETE FROM notifications WHERE uid=$1", user.uid)
    return {"status": "cleared"}


@router.delete("/{notif_id}")
async def delete_notification(
    notif_id: str,
    user: TokenVerifyResponse = Depends(get_current_user),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id FROM notifications WHERE id=$1 AND uid=$2", notif_id, user.uid
        )
    if not row:
        raise HTTPException(status_code=404, detail="Notification not found")
    async with pool().acquire() as conn:
        await conn.execute("DELETE FROM notifications WHERE id=$1", notif_id)
    return {"status": "deleted"}
