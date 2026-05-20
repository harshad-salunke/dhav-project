import pygeohash as geohash
from firebase_admin import db

from services.geo import haversine_km
from config import get_settings

settings = get_settings()
PRECISION = settings.geohash_precision  # 6 = ~1.2 km cells


def _encode(lat: float, lng: float) -> str:
    return geohash.encode(lat, lng, precision=PRECISION)


def index_store_geofence(store_id: str, lat: float, lng: float,
                          is_active: bool = True, is_verified: bool = False,
                          is_suspended: bool = False, zone_id: str = "") -> str:
    gh = _encode(lat, lng)
    db.reference(f"geofence_index/{gh}/{store_id}").set({
        "store_id": store_id,
        "lat": lat,
        "lng": lng,
        "is_active": is_active,
        "is_verified": is_verified,
        "is_suspended": is_suspended,
        "zone_id": zone_id,
    })
    return gh


def remove_store_from_geofence_index(store_id: str, lat: float, lng: float) -> None:
    gh = _encode(lat, lng)
    db.reference(f"geofence_index/{gh}/{store_id}").delete()


def _get_adjacent(hash_str: str, direction: str) -> str:
    """pygeohash has no get_adjacent; derive neighbor via decode+offset+encode."""
    lat, lng, lat_err, lng_err = geohash.decode_exactly(hash_str)
    precision = len(hash_str)
    if direction == "top":
        return geohash.encode(lat + 2 * lat_err, lng, precision=precision)
    if direction == "bottom":
        return geohash.encode(lat - 2 * lat_err, lng, precision=precision)
    if direction == "right":
        return geohash.encode(lat, lng + 2 * lng_err, precision=precision)
    if direction == "left":
        return geohash.encode(lat, lng - 2 * lng_err, precision=precision)
    raise ValueError(f"Unknown direction: {direction}")


def _get_all_neighbors(center: str) -> list:
    """Return the 8 surrounding geohash cells (cardinal + diagonal)."""
    top    = _get_adjacent(center, "top")
    bottom = _get_adjacent(center, "bottom")
    right  = _get_adjacent(center, "right")
    left   = _get_adjacent(center, "left")
    return [
        top, bottom, right, left,
        _get_adjacent(top,    "right"),
        _get_adjacent(top,    "left"),
        _get_adjacent(bottom, "right"),
        _get_adjacent(bottom, "left"),
    ]


def find_nearby_stores(customer_lat: float, customer_lng: float,
                        radius_km: float) -> list:
    center_hash = _encode(customer_lat, customer_lng)
    cells_to_check = [center_hash] + _get_all_neighbors(center_hash)

    results = []
    for cell in cells_to_check:
        node = db.reference(f"geofence_index/{cell}").get()
        if not node:
            continue
        for store_id, data in node.items():
            if not data.get("is_active"):
                continue
            if data.get("is_suspended"):
                continue
            dist = haversine_km(customer_lat, customer_lng, data["lat"], data["lng"])
            if dist <= radius_km:
                results.append({**data, "distance_km": round(dist, 3)})

    results.sort(key=lambda x: x["distance_km"])
    return results


def find_all_stores_in_radius(customer_lat: float, customer_lng: float,
                               radius_km: float) -> list:
    """Like find_nearby_stores but includes inactive/suspended stores (for map display)."""
    center_hash = _encode(customer_lat, customer_lng)
    cells_to_check = [center_hash] + _get_all_neighbors(center_hash)

    results = []
    for cell in cells_to_check:
        node = db.reference(f"geofence_index/{cell}").get()
        if not node:
            continue
        for store_id, data in node.items():
            dist = haversine_km(customer_lat, customer_lng, data["lat"], data["lng"])
            if dist <= radius_km:
                results.append({**data, "distance_km": round(dist, 3)})

    results.sort(key=lambda x: x["distance_km"])
    return results
