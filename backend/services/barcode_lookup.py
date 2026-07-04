"""
Barcode → product-metadata lookup over FREE public databases, with fallback.

Sources, tried in order until one has a usable product name:
  1. Open Food Facts     (groceries/FMCG — best Indian coverage, no key)
  2. Open Beauty Facts   (personal care/cosmetics — same API shape)
  3. Open Products Facts (everything else — same API shape)
  4. UPCitemdb trial     (100 req/day, disabled by default via config flag)

All *Facts sources share one client (base-URL list). Results are normalized to
a single `prefill` dict the store app pours into the add-product form:
    {name, brand, description, quantity_text, image_urls[], source}

Lookups are cached in the in-process TTLCache for 24 h — store owners in one
area scan the same FMCG barcodes over and over, and the public APIs are
rate-limited, so never hit them twice for the same code in a day.

Etiquette: Open*Facts asks API users to send an identifying User-Agent.
"""
import asyncio

import httpx

from config import get_settings
from services.cache import catalog_cache

# Identify ourselves to the public APIs (Open Food Facts policy).
_USER_AGENT = "DHAV-KiranaApp/1.0 (dhav-backend; harshadsalunke2002@gmail.com)"

# Open*Facts family — identical API shape, one client loop.
_FACTS_BASES = [
    ("openfoodfacts", "https://world.openfoodfacts.org"),
    ("openbeautyfacts", "https://world.openbeautyfacts.org"),
    ("openproductsfacts", "https://world.openproductsfacts.org"),
]
_FACTS_FIELDS = ("product_name,brands,generic_name,quantity,"
                 "image_url,image_front_url,image_ingredients_url,image_nutrition_url,"
                 "ingredients_text,allergens,nutriscore_grade,nutriments")

# Which per-100g nutriment values we surface, with friendly labels + units.
# These land in the product's `specs` map — the customer app already renders
# specs as highlight chips + the "View details" sheet.
_NUTRIMENT_LABELS = [
    ("energy-kcal_100g", "Energy (per 100g)", "kcal"),
    ("fat_100g", "Fat (per 100g)", "g"),
    ("saturated-fat_100g", "Saturated Fat (per 100g)", "g"),
    ("carbohydrates_100g", "Carbohydrates (per 100g)", "g"),
    ("sugars_100g", "Sugars (per 100g)", "g"),
    ("fiber_100g", "Fibre (per 100g)", "g"),
    ("proteins_100g", "Protein (per 100g)", "g"),
    ("salt_100g", "Salt (per 100g)", "g"),
]


def _specs_from_facts(product: dict) -> dict[str, str]:
    """Distil the Open*Facts extras (ingredients, allergens, nutrition,
    Nutri-Score) into the flat {label: value} shape of catalog_items.specs."""
    specs: dict[str, str] = {}

    ingredients = _clean(product.get("ingredients_text"))
    if ingredients:
        specs["Ingredients"] = ingredients[:600]

    allergens = _clean(product.get("allergens"))
    if allergens:
        # API sometimes returns tags like "en:gluten,en:milk" — strip prefixes.
        cleaned = ", ".join(
            a.split(":")[-1].strip().capitalize()
            for a in allergens.split(",") if a.strip())
        if cleaned:
            specs["Allergens"] = cleaned

    nutriments = product.get("nutriments") or {}
    for key, label, unit in _NUTRIMENT_LABELS:
        v = nutriments.get(key)
        if v is None:
            continue
        try:
            num = float(v)
        except (TypeError, ValueError):
            continue
        # trim "13.0" → "13" but keep "77.3"
        text = f"{num:g}"
        specs[label] = f"{text} {unit}"

    grade = _clean(product.get("nutriscore_grade"))
    if grade and grade.lower() in "abcde":
        specs["Nutri-Score"] = grade.upper()

    return specs

_PER_SOURCE_TIMEOUT = 4.0   # seconds per API
_CACHE_TTL = 24 * 3600      # 24 h
_MAX_IMAGES = 3             # product images are capped at 3 platform-wide


def _clean(v) -> str:
    return str(v).strip() if v else ""


def _normalize_facts(product: dict, source: str) -> dict | None:
    name = _clean(product.get("product_name")) or _clean(product.get("generic_name"))
    if not name:
        return None
    images: list[str] = []
    for key in ("image_url", "image_front_url", "image_ingredients_url", "image_nutrition_url"):
        u = _clean(product.get(key))
        if u and u not in images:
            images.append(u)
    return {
        "name": name,
        "brand": _clean(product.get("brands")).split(",")[0].strip(),
        "description": _clean(product.get("generic_name")),
        "quantity_text": _clean(product.get("quantity")),
        "image_urls": images[:_MAX_IMAGES],
        # Ingredients / allergens / per-100g nutrition / Nutri-Score, already in
        # the {label: value} shape of catalog_items.specs.
        "specs": _specs_from_facts(product),
        "source": source,
    }


def _normalize_upcitemdb(item: dict) -> dict | None:
    name = _clean(item.get("title"))
    if not name:
        return None
    specs: dict[str, str] = {}
    if _clean(item.get("model")):
        specs["Model"] = _clean(item.get("model"))
    if _clean(item.get("color")):
        specs["Colour"] = _clean(item.get("color"))
    if _clean(item.get("weight")):
        specs["Weight"] = _clean(item.get("weight"))
    return {
        "name": name,
        "brand": _clean(item.get("brand")),
        "description": _clean(item.get("description")),
        "quantity_text": _clean(item.get("size")),
        "image_urls": [u for u in (item.get("images") or []) if u][:_MAX_IMAGES],
        "specs": specs,
        "source": "upcitemdb",
    }


async def _try_facts(client: httpx.AsyncClient, source: str, base: str, code: str) -> dict | None:
    try:
        resp = await client.get(
            f"{base}/api/v2/product/{code}.json",
            params={"fields": _FACTS_FIELDS},
            timeout=_PER_SOURCE_TIMEOUT,
        )
        if resp.status_code != 200:
            return None
        data = resp.json()
        if data.get("status") != 1 or not data.get("product"):
            return None
        return _normalize_facts(data["product"], source)
    except Exception:
        return None  # timeout / network / bad JSON → just fall through


async def _try_upcitemdb(client: httpx.AsyncClient, code: str) -> dict | None:
    try:
        resp = await client.get(
            "https://api.upcitemdb.com/prod/trial/lookup",
            params={"upc": code},
            timeout=_PER_SOURCE_TIMEOUT,
        )
        if resp.status_code != 200:
            return None
        items = resp.json().get("items") or []
        return _normalize_upcitemdb(items[0]) if items else None
    except Exception:
        return None


async def lookup_barcode(code: str) -> dict | None:
    """Try each free source in order; return the normalized prefill dict of the
    first hit, or None when no source knows the barcode. Cached for 24 h
    (misses too, so a burst of rescans of an unknown code stays local)."""
    code = code.strip()
    if not code.isdigit() or not 6 <= len(code) <= 14:
        return None  # not a plausible EAN/UPC

    cache_key = f"barcode:{code}"
    cached = catalog_cache.get(cache_key)
    if cached is not None:
        return cached or None  # {} sentinel = cached miss

    result: dict | None = None
    async with httpx.AsyncClient(headers={"User-Agent": _USER_AGENT}) as client:
        for source, base in _FACTS_BASES:
            result = await _try_facts(client, source, base, code)
            if result:
                break
        if result is None and get_settings().barcode_upcitemdb_enabled:
            result = await _try_upcitemdb(client, code)

    catalog_cache.set(cache_key, result or {}, ttl=_CACHE_TTL)
    return result


if __name__ == "__main__":  # manual smoke test: python -m services.barcode_lookup 8901063092730
    import sys
    print(asyncio.run(lookup_barcode(sys.argv[1] if len(sys.argv) > 1 else "8901063092730")))
