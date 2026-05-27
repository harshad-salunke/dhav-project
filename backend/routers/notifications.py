"""
Notification endpoints — allow any authenticated user to read and manage
their own notification history stored at notifications/{uid}/{notif_id}.
"""
from fastapi import APIRouter, HTTPException, Depends

from firebase_admin import db

from models.user import TokenVerifyResponse
from dependencies import get_current_user
from utils.helpers import now_ms

router = APIRouter()


# ── GET /notifications/me ──────────────────────────────────────────────────────

@router.get("/me")
async def get_my_notifications(
    user: TokenVerifyResponse = Depends(get_current_user),
    limit: int = 100,
):
    """
    Returns the calling user's persisted notifications, newest first.
    """
    raw = db.reference(f"notifications/{user.uid}").get() or {}
    notifs = list(raw.values())
    notifs.sort(key=lambda n: n.get("created_at", 0), reverse=True)
    unread = sum(1 for n in notifs if not n.get("is_read", False))
    return {
        "notifications": notifs[:limit],
        "total": len(notifs),
        "unread": unread,
    }


# ── PATCH /notifications/{notif_id}/read ──────────────────────────────────────

@router.patch("/{notif_id}/read")
async def mark_notification_read(
    notif_id: str,
    user: TokenVerifyResponse = Depends(get_current_user),
):
    """Mark a single notification as read."""
    ref = db.reference(f"notifications/{user.uid}/{notif_id}")
    notif = ref.get()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    ref.update({"is_read": True})
    return {"status": "read"}


# ── PATCH /notifications/me/read-all ──────────────────────────────────────────

@router.patch("/me/read-all")
async def mark_all_notifications_read(
    user: TokenVerifyResponse = Depends(get_current_user),
):
    """Mark every notification for this user as read."""
    ref = db.reference(f"notifications/{user.uid}")
    raw = ref.get() or {}
    updates: dict = {}
    for notif_id, notif in raw.items():
        if not notif.get("is_read", False):
            updates[f"{notif_id}/is_read"] = True
    if updates:
        ref.update(updates)
    return {"status": "all_read", "updated": len(updates)}


# ── DELETE /notifications/me ───────────────────────────────────────────────────

@router.delete("/me")
async def clear_my_notifications(
    user: TokenVerifyResponse = Depends(get_current_user),
):
    """Delete all notifications for the calling user."""
    db.reference(f"notifications/{user.uid}").delete()
    return {"status": "cleared"}


# ── DELETE /notifications/{notif_id} ──────────────────────────────────────────

@router.delete("/{notif_id}")
async def delete_notification(
    notif_id: str,
    user: TokenVerifyResponse = Depends(get_current_user),
):
    """Delete a single notification."""
    ref = db.reference(f"notifications/{user.uid}/{notif_id}")
    if not ref.get():
        raise HTTPException(status_code=404, detail="Notification not found")
    ref.delete()
    return {"status": "deleted"}
