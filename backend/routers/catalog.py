from fastapi import APIRouter, Query, HTTPException, Depends
from firebase_admin import db

from models.catalog import CatalogItem, CatalogItemCreateRequest
from models.user import TokenVerifyResponse
from dependencies import get_current_user, require_role
from services.geofencing import find_nearby_stores
from utils.helpers import new_id

router = APIRouter()


@router.get("/categories")
async def get_categories():
    items_node = db.reference("catalog_items").get() or {}
    categories = sorted({v["category"] for v in items_node.values() if v.get("is_active")})
    return {"categories": categories}


@router.get("/items")
async def get_items(
    category: str = Query(None),
    search: str = Query(None),
    limit: int = Query(50, le=200),
):
    items_node = db.reference("catalog_items").get() or {}
    results = []
    for item_id, data in items_node.items():
        if not data.get("is_active", True):
            continue
        if category and data.get("category") != category:
            continue
        if search:
            q = search.lower()
            if (q not in data.get("name", "").lower()
                    and q not in data.get("name_hindi", "").lower()
                    and q not in data.get("name_marathi", "").lower()):
                continue
        results.append({**data, "item_id": item_id})
    return {"items": results[:limit], "total": len(results)}


@router.get("/items/nearby")
async def get_nearby_items(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(2.0, le=5.0),
    category: str = Query(None),
):
    nearby_stores = find_nearby_stores(lat, lng, radius_km)
    if not nearby_stores:
        return {"items": [], "stores_found": 0}

    available_item_ids: set[str] = set()
    for store_data in nearby_stores:
        store_node = db.reference(f"stores/{store_data['store_id']}").get() or {}
        for item_id in store_node.get("available_item_ids", []):
            available_item_ids.add(item_id)

    items_node = db.reference("catalog_items").get() or {}
    results = []
    for item_id, data in items_node.items():
        if item_id not in available_item_ids:
            continue
        if not data.get("is_active", True):
            continue
        if category and data.get("category") != category:
            continue
        results.append({**data, "item_id": item_id})

    return {"items": results, "stores_found": len(nearby_stores)}


@router.post("/items", status_code=201)
async def create_catalog_item(
    body: CatalogItemCreateRequest,
    _: TokenVerifyResponse = Depends(require_role("admin")),
):
    item_id = new_id()
    item_data = {**body.model_dump(), "item_id": item_id, "is_active": True}
    db.reference(f"catalog_items/{item_id}").set(item_data)
    return {"item_id": item_id}


@router.patch("/items/{item_id}")
async def update_catalog_item(
    item_id: str,
    body: dict,
    _: TokenVerifyResponse = Depends(require_role("admin")),
):
    ref = db.reference(f"catalog_items/{item_id}")
    if not ref.get():
        raise HTTPException(status_code=404, detail="Item not found")
    ref.update(body)
    return {"status": "updated"}


@router.delete("/items/{item_id}")
async def deactivate_catalog_item(
    item_id: str,
    _: TokenVerifyResponse = Depends(require_role("admin")),
):
    ref = db.reference(f"catalog_items/{item_id}")
    if not ref.get():
        raise HTTPException(status_code=404, detail="Item not found")
    ref.update({"is_active": False})
    return {"status": "deactivated"}
