import asyncio
from concurrent.futures import ThreadPoolExecutor

from fastapi import APIRouter, Query, HTTPException, Depends
from firebase_admin import db

from models.catalog import CatalogItem, CatalogItemCreateRequest
from models.user import TokenVerifyResponse
from dependencies import get_current_user, require_role
from services.geofencing import find_nearby_stores, find_all_stores_in_radius
from services.cache import catalog_cache, CATALOG_TTL, CATEGORY_TTL, STORE_NODE_TTL
from utils.helpers import new_id

router = APIRouter()

# Shared thread pool for Firebase blocking calls
_pool = ThreadPoolExecutor(max_workers=8)


def _fb_get(path: str):
    """Blocking Firebase read — run inside executor to avoid blocking the event loop."""
    return db.reference(path).get()


async def _async_fb_get(path: str):
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(_pool, _fb_get, path)


async def _get_store_node(store_id: str) -> dict:
    """Return store node, served from cache when warm."""
    cache_key = f"store:{store_id}"
    cached = catalog_cache.get(cache_key)
    if cached is not None:
        return cached
    data = await _async_fb_get(f"stores/{store_id}") or {}
    catalog_cache.set(cache_key, data, ttl=STORE_NODE_TTL)
    return data


async def _get_catalog_node() -> dict:
    """Return full catalog node, served from cache when warm."""
    cached = catalog_cache.get("catalog_all")
    if cached is not None:
        return cached
    data = await _async_fb_get("catalog") or {}
    catalog_cache.set("catalog_all", data, ttl=CATALOG_TTL)
    return data


@router.get("/categories")
async def get_categories():
    cached = catalog_cache.get("catalog_categories")
    if cached is not None:
        return {"categories": cached}

    items_node = await _get_catalog_node()
    categories = sorted({v["category"] for v in items_node.values() if v.get("is_active")})
    catalog_cache.set("catalog_categories", categories, ttl=CATEGORY_TTL)
    return {"categories": categories}


@router.get("/items")
async def get_items(
    category: str = Query(None),
    search: str = Query(None),
    limit: int = Query(50, le=200),
):
    items_node = await _get_catalog_node()
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

    async def _enrich(s):
        store_node = await _get_store_node(s["store_id"])
        return {
            "store_id": s["store_id"],
            "name": store_node.get("shop_name") or store_node.get("name") or "Kirana Store",
            "area": store_node.get("area", ""),
            "lat": s["lat"],
            "lng": s["lng"],
            "distance_km": s["distance_km"],
            "is_verified": s.get("is_verified", False),
            "is_active": s.get("is_active", True),
        }

    enriched = await asyncio.gather(*[_enrich(s) for s in stores])
    return {"stores": list(enriched), "total": len(enriched)}


@router.get("/stores/nearby/all")
async def get_all_nearby_stores(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(5.0, le=20.0),
):
    """Returns all stores in radius including inactive/suspended — used by the zone map."""
    stores = find_all_stores_in_radius(lat, lng, radius_km)

    async def _enrich(s):
        store_node = await _get_store_node(s["store_id"])
        return {
            "store_id": s["store_id"],
            "name": store_node.get("shop_name") or store_node.get("name") or "Kirana Store",
            "area": store_node.get("area", ""),
            "lat": s["lat"],
            "lng": s["lng"],
            "distance_km": s["distance_km"],
            "is_verified": s.get("is_verified", False),
            "is_active": s.get("is_active", True),
            "is_suspended": s.get("is_suspended", False),
        }

    enriched = await asyncio.gather(*[_enrich(s) for s in stores])
    return {"stores": list(enriched), "total": len(enriched)}


@router.get("/stores/{store_id}")
async def get_store_catalog(store_id: str):
    """Public: returns store profile + all catalog items available at that store."""
    store_node = await _get_store_node(store_id)
    if not store_node:
        raise HTTPException(status_code=404, detail="Store not found")

    available_ids = store_node.get("available_item_ids") or []
    if available_ids:
        # Concurrent reads for all available items
        raw_items = await asyncio.gather(*[_async_fb_get(f"catalog/{iid}") for iid in available_ids])
        items = [
            {**data, "item_id": iid}
            for iid, data in zip(available_ids, raw_items)
            if data and data.get("is_active")
        ]
    else:
        # Store hasn't configured inventory — show full active catalog (served from cache)
        catalog_node = await _get_catalog_node()
        items = [
            {**data, "item_id": iid}
            for iid, data in catalog_node.items()
            if data.get("is_active")
        ]

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

    # Concurrent reads — served from cache when warm
    store_nodes = await asyncio.gather(
        *[_get_store_node(s["store_id"]) for s in nearby_stores]
    )

    available_item_ids: set[str] = set()
    for node in store_nodes:
        if node:
            for item_id in (node.get("available_item_ids") or []):
                available_item_ids.add(item_id)

    filter_by_ids = len(available_item_ids) > 0
    items_node = await _get_catalog_node()

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


# ── Admin write endpoints — invalidate cache on mutation ──────────────────────

@router.post("/items", status_code=201)
async def create_catalog_item(
    body: CatalogItemCreateRequest,
    _: TokenVerifyResponse = Depends(require_role("admin")),
):
    item_id = new_id()
    item_data = {**body.model_dump(), "item_id": item_id, "is_active": True}
    db.reference(f"catalog/{item_id}").set(item_data)
    catalog_cache.delete("catalog_all")
    catalog_cache.delete("catalog_categories")
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
    catalog_cache.delete("catalog_all")
    catalog_cache.delete("catalog_categories")
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
    catalog_cache.delete("catalog_all")
    catalog_cache.delete("catalog_categories")
    return {"status": "deactivated"}
