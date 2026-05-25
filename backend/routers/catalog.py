from fastapi import APIRouter, Query, HTTPException, Depends
from firebase_admin import db

from models.catalog import CatalogItem, CatalogItemCreateRequest
from models.user import TokenVerifyResponse
from dependencies import get_current_user, require_role
from services.geofencing import find_nearby_stores, find_all_stores_in_radius
from utils.helpers import new_id

router = APIRouter()


@router.get("/categories")
async def get_categories():
    items_node = db.reference("catalog").get() or {}
    categories = sorted({v["category"] for v in items_node.values() if v.get("is_active")})
    return {"categories": categories}


@router.get("/items")
async def get_items(
    category: str = Query(None),
    search: str = Query(None),
    limit: int = Query(50, le=200),
):
    items_node = db.reference("catalog").get() or {}
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


@router.get("/stores/nearby")
async def get_nearby_stores_list(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(5.0, le=20.0),
):
    stores = find_nearby_stores(lat, lng, radius_km)
    enriched = []
    for s in stores:
        store_node = db.reference(f"stores/{s['store_id']}").get() or {}
        enriched.append({
            "store_id": s["store_id"],
            "name": store_node.get("shop_name") or store_node.get("name") or "Kirana Store",
            "area": store_node.get("area", ""),
            "lat": s["lat"],
            "lng": s["lng"],
            "distance_km": s["distance_km"],
            "is_verified": s.get("is_verified", False),
            "is_active": s.get("is_active", True),
        })
    return {"stores": enriched, "total": len(enriched)}


@router.get("/stores/nearby/all")
async def get_all_nearby_stores(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(5.0, le=20.0),
):
    """Returns all stores in radius including inactive/suspended — used by the zone map."""
    stores = find_all_stores_in_radius(lat, lng, radius_km)
    enriched = []
    for s in stores:
        store_node = db.reference(f"stores/{s['store_id']}").get() or {}
        enriched.append({
            "store_id": s["store_id"],
            "name": store_node.get("shop_name") or store_node.get("name") or "Kirana Store",
            "area": store_node.get("area", ""),
            "lat": s["lat"],
            "lng": s["lng"],
            "distance_km": s["distance_km"],
            "is_verified": s.get("is_verified", False),
            "is_active": s.get("is_active", True),
            "is_suspended": s.get("is_suspended", False),
        })
    return {"stores": enriched, "total": len(enriched)}


@router.get("/stores/{store_id}")
async def get_store_catalog(store_id: str):
    """Public: returns store profile + all catalog items available at that store."""
    store_node = db.reference(f"stores/{store_id}").get()
    if not store_node:
        raise HTTPException(status_code=404, detail="Store not found")

    available_ids = store_node.get("available_item_ids") or []
    items = []
    if available_ids:
        for item_id in available_ids:
            item_data = db.reference(f"catalog/{item_id}").get()
            if item_data and item_data.get("is_active"):
                items.append({**item_data, "item_id": item_id})
    else:
        # store hasn't configured inventory yet — show full active catalog
        catalog_node = db.reference("catalog").get() or {}
        for item_id, data in catalog_node.items():
            if data.get("is_active"):
                items.append({**data, "item_id": item_id})

    loc = store_node.get("location") or {}
    return {
        "store": {
            "store_id": store_id,
            "name": store_node.get("shop_name") or store_node.get("name", "Kirana Store"),
            "area": store_node.get("area", ""),
            "address": store_node.get("address", ""),
            "lat": loc.get("lat", 0.0) if isinstance(loc, dict) else store_node.get("lat", 0.0),
            "lng": loc.get("lng", 0.0) if isinstance(loc, dict) else store_node.get("lng", 0.0),
            "is_active": store_node.get("is_active", False),
            "is_open": store_node.get("is_open", False),
            "is_verified": store_node.get("is_verified", False),
            "is_suspended": store_node.get("is_suspended", False),
            "rating": store_node.get("rating", 0.0),
            "phone": store_node.get("phone", ""),
        },
        "items": items,
        "total": len(items),
    }


@router.get("/items/nearby")
async def get_nearby_items(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(5.0, le=20.0),
    category: str = Query(None),
):
    nearby_stores = find_nearby_stores(lat, lng, radius_km)
    if not nearby_stores:
        return {"items": [], "stores_found": 0}

    available_item_ids: set[str] = set()
    for store_data in nearby_stores:
        store_node = db.reference(f"stores/{store_data['store_id']}").get() or {}
        for item_id in (store_node.get("available_item_ids") or []):
            available_item_ids.add(item_id)

    # If no nearby store has configured its inventory yet, show all active catalog items.
    filter_by_ids = len(available_item_ids) > 0

    items_node = db.reference("catalog").get() or {}
    results = []
    for item_id, data in items_node.items():
        if filter_by_ids and item_id not in available_item_ids:
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
    db.reference(f"catalog/{item_id}").set(item_data)
    return {"item_id": item_id}


@router.patch("/items/{item_id}")
async def update_catalog_item(
    item_id: str,
    body: dict,
    _: TokenVerifyResponse = Depends(require_role("admin")),
):
    ref = db.reference(f"catalog/{item_id}")
    if not ref.get():
        raise HTTPException(status_code=404, detail="Item not found")
    ref.update(body)
    return {"status": "updated"}


@router.delete("/items/{item_id}")
async def deactivate_catalog_item(
    item_id: str,
    _: TokenVerifyResponse = Depends(require_role("admin")),
):
    ref = db.reference(f"catalog/{item_id}")
    if not ref.get():
        raise HTTPException(status_code=404, detail="Item not found")
    ref.update({"is_active": False})
    return {"status": "deactivated"}
