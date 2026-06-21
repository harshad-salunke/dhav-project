from pydantic import BaseModel
from typing import Optional, List


class StoreLocation(BaseModel):
    lat: float
    lng: float
    geohash: Optional[str] = None


class OperatingHours(BaseModel):
    open: str   # "09:00"
    close: str  # "22:00"


class CustomItem(BaseModel):
    custom_item_id: str
    store_id: str
    name: str
    price: float
    unit: str
    image_url: Optional[str] = None
    is_available: bool = True


class DeliveryBoy(BaseModel):
    delivery_boy_id: str
    store_id: str
    name: str
    phone: str
    profile_photo_url: Optional[str] = None
    google_account_email: str
    is_active: bool = True
    current_order_id: Optional[str] = None
    created_at: Optional[int] = None


class Store(BaseModel):
    store_id: str
    owner_uid: str
    owner_name: str
    shop_name: str
    store_type: str = "grocery"   # grocery | fruits | electronics | pharmacy
    phone: str
    email: str
    shop_photo_url: Optional[str] = None
    address: str
    location: StoreLocation
    is_open: bool = False
    is_active: bool = True
    is_verified: bool = False
    is_suspended: bool = False
    suspension_end_date: Optional[int] = None   # epoch ms
    strike_count: int = 0
    total_strikes: int = 0
    available_item_ids: List[str] = []
    operating_hours: Optional[OperatingHours] = None
    self_delivery: bool = False   # owner delivers own orders (shares live GPS) — no delivery partner
    total_orders_accepted: int = 0
    total_orders_failed: int = 0
    onboarded_by: Optional[str] = None          # admin uid
    rating: float = 0.0
    fcm_token: Optional[str] = None
    onboarding_date: Optional[int] = None       # epoch ms
    created_at: Optional[int] = None


class StoreCreateRequest(BaseModel):
    owner_uid: str
    owner_name: str
    shop_name: str
    phone: str
    email: str
    address: str
    lat: float
    lng: float
    operating_hours: Optional[OperatingHours] = None


class StoreSelfRegisterRequest(BaseModel):
    owner_name: str
    shop_name: str
    store_type: str = "grocery"   # grocery | fruits | electronics | pharmacy (mandatory in UI)
    phone: str
    address: str
    lat: float
    lng: float
    operating_hours: Optional[OperatingHours] = None
    self_delivery: bool = False


class StoreProfileUpdateRequest(BaseModel):
    shop_name: Optional[str] = None
    owner_name: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    operating_hours: Optional[OperatingHours] = None
    self_delivery: Optional[bool] = None


class StoreToggleRequest(BaseModel):
    is_open: bool


class StoreFCMTokenRequest(BaseModel):
    fcm_token: str
