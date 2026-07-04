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


# Built-in fallback verticals — served if the marketplaces table is missing/empty
# (e.g. before migration 008 is run). The customer app also has these as defaults.
_DEFAULT_MARKETPLACES = [
    {"wire": "grocery", "name": "DHAV", "tab_label": "DHAV", "emoji": "🛍️",
     "color_primary": "#1E88E5", "color_primary_dark": "#1565C0", "color_accent": "#42A5F5",
     "color_header_top": "#2196F3", "color_header_bottom": "#1565C0", "color_tint": "#E3F2FD",
     "sort_order": 0, "is_enabled": True},
    {"wire": "fruits", "name": "Fresh Fruits", "tab_label": "Fresh Fruits", "emoji": "🍉",
     "color_primary": "#2E7D32", "color_primary_dark": "#1B5E20", "color_accent": "#43A047",
     "color_header_top": "#43A047", "color_header_bottom": "#2E7D32", "color_tint": "#E8F5E9",
     "sort_order": 1, "is_enabled": True},
    {"wire": "electronics", "name": "Electronics", "tab_label": "Electronics", "emoji": "🎧",
     "color_primary": "#1A237E", "color_primary_dark": "#0D1551", "color_accent": "#3949AB",
     "color_header_top": "#3949AB", "color_header_bottom": "#1A237E", "color_tint": "#E8EAF6",
     "sort_order": 2, "is_enabled": True},
    {"wire": "pharmacy", "name": "Pharmacy", "tab_label": "Pharmacy", "emoji": "💊",
     "color_primary": "#00897B", "color_primary_dark": "#00695C", "color_accent": "#00ACC1",
     "color_header_top": "#00ACC1", "color_header_bottom": "#00897B", "color_tint": "#E0F2F1",
     "sort_order": 3, "is_enabled": True},
]


@router.get("/fees")
async def get_fees():
    """Public fee card so the apps never hardcode amounts. The customer bill =
    items + platform_fee_flat + handling_charge + donation + delivery (₹0 while
    delivery_fee_mode is "free")."""
    from config import get_settings
    s = get_settings()
    return {
        "platform_fee_flat": s.platform_fee_flat,
        "handling_charge": s.handling_charge_flat,
        "delivery_fee_mode": s.delivery_fee_mode,
        "base_delivery_fee": s.base_delivery_fee if s.delivery_fee_mode != "free" else 0.0,
        "delivery_fee_per_km": s.delivery_fee_per_km if s.delivery_fee_mode == "per_km" else 0.0,
    }


@router.get("/search")
async def search_catalog(
    q: str = Query(..., min_length=1, max_length=80),
    marketplace_type: str = Query("grocery"),
    limit: int = Query(20, le=50),
):
    """Typo-tolerant, ranked product search (public — powers the customer
    Search tab). Runs in Postgres with pg_trgm (migration 015):
      • prefix matches first ("mil" → Milk before Buttermilk),
      • then substring matches on name/brand/hindi/marathi,
      • then trigram similarity for typos ("mlik" → Milk),
    ordered by rating within each band. Also returns matching CATEGORY names
    so the app can offer "browse Dal & Pulses" shortcuts."""
    term = q.strip()
    if not term:
        return {"items": [], "category_matches": []}
    like = f"%{term}%"
    prefix = f"{term}%"

    async with pool().acquire() as conn:
        rows = await conn.fetch("""
            SELECT *,
                   (name ILIKE $3)                       AS is_prefix,
                   (name ILIKE $2 OR brand ILIKE $2
                    OR name_hindi ILIKE $2
                    OR name_marathi ILIKE $2)            AS is_substr,
                   similarity(name, $1)                  AS sim
              FROM catalog_items
             WHERE is_active = true
               AND marketplace_type = $4
               AND (
                     name ILIKE $2 OR brand ILIKE $2
                  OR name_hindi ILIKE $2 OR name_marathi ILIKE $2
                  OR similarity(name, $1) > 0.25
                  OR similarity(brand, $1) > 0.35
               )
             ORDER BY is_prefix DESC, is_substr DESC, sim DESC,
                      rating DESC NULLS LAST
             LIMIT $5
        """, term, like, prefix, marketplace_type, limit)
        cat_rows = await conn.fetch("""
            SELECT id, name, marketplace_type FROM categories
             WHERE is_enabled = true AND marketplace_type = $2
               AND (name ILIKE $1 OR similarity(name, $3) > 0.3)
             ORDER BY sort_order LIMIT 5
        """, like, marketplace_type, term)

    items = []
    for r in rows:
        d = dict(r)
        d.pop("is_prefix", None)
        d.pop("is_substr", None)
        d.pop("sim", None)
        items.append(d)
    return {
        "items": items,
        "category_matches": [dict(r) for r in cat_rows],
    }


@router.get("/popular")
async def popular_items(
    marketplace_type: str = Query("grocery"),
    limit: int = Query(10, le=30),
):
    """Most-rated products for the search screen's idle state (replaces the
    old hardcoded 'popular searches' word list). Cached 5 min."""
    cache_key = f"popular:{marketplace_type}:{limit}"
    cached = catalog_cache.get(cache_key)
    if cached is not None:
        return {"items": cached}
    async with pool().acquire() as conn:
        rows = await conn.fetch("""
            SELECT * FROM catalog_items
             WHERE is_active = true AND marketplace_type = $1
             ORDER BY rating_count DESC NULLS LAST, rating DESC NULLS LAST
             LIMIT $2
        """, marketplace_type, limit)
    items = [dict(r) for r in rows]
    catalog_cache.set(cache_key, items, ttl=CATALOG_TTL)
    return {"items": items}


@router.get("/barcode/{code}")
async def lookup_barcode(
    code: str,
    _: TokenVerifyResponse = Depends(require_role("store_owner", "admin")),
):
    """Barcode scan resolution for the store app's add-product flow.

    1. If the barcode is already in the GLOBAL catalog → return that item so the
       store just adds it to its inventory (no duplicate submission).
    2. Else look it up across free public product databases (Open Food Facts →
       Open Beauty Facts → Open Products Facts → optional UPCitemdb) and return
       a `prefill` for the submission form.
    3. Nothing found → `prefill: null` — the owner fills the form manually.
    """
    from services.barcode_lookup import lookup_barcode as external_lookup

    clean = code.strip()
    async with pool().acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM catalog_items WHERE barcode = $1 AND barcode <> ''", clean)
    if row:
        return {"found_in_catalog": True, "item": dict(row)}

    prefill = await external_lookup(clean)
    return {
        "found_in_catalog": False,
        "prefill": prefill,
        "source": (prefill or {}).get("source"),
    }


@router.get("/marketplaces")
async def get_marketplaces():
    """DB-driven marketplace verticals (admin-configurable). Falls back to the
    built-in 4 if the table is missing/empty so the app always renders."""
    cached = catalog_cache.get("marketplaces")
    if cached is not None:
        return {"marketplaces": cached}
    rows = []
    try:
        async with pool().acquire() as conn:
            rows = await conn.fetch(
                "SELECT * FROM marketplaces WHERE is_enabled = true "
                "ORDER BY sort_order, name")
    except Exception:
        rows = []
    data = [dict(r) for r in rows] or _DEFAULT_MARKETPLACES
    catalog_cache.set("marketplaces", data, ttl=CATEGORY_TTL)
    return {"marketplaces": data}


@router.get("/categories")
async def get_categories(marketplace_type: str = Query(None)):
    """DB-driven categories (admin-managed) for a marketplace, enabled + ordered.

    Falls back to legacy derived category strings only if the categories table is
    empty (e.g. before the seed is run), so older clients keep working.
    """
    cache_key = f"categories:{marketplace_type or 'all'}"
    cached = catalog_cache.get(cache_key)
    if cached is not None:
        return {"categories": cached}

    async with pool().acquire() as conn:
        if marketplace_type:
            rows = await conn.fetch(
                """SELECT * FROM categories
                   WHERE is_enabled = true AND marketplace_type = $1
                   ORDER BY sort_order, name""", marketplace_type)
        else:
            rows = await conn.fetch(
                """SELECT * FROM categories WHERE is_enabled = true
                   ORDER BY marketplace_type, sort_order, name""")

    categories = [dict(r) for r in rows]
    if not categories:
        # Legacy fallback: derive from item category strings.
        items = await _get_catalog_node()
        names = sorted({v["category"] for v in items.values() if v.get("category")})
        categories = [{"id": n, "name": n, "marketplace_type": "grocery",
                       "image_url": "", "sort_order": 0, "is_enabled": True} for n in names]

    catalog_cache.set(cache_key, categories, ttl=CATEGORY_TTL)
    return {"categories": categories}


@router.get("/subcategories")
async def get_subcategories(
    category_id: str = Query(None),
    marketplace_type: str = Query(None),
):
    """Subcategories for a category (the left vertical rail on the category page)."""
    async with pool().acquire() as conn:
        if category_id:
            rows = await conn.fetch(
                """SELECT * FROM subcategories WHERE is_enabled = true AND category_id = $1
                   ORDER BY sort_order, name""", category_id)
        elif marketplace_type:
            rows = await conn.fetch(
                """SELECT * FROM subcategories WHERE is_enabled = true AND marketplace_type = $1
                   ORDER BY sort_order, name""", marketplace_type)
        else:
            rows = await conn.fetch(
                "SELECT * FROM subcategories WHERE is_enabled = true ORDER BY sort_order, name")
    return {"subcategories": [dict(r) for r in rows]}


@router.get("/items")
async def get_items(
    category: str = Query(None),
    category_id: str = Query(None),
    subcategory_id: str = Query(None),
    marketplace_type: str = Query(None),
    brand: str = Query(None),
    search: str = Query(None),
    limit: int = Query(50, le=500),
):
    items_node = await _get_catalog_node()
    results = []
    for item_id, data in items_node.items():
        if marketplace_type and (data.get("marketplace_type") or "grocery") != marketplace_type:
            continue
        if category and data.get("category") != category:
            continue
        if category_id and data.get("category_id") != category_id:
            continue
        if subcategory_id and data.get("subcategory_id") != subcategory_id:
            continue
        if brand and (data.get("brand") or "").lower() != brand.lower():
            continue
        if search:
            q = search.lower()
            if (q not in (data.get("name") or "").lower()
                    and q not in (data.get("brand") or "").lower()
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
    marketplace_type: str = Query(None),
):
    stores = await find_nearby_stores_async(lat, lng, radius_km, store_type=marketplace_type)

    async def _enrich(s):
        store_node = await _get_store_node(s["store_id"])
        return {
            "store_id": s["store_id"],
            "name": store_node.get("shop_name") or store_node.get("name") or "Kirana Store",
            "area": store_node.get("area", ""),
            "store_type": store_node.get("store_type", "grocery"),
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
    category_id: str = Query(None),
    subcategory_id: str = Query(None),
    marketplace_type: str = Query(None),
):
    nearby_stores = await find_nearby_stores_async(lat, lng, radius_km, store_type=marketplace_type)
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
        if marketplace_type and (data.get("marketplace_type") or "grocery") != marketplace_type:
            continue
        if category and data.get("category") != category:
            continue
        if category_id and data.get("category_id") != category_id:
            continue
        if subcategory_id and data.get("subcategory_id") != subcategory_id:
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
    images = data.get("images") or ([data["image_url"]] if data.get("image_url") else [])
    primary = data.get("image_url") or (images[0] if images else "")
    async with pool().acquire() as conn:
        await conn.execute("""
            INSERT INTO catalog_items (
                id, name, name_hindi, name_marathi, category, marketplace_type,
                category_id, subcategory_id, brand, sku, description, price, mrp,
                discount_percent, stock_quantity, unit, image_url, images, specs,
                is_active, created_at
            ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,true,$20)
        """, item_id,
            data.get("name"), data.get("name_hindi", ""), data.get("name_marathi", ""),
            data.get("category", ""), data.get("marketplace_type", "grocery"),
            data.get("category_id"), data.get("subcategory_id"),
            data.get("brand", ""), data.get("sku", ""), data.get("description", ""),
            float(data.get("price", 0)), float(data.get("mrp", 0)),
            float(data.get("discount_percent", 0)), int(data.get("stock_quantity", 0)),
            data.get("unit"), primary, images, data.get("specs", {}), now_ms())
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
