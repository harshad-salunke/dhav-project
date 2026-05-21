"""
In-memory WebSocket hub for live delivery location.
Delivery boy sends GPS every 3 s; customer receives instantly.
Nothing is written to the database — location is ephemeral.
"""
import json
from collections import defaultdict
from fastapi import WebSocket, WebSocketDisconnect
from firebase_admin import auth as firebase_auth, db


# channel_id → {"delivery": WebSocket | None, "customers": list[WebSocket]}
_channels: dict[str, dict] = defaultdict(lambda: {"delivery": None, "customers": []})


async def _verify_token(token: str) -> dict | None:
    if not token or token.lower() in ("null", "undefined", ""):
        return None
    try:
        return firebase_auth.verify_id_token(token, clock_skew_seconds=60)
    except Exception:
        return None


async def _get_order(order_id: str) -> dict | None:
    return db.reference(f"orders/{order_id}").get()


async def location_ws_endpoint(websocket: WebSocket, order_id: str) -> None:
    await websocket.accept()

    # Expect first message: {"token": "...", "role": "delivery_boy" | "customer"}
    try:
        init_msg = await websocket.receive_json()
    except Exception:
        await websocket.close(code=4000)
        return

    token = init_msg.get("token", "")
    role = init_msg.get("role", "")

    decoded = await _verify_token(token)
    if not decoded:
        await websocket.send_json({"error": "unauthorized"})
        await websocket.close(code=4001)
        return

    order = await _get_order(order_id)
    if not order or order.get("status") != "out_for_delivery":
        await websocket.send_json({"error": "order_not_active"})
        await websocket.close(code=4002)
        return

    channel_id = f"order_{order_id}_location"
    channel = _channels[channel_id]

    if role == "delivery_boy":
        # Validate: must be the assigned delivery boy or store owner
        uid = decoded["uid"]
        allowed = (uid == order.get("assigned_delivery_boy_id")
                   or uid == order.get("accepted_by_store_id"))
        if not allowed:
            await websocket.send_json({"error": "forbidden"})
            await websocket.close(code=4003)
            return

        channel["delivery"] = websocket
        await websocket.send_json({"status": "connected", "role": "delivery_boy"})

        try:
            while True:
                raw = await websocket.receive_text()
                payload = json.loads(raw)
                # Validate payload has lat/lng
                if "lat" not in payload or "lng" not in payload:
                    continue
                location_msg = {
                    "lat": payload["lat"],
                    "lng": payload["lng"],
                    "ts": payload.get("ts"),
                }
                # Broadcast to all listening customers
                dead = []
                for cws in channel["customers"]:
                    try:
                        await cws.send_json(location_msg)
                    except Exception:
                        dead.append(cws)
                for d in dead:
                    channel["customers"].remove(d)
        except WebSocketDisconnect:
            channel["delivery"] = None

    elif role == "customer":
        uid = decoded["uid"]
        if uid != order.get("customer_id"):
            await websocket.send_json({"error": "forbidden"})
            await websocket.close(code=4003)
            return

        channel["customers"].append(websocket)
        await websocket.send_json({"status": "connected", "role": "customer"})

        try:
            # Customer just listens; ping/pong to keep alive
            while True:
                await websocket.receive_text()
        except WebSocketDisconnect:
            try:
                channel["customers"].remove(websocket)
            except ValueError:
                pass
    else:
        await websocket.send_json({"error": "invalid_role"})
        await websocket.close(code=4004)


def close_order_channel(order_id: str) -> None:
    channel_id = f"order_{order_id}_location"
    _channels.pop(channel_id, None)
