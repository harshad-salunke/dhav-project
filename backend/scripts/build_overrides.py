#!/usr/bin/env python3
"""
DHAV — Wikipedia-concept image overrides.

The Commons full-text resolver (resolve_images.py) is great for ELECTRONICS but
noisy for FOOD/PRODUCE/PHARMACY ("Toned Milk" → a flea-market photo). For those,
a product's canonical Wikipedia article lead image is far more reliable.

This script maps each such product NAME → a Wikipedia article title, fetches that
article's lead image (REST summary API), rejects SVG/diagrams, HTTP-verifies it,
and writes the winners into image_overrides.json (which build_seed.py applies on
top of the Commons baseline — overrides always win).

Run:  python scripts/build_overrides.py
Safe + resumable: only fills entries not already present (use --force to redo).
"""
import json, os, sys, time, urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OVR = os.path.join(HERE, "image_overrides.json")
UA = "DHAV-seed-image-resolver/1.0 (https://dhav.app; contact admin@dhav.app)"

# name (category / subcategory / base product) → Wikipedia article title.
# Only list where the article's lead image is a clean, relevant photo.
TITLE = {
    # ── dairy / staples / grocery ──
    "Full Cream Milk": "Milk", "Toned Milk": "Milk", "Cow Milk": "Milk", "Milk": "Milk",
    "Cow Ghee": "Ghee", "Buffalo Ghee": "Ghee", "Fresh Paneer": "Paneer", "Paneer & Curd": "Paneer",
    "Curd": "Curd", "Greek Yogurt": "Yogurt", "Farm Eggs": "Egg as food", "Brown Eggs": "Egg as food",
    "Whole Wheat Atta": "Atta flour", "Multigrain Atta": "Atta flour", "Maida": "Maida", "Besan": "Gram flour",
    "Basmati Rice": "Basmati", "Kolam Rice": "Rice", "Idli Rice": "Rice", "Poha": "Flattened rice",
    "Toor Dal": "Pigeon pea", "Moong Dal": "Mung bean", "Chana Dal": "Chana dal", "Rajma": "Kidney bean",
    "Kabuli Chana": "Chickpea", "Sunflower Oil": "Sunflower oil", "Groundnut Oil": "Peanut oil",
    "Mustard Oil": "Mustard oil", "Olive Oil": "Olive oil", "Turmeric Powder": "Turmeric",
    "Red Chilli Powder": "Chili powder", "Garam Masala": "Garam masala", "Coriander Powder": "Coriander",
    "Cumin Seeds": "Cumin", "Brown Bread": "Brown bread", "Milk Bread": "Bread", "Pav": "Pav (bread)",
    "Tomato Ketchup": "Ketchup", "Mixed Fruit Jam": "Fruit preserves", "Peanut Butter": "Peanut butter",
    "Pure Honey": "Honey", "Soy Sauce": "Soy sauce", "Almonds": "Almond", "Cashew": "Cashew",
    "Raisins": "Raisin", "Dates": "Date palm", "Walnut Kernels": "Walnut", "Pistachio": "Pistachio",
    "Premium Tea": "Tea", "Premium Leaf Tea": "Tea", "Green Tea Bags": "Green tea", "Instant Coffee": "Instant coffee",
    "Filter Coffee Powder": "Coffee", "Corn Flakes": "Corn flakes", "Oats": "Oat", "Muesli": "Muesli",
    "Cola": "Cola", "Orange Juice": "Orange juice", "Soda": "Soft drink", "Classic Salted Chips": "Potato chip",
    "Chocolate Bar": "Chocolate bar", "Soan Papdi": "Soan papdi", "Almonds ": "Almond",
    # ── vegetables ──
    "Onion": "Onion", "Potato": "Potato", "Tomato": "Tomato", "Cauliflower": "Cauliflower",
    "Lady Finger": "Okra", "Green Capsicum": "Bell pepper", "Spinach": "Spinach", "Coriander": "Coriander",
    "Mint": "Mentha", "Curry Leaves": "Curry tree", "Ginger": "Ginger", "Garlic": "Garlic",
    "Broccoli": "Broccoli", "Zucchini": "Zucchini", "Lettuce": "Lettuce", "Green Peas": "Pea",
    # ── fruits ──
    "Banana": "Banana", "Robusta Banana": "Banana", "Yelakki Banana": "Banana", "Red Banana": "Red banana",
    "Apple Shimla": "Apple", "Shimla Apple": "Apple", "Kashmiri Apple": "Apple", "Green Apple": "Apple",
    "Organic Apple": "Apple", "Pomegranate": "Pomegranate", "Alphonso Mango": "Alphonso (mango)",
    "Kesar Mango": "Mango", "Langra Mango": "Mango", "Totapuri Mango": "Mango", "Banganapalli Mango": "Mango",
    "Watermelon": "Watermelon", "Muskmelon": "Muskmelon", "Litchi": "Lychee", "Strawberry": "Strawberry",
    "Nagpur Orange": "Orange (fruit)", "Orange": "Orange (fruit)", "Sweet Lime": "Mosambi",
    "Dragon Fruit": "Pitaya", "Kiwi": "Kiwifruit", "Blueberry": "Blueberry", "Avocado": "Avocado",
    "Pineapple": "Pineapple", "Tender Coconut": "Coconut", "Papaya": "Papaya", "Guava": "Guava",
    "Custard Apple": "Sugar-apple", "Sapota (Chikoo)": "Sapodilla", "Grapes": "Grape",
    "Green Grapes": "Grape", "Black Grapes": "Grape", "Cherry": "Cherry", "Jamun": "Syzygium cumini",
    "Peach": "Peach", "Plum": "Plum", "Corn": "Maize", "Jackfruit Bulbs": "Jackfruit",
    "Walnut": "Walnut", "Dried Figs": "Common fig",
    # ── pharmacy (generic actives / items) ──
    "Paracetamol 500mg": "Paracetamol", "Ibuprofen 400mg": "Ibuprofen", "Hand Sanitizer": "Hand sanitizer",
    "Surgical Mask": "Surgical mask", "N95 Mask": "N95 respirator", "Cotton Roll": "Cotton pad",
    "Adhesive Bandages": "Adhesive bandage", "Antiseptic Liquid": "Antiseptic", "Sanitary Pads": "Sanitary napkin",
    "Baby Diapers": "Diaper", "Adult Diapers": "Diaper", "Digital Thermometer": "Medical thermometer",
    "Pulse Oximeter": "Pulse oximetry", "BP Monitor": "Sphygmomanometer", "Glucometer Kit": "Glucose meter",
    "Whey Protein": "Whey protein", "Chyawanprash": "Chyawanprash", "Aloe Vera Gel": "Aloe vera",
    "Condoms Pack": "Condom", "Walking Stick": "Walking stick",
    # ── taxonomy (categories / subcategories) ──
    "Vegetables & Fruits": "Vegetable", "Fresh Vegetables": "Vegetable", "Leafy & Herbs": "Leaf vegetable",
    "Daily Fruits": "Fruit", "Atta, Rice & Dal": "Rice", "Atta & Flours": "Flour", "Rice & Rice Products": "Rice",
    "Dals & Pulses": "Legume", "Oil, Ghee & Masala": "Cooking oil", "Edible Oils": "Cooking oil",
    "Ghee & Vanaspati": "Ghee", "Whole & Ground Spices": "Spice", "Dairy, Bread & Eggs": "Dairy product",
    "Milk": "Milk", "Bread & Pav": "Bread", "Paneer & Curd": "Paneer", "Eggs": "Egg as food",
    "Bakery & Biscuits": "Biscuit", "Cookies": "Cookie", "Snacks & Drinks": "Snack",
    "Chips & Namkeen": "Potato chip", "Cold Drinks & Juices": "Soft drink", "Tea, Coffee & More": "Tea",
    "Dry Fruits & Nuts": "Nut (fruit)", "Nuts": "Nut (fruit)", "Chocolates & Sweets": "Chocolate",
    "Chocolates": "Chocolate", "Seasonal Fruits": "Fruit", "Mangoes": "Mango", "Melons": "Melon",
    "Apples": "Apple", "Bananas": "Banana", "Citrus": "Citrus", "Exotic Fruits": "Fruit",
    "Fresh Vegetables ": "Vegetable", "Pain & Fever": "Analgesic", "Cough & Cold": "Common cold",
    "Vitamins & Supplements": "Dietary supplement", "First Aid": "First aid", "Personal Hygiene": "Hygiene",
}

# ── second pass: fill the names Commons missed (mostly electronics/pharmacy) ──
TITLE.update({
    # electronics
    "10000mAh Power Bank": "Battery charger", "20000mAh Power Bank": "Battery charger",
    "Magnetic Power Bank": "Battery charger", "128GB Pendrive": "USB flash drive",
    "1TB External HDD": "Hard disk drive", "24\" FHD Monitor": "Computer monitor",
    "27\" Gaming Monitor": "Computer monitor", "65W Fast Charger": "Battery charger",
    "Chargers & Cables": "Battery charger", "Type-C to Lightning Cable": "USB-C",
    "HDMI Cable 2m": "HDMI", "Action Camera 4K": "Action camera", "Full HD Webcam": "Webcam",
    "Computer Peripherals": "Peripheral", "Keyboards & Mice": "Computer keyboard",
    "Consoles & Controllers": "Video game console", "Wireless Game Controller": "Game controller",
    "Gaming Accessories": "Game controller", "Gaming Mousepad XL": "Mousepad", "RGB Gaming Chair": "Office chair",
    "E-Readers & Stylus": "E-reader", "Premium Tablet": "Tablet computer", "Tablets & E-Readers": "Tablet computer",
    "Everyday Laptop i3": "Laptop", "Laptops & Computing": "Laptop", "Fitness Bands": "Activity tracker",
    "Fitness Gear": "Physical fitness", "Fitness Skipping Rope": "Skipping rope", "Smart Body Scale": "Weighing scale",
    "Smart Water Bottle": "Water bottle", "Health & Fitness Tech": "Activity tracker",
    "Mesh WiFi System": "Wireless router", "Range & Adapters": "Wireless router", "WiFi Smart Plug": "Home automation",
    "Universal Travel Adapter": "AC adapter", "Video Doorbell": "Smart doorbell", "Outdoor CCTV": "Closed-circuit television",
    "Mobiles & Accessories": "Smartphone", "Phone Cases & Guards": "Mobile phone accessories",
    "Silicone Back Cover": "Mobile phone accessories", "Tempered Glass": "Screen protector",
    "Premium Smartwatch": "Smartwatch", "Wearables": "Smartwatch", "Smart TVs": "Smart TV",
    "Party Speaker": "Loudspeaker", "Soundbar 2.1": "Soundbar", "Speakers": "Loudspeaker",
    "UPS for PC": "Uninterruptible power supply", "Surge Protector Strip": "Surge protector",
    "Office & Power Backup": "Uninterruptible power supply", "Office Tools": "Office supplies",
    "Car Bluetooth FM": "Vehicle audio", "Cartridges": "Ink cartridge", "Ink Tank Printer": "Inkjet printing",
    "Hair Straightener": "Hair iron", "Hand Blender": "Immersion blender", "Induction Cooktop": "Induction cooking",
    "Sandwich Maker": "Pie iron", "Room Heater": "Electric heater", "Tower Fan": "Fan (machine)",
    "Personal Grooming": "Personal grooming", "A4 Paper Ream": "Paper", "Ball Pen Pack": "Ballpoint pen",
    # pharmacy / wellness
    "Acidity & Gas": "Antacid", "Acidity Tablets": "Antacid", "Antacid Syrup": "Antacid",
    "Antiallergic Tablets": "Antihistamine", "Cold & Allergy": "Antihistamine", "Anti-Dandruff Shampoo": "Shampoo",
    "Hair Conditioner": "Hair conditioner", "Anti-Fungal Cream": "Topical medication", "Antiseptic Cream": "Topical medication",
    "Burnol Cream": "Topical medication", "Moisturising Lotion": "Lotion", "Baby Lotion": "Lotion", "Body Lotion": "Lotion",
    "Nipple Cream": "Lotion", "Daily Multivitamin": "Multivitamin", "Vitamin C Chewable": "Vitamin C",
    "Minerals & Protein": "Dietary supplement", "Iron & Folic Acid": "Folate", "Prenatal Vitamins": "Prenatal vitamins",
    "Digestive Care": "Probiotic", "Probiotics": "Probiotic", "Probiotic Sachets": "Probiotic",
    "Dry Cough Syrup": "Cough medicine", "Paracetamol Syrup": "Paracetamol", "Vapour Rub": "Vicks VapoRub",
    "Cooling Eye Drops": "Eye drop", "Cotton Buds": "Cotton swab", "Crepe Bandage": "Bandage",
    "Knee Support Cap": "Knee brace", "Lubricant Gel": "Personal lubricant", "Menstrual Cup": "Menstrual cup",
    "Ovulation Kit": "Fertility testing", "Pregnancy Test Kit": "Pregnancy test", "Sexual Wellness": "Condom",
    "Underpads": "Incontinence pad", "ORS Powder": "Oral rehydration therapy", "Mouthwash": "Mouthwash",
    "Sunscreen SPF50": "Sunscreen", "Talc Powder": "Talcum powder", "Moisturising Soap": "Soap",
    "Sanitizers & Masks": "Hand sanitizer", "Diabetes & BP Care": "Blood glucose monitoring",
    "Ashwagandha Capsules": "Withania somnifera", "Giloy Tablets": "Tinospora cordifolia",
    "Triphala Churna": "Triphala", "Tulsi Drops": "Ocimum tenuiflorum",
    "Adult Nutrition Drink": "Meal replacement", "Kids Nutrition Drink": "Meal replacement",
    "Malted Health Drink": "Malted milk", "Diabetic Health Drink": "Meal replacement",
    "Protein Bar": "Energy bar", "Seeds Mix": "Seed", "Sugar-Free Sweetener": "Sugar substitute",
    # grocery / home / pooja / frozen
    "Buffalo Ghee": "Ghee", "Ghee & Vanaspati": "Ghee", "Detergent Powder": "Laundry detergent",
    "Dishwash Gel": "Dishwashing liquid", "Glass Cleaner": "Cleaning agent", "Air Freshener": "Air freshener",
    "Fresheners & Repellents": "Insect repellent", "Mosquito Repellent": "Insect repellent",
    "Agarbatti Pack": "Incense", "Pooja Needs": "Puja (Hinduism)", "Pooja Oil": "Oil lamp", "Diya Pack": "Diya (lamp)",
    "Marigold Garland": "Garland", "Banana Leaf": "Banana leaf", "Baby Wipes": "Wet wipe",
    "Atta Alternatives & Millets": "Millet", "Millets": "Millet", "Jams & Spreads": "Fruit preserves",
    "Gulab Jamun Tin": "Gulab jamun", "Elaichi Rusk": "Rusk", "Suji Rusk": "Rusk", "Rusks & Wafers": "Rusk",
    "Choco Cone Pack": "Ice cream cone", "Tubs & Cones": "Ice cream cone", "Kulfi & Bars": "Kulfi", "Kulfi Pack": "Kulfi",
    "Chocobar Pack": "Ice cream bar", "Coconut Water Pack": "Coconut water", "Moong Sprouts": "Sprouting",
    "Frozen & Instant Meals": "Frozen food", "Frozen Veg & Snacks": "Frozen food",
    "Ready-to-Eat Biryani": "Biryani", "Ready-to-Eat Dal Makhani": "Dal makhani",
    "Everyday Veg": "Vegetable", "Organic Veg": "Vegetable", "Organic Spinach": "Spinach", "Organic Picks": "Fruit",
    "Berries & Cherries": "Berry", "Litchi & Berries": "Lychee", "Monsoon Picks": "Fruit",
    "Citrus Combo": "Citrus", "Daily Fruits Combo": "Fruit", "Combo Packs": "Fruit", "Gift & Combo Packs": "Fruit",
})


def _load():
    if os.path.exists(OVR):
        return json.load(open(OVR, encoding="utf-8"))
    return {"_comment": "curated image overrides", "overrides": {}}


def _wiki_image(title, tries=4):
    url = "https://en.wikipedia.org/api/rest_v1/page/summary/" + urllib.parse.quote(title.replace(" ", "_"))
    for a in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=25) as r:
                d = json.load(r)
            img = (d.get("originalimage") or d.get("thumbnail") or {}).get("source")
            if img and not img.lower().endswith(".svg") and ".svg" not in img.lower():
                return img
            return None
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(2 * (a + 1)); continue
            return None
        except Exception:
            return None
    return None


def _verify(url):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=25) as r:
            return r.status == 200 and r.headers.get("Content-Type", "").startswith("image/")
    except Exception:
        return False


def main():
    force = "--force" in sys.argv
    data = _load()
    ovr = data.setdefault("overrides", {})
    items = list(TITLE.items())
    print(f"Resolving {len(items)} Wikipedia-concept overrides…")
    added = 0
    for i, (name, title) in enumerate(items, 1):
        if not force and ovr.get(name):
            continue
        u = _wiki_image(title)
        if u and _verify(u):
            ovr[name] = u
            added += 1
            print(f"  [{i}/{len(items)}] OK   {name:24s} ({title}) -> {u[:60]}")
        else:
            print(f"  [{i}/{len(items)}] MISS {name:24s} ({title})")
        if i % 10 == 0:
            json.dump(data, open(OVR, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
        time.sleep(0.5)
    json.dump(data, open(OVR, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(f"\nDone. {added} new overrides -> {OVR} (total {len(ovr)})")


if __name__ == "__main__":
    main()
