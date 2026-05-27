from datetime import timedelta

from firebase_admin import db, messaging

from utils.helpers import new_id, now_ms

# FCM holds messages on its servers and delivers them when the device comes
# back online. For incoming-order alerts that is harmful — a store owner who
# was offline for hours should NOT get a popup for an order that was already
# accepted by someone else 30 minutes ago. We cap the TTL at the maximum
# broadcast window (≈3 minutes across 3 waves). After this, FCM drops the
# message instead of holding it.
_ORDER_NOTIF_TTL = timedelta(seconds=180)


# ── Firebase persistence ───────────────────────────────────────────────────────

def _save_notification(
    user_id: str,
    title: str,
    body: str,
    notif_type: str,
    order_id: str | None = None,
    sender: str = "system",
) -> None:
    """Persist a notification to Firebase at notifications/{user_id}/{notif_id}."""
    if not user_id:
        return
    try:
        notif_id = new_id()
        db.reference(f"notifications/{user_id}/{notif_id}").set({
            "notif_id": notif_id,
            "title": title,
            "body": body,
            "type": notif_type,
            "order_id": order_id,
            "is_read": False,
            "created_at": now_ms(),
            "sender": sender,
        })
    except Exception as e:
        print(f"[Notif] _save_notification FAILED uid={user_id}  error={e}")


def _save_notification_multi(
    user_ids: list[str],
    title: str,
    body: str,
    notif_type: str,
    order_id: str | None = None,
    sender: str = "system",
) -> None:
    """Persist a notification for multiple users."""
    for uid in user_ids:
        _save_notification(uid, title, body, notif_type, order_id=order_id, sender=sender)


# ── FCM send helpers ───────────────────────────────────────────────────────────

def _send(token: str, title: str, body: str, data: dict, high_priority: bool = False) -> None:
    if not token:
        print(f"[FCM] _send SKIPPED: no token (title='{title}')")
        return
    msg = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in data.items()},
        token=token,
        android=messaging.AndroidConfig(
            priority="high" if high_priority else "normal",
            notification=messaging.AndroidNotification(
                sound="order_alert",
                channel_id="dhav_incoming_orders" if high_priority else "dhav_general",
                default_vibrate_timings=high_priority,
            ),
        ),
    )
    try:
        resp = messaging.send(msg)
        print(f"[FCM] _send OK  title='{title}'  resp={resp}")
    except Exception as e:
        print(f"[FCM] _send FAILED  title='{title}'  error={type(e).__name__}: {e}")


def _send_multicast(tokens: list[str], title: str, body: str, data: dict,
                     high_priority: bool = False) -> None:
    valid_tokens = [t for t in tokens if t]
    print(f"[FCM] _send_multicast: title='{title}'  total_tokens={len(tokens)}  valid_tokens={len(valid_tokens)}")
    if not valid_tokens:
        print(f"[FCM] _send_multicast SKIPPED: no valid tokens")
        return
    # DATA-ONLY message — no `notification` field. This prevents the FCM SDK
    # from auto-displaying a second notification on top of the one we show
    # ourselves from _backgroundHandler. Title/body are stashed in `data` so
    # the Flutter side can render the full-screen-intent popup.
    payload = {k: str(v) for k, v in data.items()}
    payload["title"] = title
    payload["body"] = body
    # Per-order collapse key — if FCM ends up holding multiple notifications
    # for the same order (e.g. wave 1 + wave 2 retry while phone offline),
    # only the latest one is delivered. Falls back to title bucket otherwise.
    collapse_key = f"order_{data.get('order_id')}" if data.get("order_id") else title
    msg = messaging.MulticastMessage(
        data=payload,
        tokens=valid_tokens,
        android=messaging.AndroidConfig(
            priority="high" if high_priority else "normal",
            ttl=_ORDER_NOTIF_TTL if high_priority else None,
            collapse_key=collapse_key,
        ),
    )
    try:
        resp = messaging.send_each_for_multicast(msg)
        print(f"[FCM] _send_multicast result: success={resp.success_count}  failure={resp.failure_count}")
        for i, r in enumerate(resp.responses):
            if not r.success:
                print(f"[FCM]   token[{i}] FAILED: {r.exception}")
    except Exception as e:
        print(f"[FCM] _send_multicast FAILED  title='{title}'  error={type(e).__name__}: {e}")


# ── Store notifications ────────────────────────────────────────────────────────

def send_new_order_to_stores(
    store_tokens: list[str],
    order_id: str,
    item_count: int,
    total: float,
    owner_uids: list[str] | None = None,
) -> None:
    title = "New Order! 🛒"
    body = f"{item_count} items · ₹{total:.0f} — Accept now!"
    _send_multicast(
        store_tokens,
        title=title,
        body=body,
        data={
            "type": "new_order",
            "order_id": order_id,
            "item_count": str(item_count),
            "total": str(total),
        },
        high_priority=True,
    )
    if owner_uids:
        _save_notification_multi(
            owner_uids, title, body, "new_order", order_id=order_id
        )


def send_order_taken_to_others(store_tokens: list[str], order_id: str) -> None:
    _send_multicast(
        store_tokens,
        title="Order Taken",
        body="This order was accepted by another store.",
        data={"type": "order_taken", "order_id": order_id},
        high_priority=False,
    )
    # No persistence: this is a transient "dismissed" signal, not worth archiving.


def send_strike_warning(
    store_token: str,
    strike_number: int,
    order_id: str,
    owner_uid: str | None = None,
) -> None:
    title = f"Strike {strike_number} Issued ⚠️"
    body = "Order failed to be delivered. Repeated failures will suspend your account."
    _send(
        store_token,
        title=title,
        body=body,
        data={"type": "strike_warning", "order_id": order_id, "strike_number": str(strike_number)},
    )
    if owner_uid:
        _save_notification(owner_uid, title, body, "strike_warning", order_id=order_id)


def send_store_suspended(
    store_token: str,
    days: int,
    owner_uid: str | None = None,
) -> None:
    title = "Account Suspended 🚫"
    body = (
        f"Your store has been suspended for {days} days due to repeated failures."
        if days > 0
        else "Your store has been permanently banned due to repeated failures."
    )
    _send(
        store_token,
        title=title,
        body=body,
        data={"type": "store_suspended", "suspension_days": str(days)},
    )
    if owner_uid:
        _save_notification(owner_uid, title, body, "store_suspended")


# ── Customer notifications ─────────────────────────────────────────────────────

def send_order_accepted_to_customer(
    customer_token: str,
    order_id: str,
    store_name: str,
    customer_uid: str | None = None,
) -> None:
    title = "Order Accepted! ✅"
    body = f"{store_name} is preparing your order."
    _send(
        customer_token,
        title=title,
        body=body,
        data={"type": "order_accepted", "order_id": order_id, "store_name": store_name},
    )
    if customer_uid:
        _save_notification(customer_uid, title, body, "order_accepted", order_id=order_id)


def send_order_out_for_delivery(
    customer_token: str,
    order_id: str,
    customer_uid: str | None = None,
) -> None:
    title = "Order Out for Delivery 🛵"
    body = "Your order is on the way! Track live location."
    _send(
        customer_token,
        title=title,
        body=body,
        data={"type": "out_for_delivery", "order_id": order_id},
    )
    if customer_uid:
        _save_notification(customer_uid, title, body, "out_for_delivery", order_id=order_id)


def send_order_delivered(
    customer_token: str,
    order_id: str,
    customer_uid: str | None = None,
) -> None:
    title = "Order Delivered! 🎉"
    body = "Enjoy your order. Thank you for shopping with DHAV."
    _send(
        customer_token,
        title=title,
        body=body,
        data={"type": "order_delivered", "order_id": order_id},
    )
    if customer_uid:
        _save_notification(customer_uid, title, body, "order_delivered", order_id=order_id)


def send_order_failed_to_customer(
    customer_token: str,
    order_id: str,
    customer_uid: str | None = None,
) -> None:
    title = "No Stores Available 😞"
    body = "Sorry, no nearby store could accept your order right now. Please try again."
    _send(
        customer_token,
        title=title,
        body=body,
        data={"type": "order_failed", "order_id": order_id},
    )
    if customer_uid:
        _save_notification(customer_uid, title, body, "order_failed", order_id=order_id)


# ── Admin broadcast helper ─────────────────────────────────────────────────────

def send_broadcast_notification(
    tokens: list[str],
    user_ids: list[str],
    title: str,
    body: str,
    notif_type: str = "announcement",
    sender: str = "admin",
) -> dict:
    """Send a broadcast push + persist for all targeted users."""
    sent_push = 0
    if tokens:
        valid = [t for t in tokens if t]
        if valid:
            _send_multicast(valid, title, body, {"type": notif_type}, high_priority=False)
            sent_push = len(valid)
    _save_notification_multi(user_ids, title, body, notif_type, sender=sender)
    return {"push_sent": sent_push, "persisted": len(user_ids)}
