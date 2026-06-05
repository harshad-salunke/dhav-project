"""
Redis Pub/Sub bus — the message backbone that lets DHAV run on MORE THAN ONE
server process at the same time (horizontal scaling).

THE PROBLEM IT SOLVES
---------------------
Today the live-location hub and the catalog cache live in a Python dict inside
ONE process. The moment Railway runs 2+ workers:
  * A delivery boy connected to worker A can't reach a customer on worker B
    (their in-memory channels are different objects).
  * Worker A's catalog cache can be stale after worker B handles an admin edit.

Redis Pub/Sub is a tiny shared "radio station". Any worker can `publish` to a
channel; every worker that `subscribe`d to it receives the message. That lets
all workers act as one logical server.

GRACEFUL FALLBACK
-----------------
If REDIS_URL is not set (e.g. local dev, single worker) everything still works:
publish becomes a no-op and the caller falls back to its in-process path. So you
can develop without Redis and turn it on in production by setting one env var.
"""
import asyncio
import json
import logging
from typing import Awaitable, Callable, Optional

try:
    from redis import asyncio as aioredis  # redis-py 5.x ships asyncio
except ImportError:  # redis not installed — bus stays disabled
    aioredis = None

from config import get_settings

settings = get_settings()
log = logging.getLogger("redis_bus")

_redis: Optional["aioredis.Redis"] = None
_pubsub = None
_reader_task: Optional[asyncio.Task] = None
_enabled = False

# channel name -> set of async handlers invoked with the decoded dict payload
_handlers: dict[str, set[Callable[[dict], Awaitable[None]]]] = {}
_lock = asyncio.Lock()


def is_enabled() -> bool:
    return _enabled


def client() -> Optional["aioredis.Redis"]:
    return _redis


async def init_redis() -> None:
    """Connect to Redis and start the background message reader. Safe to call
    when REDIS_URL is unset — the bus simply stays disabled."""
    global _redis, _pubsub, _reader_task, _enabled

    url = (getattr(settings, "redis_url", "") or "").strip()
    if not url or aioredis is None:
        log.info("Redis bus DISABLED (no REDIS_URL or redis pkg) — single-worker mode")
        return

    try:
        _redis = aioredis.from_url(url, encoding="utf-8", decode_responses=True)
        await _redis.ping()
        _pubsub = _redis.pubsub()
        # Subscribe to a no-op channel so .listen() has something to attach to.
        await _pubsub.subscribe("__dhav_bus__")
        _reader_task = asyncio.create_task(_reader_loop())
        _enabled = True
        log.info("Redis bus ENABLED — multi-worker mode active")
    except Exception as e:  # network down, bad URL — degrade, don't crash
        log.warning("Redis connect failed (%s) — falling back to single-worker mode", e)
        _redis = None
        _pubsub = None
        _enabled = False


async def close_redis() -> None:
    global _enabled
    _enabled = False
    if _reader_task:
        _reader_task.cancel()
    if _pubsub:
        try:
            await _pubsub.aclose()
        except Exception:
            pass
    if _redis:
        try:
            await _redis.aclose()
        except Exception:
            pass


async def publish(channel: str, payload: dict) -> bool:
    """Send a message to all workers subscribed to `channel`. Returns False when
    the bus is disabled so the caller can fall back to its local path."""
    if not _enabled or _redis is None:
        return False
    try:
        await _redis.publish(channel, json.dumps(payload))
        return True
    except Exception as e:
        log.warning("publish to %s failed: %s", channel, e)
        return False


async def subscribe(channel: str, handler: Callable[[dict], Awaitable[None]]) -> None:
    """Register `handler` to be called for every message on `channel`."""
    if not _enabled or _pubsub is None:
        return
    async with _lock:
        first = channel not in _handlers
        _handlers.setdefault(channel, set()).add(handler)
        if first:
            await _pubsub.subscribe(channel)


async def unsubscribe(channel: str, handler: Callable[[dict], Awaitable[None]]) -> None:
    if not _enabled or _pubsub is None:
        return
    async with _lock:
        handlers = _handlers.get(channel)
        if not handlers:
            return
        handlers.discard(handler)
        if not handlers:
            _handlers.pop(channel, None)
            try:
                await _pubsub.unsubscribe(channel)
            except Exception:
                pass


async def _reader_loop() -> None:
    """Single background task: pull messages off the shared pubsub connection and
    dispatch each to the handlers registered for its channel."""
    assert _pubsub is not None
    try:
        async for message in _pubsub.listen():
            if message.get("type") != "message":
                continue
            channel = message.get("channel")
            handlers = _handlers.get(channel)
            if not handlers:
                continue
            try:
                payload = json.loads(message["data"])
            except (ValueError, TypeError):
                continue
            # Copy the set — handlers may unsubscribe while iterating.
            for handler in list(handlers):
                try:
                    await handler(payload)
                except Exception as e:
                    log.warning("handler for %s errored: %s", channel, e)
    except asyncio.CancelledError:
        pass
    except Exception as e:
        log.warning("reader loop stopped: %s", e)
