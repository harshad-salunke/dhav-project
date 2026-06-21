"""
3-wave order broadcasting — PostgreSQL edition.

Atomic acceptance uses a single PostgreSQL UPDATE … WHERE status='broadcasting' RETURNING *
which is row-level-locked, so only one store wins even under concurrent requests.
All Firebase RTDB reads/writes are replaced with asyncpg pool queries.
Redis Pub/Sub for cross-worker signalling is unchanged.
"""
import asyncio
import logging

from services.db import pool
from services import redis_bus
from services.geofencing import find_nearby_stores_async
from services.notifications import (
    send_new_order_to_stores,
    send_order_failed_to_customer,
)
from config import get_settings
from utils.helpers import now_ms

settings = get_settings()
log = logging.getLogger("broadcasting")

WAVES = [
    (settings.broadcast_wave1_radius_km, settings.broadcast_wave1_timeout_seconds),
    (settings.broadcast_wave2_radius_km, settings.broadcast_wave2_timeout_seconds),
    (settings.broadcast_wave3_radius_km, settings.broadcast_wave3_timeout_seconds),
]

_active_broadcasts: dict[str, asyncio.Task] = {}
_accept_events: dict[str, asyncio.Event] = {}


def _accept_channel(order_id: str) -> str:
    return f"order:{order_id}:accepted"


async def _get_store_fcm_tokens(store_ids: list[str]) -> dict[str, str]:
    if not store_ids:
        return {}
    async with pool().acquire() as conn:
        rows = await conn.fetch(
            "SELECT id, fcm_token FROM stores WHERE id = ANY($1) AND fcm_token IS NOT NULL",
            store_ids,
        )
    return {row["id"]: row["fcm_token"] for row in rows}


async def _run_broadcast(order_id: str, customer_lat: float, customer_lng: float,
                         item_count: int, total: float, customer_id: str,
                         marketplace_type: str = "grocery") -> None:
    event = asyncio.Event()
    _accept_events[order_id] = event

    async def _on_accept(_: dict) -> None:
        event.set()

    await redis_bus.subscribe(_accept_channel(order_id), _on_accept)

    try:
        for wave_num, (radius_km, timeout_sec) in enumerate(WAVES, start=1):
            async with pool().acquire() as conn:
                row = await conn.fetchrow(
                    "SELECT status, broadcast_store_ids, rejected_store_ids FROM orders WHERE id = $1",
                    order_id,
                )
            if not row or row["status"] not in ("pending", "broadcasting"):
                return

            nearby = await find_nearby_stores_async(customer_lat, customer_lng, radius_km,
                                                     store_type=marketplace_type)
            already_notified: set = set(row["broadcast_store_ids"] or [])
            new_stores = [s for s in nearby if s["store_id"] not in already_notified
                          and not s.get("is_suspended")]
            store_ids = [s["store_id"] for s in new_stores]
            all_store_ids = list(already_notified) + store_ids

            tokens_map = await _get_store_fcm_tokens(store_ids)
            tokens = list(tokens_map.values())
            log.info("[BROADCAST] order=%s wave=%s radius=%skm nearby=%s eligible=%s tokens=%s",
                     order_id, wave_num, radius_km, len(nearby), len(store_ids), len(tokens))

            async with pool().acquire() as conn:
                await conn.execute("""
                    UPDATE orders SET
                        status = 'broadcasting',
                        broadcast_wave = $2,
                        broadcast_radius_km = $3,
                        broadcast_store_ids = $4::jsonb,
                        broadcast_started_at = $5
                    WHERE id = $1
                """, order_id, wave_num, radius_km, all_store_ids, now_ms())

            if tokens:
                send_new_order_to_stores(tokens, order_id, item_count, total)

            try:
                await asyncio.wait_for(event.wait(), timeout=timeout_sec)
            except asyncio.TimeoutError:
                continue

            async with pool().acquire() as conn:
                fresh = await conn.fetchrow("SELECT status FROM orders WHERE id = $1", order_id)
            if fresh and fresh["status"] == "accepted":
                return
            event.clear()

        # All waves exhausted — fail the order
        async with pool().acquire() as conn:
            await conn.execute(
                "UPDATE orders SET status = 'failed', failure_reason = 'no_stores_available' WHERE id = $1",
                order_id,
            )
        async with pool().acquire() as conn:
            row = await conn.fetchrow("SELECT fcm_token FROM users WHERE uid = $1", customer_id)
        customer_token = (row["fcm_token"] if row else "") or ""
        send_order_failed_to_customer(customer_token, order_id)

    except asyncio.CancelledError:
        raise
    except Exception as e:
        log.warning("broadcast for %s errored: %s", order_id, e)
    finally:
        _accept_events.pop(order_id, None)
        await redis_bus.unsubscribe(_accept_channel(order_id), _on_accept)


def start_broadcast(order_id: str, customer_lat: float, customer_lng: float,
                    item_count: int, total: float, customer_id: str,
                    marketplace_type: str = "grocery") -> None:
    loop = asyncio.get_event_loop()
    task = loop.create_task(
        _run_broadcast(order_id, customer_lat, customer_lng, item_count, total,
                       customer_id, marketplace_type)
    )
    _active_broadcasts[order_id] = task
    task.add_done_callback(lambda _: _active_broadcasts.pop(order_id, None))


async def signal_order_accepted(order_id: str) -> None:
    event = _accept_events.get(order_id)
    if event is not None:
        event.set()
    await redis_bus.publish(_accept_channel(order_id), {"event": "accepted"})


async def atomic_accept_order(order_id: str, store_id: str) -> bool:
    """
    PostgreSQL atomic UPDATE: only the first store wins.
    The WHERE status='broadcasting' clause acts as the guard — PostgreSQL's
    row-level lock ensures exactly one concurrent UPDATE succeeds.
    """
    async with pool().acquire() as conn:
        row = await conn.fetchrow("""
            UPDATE orders
            SET status = 'accepted',
                accepted_by_store_id = $2,
                accepted_at = $3
            WHERE id = $1 AND status = 'broadcasting'
            RETURNING id, accepted_by_store_id
        """, order_id, store_id, now_ms())
    return row is not None and row["accepted_by_store_id"] == store_id


def cancel_broadcast(order_id: str) -> None:
    task = _active_broadcasts.pop(order_id, None)
    if task:
        task.cancel()
