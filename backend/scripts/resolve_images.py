#!/usr/bin/env python3
"""
DHAV image resolver — finds ONE real, stable, verified image URL for every
category / subcategory / product NAME used by build_seed.py.

Why this exists:
  build_seed.py used to point images at LoremFlickr (random photos, often broken).
  This script instead resolves each name to a REAL photo on Wikimedia Commons
  (permanent upload.wikimedia.org URLs — free, no API key, never rotate) and
  HTTP-verifies every URL returns an actual image, so the seed has ZERO broken images.

Sources, in priority order:
  1. image_overrides.json  → hand-pinned exact/branded URLs (always win).
  2. Wikimedia Commons     → relevance-scored search on a (curated) query, verified.

Output:
  image_map.resolved.json  → { "<name>": "<verified url>", ... }
  build_seed.py reads this. Re-running is resumable: already-resolved names are
  skipped (use --refresh <name> or delete the entry to redo one).

Run:
  python scripts/resolve_images.py            # resolve everything still missing
  python scripts/resolve_images.py --report   # show coverage / what's unresolved
"""
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OVERRIDES_FILE = os.path.join(HERE, "image_overrides.json")
RESOLVED_FILE = os.path.join(HERE, "image_map.resolved.json")
UA = "DHAV-seed-image-resolver/1.0 (https://dhav.app; contact admin@dhav.app)"

# ── curated query hints ──────────────────────────────────────────────────────
# Many product names are ambiguous to an image search ("Onion" → onion flowers,
# "Pav" → a place name). Map the tricky ones to a query that yields the right photo.
# Anything not listed searches on its own (generic) name + a marketplace hint word.
QUERY_HINTS = {
    # grocery / produce
    "Onion": "red onion bulb", "Potato": "potato tuber", "Tomato": "tomato fruit red",
    "Cauliflower": "cauliflower head", "Lady Finger": "okra vegetable", "Green Capsicum": "green bell pepper",
    "Spinach": "spinach leaves", "Coriander": "coriander cilantro bunch", "Mint": "mint leaves herb",
    "Curry Leaves": "curry leaves", "Pav": "pav bread bun", "Poha": "flattened rice poha",
    "Besan": "gram flour besan", "Maida": "wheat flour", "Whole Wheat Atta": "wheat flour atta",
    "Multigrain Atta": "multigrain flour", "Basmati Rice": "basmati rice grains", "Kolam Rice": "white rice grains",
    "Idli Rice": "white rice", "Toor Dal": "toor dal pigeon pea split", "Moong Dal": "moong dal mung",
    "Chana Dal": "chana dal split chickpea", "Rajma": "kidney beans rajma", "Kabuli Chana": "chickpeas kabuli",
    "Cow Ghee": "ghee clarified butter", "Buffalo Ghee": "ghee jar", "Sunflower Oil": "sunflower cooking oil bottle",
    "Groundnut Oil": "peanut oil bottle", "Mustard Oil": "mustard oil bottle", "Olive Oil": "olive oil bottle",
    "Turmeric Powder": "turmeric powder", "Red Chilli Powder": "red chilli powder", "Garam Masala": "garam masala spice",
    "Coriander Powder": "coriander powder", "Cumin Seeds": "cumin seeds", "Full Cream Milk": "milk glass bottle",
    "Toned Milk": "milk packet", "Cow Milk": "milk", "Brown Bread": "brown bread loaf", "Milk Bread": "bread loaf",
    "Fresh Paneer": "paneer cheese cubes", "Curd": "yogurt curd bowl", "Greek Yogurt": "greek yogurt",
    "Farm Eggs": "chicken eggs", "Brown Eggs": "brown eggs",
    # snacks / drinks
    "Classic Salted Chips": "potato chips", "Aloo Bhujia": "bhujia namkeen", "Kurkure Masala": "corn snack",
    "Cola": "cola soft drink bottle", "Orange Juice": "orange juice glass", "Mango Drink": "mango juice",
    "Soda": "soda lemon drink", "Premium Tea": "tea leaves", "Instant Coffee": "instant coffee jar",
    "Green Tea Bags": "green tea bag",
    # fruits
    "Alphonso Mango": "alphonso mango", "Kesar Mango": "mango fruit", "Langra Mango": "mango",
    "Watermelon": "watermelon fruit", "Muskmelon": "muskmelon cantaloupe", "Litchi": "lychee fruit",
    "Strawberry": "strawberry fruit", "Robusta Banana": "banana fruit", "Yelakki Banana": "banana",
    "Red Banana": "red banana", "Shimla Apple": "red apple fruit", "Kashmiri Apple": "apple fruit",
    "Green Apple": "green apple", "Nagpur Orange": "orange fruit", "Sweet Lime": "sweet lime mosambi",
    "Dragon Fruit": "dragon fruit pitaya", "Kiwi": "kiwifruit", "Blueberry": "blueberries",
    "Avocado": "avocado fruit", "Pineapple": "pineapple fruit", "Tender Coconut": "tender coconut",
    "Papaya": "papaya fruit", "Pomegranate": "pomegranate fruit", "Guava": "guava fruit",
    "Custard Apple": "custard apple sitaphal", "Sapota (Chikoo)": "sapodilla chikoo",
    # electronics (generic product-type photos; brand-exact via overrides)
    "5G Smartphone 128GB": "smartphone", "Pro Smartphone 256GB": "smartphone black",
    "Budget Smartphone 64GB": "smartphone", "TWS Earbuds": "wireless earbuds", "ANC Earbuds": "earbuds case",
    "Bluetooth Headphone": "headphones", "Over-Ear ANC Headphone": "over ear headphones",
    "Portable Bluetooth Speaker": "bluetooth speaker", "AMOLED Smart Watch": "smartwatch",
    "Fitness Band": "fitness band tracker", "Thin & Light Laptop i5": "laptop computer",
    "Gaming Laptop RTX": "gaming laptop", "Wireless Keyboard": "computer keyboard", "Gaming Mouse": "computer mouse",
    "10000mAh Power Bank": "power bank", "32\" HD Smart TV": "television flat screen",
    "43\" FHD Smart TV": "television", "55\" 4K Smart TV": "television", "Android Tablet 10\"": "tablet computer",
    "Smart LED Bulb": "led bulb", "Mixer Grinder 750W": "mixer grinder", "Electric Kettle": "electric kettle",
    "Beard Trimmer": "beard trimmer", "Hair Dryer": "hair dryer", "Dual Band WiFi Router": "wifi router",
    # pharmacy (generic — exact medicine boxes via overrides)
    "Paracetamol 500mg": "paracetamol tablets", "Ibuprofen 400mg": "ibuprofen tablets",
    "Pain Relief Spray": "spray bottle", "Pain Balm": "ointment tube", "Cough Syrup": "syrup bottle medicine",
    "Hand Sanitizer": "hand sanitizer bottle", "Surgical Mask": "surgical face mask", "N95 Mask": "n95 respirator mask",
    "Sanitary Pads": "sanitary pad", "Baby Diapers": "diaper", "Glucometer Kit": "glucometer blood glucose",
    "BP Monitor": "blood pressure monitor", "Digital Thermometer": "digital thermometer",
    "Pulse Oximeter": "pulse oximeter", "Whey Protein": "protein powder tub",
}

# marketplace hint appended to the search when a name has no curated query
MARKET_HINT = {"grocery": "food", "fruits": "fruit", "electronics": "device", "pharmacy": "medicine"}

# reject obviously-wrong files (logos, scientific/diseased shots, accessories, etc.)
BAD_WORDS = ("logo", "icon", "map", "diagram", "chart", "coat of arms", "flag",
             "signature", "barcode", "qr code", "patent", "graph", "symbol",
             "bacteria", "disease", "colonization", "colonisation", "rotten", "mould",
             "mold", "fungus", "infection", "microscope", "histolog", "cross section",
             "cross-section", "anamorphic", "lens", "accessory", "sprouting", "decay",
             "pest", "insect", "larva", "skeleton", "anatomy", "blueprint", "schematic",
             "x-ray", "molecule", "chemical structure", "specimen", "herbarium")

# words that signal a clean studio / product shot → small bonus
GOOD_WORDS = ("white background", "isolated", "raw", "fresh", "product", "packaging",
              "pack", "bottle", "box", "studio")


def _load(path, default):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return default


def _commons_search(query, limit=12):
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": "filetype:bitmap " + query, "gsrnamespace": 6, "gsrlimit": limit,
        "prop": "imageinfo", "iiprop": "url|mime|size", "iiurlwidth": 640,
    })
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    return list(data.get("query", {}).get("pages", {}).values())


def _score(title, ii, query):
    """Higher = more relevant. Title-word overlap + size sanity, penalise junk."""
    t = title.lower()
    if any(b in t for b in BAD_WORDS):
        return -100
    if ii.get("mime") not in ("image/jpeg", "image/png"):
        return -100
    w, hh = ii.get("width", 0), ii.get("height", 0)
    if w < 200 or hh < 200:
        return -50
    qwords = [w for w in re.sub(r"[^a-z0-9 ]", " ", query.lower()).split() if len(w) > 2]
    overlap = sum(1 for w in qwords if w in t)
    score = overlap * 10
    if overlap == 0:          # title shares nothing with the query → almost always wrong
        return -10
    if any(g in t for g in GOOD_WORDS):
        score += 5
    # prefer roughly square-ish product shots, reasonable resolution
    if 0.6 <= (w / hh if hh else 0) <= 1.8:
        score += 3
    if w >= 600:
        score += 2
    return score


def _verify(url):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA}, method="GET")
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status == 200 and r.headers.get("Content-Type", "").startswith("image/")
    except Exception:
        return False


def resolve_one(name, market):
    query = QUERY_HINTS.get(name) or f"{name} {MARKET_HINT.get(market, '')}".strip()
    try:
        pages = _commons_search(query)
    except Exception as e:
        print(f"   ! search error for {name!r}: {e}")
        return None
    cand = []
    for p in pages:
        ii = (p.get("imageinfo") or [{}])[0]
        u = ii.get("thumburl") or ii.get("url")
        if not u:
            continue
        cand.append((_score(p.get("title", ""), ii, query), u))
    cand.sort(reverse=True)
    for sc, u in cand:
        if sc <= 0:
            break
        if _verify(u):
            return u
    return None


def all_names():
    """Yield (name, market) for every category, subcategory and base product name."""
    sys.path.insert(0, HERE)
    import build_seed as b
    seen = set()
    for market, cats in b.MARKETS.items():
        for cat_name, subs in cats:
            for key in [cat_name]:
                if key not in seen:
                    seen.add(key); yield key, market
            for sub_name, products in subs.items():
                if sub_name not in seen:
                    seen.add(sub_name); yield sub_name, market
                for (pname, *_rest) in products:
                    if pname not in seen:
                        seen.add(pname); yield pname, market


def main():
    overrides = _load(OVERRIDES_FILE, {}).get("overrides", {})
    resolved = _load(RESOLVED_FILE, {})
    names = list(all_names())

    if "--report" in sys.argv:
        miss = [n for n, _ in names if n not in overrides and n not in resolved]
        print(f"names total={len(names)} overridden={sum(1 for n,_ in names if n in overrides)} "
              f"resolved={sum(1 for n,_ in names if n in resolved)} MISSING={len(miss)}")
        for n in miss[:60]:
            print("   -", n)
        return

    # overrides always win — copy them in
    for n, u in overrides.items():
        resolved[n] = u

    todo = [(n, m) for n, m in names if n not in resolved]
    print(f"{len(names)} names | already {len(names)-len(todo)} | resolving {len(todo)} via Commons…")
    for i, (n, m) in enumerate(todo, 1):
        u = resolve_one(n, m)
        if u:
            resolved[n] = u
            print(f"  [{i}/{len(todo)}] OK   {n}  ->  {u[:70]}")
        else:
            print(f"  [{i}/{len(todo)}] MISS {n}  (no relevant verified image)")
        if i % 10 == 0:  # checkpoint
            with open(RESOLVED_FILE, "w", encoding="utf-8") as f:
                json.dump(resolved, f, indent=1, ensure_ascii=False)
        time.sleep(0.3)  # be polite to Commons

    with open(RESOLVED_FILE, "w", encoding="utf-8") as f:
        json.dump(resolved, f, indent=1, ensure_ascii=False)
    ok = sum(1 for n, _ in names if n in resolved)
    print(f"\nDone. resolved {ok}/{len(names)} names -> {RESOLVED_FILE}")


if __name__ == "__main__":
    main()
