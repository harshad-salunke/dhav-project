from firebase_admin import messaging


def _send(token: str, title: str, body: str, data: dict, high_priority: bool = False) -> None:
    if not token:
        return
    msg = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in data.items()},
        token=token,
        android=messaging.AndroidConfig(
            priority="high" if high_priority else "normal",
            notification=messaging.AndroidNotification(
                sound="default",
                channel_id="dhav_orders" if high_priority else "dhav_general",
                default_vibrate_timings=high_priority,
            ),
        ),
    )
    try:
        messaging.send(msg)
    except Exception:
        pass


def _send_multicast(tokens: list[str], title: str, body: str, data: dict,
                     high_priority: bool = False) -> None:
    valid_tokens = [t for t in tokens if t]
    if not valid_tokens:
        return
    msg = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in data.items()},
        tokens=valid_tokens,
        android=messaging.AndroidConfig(
            priority="high" if high_priority else "normal",
            notification=messaging.AndroidNotification(
                sound="default",
                channel_id="dhav_orders" if high_priority else "dhav_general",
                default_vibrate_timings=high_priority,
            ),
        ),
    )
    try:
        messaging.send_multicast(msg)
    except Exception:
        pass


# ── Store notifications ────────────────────────────────────────────────────────

def send_new_order_to_stores(store_tokens: list[str], order_id: str,
                              item_count: int, total: float) -> None:
    _send_multicast(
        store_tokens,
        title="New Order! 🛒",
        body=f"{item_count} items · ₹{total:.0f} — Accept now!",
        data={"type": "new_order", "order_id": order_id},
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
