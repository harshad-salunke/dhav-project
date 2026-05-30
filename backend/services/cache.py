import time
import threading
from typing import Any, Optional


class TTLCache:
    """Thread-safe in-memory cache with per-key TTL (seconds)."""

    def __init__(self):
        self._data: dict[str, tuple[Any, float]] = {}
        self._lock = threading.Lock()

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
            self._data[key] = (value, time.monotonic() + ttl)

    def delete(self, key: str) -> None:
        with self._lock:
            self._data.pop(key, None)

    def clear(self) -> None:
        with self._lock:
            self._data.clear()


# Module-level singleton — imported by routers
catalog_cache = TTLCache()

CATALOG_TTL = 300      # 5 minutes
CATEGORY_TTL = 600     # 10 minutes (categories change rarely)
STORE_NODE_TTL = 120   # 2 minutes (store name/location rarely changes mid-session)
USER_PROFILE_TTL = 120 # 2 minutes (role/active status rarely changes mid-session)
