"""
Live delivery-location WebSocket hub.

Delivery boy streams GPS (~every 3 s); subscribed customers receive it live.

PERSISTENCE
-----------
The live fan-out stays in-memory (low latency), but every ~15 s we ALSO write the
latest point to `orders.last_lat/last_lng/last_location_at`. That gives us two
things the ephemeral-only design lacked:
  • a customer who opens (or reopens) tracking is seeded with the last-known
    position immediately, instead of staring at a blank map until the next ping;
  • a durable record that survives a worker restart and works across workers.
Writes are throttled (not every 3 s ping) so the DB isn't hammered — the live
stream is what's real-time, the DB row is a periodic checkpoint (Zomato-style).

SCALING DESIGN
--------------
Each worker keeps only the customer sockets connected to IT (`_local_customers`).
Rider GPS is PUBLISHED to a Redis channel; every worker that has a customer
watching that order is SUBSCRIBED and fans the update out to its own sockets.
This makes tracking work no matter which worker the rider vs. the customer
landed on — the key to horizontal scaling.

When Redis is disabled (local dev / single worker) the hub short-circuits and
delivers rider GPS straight to local sockets. Same behaviour, zero setup.

MEMORY SAFETY
-------------
Channels are created on first customer and DELETED when the last customer
leaves or the order is delivered (`close_order_channel`). The previous version
leaked an entry per order forever — fixed here.
"""
import asyncio
import json
import logging
import time
from datetime import datetime, timezone

from fastapi import WebSocket, WebSocketDisconnect
from firebase_admin import auth as firebase_auth

from services.db import pool
from services import redis_bus

log = logging.getLogger("location_ws")

# order_id -> set of customer WebSockets connected to THIS worker
_local_customers: dict[str, set[WebSocket]] = {}
# order_id -> the Redis handler we registered (so we can unsubscribe it)
_order_handlers: dict[str, object] = {}
# order_id -> (lat, lng, monotonic_ts) of the last update we forwarded
_last_sent: dict[str, tuple[float, float, float]] = {}
# order_id -> monotonic ts of the last time we persisted to the DB
_last_persisted: dict[str, float] = {}
_lock = asyncio.Lock()

_MIN_INTERVAL_S = 1.0       # throttle: never forward faster than 1/s per order
_DB_PERSIST_INTERVAL_S = 15.0  # throttle: write last-known to the DB at most every 15 s
# Only seed a fresh customer from the DB if the checkpoint is still recent.
_SEED_MAX_AGE_S = 300.0


def _channel(order_id: str) -> str:
    return f"ws:order:{order_id}:loc"


async def _verify_token(token: str) -> dict | None:
    if not token or token.lower() in ("null", "undefined", ""):
        return None
    try:
        return firebase_auth.verify_id_token(token, clock_skew_seconds=60)
    except Exception:
        return None


# ── customer-side fan-out ──────────────────────────────────────────────────────

async def _deliver_local(order_id: str, msg: dict) -> None:
    """Send `msg` to every customer socket for this order on this worker."""
    sockets = list(_local_customers.get(order_id, ()))
    if not sockets:
        return
    dead = []
    for ws in sockets:
        try:
            await ws.send_json(msg)
        except Exception:
            dead.append(ws)
    if dead:
        async with _lock:
            living = _local_customers.get(order_id)
            if living:
                for d in dead:
                    living.discard(d)


async def _add_customer(order_id: str, ws: WebSocket) -> None:
    async with _lock:
        first = order_id not in _local_customers
        _local_customers.setdefault(order_id, set()).add(ws)
        if first:
            # Subscribe this worker to the order's Redis channel.
            async def _handler(payload: dict, _oid=order_id) -> None:
                if payload.get("_close"):
                    await _close_local(_oid)
                else:
                    await _deliver_local(_oid, payload)

            _order_handlers[order_id] = _handler
            await redis_bus.subscribe(_channel(order_id), _handler)


async def _remove_customer(order_id: str, ws: WebSocket) -> None:
    async with _lock:
        sockets = _local_customers.get(order_id)
        if not sockets:
            return
        sockets.discard(ws)
        if not sockets:
            _local_customers.pop(order_id, None)
            handler = _order_handlers.pop(order_id, None)
            _last_sent.pop(order_id, None)
            if handler is not None:
                await redis_bus.unsubscribe(_channel(order_id), handler)


async def _close_local(order_id: str) -> None:
    """Close every local customer socket for an order and drop its state."""
    async with _lock:
        sockets = _local_customers.pop(order_id, None)
        handler = _order_handlers.pop(order_id, None)
        _last_sent.pop(order_id, None)
        _last_persisted.pop(order_id, None)
    if handler is not None:
        await redis_bus.unsubscribe(_channel(order_id), handler)
    for ws in list(sockets or ()):
        try:
            await ws.close(code=1000)
        except Exception:
            pass


# ── rider-side ingest ──────────────────────────────────────────────────────────

async def _persist_location(order_id: str, lat: float, lng: float) -> None:
    """Throttled checkpoint of the rider's position to the orders row."""
    now = time.monotonic()
    last = _last_persisted.get(order_id)
    if last is not None and (now - last) < _DB_PERSIST_INTERVAL_S:
        return
    _last_persisted[order_id] = now
    try:
        async with pool().acquire() as conn:
            await conn.execute(
                "UPDATE orders SET last_lat=$2, last_lng=$3, last_location_at=now() "
                "WHERE id=$1",
                order_id, lat, lng,
            )
    except Exception:
        # A failed checkpoint must never break the live stream — just retry next tick.
        log.warning("location persist failed for order %s", order_id, exc_info=True)
        _last_persisted.pop(order_id, None)


def _seed_point(order: dict) -> dict | None:
    """Build the initial {lat,lng,ts} for a customer from the DB checkpoint,
    or None if there's no recent stored position."""
    lat, lng, at = order.get("last_lat"), order.get("last_lng"), order.get("last_location_at")
    if lat is None or lng is None or at is None:
        return None
    if at.tzinfo is None:
        at = at.replace(tzinfo=timezone.utc)
    if (datetime.now(timezone.utc) - at).total_seconds() > _SEED_MAX_AGE_S:
        return None  # stale checkpoint — don't show an old position as "live"
    return {"lat": float(lat), "lng": float(lng), "ts": int(at.timestamp() * 1000)}


async def _forward_rider_update(order_id: str, lat: float, lng: float, ts) -> None:
    # Throttle + delta: drop bursts and no-move repeats to cut network traffic.
    now = time.monotonic()
    prev = _last_sent.get(order_id)
    if prev is not None:
        plat, plng, pts = prev
        if (now - pts) < _MIN_INTERVAL_S and plat == lat and plng == lng:
            return
    _last_sent[order_id] = (lat, lng, now)

    msg = {"lat": lat, "lng": lng, "ts": ts}
    channel = _channel(order_id)
    # When Redis is on, publish only — every worker's subscriber (including this
    # one, if a customer is local) delivers it. Avoids double-send.
    published = await redis_bus.publish(channel, msg)
    if not published:
        await _deliver_local(order_id, msg)

    # Durable checkpoint (throttled) so late-joining customers see a marker at once.
    await _persist_location(order_id, lat, lng)


# ── public API ─────────────────────────────────────────────────────────────────

async def location_ws_endpoint(websocket: WebSocket, order_id: str) -> None:
    await websocket.accept()

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

    async with pool().acquire() as conn:
        row = await conn.fetchrow(
            "SELECT status, customer_id, assigned_delivery_boy_id, accepted_by_store_id, "
            "last_lat, last_lng, last_location_at "
            "FROM orders WHERE id=$1",
            order_id,
        )
    order = dict(row) if row else None
    if not order or order.get("status") != "out_for_delivery":
        await websocket.send_json({"error": "order_not_active"})
        await websocket.close(code=4002)
        return

    uid = decoded["uid"]

    if role == "delivery_boy":
        allowed = (uid == order.get("assigned_delivery_boy_id")
                   or uid == order.get("accepted_by_store_id"))
        if not allowed:
            await websocket.send_json({"error": "forbidden"})
            await websocket.close(code=4003)
            return

        await websocket.send_json({"status": "connected", "role": "delivery_boy"})
        try:
            while True:
                raw = await websocket.receive_text()
                try:
                    payload = json.loads(raw)
                except (ValueError, TypeError):
                    continue
                if "lat" not in payload or "lng" not in payload:
                    continue
                await _forward_rider_update(
                    order_id, payload["lat"], payload["lng"], payload.get("ts")
                )
        except WebSocketDisconnect:
            return

    elif role == "customer":
        if uid != order.get("customer_id"):
            await websocket.send_json({"error": "forbidden"})
            await websocket.close(code=4003)
            return

        await _add_customer(order_id, websocket)
        await websocket.send_json({"status": "connected", "role": "customer"})

        # Seed the map immediately with the last-known checkpoint (if recent),
        # so the customer isn't staring at a blank map until the next live ping.
        seed = _seed_point(order)
        if seed is not None:
            try:
                await websocket.send_json(seed)
            except Exception:
                pass

        try:
            while True:
                await websocket.receive_text()  # keepalive pings
        except WebSocketDisconnect:
            pass
        finally:
            await _remove_customer(order_id, websocket)

    else:
        await websocket.send_json({"error": "invalid_role"})
        await websocket.close(code=4004)


async def close_order_channel(order_id: str) -> None:
    """Call when an order is delivered/cancelled: close watchers everywhere.
    Broadcasts a close control message so customers on OTHER workers drop too."""
    await redis_bus.publish(_channel(order_id), {"_close": True})
    await _close_local(order_id)
