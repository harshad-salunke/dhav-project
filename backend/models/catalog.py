from pydantic import BaseModel
from typing import Optional, List, Dict, Any


class CatalogItem(BaseModel):
    item_id: str
    name: str
    name_hindi: Optional[str] = None
    name_marathi: Optional[str] = None
    category: str
    marketplace_type: str = "grocery"
    category_id: Optional[str] = None
    subcategory_id: Optional[str] = None
    brand: Optional[str] = None
    sku: Optional[str] = None
    description: Optional[str] = None
    unit: str
    price: float = 0.0
    mrp: float = 0.0
    discount_percent: float = 0.0
    stock_quantity: int = 0
    image_url: Optional[str] = None
    images: List[str] = []
    specs: Dict[str, Any] = {}
    is_active: bool = True


class CatalogItemCreateRequest(BaseModel):
    name: str
    name_hindi: Optional[str] = None
    name_marathi: Optional[str] = None
    category: Optional[str] = None
    marketplace_type: str = "grocery"
    category_id: Optional[str] = None
    subcategory_id: Optional[str] = None
    brand: Optional[str] = None
    sku: Optional[str] = None
    description: Optional[str] = None
    unit: str
    price: float = 0.0
    mrp: float = 0.0
    discount_percent: float = 0.0
    stock_quantity: int = 0
    image_url: Optional[str] = None
    images: List[str] = []
    specs: Dict[str, Any] = {}


class CategoryRequest(BaseModel):
    marketplace_type: str
    name: str
    image_url: Optional[str] = ""
    sort_order: int = 0
    is_enabled: bool = True


class SubcategoryRequest(BaseModel):
    category_id: str
    marketplace_type: Optional[str] = None
    name: str
    image_url: Optional[str] = ""
    sort_order: int = 0
    is_enabled: bool = True
