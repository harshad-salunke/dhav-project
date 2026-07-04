#!/usr/bin/env python3
"""
DHAV seed generator → backend/migrations/data_init/ (the ONLY seed output)

Generates a large, production-like dataset for the 4 marketplaces:
    grocery · fruits · electronics · pharmacy

For every marketplace it emits:
  - categories            (admin-managed, image_url, sort_order, enabled)
  - subcategories         (parent category, image_url)
  - catalog_items         (marketplace_type, category_id, subcategory_id, brand, sku,
                           description, unit, price, mrp, discount_percent, stock,
                           images[3-5], specs{}, image_url, group_id variant families,
                           demo rating/rating_count)
  - demo stores           (one+ per marketplace_type near Pune, each stocking its items)

Images: REAL, HTTP-verified photos on a stable CDN (upload.wikimedia.org),
    resolved per name by resolve_images.py (+ image_overrides.json for pinned/
    branded shots) into image_map.resolved.json. No broken/dummy images.

Deterministic: stable IDs + hash-based pricing → re-running produces identical SQL,
and the SQL uses ON CONFLICT DO UPDATE so it is safely re-runnable in Supabase.

Run:  python backend/scripts/build_seed.py
"""
import hashlib
import os
import re
import urllib.parse

MIG_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "migrations"))
NOW = 1718900000000  # fixed epoch ms for determinism


# ── helpers ──────────────────────────────────────────────────────────────────
def slug(*parts: str) -> str:
    s = "_".join(parts).lower()
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    return s


def h(*parts: str) -> int:
    return int(hashlib.md5("|".join(parts).encode()).hexdigest(), 16)


def sql_str(v) -> str:
    if v is None:
        return "NULL"
    return "'" + str(v).replace("'", "''") + "'"


# ── REAL images: load the verified map produced by resolve_images.py ──────────
# Every category / subcategory / product NAME resolves to a real, HTTP-verified
# image on a stable CDN (upload.wikimedia.org). Pinned/branded overrides live in
# image_overrides.json (merged into the resolved file). If a name is somehow
# missing we fall back to a guaranteed-stable per-marketplace photo so the seed
# NEVER contains a broken image.
import json as _json
_RESOLVED_FILE = os.path.join(os.path.dirname(__file__), "image_map.resolved.json")
_OVERRIDES_FILE = os.path.join(os.path.dirname(__file__), "image_overrides.json")
try:
    with open(_RESOLVED_FILE, encoding="utf-8") as _f:
        IMAGE_MAP = _json.load(_f)
except FileNotFoundError:
    IMAGE_MAP = {}
# overrides win over the auto-resolver, applied at generation time (no re-resolve needed)
try:
    with open(_OVERRIDES_FILE, encoding="utf-8") as _f:
        IMAGE_MAP.update({k: v for k, v in (_json.load(_f).get("overrides") or {}).items() if v})
except FileNotFoundError:
    pass

# stable, always-loading fallback per marketplace (real Wikimedia photos)
MARKET_FALLBACK = {
    "grocery":     "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Grocery_store_%28132442271%29.jpeg/960px-Grocery_store_%28132442271%29.jpeg",
    "fruits":      "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/Fruit_stall_in_Barcelona_Market.jpg/960px-Fruit_stall_in_Barcelona_Market.jpg",
    "electronics": "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Consumer_electronics.jpg/960px-Consumer_electronics.jpg",
    "pharmacy":    "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Pharmacy_shelves.jpg/960px-Pharmacy_shelves.jpg",
}


def img_for(name: str, market: str) -> str:
    """The one real, verified image URL for a category/subcategory/product name."""
    return IMAGE_MAP.get(name) or MARKET_FALLBACK.get(market, MARKET_FALLBACK["grocery"])


def imgs(name: str, n: int, market: str = "grocery") -> list[str]:
    """Image list for the product carousel (one verified real image; padded to n)."""
    return [img_for(name, market)]


def price_for(name: str, lo: int, hi: int) -> int:
    span = max(hi - lo, 1)
    return lo + (h("price", name) % span)


def discount_for(name: str) -> int:
    # 0,5,8,10,12,15,18,20,22,25 % — deterministic, most items discounted
    return [0, 5, 8, 10, 12, 15, 18, 20, 22, 25][h("disc", name) % 10]


def stock_for(name: str) -> int:
    return 5 + (h("stock", name) % 95)


# Realistic pack-size SKUs per base unit → (unit, price_multiplier vs the base unit).
# Mirrors the "Select Unit" design (e.g. Aashirvaad Atta 1kg / 5kg / 10kg). Only applied
# to consumable marketplaces (grocery/fruits/pharmacy); electronics stays "1 unit".
PACK_SIZES = {
    "250 g":  [("250 g", 1.0), ("500 g", 1.85)],
    "500 g":  [("250 g", 0.55), ("500 g", 1.0), ("1 kg", 1.9)],
    "1 kg":   [("500 g", 0.55), ("1 kg", 1.0), ("2 kg", 1.9)],
    "2 kg":   [("1 kg", 0.55), ("2 kg", 1.0)],
    "5 kg":   [("1 kg", 0.22), ("5 kg", 1.0), ("10 kg", 1.9)],
    "100 g":  [("100 g", 1.0), ("200 g", 1.85)],
    "200 g":  [("100 g", 0.55), ("200 g", 1.0), ("500 g", 2.3)],
    "500 ml": [("250 ml", 0.55), ("500 ml", 1.0), ("1 L", 1.9)],
    "1 L":    [("500 ml", 0.55), ("1 L", 1.0)],
    "200 ml": [("100 ml", 0.55), ("200 ml", 1.0)],
    "100 ml": [("100 ml", 1.0), ("200 ml", 1.85)],
    "1 kg ":  [("1 kg", 1.0)],
    # pharmacy / medicine pack sizes
    "10 tablets": [("10 tablets", 1.0), ("15 tablets", 1.4), ("30 tablets", 2.7)],
    "15 tablets": [("10 tablets", 0.7), ("15 tablets", 1.0), ("30 tablets", 1.9)],
    "30 tablets": [("15 tablets", 0.55), ("30 tablets", 1.0), ("60 tablets", 1.9)],
    "60 caps":    [("30 caps", 0.55), ("60 caps", 1.0)],
    "60 tablets": [("30 tablets", 0.55), ("60 tablets", 1.0)],
    "10 ml":      [("10 ml", 1.0), ("15 ml", 1.4)],
    "Pack of 30": [("Pack of 10", 0.4), ("Pack of 30", 1.0)],
    "Pack of 10": [("Pack of 10", 1.0), ("Pack of 30", 2.6)],
    "10 pcs":     [("3 pcs", 0.35), ("10 pcs", 1.0)],
    "6 pcs":      [("6 pcs", 1.0), ("12 pcs", 1.9)],
}


def pack_variants(market: str, unit: str, n_brands: int) -> list[tuple[str, float]]:
    """Pack-size SKUs for a product. Bounded so brand-rich items don't explode:
    1 brand → up to 3 sizes, 2 brands → up to 2, 3+ brands → just the listed size."""
    if market == "electronics":
        return [(unit, 1.0)]
    sizes = PACK_SIZES.get(unit, [(unit, 1.0)])
    cap = 3 if n_brands <= 2 else 2
    # keep the listed unit first, then nearest others, capped
    listed = [s for s in sizes if s[0] == unit] or [(unit, 1.0)]
    others = [s for s in sizes if s[0] != unit]
    return (listed + others)[:cap]


# ── content tables ───────────────────────────────────────────────────────────
# Each marketplace → list of (category_name, {subcategory_name: [product, ...]})
# A product is (name, brand, unit, price_lo, price_hi). Description/specs auto-built.

GROCERY = [
    ("Vegetables & Fruits", {
        "Fresh Vegetables": [("Onion", "Farm Fresh", "1 kg", 30, 60), ("Potato", "Farm Fresh", "1 kg", 25, 50),
                              ("Tomato", "Farm Fresh", "1 kg", 25, 55), ("Cauliflower", "Farm Fresh", "1 pc", 25, 45),
                              ("Lady Finger", "Farm Fresh", "500 g", 20, 40), ("Green Capsicum", "Farm Fresh", "250 g", 20, 40)],
        "Leafy & Herbs": [("Spinach", "Farm Fresh", "1 bunch", 15, 30), ("Coriander", "Farm Fresh", "1 bunch", 10, 25),
                          ("Mint", "Farm Fresh", "1 bunch", 10, 20), ("Curry Leaves", "Farm Fresh", "1 bunch", 10, 20)],
        "Daily Fruits": [("Banana", "Fresh", "6 pcs", 30, 50), ("Apple Shimla", "Fresh", "1 kg", 90, 160),
                         ("Pomegranate", "Fresh", "1 kg", 90, 180)],
    }),
    ("Atta, Rice & Dal", {
        "Atta & Flours": [("Whole Wheat Atta", "Aashirvaad", "5 kg", 220, 320), ("Multigrain Atta", "Aashirvaad", "5 kg", 260, 360),
                          ("Besan", "Rajdhani", "1 kg", 80, 130), ("Maida", "Pillsbury", "1 kg", 45, 70)],
        "Rice & Rice Products": [("Basmati Rice", "India Gate", "5 kg", 380, 650), ("Kolam Rice", "Daawat", "5 kg", 280, 420),
                                 ("Poha", "Local", "500 g", 25, 45), ("Idli Rice", "Local", "5 kg", 260, 380)],
        "Dals & Pulses": [("Toor Dal", "Tata Sampann", "1 kg", 120, 180), ("Moong Dal", "Tata Sampann", "1 kg", 110, 170),
                          ("Chana Dal", "Tata Sampann", "1 kg", 90, 140), ("Rajma", "Tata Sampann", "500 g", 70, 120),
                          ("Kabuli Chana", "Tata Sampann", "500 g", 60, 110)],
    }),
    ("Oil, Ghee & Masala", {
        "Edible Oils": [("Sunflower Oil", "Fortune", "1 L", 110, 170), ("Groundnut Oil", "Gemini", "1 L", 160, 230),
                        ("Mustard Oil", "Fortune", "1 L", 130, 190), ("Olive Oil", "Figaro", "500 ml", 350, 520)],
        "Ghee & Vanaspati": [("Cow Ghee", "Amul", "1 L", 480, 650), ("Buffalo Ghee", "Gowardhan", "1 L", 520, 700)],
        "Whole & Ground Spices": [("Turmeric Powder", "Everest", "200 g", 50, 90), ("Red Chilli Powder", "Everest", "200 g", 70, 120),
                                  ("Garam Masala", "MDH", "100 g", 60, 100), ("Coriander Powder", "Catch", "200 g", 50, 90),
                                  ("Cumin Seeds", "Tata Sampann", "200 g", 80, 130)],
    }),
    ("Dairy, Bread & Eggs", {
        "Milk": [("Full Cream Milk", "Amul", "1 L", 60, 75), ("Toned Milk", "Gokul", "1 L", 50, 64),
                 ("Cow Milk", "Chitale", "1 L", 55, 70)],
        "Bread & Pav": [("Brown Bread", "Britannia", "400 g", 35, 55), ("Pav", "Modern", "6 pcs", 25, 40),
                        ("Milk Bread", "Harvest Gold", "400 g", 35, 55)],
        "Paneer & Curd": [("Fresh Paneer", "Amul", "200 g", 80, 120), ("Curd", "Chitale", "400 g", 30, 50),
                          ("Greek Yogurt", "Epigamia", "90 g", 40, 70)],
        "Eggs": [("Farm Eggs", "Eggoz", "6 pcs", 50, 85), ("Brown Eggs", "Eggoz", "6 pcs", 60, 95)],
    }),
    ("Bakery & Biscuits", {
        "Cookies": [("Choco Chip Cookies", "Sunfeast", "120 g", 30, 60), ("Hide & Seek", "Parle", "120 g", 28, 50),
                    ("Good Day Cashew", "Britannia", "200 g", 35, 60)],
        "Cream Biscuits": [("Bourbon", "Britannia", "150 g", 25, 45), ("Oreo", "Cadbury", "120 g", 30, 50)],
        "Rusks & Wafers": [("Suji Rusk", "Parle", "300 g", 40, 70), ("Elaichi Rusk", "Britannia", "300 g", 40, 70)],
    }),
    ("Snacks & Drinks", {
        "Chips & Namkeen": [("Classic Salted Chips", "Lays", "52 g", 20, 35), ("Aloo Bhujia", "Haldiram", "200 g", 50, 90),
                            ("Kurkure Masala", "Kurkure", "90 g", 20, 35), ("Moong Dal", "Haldiram", "200 g", 50, 90)],
        "Cold Drinks & Juices": [("Cola", "Coca-Cola", "750 ml", 35, 50), ("Orange Juice", "Real", "1 L", 90, 130),
                                 ("Mango Drink", "Slice", "600 ml", 35, 55), ("Soda", "Sprite", "750 ml", 35, 50)],
        "Tea, Coffee & More": [("Premium Tea", "Tata Tea", "500 g", 220, 320), ("Instant Coffee", "Nescafe", "100 g", 280, 400),
                               ("Green Tea Bags", "Lipton", "25 bags", 130, 200)],
    }),
    ("Instant & Frozen Food", {
        "Noodles & Pasta": [("Masala Noodles", "Maggi", "70 g", 12, 20), ("Penne Pasta", "Del Monte", "500 g", 90, 140),
                            ("Cup Noodles", "Top Ramen", "70 g", 30, 50)],
        "Ready to Cook": [("Poha Mix", "MTR", "200 g", 40, 70), ("Upma Mix", "MTR", "200 g", 40, 70),
                          ("Gulab Jamun Mix", "Gits", "200 g", 60, 100)],
        "Frozen Snacks": [("Aloo Tikki", "McCain", "400 g", 90, 150), ("French Fries", "McCain", "420 g", 99, 160),
                          ("Veg Spring Roll", "McCain", "300 g", 110, 180)],
    }),
    ("Sauces & Spreads", {
        "Ketchup & Sauces": [("Tomato Ketchup", "Kissan", "950 g", 90, 140), ("Green Chilli Sauce", "Ching's", "190 g", 40, 70),
                             ("Soy Sauce", "Ching's", "200 g", 45, 80)],
        "Jams & Spreads": [("Mixed Fruit Jam", "Kissan", "500 g", 110, 170), ("Peanut Butter", "Pintola", "350 g", 180, 280),
                           ("Chocolate Spread", "Nutella", "350 g", 280, 420)],
        "Honey & Health": [("Pure Honey", "Dabur", "500 g", 180, 280), ("Apple Cider Vinegar", "Kapiva", "500 ml", 250, 380)],
    }),
    ("Home & Cleaning", {
        "Detergents": [("Detergent Powder", "Surf Excel", "1 kg", 110, 170), ("Liquid Detergent", "Ariel", "1 L", 180, 280),
                       ("Dishwash Gel", "Vim", "750 ml", 90, 150)],
        "Cleaners": [("Floor Cleaner", "Lizol", "975 ml", 150, 230), ("Toilet Cleaner", "Harpic", "1 L", 120, 190),
                     ("Glass Cleaner", "Colin", "500 ml", 90, 140)],
        "Fresheners & Repellents": [("Air Freshener", "Odonil", "200 ml", 130, 200), ("Mosquito Repellent", "Good Knight", "45 ml", 70, 110)],
    }),
    ("Personal Care", {
        "Oral Care": [("Toothpaste", ["Colgate", "Closeup", "Sensodyne"], "200 g", 90, 150),
                      ("Toothbrush", ["Oral-B", "Colgate"], "2 pcs", 60, 110),
                      ("Mouthwash", ["Listerine", "Colgate"], "250 ml", 120, 190)],
        "Hair Care": [("Anti-Dandruff Shampoo", ["Head & Shoulders", "Clinic Plus", "Dove"], "340 ml", 250, 380),
                      ("Coconut Hair Oil", ["Parachute", "Dabur"], "300 ml", 90, 150),
                      ("Hair Conditioner", ["Tresemme", "Sunsilk"], "190 ml", 150, 230)],
        "Skin & Body": [("Moisturising Soap", ["Dove", "Lux", "Pears"], "4x100 g", 180, 280),
                        ("Body Lotion", ["Nivea", "Vaseline"], "400 ml", 250, 380),
                        ("Face Wash", ["Himalaya", "Garnier", "Pond's"], "150 ml", 130, 200),
                        ("Talc Powder", ["Pond's", "Yardley"], "300 g", 130, 200)],
    }),
    ("Tea, Coffee & Beverages", {
        "Tea": [("Premium Leaf Tea", ["Tata Tea", "Red Label", "Taj Mahal"], "500 g", 220, 340),
                ("Green Tea Bags", ["Lipton", "Tetley", "Organic India"], "25 bags", 130, 220)],
        "Coffee": [("Instant Coffee", ["Nescafe", "Bru", "Continental"], "100 g", 250, 420),
                   ("Filter Coffee Powder", ["Narasu's", "Cothas"], "500 g", 220, 360)],
        "Health Drinks": [("Malted Health Drink", ["Bournvita", "Horlicks", "Boost"], "500 g", 210, 340)],
    }),
    ("Breakfast & Cereal", {
        "Cereals": [("Corn Flakes", ["Kellogg's", "Bagrry's"], "475 g", 150, 240),
                    ("Muesli", ["Bagrry's", "Kellogg's"], "500 g", 250, 400),
                    ("Oats", ["Quaker", "Saffola"], "1 kg", 150, 260)],
        "Spreads & Honey": [("Mixed Fruit Jam", ["Kissan", "Mala's"], "500 g", 110, 180),
                            ("Pure Honey", ["Dabur", "Patanjali"], "500 g", 180, 300)],
    }),
    ("Chocolates & Sweets", {
        "Chocolates": [("Chocolate Bar", ["Cadbury", "Nestle", "Amul"], "150 g", 80, 160),
                       ("Chocolate Pouch", ["Dairy Milk", "5 Star", "Munch"], "Pack of 10", 90, 180)],
        "Indian Sweets": [("Soan Papdi", ["Haldiram", "Bikano"], "500 g", 110, 200),
                          ("Gulab Jamun Tin", ["Haldiram", "Gits"], "1 kg", 180, 300)],
    }),
    ("Atta Alternatives & Millets", {
        "Millets": [("Bajra Flour", ["Local", "24 Mantra"], "1 kg", 60, 110),
                    ("Jowar Flour", ["Local", "24 Mantra"], "1 kg", 60, 110),
                    ("Ragi Flour", ["Local", "24 Mantra"], "1 kg", 70, 130)],
        "Organic Grains": [("Organic Quinoa", ["24 Mantra", "True Elements"], "500 g", 200, 340),
                           ("Organic Brown Rice", ["24 Mantra"], "1 kg", 120, 200)],
    }),
    ("Pickles & Chutney", {
        "Pickles": [("Mango Pickle", ["Mother's Recipe", "Priya"], "400 g", 90, 160),
                    ("Mixed Pickle", ["Mother's Recipe", "Nilon's"], "400 g", 90, 160)],
        "Chutney & Pastes": [("Ginger Garlic Paste", ["Dabur Hommade", "Ashoka"], "200 g", 50, 90),
                             ("Tamarind Paste", ["Dabur", "Ashoka"], "200 g", 50, 90)],
    }),
    ("Dry Fruits & Nuts", {
        "Nuts": [("Almonds", ["Happilo", "Nutraj"], "200 g", 180, 320),
                 ("Cashew", ["Happilo", "Nutraj"], "200 g", 200, 360)],
        "Dried Fruits": [("Raisins", ["Happilo", "Nutraj"], "200 g", 80, 150),
                         ("Dates", ["Lion", "Happilo"], "500 g", 120, 240)],
    }),
    ("Pooja Needs", {
        "Essentials": [("Agarbatti Pack", ["Cycle", "Zed Black"], "Pack of 100", 50, 110),
                       ("Camphor", ["Mangalam", "Cycle"], "100 g", 70, 140),
                       ("Cotton Wicks", ["Local"], "Pack of 200", 20, 50)],
        "Lamps & Oil": [("Pooja Oil", ["Idhayam", "Local"], "500 ml", 90, 160),
                        ("Diya Pack", ["Local"], "12 pcs", 30, 80)],
    }),
    ("Stationery & Office", {
        "Writing": [("Ball Pen Pack", ["Cello", "Reynolds"], "Pack of 10", 50, 110),
                    ("Notebook", ["Classmate", "Navneet"], "1 unit", 40, 90)],
        "Office Supplies": [("A4 Paper Ream", ["JK", "Century"], "500 sheets", 250, 400),
                            ("Sticky Notes", ["Oddy", "3M"], "1 pack", 50, 120)],
    }),
    ("Pet Care", {
        "Dog Food": [("Adult Dog Food", ["Pedigree", "Drools"], "1.2 kg", 250, 450),
                     ("Dog Biscuits", ["Pedigree", "Choostix"], "500 g", 120, 220)],
        "Cat Food": [("Cat Food", ["Whiskas", "Me-O"], "1.2 kg", 280, 480)],
    }),
    ("Ice Cream & Frozen Desserts", {
        "Tubs & Cones": [("Vanilla Ice Cream Tub", ["Amul", "Kwality Walls", "Vadilal"], "700 ml", 110, 220),
                         ("Choco Cone Pack", ["Cornetto", "Amul"], "4 pcs", 120, 220)],
        "Kulfi & Bars": [("Kulfi Pack", ["Amul", "Vadilal"], "6 pcs", 90, 180),
                         ("Chocobar Pack", ["Amul", "Kwality Walls"], "6 pcs", 90, 180)],
    }),
    ("Frozen & Instant Meals", {
        "Frozen Veg & Snacks": [("Frozen Green Peas", ["Safal", "McCain"], "500 g", 60, 120),
                                ("Veg Cutlet", ["McCain", "ITC"], "400 g", 99, 180)],
        "Ready Meals": [("Ready-to-Eat Dal Makhani", ["MTR", "Haldiram"], "300 g", 80, 150),
                        ("Ready-to-Eat Biryani", ["MTR", "Kohinoor"], "300 g", 90, 170)],
    }),
]

FRUITS = [
    ("Seasonal Fruits", {
        "Mangoes": [("Alphonso Mango", "Konkan", "1 dozen", 400, 800), ("Kesar Mango", "Gujarat", "1 kg", 120, 220),
                    ("Langra Mango", "UP", "1 kg", 90, 160)],
        "Melons": [("Watermelon", "Fresh", "1 pc", 40, 90), ("Muskmelon", "Fresh", "1 kg", 40, 80)],
        "Litchi & Berries": [("Litchi", "Fresh", "500 g", 90, 160), ("Strawberry", "Mahabaleshwar", "200 g", 80, 160)],
    }),
    ("Daily Fruits", {
        "Bananas": [("Robusta Banana", "Fresh", "6 pcs", 30, 55), ("Yelakki Banana", "Fresh", "500 g", 40, 70),
                    ("Red Banana", "Fresh", "4 pcs", 50, 90)],
        "Apples": [("Shimla Apple", "Himachal", "1 kg", 120, 200), ("Kashmiri Apple", "Kashmir", "1 kg", 150, 260),
                   ("Green Apple", "Imported", "4 pcs", 120, 200)],
        "Citrus": [("Nagpur Orange", "Nagpur", "1 kg", 60, 120), ("Sweet Lime", "Fresh", "1 kg", 50, 100),
                   ("Mini Orange", "Fresh", "250 g", 30, 60)],
    }),
    ("Exotic Fruits", {
        "Imported": [("Dragon Fruit", "Imported", "1 pc", 60, 120), ("Kiwi", "Imported", "3 pcs", 70, 130),
                     ("Blueberry", "Imported", "125 g", 200, 380), ("Avocado", "Imported", "1 pc", 80, 150)],
        "Tropical": [("Pineapple", "Fresh", "1 pc", 50, 100), ("Tender Coconut", "Fresh", "1 pc", 40, 80),
                     ("Papaya", "Fresh", "1 kg", 40, 80)],
    }),
    ("Fresh Vegetables", {
        "Everyday Veg": [("Onion", "Farm Fresh", "1 kg", 30, 60), ("Tomato", "Farm Fresh", "1 kg", 25, 55),
                         ("Potato", "Farm Fresh", "1 kg", 25, 50), ("Ginger", "Farm Fresh", "250 g", 25, 50),
                         ("Garlic", "Farm Fresh", "250 g", 30, 60)],
        "Exotic Veg": [("Broccoli", "Farm Fresh", "500 g", 40, 80), ("Zucchini", "Farm Fresh", "500 g", 40, 80),
                       ("Cherry Tomato", "Farm Fresh", "200 g", 40, 80), ("Lettuce", "Farm Fresh", "1 pc", 40, 80)],
    }),
    ("Dry Fruits & Nuts", {
        "Nuts": [("Almonds", "Happilo", "200 g", 180, 320), ("Cashew", "Happilo", "200 g", 200, 360),
                 ("Walnut Kernels", "Happilo", "200 g", 250, 420), ("Pistachio", "Happilo", "200 g", 280, 460)],
        "Dried": [("Raisins", "Happilo", "200 g", 80, 150), ("Dates", "Lion", "500 g", 120, 220),
                  ("Dried Figs", "Happilo", "200 g", 220, 380)],
    }),
    ("Fresh Cuts & Sprouts", {
        "Cut Fruits": [("Mixed Fruit Bowl", "DHAV Fresh", "300 g", 60, 110), ("Cut Pineapple", "DHAV Fresh", "250 g", 50, 90),
                       ("Cut Papaya", "DHAV Fresh", "250 g", 40, 80)],
        "Sprouts & Salads": [("Moong Sprouts", "DHAV Fresh", "200 g", 30, 60), ("Mixed Salad", "DHAV Fresh", "200 g", 40, 80)],
    }),
    ("Juices & Coconut", {
        "Fresh Juice": [("Orange Juice", "DHAV Fresh", "300 ml", 50, 90), ("Watermelon Juice", "DHAV Fresh", "300 ml", 40, 80),
                        ("Mosambi Juice", "DHAV Fresh", "300 ml", 50, 90)],
        "Coconut": [("Tender Coconut", "Fresh", "1 pc", 40, 80), ("Coconut Water Pack", "Cocofly", "200 ml", 30, 60)],
    }),
    ("Flowers & Leaves", {
        "Pooja Flowers": [("Marigold Garland", "Fresh", "1 pc", 20, 50), ("Rose Bunch", "Fresh", "10 pcs", 40, 90),
                          ("Jasmine", "Fresh", "1 string", 20, 50)],
        "Banana Leaves": [("Banana Leaf", "Fresh", "2 pcs", 15, 35), ("Mango Leaves", "Fresh", "1 bunch", 15, 35)],
    }),
    ("Organic Picks", {
        "Organic Fruits": [("Organic Banana", "Organic", "6 pcs", 50, 90), ("Organic Apple", "Organic", "1 kg", 160, 280)],
        "Organic Veg": [("Organic Spinach", "Organic", "1 bunch", 25, 50), ("Organic Tomato", "Organic", "500 g", 30, 60)],
    }),
    ("Seasonal Specials", {
        "Monsoon Picks": [("Jamun", "Fresh", "250 g", 40, 90), ("Corn", "Fresh", "2 pcs", 25, 50),
                          ("Peach", "Fresh", "500 g", 80, 150), ("Plum", "Fresh", "500 g", 70, 140)],
        "Winter Picks": [("Guava", "Fresh", "1 kg", 50, 100), ("Custard Apple", "Fresh", "1 kg", 80, 160),
                         ("Green Peas", "Fresh", "500 g", 40, 90), ("Orange", "Fresh", "1 kg", 60, 120),
                         ("Strawberry Box", "Fresh", "200 g", 80, 160)],
    }),
    ("Berries & Cherries", {
        "Berries": [("Blueberry Box", ["Imported", "Organic"], "125 g", 200, 380),
                    ("Raspberry Box", "Imported", "125 g", 220, 400),
                    ("Blackberry Box", "Imported", "125 g", 220, 400)],
        "Cherries & Grapes": [("Cherry", "Imported", "250 g", 180, 360),
                              ("Green Grapes", ["Fresh", "Organic"], "500 g", 50, 110),
                              ("Black Grapes", "Fresh", "500 g", 50, 110)],
    }),
    ("Mangoes & Tropical", {
        "Premium Mangoes": [("Devgad Alphonso", "Konkan", "1 dozen", 500, 999),
                            ("Ratnagiri Alphonso", "Konkan", "1 dozen", 500, 999),
                            ("Banganapalli Mango", "Andhra", "1 kg", 90, 180),
                            ("Totapuri Mango", "Fresh", "1 kg", 60, 120)],
        "Tropical Picks": [("Sapota (Chikoo)", "Fresh", "500 g", 40, 90),
                           ("Jackfruit Bulbs", "Fresh", "250 g", 60, 130),
                           ("Mangosteen", "Imported", "250 g", 150, 320)],
    }),
    ("Gift & Combo Packs", {
        "Fruit Baskets": [("Mixed Fruit Basket", "DHAV Fresh", "1 pack", 350, 700),
                          ("Exotic Fruit Basket", "DHAV Fresh", "1 pack", 600, 1200)],
        "Combo Packs": [("Daily Fruits Combo", "DHAV Fresh", "1 pack", 200, 400),
                        ("Citrus Combo", "DHAV Fresh", "1 pack", 150, 320)],
    }),
]

ELECTRONICS = [
    ("Mobiles & Accessories", {
        "Smartphones": [("5G Smartphone 128GB", ["Samsung", "Redmi", "Realme", "Motorola"], "1 unit", 13999, 24999),
                        ("Pro Smartphone 256GB", ["OnePlus", "iQOO", "Vivo"], "1 unit", 28999, 44999),
                        ("Budget Smartphone 64GB", ["Redmi", "Poco", "Infinix"], "1 unit", 8999, 13999)],
        "Chargers & Cables": [("65W Fast Charger", ["Mi", "Realme", "OnePlus"], "1 unit", 799, 1499),
                              ("USB-C to C Cable", ["Portronics", "Ambrane", "boAt"], "1 m", 199, 499),
                              ("Type-C to Lightning Cable", ["Ambrane", "Apple"], "1 m", 399, 999)],
        "Phone Cases & Guards": [("Silicone Back Cover", ["Spigen", "Gripp", "Ringke"], "1 unit", 299, 699),
                                 ("Tempered Glass", ["Gripp", "Spigen"], "2 pcs", 199, 499)],
    }),
    ("Audio", {
        "Earbuds": [("TWS Earbuds", ["boAt", "Noise", "Realme", "OnePlus", "Boult"], "1 unit", 999, 2499),
                    ("ANC Earbuds", ["OnePlus", "Nothing", "Samsung"], "1 unit", 2999, 5999)],
        "Headphones": [("Bluetooth Headphone", ["boAt", "JBL", "Sony"], "1 unit", 1299, 2999),
                       ("Over-Ear ANC Headphone", ["Sony", "Boult", "Marshall"], "1 unit", 4999, 9999),
                       ("Gaming Headset", ["HyperX", "Redgear", "Logitech"], "1 unit", 2499, 5999)],
        "Speakers": [("Portable Bluetooth Speaker", ["JBL", "boAt", "Mivi", "Sony"], "1 unit", 1499, 3999),
                     ("Party Speaker", ["Mivi", "Zebronics", "Portronics"], "1 unit", 2999, 6999),
                     ("Soundbar 2.1", ["Zebronics", "boAt", "JBL"], "1 unit", 3499, 7999)],
    }),
    ("Wearables", {
        "Smart Watches": [("AMOLED Smart Watch", ["Noise", "Fire-Boltt", "boAt", "Amazfit"], "1 unit", 1499, 3499),
                          ("Premium Smartwatch", ["Samsung", "Apple", "Garmin"], "1 unit", 8999, 24999)],
        "Fitness Bands": [("Fitness Band", ["Mi", "boAt", "Fastrack"], "1 unit", 1299, 3499)],
    }),
    ("Laptops & Computing", {
        "Laptops": [("Thin & Light Laptop i5", ["HP", "Lenovo", "Dell", "Asus"], "1 unit", 44999, 64999),
                    ("Gaming Laptop RTX", ["Asus", "Acer", "MSI"], "1 unit", 74999, 109999),
                    ("Everyday Laptop i3", ["Lenovo", "HP"], "1 unit", 32999, 44999)],
        "Keyboards & Mice": [("Wireless Keyboard", ["Logitech", "Dell", "HP"], "1 unit", 999, 2499),
                             ("Gaming Mouse", ["Logitech", "Redgear", "HP"], "1 unit", 899, 2499),
                             ("Mechanical Keyboard", ["Redragon", "Cosmic Byte"], "1 unit", 1999, 4999)],
        "Storage": [("1TB External HDD", ["WD", "Seagate"], "1 unit", 3499, 5499),
                    ("256GB SSD", ["Crucial", "WD", "Samsung"], "1 unit", 1999, 3499),
                    ("128GB Pendrive", ["SanDisk", "HP"], "1 unit", 699, 1299)],
        "Monitors": [("24\" FHD Monitor", ["LG", "Dell", "Acer"], "1 unit", 8999, 14999),
                     ("27\" Gaming Monitor", ["LG", "Asus", "BenQ"], "1 unit", 14999, 28999)],
    }),
    ("Power & Charging", {
        "Power Banks": [("10000mAh Power Bank", ["Mi", "Ambrane", "boAt"], "1 unit", 999, 1999),
                        ("20000mAh Power Bank", ["Ambrane", "Mi", "URBN"], "1 unit", 1499, 2999),
                        ("Magnetic Power Bank", ["Anker", "URBN"], "1 unit", 2499, 4999)],
        "Adapters & Hubs": [("Multiport USB Hub", ["Portronics", "Zebronics"], "1 unit", 799, 1999),
                            ("Universal Travel Adapter", ["Belkin", "Portronics"], "1 unit", 999, 2499)],
    }),
    ("Television", {
        "Smart TVs": [("32\" HD Smart TV", ["Mi", "Samsung", "TCL"], "1 unit", 12999, 18999),
                      ("43\" FHD Smart TV", ["OnePlus", "Sony", "LG"], "1 unit", 22999, 32999),
                      ("55\" 4K Smart TV", ["Samsung", "LG", "Sony"], "1 unit", 38999, 59999)],
        "Streaming Devices": [("4K Streaming Stick", ["Amazon", "Google"], "1 unit", 2999, 4999),
                              ("Android TV Box", ["Mi", "Realme"], "1 unit", 2499, 4499)],
    }),
    ("Tablets & E-Readers", {
        "Tablets": [("Android Tablet 10\"", ["Samsung", "Lenovo", "Realme"], "1 unit", 12999, 24999),
                    ("Premium Tablet", ["Apple", "Samsung"], "1 unit", 28999, 54999)],
        "E-Readers & Stylus": [("E-Reader", ["Amazon"], "1 unit", 7999, 13999),
                               ("Tablet Stylus Pen", ["Apple", "Samsung"], "1 unit", 1999, 8999)],
    }),
    ("Cameras & Drones", {
        "Action Cameras": [("Action Camera 4K", ["GoPro", "DJI", "Insta360"], "1 unit", 24999, 39999)],
        "Security Cameras": [("WiFi Home Camera", ["Mi", "TP-Link", "CP Plus"], "1 unit", 1999, 3499),
                             ("Outdoor CCTV", ["TP-Link", "CP Plus", "Hikvision"], "1 unit", 2999, 5999)],
        "Drones": [("Camera Drone", ["DJI", "Ryze"], "1 unit", 29999, 89999)],
    }),
    ("Smart Home", {
        "Smart Lighting": [("Smart LED Bulb", ["Wipro", "Philips", "Mi"], "1 unit", 499, 999),
                           ("LED Strip Light", ["Mi", "Wipro"], "5 m", 999, 1999)],
        "Smart Devices": [("WiFi Smart Plug", ["TP-Link", "Wipro"], "1 unit", 699, 1499),
                          ("Smart Speaker", ["Amazon", "Google"], "1 unit", 2999, 5499),
                          ("Video Doorbell", ["Qubo", "Mi"], "1 unit", 2999, 5999)],
    }),
    ("Gaming", {
        "Consoles & Controllers": [("Wireless Game Controller", ["Sony", "Microsoft", "Cosmic Byte"], "1 unit", 3999, 6999),
                                   ("Handheld Console", ["Ampere", "Nintendo"], "1 unit", 4999, 24999)],
        "Gaming Accessories": [("Gaming Mousepad XL", ["Redgear", "Cosmic Byte"], "1 unit", 499, 1299),
                               ("RGB Gaming Chair", ["Green Soul", "Cellbell"], "1 unit", 8999, 16999)],
    }),
    ("Kitchen Appliances", {
        "Cooking": [("Mixer Grinder 750W", ["Philips", "Bajaj", "Prestige"], "1 unit", 2499, 4999),
                    ("Electric Kettle", ["Prestige", "Pigeon", "Bajaj"], "1 unit", 799, 1799),
                    ("Hand Blender", ["Bajaj", "Philips"], "1 unit", 999, 2199),
                    ("Induction Cooktop", ["Prestige", "Philips"], "1 unit", 1999, 3999)],
        "Beverage": [("Coffee Maker", ["Philips", "Morphy Richards"], "1 unit", 2999, 5999),
                     ("Sandwich Maker", ["Bajaj", "Prestige"], "1 unit", 999, 1999)],
    }),
    ("Home Appliances", {
        "Cooling & Heating": [("Tower Fan", ["Havells", "Bajaj"], "1 unit", 3499, 6999),
                              ("Room Heater", ["Orpat", "Bajaj", "Usha"], "1 unit", 1299, 2999),
                              ("Air Cooler", ["Symphony", "Bajaj"], "1 unit", 6999, 12999)],
        "Cleaning & Care": [("Steam Iron", ["Philips", "Bajaj", "Usha"], "1 unit", 999, 2299),
                            ("Vacuum Cleaner", ["Eureka Forbes", "Agaro"], "1 unit", 3999, 8999)],
    }),
    ("Personal Grooming", {
        "Trimmers & Shavers": [("Beard Trimmer", ["Philips", "Mi", "Nova"], "1 unit", 999, 2499),
                               ("Electric Shaver", ["Philips", "Braun"], "1 unit", 1999, 4999)],
        "Hair Styling": [("Hair Dryer", ["Nova", "Philips", "Vega"], "1 unit", 699, 1799),
                         ("Hair Straightener", ["Philips", "Vega"], "1 unit", 999, 2499)],
    }),
    ("Networking & WiFi", {
        "Routers": [("Dual Band WiFi Router", ["TP-Link", "D-Link", "Tenda"], "1 unit", 1299, 2999),
                    ("Mesh WiFi System", ["TP-Link", "Tenda"], "1 unit", 3999, 7999)],
        "Range & Adapters": [("WiFi Range Extender", ["TP-Link", "D-Link"], "1 unit", 999, 1999),
                             ("USB WiFi Adapter", ["TP-Link", "Tenda"], "1 unit", 499, 999)],
    }),
    ("Printers & Ink", {
        "Printers": [("Ink Tank Printer", ["HP", "Canon", "Epson"], "1 unit", 9999, 16999),
                     ("Laser Printer", ["HP", "Brother"], "1 unit", 9999, 18999)],
        "Cartridges": [("Ink Cartridge", ["HP", "Canon"], "1 unit", 599, 1499),
                       ("Toner Cartridge", ["HP", "Brother"], "1 unit", 1499, 3499)],
    }),
    ("Computer Peripherals", {
        "Web & Audio": [("Full HD Webcam", ["Logitech", "Zebronics"], "1 unit", 999, 2999),
                        ("USB Microphone", ["Maono", "Boya"], "1 unit", 1499, 3999)],
        "Connectivity": [("USB 3.0 Hub", ["Zebronics", "Portronics"], "1 unit", 499, 1299),
                         ("HDMI Cable 2m", ["AmazonBasics", "Honeywell"], "1 unit", 299, 799)],
    }),
    ("Car Electronics", {
        "In-Car": [("Dash Camera", ["70mai", "Qubo"], "1 unit", 2999, 6999),
                   ("Car Phone Holder", ["Portronics", "Tukzer"], "1 unit", 299, 799),
                   ("Car Charger", ["Portronics", "Mi"], "1 unit", 299, 899)],
        "Audio & Vacuum": [("Car Bluetooth FM", ["JBL", "boAt"], "1 unit", 499, 1299),
                           ("Car Vacuum Cleaner", ["Agaro", "Bergmann"], "1 unit", 999, 2499)],
    }),
    ("Health & Fitness Tech", {
        "Smart Health": [("Smart Body Scale", ["Mi", "HealthSense"], "1 unit", 999, 2499),
                         ("Massage Gun", ["Agaro", "Caresmith"], "1 unit", 2999, 6999)],
        "Fitness Gear": [("Fitness Skipping Rope", ["Boldfit"], "1 unit", 199, 499),
                         ("Smart Water Bottle", ["Hydra"], "1 unit", 499, 1299)],
    }),
    ("Office & Power Backup", {
        "Backup": [("UPS for PC", ["APC", "Zebronics"], "1 unit", 2499, 4999),
                   ("Surge Protector Strip", ["Belkin", "GM"], "1 unit", 499, 1299)],
        "Office Tools": [("Document Scanner", ["Canon", "HP"], "1 unit", 6999, 13999),
                         ("Paper Shredder", ["Kores", "Bambalio"], "1 unit", 3999, 8999)],
    }),
    ("Music & Studio", {
        "Instruments Tech": [("MIDI Keyboard", ["Akai", "Nektar"], "1 unit", 6999, 14999),
                             ("Audio Interface", ["Focusrite", "Behringer"], "1 unit", 7999, 15999)],
        "Studio Gear": [("Condenser Mic", ["Maono", "Audio-Technica"], "1 unit", 2999, 7999),
                        ("Studio Headphone", ["Audio-Technica", "Sony"], "1 unit", 3999, 9999)],
    }),
]

PHARMACY = [
    ("Pain & Fever", {
        "Pain Relief": [("Paracetamol 500mg", "Crocin", "15 tablets", 25, 45), ("Ibuprofen 400mg", "Brufen", "10 tablets", 30, 55),
                        ("Pain Relief Spray", "Volini", "55 g", 130, 200), ("Pain Balm", "Moov", "50 g", 90, 150)],
        "Fever Care": [("Paracetamol Syrup", "Calpol", "60 ml", 40, 70), ("Cold & Fever Tablets", "Dolo", "15 tablets", 25, 45)],
    }),
    ("Cough & Cold", {
        "Cough Syrups": [("Cough Syrup", "Benadryl", "100 ml", 90, 150), ("Dry Cough Syrup", "Ascoril", "100 ml", 95, 160)],
        "Cold & Allergy": [("Antiallergic Tablets", "Cetzine", "10 tablets", 30, 55), ("Nasal Spray", "Otrivin", "10 ml", 90, 150),
                           ("Vapour Rub", "Vicks", "50 ml", 120, 190)],
    }),
    ("Vitamins & Supplements", {
        "Multivitamins": [("Daily Multivitamin", "Revital", "30 tablets", 280, 450), ("Vitamin C Chewable", "Limcee", "15 tablets", 30, 60),
                          ("Vitamin D3", "Calcirol", "1 sachet", 30, 60)],
        "Minerals & Protein": [("Calcium Tablets", "Shelcal", "15 tablets", 90, 150), ("Whey Protein", "Optimum", "1 kg", 1999, 3499),
                               ("Iron & Folic Acid", "Autrin", "15 tablets", 60, 110)],
    }),
    ("Digestive Care", {
        "Acidity & Gas": [("Antacid Syrup", "Gelusil", "200 ml", 90, 150), ("Acidity Tablets", "Digene", "15 tablets", 40, 75)],
        "Probiotics": [("Probiotic Sachets", "Enterogermina", "10 vials", 180, 280), ("ORS Powder", "Electral", "5 sachets", 50, 90)],
    }),
    ("First Aid", {
        "Bandages & Antiseptics": [("Adhesive Bandages", "Band-Aid", "20 pcs", 40, 80), ("Antiseptic Liquid", "Dettol", "250 ml", 90, 150),
                                   ("Cotton Roll", "Surgicotton", "100 g", 40, 80)],
        "Wound Care": [("Antiseptic Cream", "Soframycin", "30 g", 60, 110), ("Burnol Cream", "Burnol", "20 g", 70, 120),
                       ("Crepe Bandage", "Vissco", "1 pc", 90, 160)],
    }),
    ("Personal Hygiene", {
        "Sanitizers & Masks": [("Hand Sanitizer", "Lifebuoy", "500 ml", 130, 220), ("Surgical Mask", "3M", "50 pcs", 99, 199),
                               ("N95 Mask", "Venus", "5 pcs", 199, 399)],
        "Feminine Care": [("Sanitary Pads", "Whisper", "30 pads", 199, 320), ("Menstrual Cup", "Sirona", "1 pc", 299, 499),
                          ("Intimate Wash", "VWash", "200 ml", 180, 280)],
    }),
    ("Skin & Health Care", {
        "Skin Care": [("Moisturising Lotion", "Cetaphil", "250 ml", 350, 520), ("Sunscreen SPF50", "La Shield", "50 g", 450, 650),
                      ("Anti-Fungal Cream", "Candid", "20 g", 90, 150)],
        "Sexual Wellness": [("Condoms Pack", "Durex", "10 pcs", 180, 320), ("Pregnancy Test Kit", "Prega News", "1 kit", 50, 90)],
    }),
    ("Diabetes & BP Care", {
        "Devices": [("Glucometer Kit", "Accu-Chek", "1 kit", 999, 1799), ("BP Monitor", "Omron", "1 unit", 1499, 2999),
                    ("Glucose Test Strips", "OneTouch", "25 strips", 350, 550)],
        "Sugar-Free": [("Sugar-Free Sweetener", "Sugar Free", "100 pellets", 90, 160), ("Diabetic Health Drink", "Diabetic", "400 g", 380, 560)],
    }),
    ("Baby & Mother Care", {
        "Baby Care": [("Baby Diapers", "Pampers", "Pack of 30", 399, 699), ("Baby Lotion", "Johnson", "200 ml", 130, 220),
                      ("Baby Wipes", "Himalaya", "72 pcs", 99, 180)],
        "Mother Care": [("Prenatal Vitamins", "Folvite", "30 tablets", 90, 160), ("Nipple Cream", "Mom & World", "30 g", 250, 380)],
    }),
    ("Ayurveda & Wellness", {
        "Immunity": [("Chyawanprash", ["Dabur", "Patanjali", "Baidyanath"], "1 kg", 280, 420),
                     ("Giloy Tablets", ["Patanjali", "Himalaya"], "60 tablets", 90, 160),
                     ("Ashwagandha Capsules", ["Himalaya", "Kapiva"], "60 caps", 250, 400)],
        "Herbal Care": [("Tulsi Drops", ["Patanjali", "Dabur"], "20 ml", 60, 110),
                        ("Aloe Vera Gel", ["Patanjali", "Himalaya"], "150 ml", 90, 160),
                        ("Triphala Churna", ["Baidyanath", "Dabur"], "100 g", 80, 140)],
    }),
    ("Sexual Wellness", {
        "Protection": [("Condoms Pack", ["Durex", "Skore", "Manforce"], "10 pcs", 180, 360),
                       ("Lubricant Gel", ["Durex", "Skore"], "50 ml", 180, 320)],
        "Wellness": [("Pregnancy Test Kit", ["Prega News", "i-can"], "1 kit", 50, 99),
                     ("Ovulation Kit", ["i-know"], "5 strips", 250, 420)],
    }),
    ("Elderly Care", {
        "Mobility & Support": [("Knee Support Cap", ["Vissco", "Tynor"], "1 pc", 250, 450),
                               ("Walking Stick", ["Vissco"], "1 pc", 350, 650)],
        "Adult Care": [("Adult Diapers", ["Friends", "Liberty"], "Pack of 10", 350, 650),
                       ("Underpads", ["Friends"], "Pack of 10", 250, 450)],
    }),
    ("Eye & Ear Care", {
        "Eye Care": [("Lubricating Eye Drops", ["Refresh Tears", "Systane"], "10 ml", 90, 180),
                     ("Cooling Eye Drops", ["Itone", "Roto"], "10 ml", 60, 130)],
        "Ear Care": [("Ear Drops", ["Soliwax", "Clearwax"], "10 ml", 70, 140),
                     ("Cotton Buds", ["Johnson", "Origami"], "100 pcs", 40, 90)],
    }),
    ("Nutrition & Health Food", {
        "Health Drinks": [("Adult Nutrition Drink", ["Ensure", "Protinex"], "400 g", 380, 620),
                          ("Kids Nutrition Drink", ["PediaSure", "Complan"], "400 g", 380, 620)],
        "Health Snacks": [("Protein Bar", ["Yogabar", "RiteBite"], "Pack of 6", 250, 450),
                          ("Seeds Mix", ["True Elements"], "250 g", 180, 320)],
    }),
    ("Medical Devices", {
        "Monitoring": [("Digital Thermometer", ["Dr Trust", "Omron"], "1 unit", 150, 350),
                       ("Pulse Oximeter", ["Dr Trust", "BPL"], "1 unit", 800, 1600),
                       ("Nebulizer", ["Omron", "Dr Trust"], "1 unit", 1200, 2400)],
        "Support & Aids": [("Hot Water Bag", ["Duckback", "Flamingo"], "1 pc", 150, 350),
                           ("Weighing Scale", ["Dr Trust", "Hesley"], "1 unit", 900, 1800)],
    }),
]

MARKETS = {"grocery": GROCERY, "fruits": FRUITS, "electronics": ELECTRONICS, "pharmacy": PHARMACY}

# Demo stores per marketplace, near Pune (Hinjawadi / Wakad / Baner cluster).
DEMO_STORES = {
    "grocery":     [("DHAV SuperMart",       "Hinjawadi", 18.5913, 73.7389),
                    ("Daily Needs Kirana",   "Wakad",     18.5984, 73.7610)],
    "fruits":      [("DHAV Fresh Fruits",    "Baner",     18.5590, 73.7868),
                    ("Green Basket",         "Hinjawadi", 18.5920, 73.7400)],
    "electronics": [("DHAV Electronics Hub", "Wakad",     18.6000, 73.7625),
                    ("Gadget World",         "Baner",     18.5601, 73.7880)],
    "pharmacy":    [("DHAV Pharmacy",        "Hinjawadi", 18.5905, 73.7395),
                    ("HealthPlus Medical",   "Wakad",     18.5990, 73.7600)],
}

# Demo customers scattered across Pune so the admin Coverage map has people to
# cluster. Some areas sit on top of the demo stores (→ "covered"), others are far
# (→ "no shop nearby"). (area, base_lat, base_lng, how_many)
DEMO_CUSTOMER_AREAS = [
    ("Hinjawadi",   18.5913, 73.7389, 6),   # covered (stores here)
    ("Wakad",       18.5984, 73.7610, 5),   # covered
    ("Baner",       18.5590, 73.7868, 5),   # covered
    ("Kothrud",     18.5074, 73.8077, 5),   # far → uncovered
    ("Viman Nagar", 18.5679, 73.9143, 4),   # far → uncovered
    ("Hadapsar",    18.5089, 73.9260, 4),   # far → uncovered
    ("Aundh",       18.5590, 73.8077, 4),   # partial
]


# ── spec builder (the Highlights / Key-Information chips on product detail) ───
def build_specs(market: str, name: str, brand: str) -> dict:
    if market == "electronics":
        ram = ["4 GB", "6 GB", "8 GB", "12 GB", "16 GB"][h("ram", name) % 5]
        storage = ["64 GB", "128 GB", "256 GB", "512 GB", "1 TB"][h("sto", name) % 5]
        battery = ["3000 mAh", "4000 mAh", "5000 mAh", "6000 mAh"][h("bat", name) % 4]
        warranty = ["6 months", "1 year", "2 years"][h("war", name) % 3]
        return {"Brand": brand, "Warranty": warranty, "Battery": battery,
                "Storage": storage, "RAM": ram, "In the Box": "Unit, cable, manual"}
    if market == "pharmacy":
        return {"Brand": brand, "Type": "Healthcare",
                "Usage": "As directed by physician", "Storage": "Store below 25°C, away from sunlight",
                "Disclaimer": "Read the label carefully. Not a substitute for medical advice.",
                "Country of Origin": "India"}
    if market == "fruits":
        return {"Source": "Locally sourced, farm fresh", "Shelf Life": f"{2 + h('life', name) % 5} days",
                "Storage": "Refrigerate for freshness", "Taste Profile": ["Sweet", "Tangy", "Mild"][h("taste", name) % 3],
                "Organic": "No" if h("org", name) % 3 else "Yes", "Country of Origin": "India"}
    # grocery
    return {"Brand": brand, "Shelf Life": f"{3 + h('life', name) % 9} months",
            "Type": "Packaged", "Storage": "Store in a cool, dry place",
            "FSSAI": "Licensed", "Country of Origin": "India"}


def build_description(market: str, name: str, brand: str, unit: str) -> str:
    base = {
        "grocery": f"{brand} {name} ({unit}) — everyday quality you can trust, delivered fresh to your door.",
        "fruits": f"Hand-picked {name} ({unit}), naturally ripened and farm fresh. Rich in nutrients and bursting with flavour.",
        "electronics": f"{brand} {name} — reliable performance, premium build and a manufacturer warranty. Genuine product with full after-sales support.",
        "pharmacy": f"{brand} {name} ({unit}). Genuine, sealed healthcare product. Please read the label and use as directed by your physician.",
    }
    return base[market]


# ── SQL emit ─────────────────────────────────────────────────────────────────
def main():
    cat_rows, sub_rows, item_rows = [], [], []
    store_rows, inv_updates = [], []

    for market, cats in MARKETS.items():
        market_item_ids: dict = {}  # store_type → list of item ids stocked
        for ci, (cat_name, subs) in enumerate(cats):
            cat_id = slug("cat", market, cat_name)
            cat_rows.append((cat_id, market, cat_name, img_for(cat_name, market), ci))
            for si, (sub_name, products) in enumerate(subs.items()):
                sub_id = slug("sub", market, cat_name, sub_name)
                sub_rows.append((sub_id, cat_id, market, sub_name, img_for(sub_name, market), si))
                for pi, (base_name, brand_spec, unit, lo, hi) in enumerate(products):
                    # brand_spec may be a single brand (str) or a list of brands.
                    # A list emits one realistic product per brand ("<Brand> <Item>"),
                    # the way Zepto/Blinkit list the same item across many brands.
                    brand_list = brand_spec if isinstance(brand_spec, (list, tuple)) else [brand_spec]
                    for bi, brand in enumerate(brand_list):
                        pname = f"{brand} {base_name}" if len(brand_list) > 1 and not base_name.startswith(brand) else base_name
                        disc = discount_for(pname)
                        n_imgs = 3 + (h("nimg", pname) % 3)  # 3..5
                        images = imgs(base_name, n_imgs, market)
                        specs = build_specs(market, pname, brand)
                        desc = build_description(market, base_name, brand, unit)
                        base_mrp = price_for(pname, lo, hi)
                        # variant family: all pack-size SKUs of the same brand+product
                        # share one group_id → powers the "Select Unit" switcher.
                        variants = pack_variants(market, unit, len(brand_list))
                        group_id = (slug("grp", market, cat_name, base_name, brand, str(pi), str(bi))
                                    if len(variants) > 1 else "")
                        # deterministic demo rating (replaces the old 007 random back-fill);
                        # real ratings from the rate-order flow overwrite these.
                        rating = round(3.7 + (h("rating", pname, brand) % 13) / 10.0, 1)   # 3.7..4.9
                        # one row per realistic pack-size SKU (the "Select Unit" sizes)
                        for vi, (vunit, mult) in enumerate(variants):
                            mrp = max(round(base_mrp * mult), 1)
                            price = max(round(mrp * (1 - disc / 100)), 1)
                            item_id = slug("itm", market, cat_name, base_name, brand, str(pi), str(bi), vunit, str(vi))
                            sku = f"DHAV-{market[:3].upper()}-{(h('sku', item_id) % 900000) + 100000}"
                            item_rows.append({
                                "id": item_id, "name": pname, "market": market, "cat_id": cat_id,
                                "sub_id": sub_id, "brand": brand, "sku": sku, "desc": desc,
                                "unit": vunit, "price": price, "mrp": mrp, "disc": disc,
                                "stock": stock_for(item_id), "images": images, "primary": images[0],
                                "specs": specs, "category_name": cat_name,
                                "group_id": group_id, "rating": rating,
                                "rating_count": 40 + (h("rating_count", item_id) % 4000),
                            })
                            market_item_ids.setdefault(market, []).append(item_id)

        # demo stores for this marketplace, each stocks all of this market's items
        ids = market_item_ids.get(market, [])
        for (sname, area, lat, lng) in DEMO_STORES[market]:
            sid = slug("store", market, sname)
            store_rows.append((sid, market, sname, area, lat, lng, ids))

    # demo customers (scattered around Pune for the Coverage map)
    customer_rows = []  # (uid, name, email, area, lat, lng)
    cnum = 0
    for (area, blat, blng, count) in DEMO_CUSTOMER_AREAS:
        for i in range(count):
            cnum += 1
            # deterministic small spread (~±1.2 km) so points don't stack
            dlat = ((h("clat", area, str(i)) % 240) - 120) / 10000.0
            dlng = ((h("clng", area, str(i)) % 240) - 120) / 10000.0
            uid = slug("cust_demo", area, str(i))
            customer_rows.append((uid, f"Demo Customer {cnum}",
                                  f"customer{cnum}@dhav.test", area,
                                  round(blat + dlat, 6), round(blng + dlng, 6)))

    # ── write file ──
    import json
    from collections import Counter as _Counter
    by_market_cnt = _Counter(it["market"] for it in item_rows)
    cat_market_cnt = _Counter(m for (_cid, m, *_r) in cat_rows)
    sub_market_cnt = _Counter(m for (_sid, _cid, m, *_r) in sub_rows)

    def bannered(value_strs, markets, count_map, label):
        """Return a single ',\\n'-joined VALUES body, but insert a `-- banner` comment
        line whenever the marketplace changes — so the SQL reads section-by-section."""
        pieces = []
        last = None
        for vstr, m in zip(value_strs, markets):
            if m != last:
                banner = f"-- ═══════════  {m.upper()}  ({count_map[m]} {label})  ═══════════"
                pieces.append(f"{banner}\n{vstr}")
                last = m
            else:
                pieces.append(vstr)
        return ",\n".join(pieces)

    import pygeohash as gh

    # ── reusable block builders (so the combined file AND the split files share code) ──
    RESET = [
        "DELETE FROM catalog_items WHERE starts_with(id, 'itm_');",
        "DELETE FROM subcategories WHERE starts_with(id, 'sub_');",
        "DELETE FROM categories    WHERE starts_with(id, 'cat_');",
        "DELETE FROM stores        WHERE starts_with(id, 'store_');",
        "DELETE FROM users         WHERE starts_with(uid, 'cust_demo_');",
        "",
    ]

    def cat_block():
        vals = [f"({sql_str(cid)},{sql_str(m)},{sql_str(n)},{sql_str(img)},{so},true,{NOW},{NOW})"
                for (cid, m, n, img, so) in cat_rows]
        return [
            "INSERT INTO categories (id, marketplace_type, name, image_url, sort_order, is_enabled, created_at, updated_at) VALUES",
            bannered(vals, [r[1] for r in cat_rows], cat_market_cnt, "categories"),
            "ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, image_url=EXCLUDED.image_url, "
            "marketplace_type=EXCLUDED.marketplace_type, sort_order=EXCLUDED.sort_order, "
            "is_enabled=true, updated_at=EXCLUDED.updated_at;", ""]

    def sub_block():
        vals = [f"({sql_str(sid)},{sql_str(cid)},{sql_str(m)},{sql_str(n)},{sql_str(img)},{so},true,{NOW},{NOW})"
                for (sid, cid, m, n, img, so) in sub_rows]
        return [
            "INSERT INTO subcategories (id, category_id, marketplace_type, name, image_url, sort_order, is_enabled, created_at, updated_at) VALUES",
            bannered(vals, [r[2] for r in sub_rows], sub_market_cnt, "subcategories"),
            "ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, image_url=EXCLUDED.image_url, "
            "category_id=EXCLUDED.category_id, marketplace_type=EXCLUDED.marketplace_type, "
            "sort_order=EXCLUDED.sort_order, is_enabled=true, updated_at=EXCLUDED.updated_at;", ""]

    def _item_val(it):
        return (f"({sql_str(it['id'])},{sql_str(it['name'])},'','',{sql_str(it['category_name'])},"
                f"{sql_str(it['market'])},{sql_str(it['cat_id'])},{sql_str(it['sub_id'])},{sql_str(it['brand'])},"
                f"{sql_str(it['sku'])},{sql_str(it['desc'])},{sql_str(it['unit'])},{it['price']},{it['mrp']},"
                f"{it['disc']},{it['stock']},{sql_str(it['primary'])},{sql_str(json.dumps(it['images']))}::jsonb,"
                f"{sql_str(json.dumps(it['specs']))}::jsonb,{sql_str(it['group_id'])},{it['rating']},"
                f"{it['rating_count']},true,{NOW},{NOW})")

    _ITEM_INSERT = ("INSERT INTO catalog_items (id, name, name_hindi, name_marathi, category, marketplace_type, "
                    "category_id, subcategory_id, brand, sku, description, unit, price, mrp, discount_percent, "
                    "stock_quantity, image_url, images, specs, group_id, rating, rating_count, "
                    "is_active, created_at, updated_at) VALUES")
    _ITEM_CONFLICT = ("ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, category=EXCLUDED.category, "
                      "marketplace_type=EXCLUDED.marketplace_type, category_id=EXCLUDED.category_id, "
                      "subcategory_id=EXCLUDED.subcategory_id, brand=EXCLUDED.brand, sku=EXCLUDED.sku, "
                      "description=EXCLUDED.description, unit=EXCLUDED.unit, price=EXCLUDED.price, mrp=EXCLUDED.mrp, "
                      "discount_percent=EXCLUDED.discount_percent, stock_quantity=EXCLUDED.stock_quantity, "
                      "image_url=EXCLUDED.image_url, images=EXCLUDED.images, specs=EXCLUDED.specs, "
                      "group_id=EXCLUDED.group_id, "
                      "rating=CASE WHEN catalog_items.rating_count > 0 AND catalog_items.rating > 0 "
                      "THEN catalog_items.rating ELSE EXCLUDED.rating END, "
                      "rating_count=CASE WHEN catalog_items.rating_count > 0 AND catalog_items.rating > 0 "
                      "THEN catalog_items.rating_count ELSE EXCLUDED.rating_count END, "
                      "is_active=true, updated_at=EXCLUDED.updated_at;")

    def items_block(items, banner=True):
        vals = [_item_val(it) for it in items]
        body = (bannered(vals, [it["market"] for it in items], by_market_cnt, "products")
                if banner else ",\n".join(vals))
        return [_ITEM_INSERT, body, _ITEM_CONFLICT, ""]

    def store_block():
        vals = []
        for (sid, m, sname, area, lat, lng, ids) in store_rows:
            gh6 = gh.encode(lat, lng, precision=6)
            loc = json.dumps({"lat": lat, "lng": lng, "geohash": gh6})
            oh = json.dumps({"open": "08:00", "close": "22:00"})
            vals.append(
                f"({sql_str(sid)},{sql_str('demo_'+sid)},{sql_str('DHAV Demo Owner')},{sql_str(sname)},"
                f"{sql_str(sname)},{sql_str(area)},{sql_str(m)},{sql_str('+919999999999')},"
                f"{sql_str(area+', Pune')},{sql_str(gh6)},{sql_str(loc)}::jsonb,true,true,true,"
                f"{sql_str(json.dumps(ids))}::jsonb,{sql_str(oh)}::jsonb,{sql_str(MARKET_FALLBACK.get(m, ''))},{NOW})")
        return [
            "INSERT INTO stores (id, owner_uid, owner_name, shop_name, name, area, store_type, phone, "
            "address, geohash6, location, is_open, is_active, is_verified, available_item_ids, "
            "operating_hours, image_url, created_at) VALUES",
            ",\n".join(vals),
            "ON CONFLICT (id) DO UPDATE SET store_type=EXCLUDED.store_type, "
            "available_item_ids=EXCLUDED.available_item_ids, geohash6=EXCLUDED.geohash6, "
            "location=EXCLUDED.location, is_open=true, is_active=true, is_verified=true;", ""]

    def customers_block():
        vals = []
        for (uid, name, email, area, lat, lng) in customer_rows:
            addr = json.dumps({"label": "Home", "area": area, "city": "Pune",
                               "lat": lat, "lng": lng})
            vals.append(
                f"({sql_str(uid)},{sql_str(name)},{sql_str(email)},'customer',"
                f"{sql_str(addr)}::jsonb,{sql_str('['+addr+']')}::jsonb,true,{NOW})")
        return [
            "INSERT INTO users (uid, name, email, role, address, saved_addresses, is_active, created_at) VALUES",
            ",\n".join(vals),
            "ON CONFLICT (uid) DO UPDATE SET name=EXCLUDED.name, email=EXCLUDED.email, "
            "address=EXCLUDED.address, saved_addresses=EXCLUDED.saved_addresses, "
            "role='customer', is_active=true;", ""]

    def part_header(title, note):
        return [f"-- DHAV seed — {title}", "-- GENERATED by backend/scripts/build_seed.py — do not edit by hand.",
                f"-- {note}", ""]

    # ── data_init/ — the clean, ordered, copy-paste flow (schema → all data) ──
    # Self-contained: step 0 creates every table, steps 1-7 fill the catalog. Each
    # file is well under Supabase's ~1 MB SQL-editor cap. Just open each in order,
    # paste, Run. This is the folder to hand to a fresh / wiped database.
    init_dir = os.path.join(MIG_DIR, "data_init")
    os.makedirs(init_dir, exist_ok=True)

    def write_init(fname, body_lines):
        with open(os.path.join(init_dir, fname), "w", encoding="utf-8") as f:
            f.write("\n".join(body_lines) if isinstance(body_lines, list) else body_lines)

    # step 0: schema (copied from the single source of truth 000_full_schema.sql)
    schema_src = os.path.join(MIG_DIR, "000_full_schema.sql")
    with open(schema_src, encoding="utf-8") as f:
        schema_sql = f.read()
    write_init("00_create_tables.sql",
               "-- DHAV data-init — STEP 0/8: create ALL tables (run FIRST on a wiped DB).\n"
               "-- Source of truth: backend/migrations/000_full_schema.sql (copied at seed-gen time).\n"
               "--\n"
               "-- OPTIONAL FULL WIPE: to start from a truly empty DB, uncomment the block\n"
               "-- below and run it FIRST (it drops EVERY table in public — all data is lost):\n"
               "--\n"
               "-- DO $$\n"
               "-- DECLARE r RECORD;\n"
               "-- BEGIN\n"
               "--   FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP\n"
               "--     EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';\n"
               "--   END LOOP;\n"
               "-- END $$;\n\n"
               + schema_sql)

    write_init("01_taxonomy.sql",
               part_header("STEP 1/8 — reset + categories + subcategories",
                           "Run after 00. Wipes old seed rows then inserts the taxonomy (real images).")
               + RESET + cat_block() + sub_block())
    init_products = {"grocery": "02_products_grocery.sql", "fruits": "03_products_fruits.sql",
                     "electronics": "04_products_electronics.sql", "pharmacy": "05_products_pharmacy.sql"}
    for step, (m, fname) in enumerate(init_products.items(), start=2):
        sub_items = [it for it in item_rows if it["market"] == m]
        write_init(fname, part_header(f"STEP {step}/8 — {m} products ({len(sub_items)})",
                                      "Run after 01.") + items_block(sub_items, banner=False))
    write_init("06_stores.sql",
               part_header("STEP 6/8 — demo stores", "Run after the product steps.") + store_block())
    write_init("07_customers.sql",
               part_header("STEP 7/8 — demo customers (admin Coverage map)",
                           "Run LAST.") + customers_block())
    write_init("README.md", "\n".join([
        "# DHAV — Database init (copy-paste flow)", "",
        "Wiped your Supabase DB? Run these in the **Supabase SQL Editor**, in order — "
        "open each file, copy all, paste, click **Run**, then the next one:", "",
        "| Order | File | What it does |",
        "|---|---|---|",
        "| 0 | `00_create_tables.sql` | Creates every table + index (empty DB → full schema). |",
        "| 1 | `01_taxonomy.sql` | Categories + subcategories (with real images). |",
        "| 2 | `02_products_grocery.sql` | Grocery products. |",
        "| 3 | `03_products_fruits.sql` | Fresh-fruits products. |",
        "| 4 | `04_products_electronics.sql` | Electronics products. |",
        "| 5 | `05_products_pharmacy.sql` | Pharmacy products. |",
        "| 6 | `06_stores.sql` | 8 demo stores (each stocks its marketplace). |",
        "| 7 | `07_customers.sql` | ~33 demo customers for the admin Coverage map. |", "",
        f"**Totals:** {len(cat_rows)} categories · {len(sub_rows)} subcategories · "
        f"{len(item_rows)} products · {len(store_rows)} stores · {len(customer_rows)} customers.", "",
        "Every category/subcategory/product image is a **real, HTTP-verified photo** on a stable "
        "CDN (no broken/dummy images). Steps 1-7 are safe to re-run (they delete only the "
        "`cat_/sub_/itm_/store_/cust_demo_` seed rows first, never your admin-created rows).", "",
        "> Generated by `backend/scripts/build_seed.py` (images via `resolve_images.py` + "
        "`image_overrides.json`). Do not hand-edit — edit the generator and re-run.", "",
    ]))

    # summary
    print(f"Wrote {init_dir}/ (00_create_tables .. 07_customers) -- the clean copy-paste flow")
    print(f"  categories={len(cat_rows)} subcategories={len(sub_rows)} products={len(item_rows)} "
          f"stores={len(store_rows)} customers={len(customer_rows)}")
    for m in MARKETS:
        print(f"  {m:12s} categories={cat_market_cnt[m]:3d} products={by_market_cnt[m]:4d}")


if __name__ == "__main__":
    main()
