"""
Geofencing via PostgreSQL.

Previous design stored a separate Firebase RTDB node `geofence_index/{geohash}/{store_id}`.
New design: every store row has a `geohash6` column. Finding nearby stores is a direct
SQL query — no separate index table needed, and no sync/async split.

index_store_geofence / remove_store_from_geofence_index are kept as no-ops for callers
that haven't been updated yet; the actual open/closed state is read live from the
stores table in every query.
"""
import math

import pygeohash as geohash

from services.geo import haversine_km
from config import get_settings

settings = get_settings()
PRECISION = settings.geohash_precision  # 6 = ~1.2 km cells


def _encode(lat: float, lng: float) -> str:
    return geohash.encode(lat, lng, precision=PRECISION)


def _cells_covering_radius(lat: float, lng: float, radius_km: float) -> list[str]:
    """Return all geohash-6 cells that could contain a store within radius_km."""
    center = _encode(lat, lng)
    _, _, lat_err, lng_err = geohash.decode_exactly(center)
    cell_h_km = max(2 * lat_err * 111.0, 0.01)
    cell_w_km = max(2 * lng_err * 111.0 * math.cos(math.radians(lat)), 0.01)
    steps_lat = int(math.ceil(radius_km / cell_h_km)) + 1
    steps_lng = int(math.ceil(radius_km / cell_w_km)) + 1
    cells: set[str] = set()
    for dy in range(-steps_lat, steps_lat + 1):
        for dx in range(-steps_lng, steps_lng + 1):
            cells.add(_encode(lat + dy * 2 * lat_err, lng + dx * 2 * lng_err))
    return list(cells)


async def find_nearby_stores_async(customer_lat: float, customer_lng: float,
                                   radius_km: float,
                                   store_type: str | None = None) -> list[dict]:
    """Return open, active, non-suspended stores within radius_km.

    When ``store_type`` is given (one of grocery/fruits/electronics/pharmacy) the
    result is restricted to stores of that marketplace type — this is what keeps
    an electronics order from ever reaching a grocery store, and vice-versa.
    """
    from services.db import pool
    cells = _cells_covering_radius(customer_lat, customer_lng, radius_km)
    async with pool().acquire() as conn:
        rows = await conn.fetch("""
            SELECT id AS store_id,
                   (location->>'lat')::float AS lat,
                   (location->>'lng')::float AS lng,
                   is_active, is_verified,
                   COALESCE(store_type, 'grocery') AS store_type,
                   COALESCE(is_suspended, false) AS is_suspended
            FROM stores
            WHERE geohash6 = ANY($1)
              AND is_open = true
              AND is_active = true
              AND NOT COALESCE(is_suspended, false)
              AND ($2::text IS NULL OR COALESCE(store_type, 'grocery') = $2)
        """, cells, store_type)

    results = []
    for row in rows:
        dist = haversine_km(customer_lat, customer_lng, row["lat"], row["lng"])
        if dist <= radius_km:
            results.append({**dict(row), "distance_km": round(dist, 3)})
    results.sort(key=lambda x: x["distance_km"])
    return results


async def find_all_stores_in_radius_async(customer_lat: float, customer_lng: float,
                                          radius_km: float) -> list[dict]:
    """Return ALL stores in radius (including inactive/suspended) — for map display."""
    from services.db import pool
    cells = _cells_covering_radius(customer_lat, customer_lng, radius_km)
    async with pool().acquire() as conn:
        rows = await conn.fetch("""
            SELECT id AS store_id,
                   (location->>'lat')::float AS lat,
                   (location->>'lng')::float AS lng,
                   is_active, is_verified,
                   COALESCE(is_suspended, false) AS is_suspended
            FROM stores
            WHERE geohash6 = ANY($1)
        """, cells)

    results = []
    for row in rows:
        dist = haversine_km(customer_lat, customer_lng, row["lat"], row["lng"])
        if dist <= radius_km:
            results.append({**dict(row), "distance_km": round(dist, 3)})
    results.sort(key=lambda x: x["distance_km"])
    return results


# ── No-op stubs kept for callers that call these explicitly ───────────────────
# The geofence is now derived from stores.geohash6 + is_open dynamically in SQL.
# Opening/closing a store updates is_open in the stores table; the next query
# picks it up automatically — no separate index record to maintain.

def index_store_geofence(store_id: str, lat: float, lng: float,
                          is_active: bool = True, is_verified: bool = False,
                          is_suspended: bool = False, zone_id: str = "") -> str:
    return _encode(lat, lng)


def remove_store_from_geofence_index(store_id: str, lat: float, lng: float) -> None:
    pass
