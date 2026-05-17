from pydantic import BaseModel
from typing import Optional


class CatalogItem(BaseModel):
    item_id: str
    name: str
    name_hindi: Optional[str] = None
    name_marathi: Optional[str] = None
    category: str
    unit: str
    price: float = 0.0
    image_url: Optional[str] = None
    is_active: bool = True


class CatalogItemCreateRequest(BaseModel):
    name: str
    name_hindi: Optional[str] = None
    name_marathi: Optional[str] = None
    category: str
    unit: str
    price: float = 0.0
    image_url: Optional[str] = None
