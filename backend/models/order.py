from pydantic import BaseModel
from typing import Optional, List


class OrderAddress(BaseModel):
    address_id: Optional[str] = None
    label: str = "Home"
    flat_building: Optional[str] = None
    street: Optional[str] = None
    area: str
    city: str = "Pune"
    pincode: Optional[str] = None
    lat: float
    lng: float


class OrderItem(BaseModel):
    item_id: str
    item_name: str
    quantity: float
    unit: str
    price_per_unit: float
    total_price: float
    is_catalog_item: bool = True


class Order(BaseModel):
    order_id: str
    customer_id: str
    customer_address: OrderAddress
    items: List[OrderItem]
    total_product_amount: float
    delivery_fee: float
    total_customer_amount: float
    platform_fee_percentage: float = 5.0
    platform_fee_amount: float = 0.0
    platform_fee_settled: bool = False
    payment_method: str = "cod"
    status: str = "pending"
    # pending | broadcasting | accepted | packed | out_for_delivery | delivered | failed | cancelled
    broadcast_radius_km: float = 1.0
    broadcast_wave: int = 1
    broadcast_started_at: Optional[int] = None
    broadcast_store_ids: List[str] = []
    rejected_store_ids: List[str] = []
    timed_out_store_ids: List[str] = []
    accepted_by_store_id: Optional[str] = None
    accepted_at: Optional[int] = None
    assigned_delivery_boy_id: Optional[str] = None
    delivery_boy_name: Optional[str] = None
    delivery_boy_phone: Optional[str] = None
    ws_channel_id: Optional[str] = None
    estimated_delivery_minutes: int = 30
    delivered_at: Optional[int] = None
    failure_reason: Optional[str] = None
    geofence_zone_id: Optional[str] = None
    created_at: Optional[int] = None


class PlaceOrderRequest(BaseModel):
    customer_address: OrderAddress
    items: List[OrderItem]
    # Which marketplace this cart belongs to (grocery|fruits|electronics|pharmacy).
    # Drives type-correct broadcast routing — the order only ever reaches stores of
    # this type.
    marketplace_type: str = "grocery"
    # ── Checkout extras (optional; captured on the order) ──
    gstin: str = ""
    donation_amount: float = 0.0
    handling_charge: float = 0.0
    delivery_instructions: List[str] = []


class DirectOrderRequest(PlaceOrderRequest):
    store_id: str


class AssignDeliveryBoyRequest(BaseModel):
    delivery_boy_id: str


class RejectOrderRequest(BaseModel):
    reason: Optional[str] = None


ORDER_TRANSITIONS = {
    "accepted": ["packed"],
    "packed": ["out_for_delivery"],
    "out_for_delivery": ["delivered"],
}
