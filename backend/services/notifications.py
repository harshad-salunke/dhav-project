from datetime import timedelta

from firebase_admin import messaging

# FCM holds messages on its servers and delivers them when the device comes
# back online. For incoming-order alerts that is harmful — a store owner who
# was offline for hours should NOT get a popup for an order that was already
# accepted by someone else 30 minutes ago. We cap the TTL at the maximum
# broadcast window (≈3 minutes across 3 waves). After this, FCM drops the
# message instead of holding it.
_ORDER_NOTIF_TTL = timedelta(seconds=180)


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

def send_new_order_to_stores(store_tokens: list[str], order_id: str,
                              item_count: int, total: float) -> None:
    _send_multicast(
        store_tokens,
        title="New Order! 🛒",
        body=f"{item_count} items · ₹{total:.0f} — Accept now!",
        data={
            "type": "new_order",
            "order_id": order_id,
            "item_count": str(item_count),
            "total": str(total),
        },
        high_priority=True,
    )


def send_order_taken_to_others(store_tokens: list[str], order_id: str) -> None:
    _send_multicast(
        store_tokens,
        title="Order Taken",
        body="This order was accepted by another store.",
        data={"type": "order_taken", "order_id": order_id},
        high_priority=False,
    )


def send_strike_warning(store_token: str, strike_number: int, order_id: str) -> None:
    _send(
        store_token,
        title=f"Strike {strike_number} Issued ⚠️",
        body="Order failed to be delivered. Repeated failures will suspend your account.",
        data={"type": "strike_warning", "order_id": order_id, "strike_number": str(strike_number)},
    )


def send_store_suspended(store_token: str, days: int) -> None:
    _send(
        store_token,
        title="Account Suspended 🚫",
        body=f"Your store has been suspended for {days} days due to repeated failures.",
        data={"type": "store_suspended", "suspension_days": str(days)},
    )


# ── Customer notifications ─────────────────────────────────────────────────────

def send_order_accepted_to_customer(customer_token: str, order_id: str,
                                     store_name: str) -> None:
    _send(
        customer_token,
        title="Order Accepted! ✅",
        body=f"{store_name} is preparing your order.",
        data={"type": "order_accepted", "order_id": order_id, "store_name": store_name},
    )


def send_order_out_for_delivery(customer_token: str, order_id: str) -> None:
    _send(
        customer_token,
        title="Order Out for Delivery 🛵",
        body="Your order is on the way! Track live location.",
        data={"type": "out_for_delivery", "order_id": order_id},
    )


def send_order_delivered(customer_token: str, order_id: str) -> None:
    _send(
        customer_token,
        title="Order Delivered! 🎉",
        body="Enjoy your order. Thank you for shopping with DHAV.",
        data={"type": "order_delivered", "order_id": order_id},
    )


def send_order_failed_to_customer(customer_token: str, order_id: str) -> None:
    _send(
        customer_token,
        title="No Stores Available 😞",
        body="Sorry, no nearby store could accept your order right now. Please try again.",
        data={"type": "order_failed", "order_id": order_id},
    )
