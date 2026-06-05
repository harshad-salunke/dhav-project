import asyncio

from fastapi import APIRouter, Query, HTTPException, Depends

from models.catalog import CatalogItem, CatalogItemCreateRequest
from models.user import TokenVerifyResponse
from dependencies import get_current_user, require_role
from services.db import pool
from services import cache
from services.geofencing import find_nearby_stores_async, find_all_stores_in_radius_async
from services.cache import catalog_cache, CATALOG_TTL, CATEGORY_TTL, STORE_NODE_TTL
from utils.helpers import new_id, now_ms

router = APIRouter()


async def _get_store_node(store_id: str) -> dict:
    cache_key = f"store:{store_id}"
    cached = catalog_cache.get(cache_key)
    if cached is not None:
        return cached
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM stores WHERE id=$1", store_id)
    data = dict(row) if row else {}
    catalog_cache.set(cache_key, data, ttl=STORE_NODE_TTL)
    return data


async def _get_catalog_node() -> dict:
    cached = catalog_cache.get("catalog_all")
    if cached is not None:
        return cached
    async with pool().acquire() as conn:
        rows = await conn.fetch("SELECT * FROM catalog_items WHERE is_active=true")
    data = {row["id"]: dict(row) for row in rows}
    catalog_cache.set("catalog_all", data, ttl=CATALOG_TTL)
    return data


@router.get("/categories")
async def get_categories():
    cached = catalog_cache.get("catalog_categories")
    if cached is not None:
        return {"categories": cached}
    items = await _get_catalog_node()
    categories = sorted({v["category"] for v in items.values() if v.get("category")})
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
        if category and data.get("category") != category:
            continue
        if search:
            q = search.lower()
            if (q not in (data.get("name") or "").lower()
                    and q not in (data.get("name_hindi") or "").lower()
                    and q not in (data.get("name_marathi") or "").lower()):
                continue
        results.append({**data, "item_id": item_id})
    return {"items": results[:limit], "total": len(results)}


@router.get("/stores/nearby")
async def get_nearby_stores_list(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(5.0, le=20.0),
):
    stores = await find_nearby_stores_async(lat, lng, radius_km)

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
    stores = await find_all_stores_in_radius_async(lat, lng, radius_km)

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
    store_node = await _get_store_node(store_id)
    if not store_node:
        raise HTTPException(status_code=404, detail="Store not found")

    available_ids = store_node.get("available_item_ids") or []
    if available_ids:
        async with pool().acquire() as conn:
            rows = await conn.fetch(
                "SELECT * FROM catalog_items WHERE id = ANY($1) AND is_active=true",
                available_ids,
            )
        items = [{**dict(r), "item_id": r["id"]} for r in rows]
    else:
        catalog_node = await _get_catalog_node()
        items = [{**data, "item_id": iid} for iid, data in catalog_node.items()]

    loc = store_node.get("location") or {}
    return {
        "store": {
            "store_id": store_id,
            "name": store_node.get("shop_name") or store_node.get("name", "Kirana Store"),
            "area": store_node.get("area", ""),
            "address": store_node.get("address", ""),
            "lat": loc.get("lat", 0.0) if isinstance(loc, dict) else 0.0,
            "lng": loc.get("lng", 0.0) if isinstance(loc, dict) else 0.0,
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
    nearby_stores = await find_nearby_stores_async(lat, lng, radius_km)
    if not nearby_stores:
        return {"items": [], "stores_found": 0}

    store_nodes = await asyncio.gather(*[_get_store_node(s["store_id"]) for s in nearby_stores])
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
        if category and data.get("category") != category:
            continue
        results.append({**data, "item_id": item_id})

    return {"items": results, "stores_found": len(nearby_stores)}


# ── Admin write endpoints ──────────────────────────────────────────────────────

@router.post("/items", status_code=201)
async def create_catalog_item(
    body: CatalogItemCreateRequest,
    _: TokenVerifyResponse = Depends(require_role("admin")),
):
    item_id = new_id()
    data = body.model_dump()
    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO catalog_items (id, name, name_hindi, name_marathi, category, price, unit, image_url, is_active, created_at)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true,$9)
        """, item_id,
            data.get("name"), data.get("name_hindi", ""), data.get("name_marathi", ""),
            data.get("category"), data.get("price", 0), data.get("unit"),
            data.get("image_url", ""), now_ms())
    await cache.invalidate("catalog")
    return {"item_id": item_id}


@router.patch("/items/{item_id}")
async def update_catalog_item(
    item_id: str,
    body: dict,
    _: TokenVerifyResponse = Depends(require_role("admin")),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT id FROM catalog_items WHERE id=$1", item_id)
    if not row:
        raise HTTPException(status_code=404, detail="Item not found")

    allowed = {"name", "name_hindi", "name_marathi", "category", "price", "unit", "image_url", "is_active"}
    updates = {k: v for k, v in body.items() if k in allowed}
    if updates:
        fields, vals = [], [item_id]
        for k, v in updates.items():
            vals.append(v)
            fields.append(f"{k}=${len(vals)}")
        vals.append(now_ms())
        fields.append(f"updated_at=${len(vals)}")
        async with pool().acquire() as conn:
            await conn.execute(f"UPDATE catalog_items SET {', '.join(fields)} WHERE id=$1", *vals)
    await cache.invalidate("catalog")
    return {"status": "updated"}


@router.delete("/items/{item_id}")
async def deactivate_catalog_item(
    item_id: str,
    _: TokenVerifyResponse = Depends(require_role("admin")),
):
    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT id FROM catalog_items WHERE id=$1", item_id)
    if not row:
        raise HTTPException(status_code=404, detail="Item not found")
    async with pool().acquire() as conn:
        await conn.execute("UPDATE catalog_items SET is_active=false WHERE id=$1", item_id)
    await cache.invalidate("catalog")
    return {"status": "deactivated"}
