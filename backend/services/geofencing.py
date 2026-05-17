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


def find_nearby_stores(customer_lat: float, customer_lng: float,
                        radius_km: float) -> list[dict]:
    center_hash = _encode(customer_lat, customer_lng)
    neighbors = geohash.neighbors(center_hash)
    cells_to_check = [center_hash] + list(neighbors.values())

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
