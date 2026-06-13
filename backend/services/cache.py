import time
import threading
from typing import Any, Optional


class TTLCache:
    """Thread-safe in-memory cache with per-key TTL (seconds).

    L1 cache: lives inside ONE process and is microsecond-fast. Bounded by
    `max_size` so per-request keys (e.g. user:{uid}) can never grow memory
    without limit — the oldest entry is evicted when the cap is hit.
    """

    def __init__(self, max_size: int = 5000):
        self._data: dict[str, tuple[Any, float]] = {}
        self._lock = threading.Lock()
        self._max_size = max_size

    def get(self, key: str) -> Optional[Any]:
        with self._lock:
            entry = self._data.get(key)
            if entry is None:
                return None
            value, expires_at = entry
            if time.monotonic() > expires_at:
                del self._data[key]
                return None
            return value

    def set(self, key: str, value: Any, ttl: int = 300) -> None:
        with self._lock:
            # Bound memory: evict oldest insertion when at capacity (dicts keep
            # insertion order in Python 3.7+).
            if key not in self._data and len(self._data) >= self._max_size:
                oldest = next(iter(self._data))
                self._data.pop(oldest, None)
            self._data[key] = (value, time.monotonic() + ttl)

    def delete(self, key: str) -> None:
        with self._lock:
            self._data.pop(key, None)

    def clear(self) -> None:
        with self._lock:
            self._data.clear()

    def clear_prefix(self, prefix: str) -> None:
        with self._lock:
            for k in [k for k in self._data if k.startswith(prefix)]:
                self._data.pop(k, None)


# Module-level singleton — imported by routers
catalog_cache = TTLCache()

CATALOG_TTL = 300      # 5 minutes
CATEGORY_TTL = 600     # 10 minutes (categories change rarely)
STORE_NODE_TTL = 120   # 2 minutes (store name/location rarely changes mid-session)
USER_PROFILE_TTL = 120 # 2 minutes (role/active status rarely changes mid-session)
HOME_CONFIG_TTL = 300  # 5 minutes — admin home-UI config (Remote Config read)

# Cache key for the customer-app home-section Remote Config read.
HOME_CONFIG_KEY = "home_config"

# Cross-worker cache invalidation channel (Redis Pub/Sub).
CACHE_INVALIDATE_CHANNEL = "cache:invalidate"


def _clear_local(target: str) -> None:
    """Clear L1 keys for a logical target. Used both directly and by the
    cross-worker subscriber below."""
    if target == "catalog":
        catalog_cache.delete("catalog_all")
        catalog_cache.delete("catalog_categories")
    elif target == "home_config":
        catalog_cache.delete(HOME_CONFIG_KEY)
    elif target.startswith("store:"):
        catalog_cache.delete(target)
    elif target == "all":
        catalog_cache.clear()


async def invalidate(target: str) -> None:
    """Invalidate a cache target on THIS worker and broadcast to all others.

    `target` is "catalog", "store:{id}", or "all". With Redis enabled every
    worker drops the same keys, so an admin edit on one worker is never served
    stale from another.
    """
    _clear_local(target)
    from services import redis_bus  # lazy: keep cache importable without redis
    await redis_bus.publish(CACHE_INVALIDATE_CHANNEL, {"target": target})


async def init_invalidation_subscriber() -> None:
    """Subscribe to cross-worker invalidation messages (called on startup)."""
    from services import redis_bus

    async def _on_invalidate(payload: dict) -> None:
        target = payload.get("target", "")
        if target:
            _clear_local(target)

    await redis_bus.subscribe(CACHE_INVALIDATE_CHANNEL, _on_invalidate)
