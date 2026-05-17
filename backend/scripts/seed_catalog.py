"""
Seed 50 common kirana items into Firebase Realtime Database.
Run once: python backend/scripts/seed_catalog.py
Requires: pip install firebase-admin
Set FIREBASE_SERVICE_ACCOUNT env var to path of service account JSON.
"""

import os
import uuid
import firebase_admin
from firebase_admin import credentials, db

SERVICE_ACCOUNT_PATH = os.getenv(
    "FIREBASE_SERVICE_ACCOUNT", "backend/firebase-service-account.json"
)
DATABASE_URL = "https://dhav-quick-commerce-default-rtdb.firebaseio.com"

CATALOG_ITEMS = [
    # Grains
    {"name": "Basmati Rice", "name_hindi": "बासमती चावल", "name_marathi": "बासमती तांदूळ", "category": "Grains", "unit": "1 kg", "price": 90},
    {"name": "Toor Dal", "name_hindi": "तूर दाल", "name_marathi": "तूर डाळ", "category": "Grains", "unit": "500 g", "price": 65},
    {"name": "Chana Dal", "name_hindi": "चना दाल", "name_marathi": "चणा डाळ", "category": "Grains", "unit": "500 g", "price": 60},
    {"name": "Wheat Flour (Atta)", "name_hindi": "गेहूं का आटा", "name_marathi": "गव्हाचे पीठ", "category": "Grains", "unit": "1 kg", "price": 45},
    {"name": "Poha", "name_hindi": "पोहा", "name_marathi": "पोहे", "category": "Grains", "unit": "500 g", "price": 30},
    {"name": "Sooji (Semolina)", "name_hindi": "सूजी", "name_marathi": "रवा", "category": "Grains", "unit": "500 g", "price": 28},
    {"name": "Moong Dal", "name_hindi": "मूंग दाल", "name_marathi": "मूग डाळ", "category": "Grains", "unit": "500 g", "price": 70},
    {"name": "Besan", "name_hindi": "बेसन", "name_marathi": "बेसन", "category": "Grains", "unit": "500 g", "price": 50},

    # Oil & Ghee
    {"name": "Sunflower Oil", "name_hindi": "सूरजमुखी तेल", "name_marathi": "सूर्यफूल तेल", "category": "Oil & Ghee", "unit": "1 L", "price": 130},
    {"name": "Groundnut Oil", "name_hindi": "मूंगफली तेल", "name_marathi": "शेंगदाणा तेल", "category": "Oil & Ghee", "unit": "1 L", "price": 160},
    {"name": "Cow Ghee", "name_hindi": "गाय का घी", "name_marathi": "गायीचे तूप", "category": "Oil & Ghee", "unit": "500 ml", "price": 280},
    {"name": "Mustard Oil", "name_hindi": "सरसों का तेल", "name_marathi": "मोहरीचे तेल", "category": "Oil & Ghee", "unit": "1 L", "price": 140},

    # Dairy
    {"name": "Full Cream Milk", "name_hindi": "फुल क्रीम दूध", "name_marathi": "फुल क्रीम दूध", "category": "Dairy", "unit": "500 ml", "price": 28},
    {"name": "Curd (Dahi)", "name_hindi": "दही", "name_marathi": "दही", "category": "Dairy", "unit": "400 g", "price": 32},
    {"name": "Paneer", "name_hindi": "पनीर", "name_marathi": "पनीर", "category": "Dairy", "unit": "200 g", "price": 70},
    {"name": "Butter", "name_hindi": "मक्खन", "name_marathi": "बटर", "category": "Dairy", "unit": "100 g", "price": 55},
    {"name": "Cheese Slice", "name_hindi": "चीज़ स्लाइस", "name_marathi": "चीज स्लाइस", "category": "Dairy", "unit": "200 g", "price": 85},

    # Snacks
    {"name": "Lays Chips", "name_hindi": "लेज़ चिप्स", "name_marathi": "लेज चिप्स", "category": "Snacks", "unit": "26 g", "price": 20},
    {"name": "Haldiram Namkeen", "name_hindi": "हल्दीराम नमकीन", "name_marathi": "हल्दीराम नमकीन", "category": "Snacks", "unit": "200 g", "price": 50},
    {"name": "Biscuit (Parle-G)", "name_hindi": "पार्ले-जी बिस्किट", "name_marathi": "पार्ले-जी बिस्किट", "category": "Snacks", "unit": "100 g", "price": 10},
    {"name": "Digestive Biscuit", "name_hindi": "डाइजेस्टिव बिस्किट", "name_marathi": "डायजेस्टिव बिस्किट", "category": "Snacks", "unit": "200 g", "price": 40},
    {"name": "Kurkure", "name_hindi": "कुरकुरे", "name_marathi": "कुरकुरे", "category": "Snacks", "unit": "65 g", "price": 20},
    {"name": "Maggi Noodles", "name_hindi": "मैगी नूडल्स", "name_marathi": "मॅगी नूडल्स", "category": "Snacks", "unit": "70 g", "price": 14},

    # Personal Care
    {"name": "Colgate Toothpaste", "name_hindi": "कोलगेट टूथपेस्ट", "name_marathi": "कोलगेट टूथपेस्ट", "category": "Personal Care", "unit": "100 g", "price": 65},
    {"name": "Lifebuoy Soap", "name_hindi": "लाइफबॉय साबुन", "name_marathi": "लाइफबॉय साबण", "category": "Personal Care", "unit": "1 piece", "price": 22},
    {"name": "Shampoo (Clinic Plus)", "name_hindi": "क्लीनिक प्लस शैंपू", "name_marathi": "क्लिनिक प्लस शॅम्पू", "category": "Personal Care", "unit": "175 ml", "price": 99},
    {"name": "Dettol Hand Wash", "name_hindi": "डेटॉल हैंड वाश", "name_marathi": "डेटॉल हँड वॉश", "category": "Personal Care", "unit": "200 ml", "price": 85},
    {"name": "Parachute Coconut Oil", "name_hindi": "पैराशूट नारियल तेल", "name_marathi": "पॅराशूट नारळ तेल", "category": "Personal Care", "unit": "200 ml", "price": 95},
    {"name": "Whisper Sanitary Pads", "name_hindi": "विस्पर सैनिटरी पैड", "name_marathi": "व्हिस्पर सॅनिटरी पॅड", "category": "Personal Care", "unit": "6 pcs", "price": 49},

    # Cleaning
    {"name": "Surf Excel", "name_hindi": "सर्फ एक्सेल", "name_marathi": "सर्फ एक्सेल", "category": "Cleaning", "unit": "500 g", "price": 95},
    {"name": "Vim Dishwash Bar", "name_hindi": "विम डिशवॉश बार", "name_marathi": "विम डिशवॉश बार", "category": "Cleaning", "unit": "200 g", "price": 30},
    {"name": "Colin Glass Cleaner", "name_hindi": "कॉलिन ग्लास क्लीनर", "name_marathi": "कॉलिन ग्लास क्लिनर", "category": "Cleaning", "unit": "250 ml", "price": 90},
    {"name": "Harpic Toilet Cleaner", "name_hindi": "हार्पिक टॉयलेट क्लीनर", "name_marathi": "हार्पिक टॉयलेट क्लिनर", "category": "Cleaning", "unit": "500 ml", "price": 99},
    {"name": "Lizol Floor Cleaner", "name_hindi": "लाइज़ोल फ्लोर क्लीनर", "name_marathi": "लाइझोल फ्लोर क्लिनर", "category": "Cleaning", "unit": "500 ml", "price": 105},
    {"name": "Scotch Brite Scrub", "name_hindi": "स्कॉच ब्राइट स्क्रब", "name_marathi": "स्कॉच ब्राइट स्क्रब", "category": "Cleaning", "unit": "1 piece", "price": 35},
    {"name": "Phenyl", "name_hindi": "फिनाइल", "name_marathi": "फिनाइल", "category": "Cleaning", "unit": "1 L", "price": 50},

    # Baby Care
    {"name": "Pampers Diapers", "name_hindi": "पैम्पर्स डायपर", "name_marathi": "पॅम्पर्स डायपर", "category": "Baby Care", "unit": "Pack of 10", "price": 199},
    {"name": "Johnson Baby Powder", "name_hindi": "जॉनसन बेबी पाउडर", "name_marathi": "जॉन्सन बेबी पावडर", "category": "Baby Care", "unit": "100 g", "price": 80},
    {"name": "Johnson Baby Shampoo", "name_hindi": "जॉनसन बेबी शैंपू", "name_marathi": "जॉन्सन बेबी शॅम्पू", "category": "Baby Care", "unit": "200 ml", "price": 130},
    {"name": "Dettol Baby Wipes", "name_hindi": "डेटॉल बेबी वाइप्स", "name_marathi": "डेटॉल बेबी वाइप्स", "category": "Baby Care", "unit": "72 pcs", "price": 149},
    {"name": "Lactogen Infant Formula", "name_hindi": "लैक्टोजन इन्फेंट फॉर्मूला", "name_marathi": "लॅक्टोजन इन्फंट फॉर्म्युला", "category": "Baby Care", "unit": "400 g", "price": 295},

    # Spices & Masala
    {"name": "Red Chilli Powder", "name_hindi": "लाल मिर्च पाउडर", "name_marathi": "लाल मिरची पावडर", "category": "Spices", "unit": "100 g", "price": 35},
    {"name": "Turmeric Powder", "name_hindi": "हल्दी पाउडर", "name_marathi": "हळद पावडर", "category": "Spices", "unit": "100 g", "price": 28},
    {"name": "Cumin Seeds", "name_hindi": "जीरा", "name_marathi": "जिरे", "category": "Spices", "unit": "100 g", "price": 30},
    {"name": "Garam Masala", "name_hindi": "गरम मसाला", "name_marathi": "गरम मसाला", "category": "Spices", "unit": "50 g", "price": 40},
    {"name": "MDH Chole Masala", "name_hindi": "एमडीएच छोले मसाला", "name_marathi": "एमडीएच छोले मसाला", "category": "Spices", "unit": "100 g", "price": 55},
    {"name": "Everest Pav Bhaji Masala", "name_hindi": "एवरेस्ट पाव भाजी मसाला", "name_marathi": "एव्हरेस्ट पाव भाजी मसाला", "category": "Spices", "unit": "50 g", "price": 30},
    {"name": "Mustard Seeds", "name_hindi": "राई", "name_marathi": "मोहरी", "category": "Spices", "unit": "100 g", "price": 18},
    {"name": "Asafoetida (Hing)", "name_hindi": "हींग", "name_marathi": "हिंग", "category": "Spices", "unit": "10 g", "price": 25},
    {"name": "Coriander Powder", "name_hindi": "धनिया पाउडर", "name_marathi": "धने पावडर", "category": "Spices", "unit": "100 g", "price": 28},
]


def seed():
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred, {"databaseURL": DATABASE_URL})

    ref = db.reference("catalog")

    print(f"Seeding {len(CATALOG_ITEMS)} catalog items...")
    for item in CATALOG_ITEMS:
        item_id = str(uuid.uuid4())
        ref.child(item_id).set({
            **item,
            "image_url": f"https://via.placeholder.com/200x200?text={item['name'].replace(' ', '+')}",
            "is_active": True,
            "created_at": {".sv": "timestamp"},
        })
        print(f"  + {item['name']} ({item['category']})")

    print(f"\nDone! {len(CATALOG_ITEMS)} items seeded to Firebase.")


if __name__ == "__main__":
    seed()
