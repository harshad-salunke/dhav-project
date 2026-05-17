from pydantic import BaseModel
from typing import Optional, List


class LatLng(BaseModel):
    lat: float
    lng: float


class GeofenceZone(BaseModel):
    zone_id: str
    zone_name: str
    center_lat: float
    center_lng: float
    radius_km: float
    polygon_coordinates: List[LatLng] = []
    active_store_count: int = 0
    is_active: bool = True
    created_at: Optional[int] = None


class StoreGeofenceIndex(BaseModel):
    geohash: str
    store_id: str
    lat: float
    lng: float
    is_active: bool = True
    is_verified: bool = False
    is_suspended: bool = False
    zone_id: Optional[str] = None


class StrikeLog(BaseModel):
    strike_id: str
    store_id: str
    order_id: str
    reason: str
    strike_number: int
    action_taken: str   # warning | suspended_7_days | permanent_ban
    created_at: Optional[int] = None
