# DHAV — Product Requirements Document (PRD)

**Version:** 4.0 (FINAL)  
**Date:** May 2026  
**Status:** Ready for Development — Feed to Claude CLI  
**Prepared for:** Claude CLI / Development Team

**Changes log:**
- v1.0: Initial PRD
- v2.0: Platform fee moved to store-side, Geofencing system added, Broadcasting & splitting logic
- v3.0: Live location via WebSocket, Delivery Boy role, Customer auto-location, Order popup with View Details
- v4.0: Final — added Table of Contents, End-to-End User Journeys, Edge Cases, Security Rules, Testing Strategy, Deployment Guide, Use Cases

---

## 📑 TABLE OF CONTENTS

1. Product Overview
2. Platform Components & Roles
3. Architecture Overview
4. Data Models
5. Customer App (Flutter)
6. Store App — Store Owner View (Flutter)
6B. Store App — Delivery Boy View (Flutter)
7. Admin Dashboard (Flutter Web)
8. Core Business Logic (Geofencing, Broadcasting, Payments, Strikes)
9. Firebase Structure
10. Authentication Strategy
11. Notification Strategy
12. Payment Flow
13. Language Support
14. MVP Scope
15. Non-Functional Requirements
16. Folder Structure
17. Environment Variables
18. Go-to-Market
19. Success Metrics
20. Risks & Mitigations
21. **End-to-End User Journeys** *(NEW)*
22. **Edge Cases & Error Handling** *(NEW)*
23. **Firebase Security Rules** *(NEW)*
24. **Testing Strategy** *(NEW)*
25. **Deployment Guide** *(NEW)*
26. **Use Cases** *(NEW)*

---

---

## 1. PRODUCT OVERVIEW

### 1.1 What is DHAV?

DHAV is a hyperlocal commerce platform that connects customers in Pune with nearby registered kirana (grocery/general) stores. It enables customers to place orders that are **broadcast to multiple nearby stores simultaneously** — like Ola/Uber for groceries — and the first store to accept delivers using their own delivery boy.

### 1.2 The Problem We Are Solving

Quick commerce giants like Blinkit and Zepto are shutting down local kirana stores across India. Over 200,000 stores have closed in the past year. These stores have loyal customers, existing stock, and local trust — but no digital presence or delivery infrastructure. DHAV gives them one.

### 1.3 The Solution

- Customer places an order on the DHAV Customer App
- The order rings (broadcasts) to all registered kirana stores within 1–2 km radius
- First store to accept wins the order
- The store packs and sends their own delivery boy
- Customer pays product cost + dynamic delivery charge based on distance (Cash on Delivery to delivery boy)
- DHAV charges a dynamic percentage-based platform fee (e.g., 5% of order value) directly from the store — deducted from weekly settlement
- Stores pay DHAV their platform fee weekly via UPI/cash — simple B2B model

### 1.4 Product Mission

> "Empower every kirana store in Pune to compete with Zepto and Blinkit — using only what they already have: their stock, their trust, and their own delivery boy."

---

## 2. PLATFORM COMPONENTS

DHAV consists of **3 separate platforms** serving **4 user roles:**

| Platform | User Roles | Technology |
|---|---|---|
| **Customer App** | Customer (orders groceries) | Flutter (Android + iOS) |
| **Store App** | Store Owner (accepts orders, manages store) | Flutter (Android + iOS) |
| **Store App** | Delivery Boy (sees only delivery task + map) | Flutter (Android + iOS) — same APK, different role view |
| **Admin Dashboard** | DHAV team (monitors everything) | Flutter Web |

**Backend:** FastAPI (Python)  
**Database:** Firebase Realtime Database + Firebase Storage  
**Authentication:** Firebase Auth (Google Sign-In, Email/Password — NO OTP to keep costs low)  
**Hosting:** Firebase Hosting (Admin Dashboard) + Cloud Run or Railway (FastAPI backend)

---

## 3. ARCHITECTURE OVERVIEW

```
┌─────────────────┐    ┌──────────────────────────┐    ┌─────────────────┐
│  Customer App   │    │       Store App           │    │ Admin Dashboard │
│   (Flutter)     │    │  Role: Owner / DeliveryBoy│    │  (Flutter Web)  │
└────────┬────────┘    └────────────┬─────────────┘    └────────┬────────┘
         │                          │                            │
         └──────────────────────────┴────────────────────────────┘
                                    │
                       ┌────────────▼────────────┐
                       │     FastAPI Backend      │
                       │   REST API + Business    │
                       │   Logic + Broadcasting   │
                       │                          │
                       │  ┌────────────────────┐  │
                       │  │  WebSocket Server  │  │  ← Live location channel
                       │  │  (FastAPI WS)      │  │     NO database writes
                       │  └────────────────────┘  │
                       └────────────┬─────────────┘
                                    │
                       ┌────────────▼────────────┐
                       │     Firebase Services    │
                       │  - Realtime Database     │
                       │  - Firebase Storage      │
                       │  - Firebase Auth         │
                       │  - FCM Notifications     │
                       └─────────────────────────┘
```

**Why FastAPI + Firebase separately?**
FastAPI handles all business logic, order broadcasting, penalty logic, and the WebSocket server for live location. Firebase is only the database/storage/auth layer. Swap Firebase for PostgreSQL anytime without rewriting business logic.

**Why WebSocket for live location (not Firebase)?**
Zomato, Swiggy, and Uber do NOT write GPS coordinates to a database on every location update — that would be thousands of database writes per delivery and extremely expensive. Instead they use a **WebSocket (real-time socket connection)** — the delivery boy's phone streams GPS coordinates directly to the server, the server instantly pushes it to the customer's phone. Nothing is stored in the database. Location is ephemeral and in-memory only.

---

## 4. DATA MODELS

### 4.1 User (Customer)
```
user_id: string
name: string
email: string
phone: string (optional)
auth_provider: google | email
profile_photo_url: string
default_address: Address
saved_addresses: Address[]
created_at: timestamp
last_active: timestamp
total_orders: int
```

### 4.2 Address
```
address_id: string
label: string (Home | Work | Other)
flat_building: string
street: string
area: string
city: string (default: Pune)
pincode: string
lat: float
lng: float
```

### 4.3 Store
```
store_id: string
owner_name: string
shop_name: string
phone: string
email: string
auth_provider: google | email
shop_photo_url: string
address: Address
lat: float
lng: float
is_active: boolean
is_verified: boolean
is_suspended: boolean
suspension_end_date: timestamp | null
strike_count: int
available_item_ids: string[]
custom_items: CustomItem[]
operating_hours: { open: string, close: string }
total_orders_accepted: int
total_orders_failed: int
onboarded_by: admin_user_id
created_at: timestamp
rating: float
delivery_boys: DeliveryBoy[]             # list of registered delivery boys for this store
```

### 4.3a DeliveryBoy
```
delivery_boy_id: string
store_id: string                         # which store they belong to
name: string
phone: string
profile_photo_url: string | null
google_account_email: string             # they log into Store App with this
is_active: boolean
current_order_id: string | null          # the active delivery they are on (null if free)
created_at: timestamp

# NOTE: Live GPS location is NEVER stored in database.
# It flows only through WebSocket channel in memory.
# The only location stored is the FINAL delivered confirmation (lat/lng stamp).
```

### 4.4 CatalogItem (Master List - managed by Admin)
```
item_id: string
name: string
name_hindi: string
name_marathi: string
category: string (Grains | Oil | Dairy | Snacks | Personal Care | ...)
unit: string (kg | litre | piece | packet)
image_url: string
is_active: boolean
```

### 4.5 CustomItem (Store's own items)
```
custom_item_id: string
store_id: string
name: string
price: float
unit: string
image_url: string
is_available: boolean
```

### 4.6 Order
```
order_id: string
customer_id: string
customer_address: Address
items: OrderItem[]
total_product_amount: float
delivery_fee: float                      # Dynamic delivery charge based on distance from accepted store
total_customer_amount: float             # total_product_amount + delivery_fee
platform_fee_percentage: float           # Dynamic percentage fee charged to store (e.g., 5.0 for 5%)
platform_fee_amount: float               # Calculated platform fee amount
platform_fee_settled: boolean
payment_method: cod
status: pending | broadcasting | accepted | packed | out_for_delivery | delivered | failed | cancelled
broadcast_radius_km: float
broadcast_wave: int                      # 1 | 2 | 3
broadcast_started_at: timestamp
broadcast_store_ids: string[]
rejected_store_ids: string[]
timed_out_store_ids: string[]
accepted_by_store_id: string | null
accepted_at: timestamp | null
assigned_delivery_boy_id: string | null  # delivery boy assigned by store owner
delivery_boy_name: string | null         # denormalized for display
delivery_boy_phone: string | null
ws_channel_id: string | null             # WebSocket channel ID for live tracking
                                         # format: "order_{order_id}_location"
                                         # Created when status → out_for_delivery
                                         # Destroyed when status → delivered
estimated_delivery_minutes: int
delivered_at: timestamp | null
failure_reason: string | null
created_at: timestamp
geofence_zone_id: string
```

### 4.7 OrderItem
```
item_id: string
item_name: string
quantity: float
unit: string
price_per_unit: float
total_price: float
is_catalog_item: boolean
```

### 4.8 Notification (FCM)
```
notification_id: string
type: new_order | order_accepted | order_out_for_delivery | order_delivered | order_failed | store_warning | store_suspended
recipient_id: string
recipient_type: customer | store | admin
title: string
body: string
data: map
sent_at: timestamp
read: boolean
```

### 4.9 StrikeLog
```
strike_id: string
store_id: string
order_id: string
reason: string
strike_number: int
action_taken: warning | suspended_7_days | permanent_ban
created_at: timestamp
```

### 4.10 GeofenceZone
```
zone_id: string
zone_name: string                        # e.g. "Kothrud", "Aundh", "Wakad"
center_lat: float
center_lng: float
radius_km: float                         # zone boundary radius
polygon_coordinates: LatLng[]           # precise polygon if non-circular
active_store_count: int                  # stores currently active in this zone
is_active: boolean
created_at: timestamp
```

### 4.11 StoreGeofenceIndex
```
# Stored flat in Firebase for ultra-fast geospatial lookups
# Key: geohash of store location (precision 6 = ~1.2km accuracy)
geohash: string                          # e.g. "tf1r3p"
store_id: string
lat: float
lng: float
is_active: boolean
is_verified: boolean
is_suspended: boolean
zone_id: string
```

### 4.12 WeeklySettlement
```
settlement_id: string
store_id: string
week_start: date                         # Monday of that week
week_end: date                           # Sunday of that week
total_orders_delivered: int
total_platform_fee_owed: float           # Sum of all percentage-based platform fees for delivered orders
total_fee_paid: float
balance_due: float
status: pending | partially_paid | settled
payment_records: PaymentRecord[]
created_at: timestamp
```

### 4.13 PaymentRecord (Store → DHAV)
```
payment_id: string
settlement_id: string
store_id: string
amount: float
payment_mode: upi | cash | bank_transfer
payment_date: timestamp
recorded_by: admin_id                    # which admin confirmed this payment
notes: string
```

### 4.14 AdminUser
```
admin_id: string
name: string
email: string
role: super_admin | operations | support
created_at: timestamp
```

---

## 5. PLATFORM 1 — CUSTOMER APP (Flutter)

### 5.1 Authentication Screens

**Screen: Welcome / Splash**
- App logo, tagline: "Apni dukaan, apke darwaze tak"
- Button: "Continue with Google"
- Button: "Continue with Email"
- Language selector: English / हिंदी / मराठी

**Screen: Google Sign-In**
- Standard Firebase Google OAuth flow
- On success → check if profile complete → go to Home or Profile Setup

**Screen: Email Sign-In / Register**
- Email + Password fields
- No OTP. Firebase email/password auth only.
- "Forgot Password" → Firebase reset email

**Screen: Profile Setup (one time)**
- Name (pre-filled from Google if available)
- Add home address (map picker + manual entry)

---

### 5.2 Home Screen

**On App Open — Auto Location Fetch:**
- As soon as app opens (after login), immediately call `Geolocator.getCurrentPosition()` in Flutter
- Show a subtle loading indicator: "Finding your location…"
- Once GPS resolves → reverse geocode to area name using Google Maps Geocoding API
- Display: "Delivering to: Kothrud, Pune 📍" at top
- Customer can tap this to manually change delivery area if needed
- If location permission denied → prompt with explanation, or let them enter address manually
- Location is used to:
  1. Show which catalog items are available nearby (geofence lookup)
  2. Determine which stores will receive the broadcast when order is placed

**Rest of Home Screen:**
- Search bar: "What do you need?"
- Category chips: Grains | Oil & Ghee | Dairy | Snacks | Personal Care | Cleaning | Baby Care | Other
- Featured items grid (popular items in their detected area)
- "Recently Ordered" section (returning users)
- If order is active → floating "Track Order" banner at bottom (taps to tracking screen)
- Bottom nav: Home | Search | Orders | Profile

---

### 5.3 Search & Browse Screen

- Search by item name (searches master catalog)
- Filter by category
- Each item card shows:
  - Item photo
  - Item name (in selected language)
  - Category
  - "Add to Cart" button
  - Note: Price shown AFTER store accepts (stores set price)
- Items not available in any nearby store are greyed out

---

### 5.4 Cart Screen

- List of selected items with quantities (editable)
- Delivery address (editable, map picker)
- Estimated Order total: product cost only (Delivery charge will be added based on store distance)
- Payment: **Cash on Delivery only** (customer pays total amount to delivery boy)
- Estimated delivery: "Usually 30–60 minutes"
- "Place Order" CTA button
- Small disclaimer: "A nearby kirana store will be found for your order"

---

### 5.5 Order Broadcasting Screen (Live)

- Animation: pulsing rings expanding from customer location on map
- Text: "Finding your nearest kirana store…"
- Counter: "Checking stores nearby"
- If no store accepts in 60 seconds → radius auto-expands to 2km
- If no store in 2km → show "Sorry, no stores available right now. Try again in some time."
- Offer: "We'll notify you when a store is available" (push notification opt-in)

---

### 5.6 Order Accepted Screen

- Store name, shop photo, distance
- Owner name
- Estimated delivery time
- Items list confirmation with prices (store confirms prices at this point)
- Delivery fee (calculated dynamically based on store's distance to customer)
- Final Total Amount (Products + Delivery Fee)
- If customer disagrees with price or delivery fee → option to cancel for free

---

### 5.7 Order Tracking Screen

**Status Timeline (top half):**
- ✅ Order Placed
- ✅ Store Accepted — "[Store Name] is packing your order"
- ⏳ Being Packed
- 🛵 Out for Delivery — "[Delivery boy name] is on the way"
- 🏠 Delivered

**Live Map (bottom half — appears only when status = out_for_delivery):**
- Google Maps embedded in Flutter using `google_maps_flutter` package
- Two pins on map:
  - 🛵 Delivery boy's live location (animated, updates smoothly every 2–3 seconds)
  - 🏠 Customer's delivery address (static pin)
- Delivery boy pin moves smoothly using Flutter map marker animation (lerp between old and new coordinates)
- Live ETA shown: "Arriving in ~8 minutes"
- How location updates reach the map:
  - Customer app opens a **WebSocket connection** to: `ws://api.DHAVl.com/ws/order/{order_id}/location`
  - Delivery boy app streams GPS every 3 seconds on the same channel
  - FastAPI WebSocket server receives GPS from delivery boy → instantly pushes to customer
  - **Zero database writes** — purely in-memory relay
  - If WebSocket drops → customer app auto-reconnects silently

**Below map:**
- Delivery boy name + tap-to-call phone button
- "I have a problem" → support

---

### 5.7a Live Location — How it Works End to End

```
DELIVERY BOY PHONE (Flutter)
  │
  │  Every 3 seconds:
  │  GPS → lat/lng → send via WebSocket
  │
  ▼
FASTAPI WEBSOCKET SERVER
  │  ws://api/ws/order/{order_id}/location
  │
  │  Receives: { lat: 18.5031, lng: 73.8124, timestamp: ... }
  │  Does NOT write to Firebase. Holds in memory.
  │  Instantly pushes same payload to all subscribers of this channel
  │
  ▼
CUSTOMER APP (Flutter)
  │
  │  Receives lat/lng via WebSocket
  │  Updates Google Maps marker position
  │  Animates marker smoothly using Tween animation
  │  Recalculates ETA using distance from marker to destination
  │
  ▼
SMOOTH MOVING PIN ON MAP (like Uber/Zomato)
```

**FastAPI WebSocket handler (services/location_ws.py):**
```python
# In-memory store of active delivery channels
# { order_id: { "delivery_boy": WebSocket, "customers": [WebSocket, ...] } }
active_channels: dict = {}

@app.websocket("/ws/order/{order_id}/location")
async def location_websocket(websocket: WebSocket, order_id: str, role: str, token: str):
    """
    role = "delivery_boy" → this connection SENDS location
    role = "customer"     → this connection RECEIVES location
    token = Firebase ID token for auth verification
    """
    await websocket.accept()

    # Verify Firebase token
    decoded = verify_firebase_token(token)
    if not decoded:
        await websocket.close(code=4001)
        return

    # Register this connection
    if order_id not in active_channels:
        active_channels[order_id] = { "delivery_boy": None, "customers": [] }

    if role == "delivery_boy":
        active_channels[order_id]["delivery_boy"] = websocket
        try:
            while True:
                # Receive GPS from delivery boy
                data = await websocket.receive_json()
                # { "lat": 18.503, "lng": 73.812, "timestamp": "..." }

                # Instantly relay to all connected customers — no DB write
                for customer_ws in active_channels[order_id]["customers"]:
                    try:
                        await customer_ws.send_json(data)
                    except:
                        pass  # customer disconnected, ignore

        except WebSocketDisconnect:
            active_channels[order_id]["delivery_boy"] = None

    elif role == "customer":
        active_channels[order_id]["customers"].append(websocket)
        try:
            await websocket.wait_closed()
        except WebSocketDisconnect:
            active_channels[order_id]["customers"].remove(websocket)

    # Clean up channel when order delivered
    if (active_channels.get(order_id) and
        not active_channels[order_id]["delivery_boy"] and
        not active_channels[order_id]["customers"]):
        del active_channels[order_id]
```

**Flutter — Smooth Marker Animation (customer_app):**
```dart
// When new lat/lng arrives via WebSocket:
void _onLocationUpdate(double newLat, double newLng) {
  final newPosition = LatLng(newLat, newLng);

  // Animate marker from current position to new position
  // over 2 seconds — creates the smooth "gliding" effect
  _markerAnimationController.reset();
  _startPosition = _currentMarkerPosition;
  _endPosition = newPosition;
  _markerAnimationController.forward();

  // Update ETA
  final distance = _haversine(_currentMarkerPosition, _deliveryAddress);
  final etaMinutes = (distance / 0.5).ceil(); // assuming 30km/h avg speed
  setState(() { _etaMinutes = etaMinutes; });
}
```

---

### 5.8 Order History Screen

- List of past orders
- Each order: store name, items, date, status, total amount
- "Reorder" button on past orders

---

### 5.9 Profile Screen

- Name, photo, email
- Saved addresses (add / edit / delete)
- Language preference
- Notification settings
- Help & Support
- Logout

---

### 5.10 Notifications

All via Firebase Cloud Messaging (FCM):
- Order accepted by store
- Delivery boy assigned
- Out for delivery
- Delivered
- Order failed + platform fee refund confirmation

---

## 6. PLATFORM 2 — STORE APP (Flutter)

### 6.1 Authentication

**Screen: Welcome**
- "Register your store" button
- "I already have an account" button
- Note: Store accounts are pre-created by Admin during assisted onboarding. Store owner just logs in with the Google account set up during onboarding.

**Screen: Google Sign-In**
- Firebase Google Auth (same as customer)
- System detects this is a store account → goes to Store Dashboard

---

### 6.2 Store Dashboard (Home)

- Big status toggle at top: **OPEN 🟢 / CLOSED 🔴** (one tap)
- Today's stats: Orders Accepted | Orders Delivered | Earnings Today
- Active order card (if any order in progress)
- Recent orders list

---

### 6.3 Incoming Order — Request Popup (Most Critical Flow)

When an order broadcasts to this store, the experience has **two layers**:

---

**LAYER 1 — Quick Alert Popup (appears immediately, even if app is in background)**

This fires as a high-priority FCM notification rendered as an overlay inside the app (or as a system notification if app is killed):

```
┌──────────────────────────────────────────┐
│  🔔  NEW ORDER REQUEST                   │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  📦  3 items  •  Customer 0.8 km away    │
│  💵  Cash on Delivery                    │
│  🚚  Delivery Fee to Collect: ₹15       │
│                                          │
│  ⏱️  [ ══════════════════░░ ] 38 sec     │
│                                          │
│  ┌──────────────┐  ┌──────────────────┐  │
│  │  VIEW ORDER  │  │  QUICK ACCEPT ✅  │  │
│  │   DETAILS   │  │                  │  │
│  └──────────────┘  └──────────────────┘  │
│                                          │
│        [ ❌ Reject ]                     │
└──────────────────────────────────────────┘
```

- **Audio:** Loud ring sound (like incoming phone call) — plays even if phone is on silent using Android AudioManager.STREAM_ALARM
- **Vibration:** Continuous vibration pattern until action taken
- **Countdown bar:** Visual timer showing remaining seconds (45 seconds)
- **"QUICK ACCEPT"** → immediately accepts order, skips detail view (for experienced store owners who trust the platform)
- **"VIEW ORDER DETAILS"** → opens Layer 2 (detail sheet) without stopping the timer
- **"Reject"** → small text button, dismisses this order

---

**LAYER 2 — Order Detail Bottom Sheet (opens on "View Order Details" tap)**

A full bottom sheet slides up while the countdown continues:

```
┌──────────────────────────────────────────┐
│  ORDER DETAILS          ⏱️ 31 sec        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  ITEMS:                                  │
│  ✅ Tata Salt 1kg          you have this │
│  ✅ Amul Butter 100g       you have this │
│  ✅ Maggi Noodles 70g x2   you have this │
│  ⚠️  Horlicks 200g         CHECK STOCK  │
│                                          │
│  DELIVERY TO:                            │
│  📍 Flat 4B, Shivaji Nagar              │
│     0.8 km from your store               │
│                                          │
│  PAYMENT: Cash on Delivery               │
│  ESTIMATED EARNING: ₹ [product total]   │
│  PLATFORM FEE DEDUCTION: [dynamic %]     │
│                                          │
│  [ ════════════════░░░░ ]  31 sec left  │
│                                          │
│  ┌─────────────────────────────────────┐ │
│  │          ✅ ACCEPT ORDER            │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │          ❌ Reject Order            │ │
│  └─────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

Key UX details:
- Items cross-checked against store's own inventory — green ✅ if they have it, ⚠️ if uncertain
- Customer distance shown on map thumbnail (small static map preview)
- Timer continues counting down in this view — store cannot "pause" time by opening details
- If timer hits 0 while detail sheet is open → order auto-rejects, sheet closes with "Order expired — taken by another store"
- On ACCEPT → shows confirmation: "Can you deliver in 45 minutes? YES / NO" (if NO → treated as reject)

---

**FCM Implementation for Background Alert:**
```dart
// In store app — FirebaseMessaging handler
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  if (message.data['type'] == 'new_order') {
    // App was in background, user tapped notification
    // Navigate directly to order detail bottom sheet
    _showOrderDetailSheet(message.data['order_id']);
  }
});

FirebaseMessaging.onMessage.listen((message) {
  if (message.data['type'] == 'new_order') {
    // App is in foreground — show overlay popup directly
    _showIncomingOrderOverlay(message.data);
  }
});
```

---

### 6.4 Active Order Management Screen (Store Owner)

After accepting:
- Full order items list with quantities
- Customer address + distance
- Step buttons (tap in sequence):

**Step 1 — Assign Delivery Boy:**
- Dropdown: list of store's registered delivery boys (with availability status)
- Or: "Add a one-time delivery boy" (enter name + phone manually)
- Tap "Assign" → delivery boy gets notified on their app

**Step 2 — Mark Packed:**
- Button: "Order is Packed ✅"
- Customer notified: "Your order is packed and being assigned a delivery partner"

**Step 3 — Confirm Dispatch:**
- Button: "Delivery Boy Dispatched 🛵"
- This opens the WebSocket channel for live tracking
- Customer app starts showing live map

**Step 4 — Mark Delivered:**
- Button: "Order Delivered 🏠"
- Closes WebSocket channel
- Platform fee counter increments for this store
- Order marked complete

**Problem Button:**
- "Report a problem with this order" → opens reason selector (item not available / customer not reachable / other) → submits failure report

---

### 6.5 My Inventory Screen

- Master catalog list (500+ items)
- Each item: Name, image, toggle ON/OFF (I have this / I don't have this)
- Search within catalog
- My custom items section:
  - Add custom item: Name, price, unit, photo
  - Edit / delete custom items
- This screen is set up once during onboarding by admin, updated by store owner

---

### 6.6 Earnings & Settlement Screen

- This week's orders delivered: count
- Gross earnings (total product cash collected from customers): ₹ amount
- Platform fee owed to DHAV this week: ₹ amount
  - Calculated as: Sum of percentage-based fees on all delivered orders (e.g., 5% of order values)
- Net earnings (what store keeps): ₹ amount
- Settlement status: ✅ Settled | ⏳ Due by Sunday | ⚠️ Overdue
- History: past weeks with settled / overdue status
- "Pay DHAV" button → shows DHAV UPI ID / bank details to transfer fee
- Note: "Platform fee is charged dynamically as a percentage of your successful orders. Pay by end of each week."

---

### 6.7 Store Profile Screen

- Shop name, photo
- Operating hours (edit)
- Address
- Owner name, phone
- Account status: Active / Suspended
- Strike count: ⚠️ 0 / 3 strikes
- **Manage Delivery Boys** button → goes to Delivery Boy Management screen
- Help & Support

---

### 6.8 Delivery Boy Management Screen (Store Owner only)

- List of all registered delivery boys for this store
- Each entry: Name | Phone | Status (Available / On Delivery) | Total Deliveries
- Add Delivery Boy button:
  - Enter name, phone, Google account email
  - System creates delivery boy account linked to this store
  - Delivery boy receives SMS/WhatsApp with app download link and login instructions
- Remove delivery boy button (with confirmation)

---

## 6B. DELIVERY BOY VIEW — Store App (Same APK, Different Role)

When a delivery boy logs into the Store App with their Google account, the system detects role = `delivery_boy` and shows a **completely different UI** — stripped of all store management features. They only see what they need for delivery.

---

### 6B.1 Delivery Boy — Home Screen

```
┌────────────────────────────────────┐
│  DHAV Delivery                │
│  Hi, Raju 👋                       │
│                                    │
│  STATUS:  🟢 Available             │
│           [ Toggle ON / OFF ]      │
│                                    │
│  ┌──────────────────────────────┐  │
│  │   No active delivery         │  │
│  │   Waiting for assignment...  │  │
│  └──────────────────────────────┘  │
│                                    │
│  Today's Deliveries: 4             │
│  [View History]                    │
└────────────────────────────────────┘
```

- Simple toggle: Available / Not Available
- When available → they can receive delivery assignments from store owner
- No order details, no catalog, no inventory — none of that is visible

---

### 6B.2 Delivery Boy — Incoming Assignment Notification

When store owner assigns an order to this delivery boy, their phone shows:

```
┌────────────────────────────────────┐
│  🛵 NEW DELIVERY ASSIGNMENT        │
│                                    │
│  Pick up from:                     │
│  📦 Sharma Kirana Store            │
│     Near Bus Stop, Kothrud         │
│                                    │
│  Deliver to:                       │
│  🏠 Flat 4B, Shivaji Nagar        │
│     0.8 km from store              │
│                                    │
│  Customer Phone: 📞 [tap to call]  │
│                                    │
│  💵 Collect: ₹ [total amount]      │
│     (Products + Delivery Fee)      │
│     Cash on Delivery               │
│                                    │
│  [ ✅ ACCEPT ]   [ ❌ Decline ]    │
└────────────────────────────────────┘
```

- Delivery boy ONLY sees: pickup address, drop address, customer phone, cash to collect
- They do NOT see item names, store financials, order history, or any store management
- One tap to accept

---

### 6B.3 Delivery Boy — Active Delivery Screen

After accepting the delivery:

```
┌────────────────────────────────────┐
│  🛵 ACTIVE DELIVERY                │
│                                    │
│  [  GOOGLE MAP showing:            │
│     - Current location (blue dot)  │
│     - Pickup pin (store)           │
│     - Drop pin (customer)          │
│     - Route drawn                  ]│
│                                    │
│  ┌──────────────────────────────┐  │
│  │  📦 PICKUP                   │  │
│  │  Sharma Kirana, Kothrud      │  │
│  │  [ Open in Google Maps 🗺️ ]  │  │
│  └──────────────────────────────┘  │
│                                    │
│  ┌──────────────────────────────┐  │
│  │  🏠 DROP                     │  │
│  │  Flat 4B, Shivaji Nagar      │  │
│  │  [ Open in Google Maps 🗺️ ]  │  │
│  └──────────────────────────────┘  │
│                                    │
│  📞 Call Customer                  │
│                                    │
│  [ ✅ MARK AS DELIVERED ]          │
└────────────────────────────────────┘
```

**Navigation Options (two modes):**

**Mode 1 — In-App Map:**
- Uses `google_maps_flutter` with a drawn route
- Delivery boy's live GPS streams via WebSocket to customer's app
- Map shows their real-time position (blue dot) plus route to destination

**Mode 2 — Launch Google Maps (external):**
- "Open in Google Maps" button for pickup and drop separately
- Uses `url_launcher` package:
  ```dart
  // Launch Google Maps with destination pin
  final url = 'https://www.google.com/maps/dir/?api=1'
      '&destination=${dropLat},${dropLng}'
      '&travelmode=two_wheeler';
  await launchUrl(Uri.parse(url));
  ```
- When delivery boy returns to DHAV app, the WebSocket resumes streaming
- This gives maximum flexibility — old phones, slow processors can just use Google Maps directly

**Live Location Streaming (while on delivery):**
```dart
// Delivery boy app — streams GPS every 3 seconds via WebSocket
final channel = WebSocketChannel.connect(
  Uri.parse('wss://api.DHAVl.com/ws/order/${orderId}/location'
      '?role=delivery_boy&token=${firebaseToken}')
);

Timer.periodic(Duration(seconds: 3), (_) async {
  final position = await Geolocator.getCurrentPosition();
  channel.sink.add(jsonEncode({
    'lat': position.latitude,
    'lng': position.longitude,
    'timestamp': DateTime.now().toIso8601String(),
  }));
});
```

---

### 6B.4 Delivery Boy — Mark Delivered

After handing over the package and collecting cash:
- Tap "MARK AS DELIVERED" → confirmation dialog: "Confirm delivery and cash collected?"
- On confirm → order marked delivered in system
- WebSocket channel closed
- Customer gets "Order Delivered" notification
- Screen returns to Home (Available state)

---

### 6B.5 Delivery Boy — History Screen

- List of today's / past deliveries
- Each: date, area, status (delivered / failed)
- No financial data shown — that is the store owner's view only

---

### 6.9 Penalty / Strike Notifications (Store Owner View)

- Strike 1: Full-screen warning when opening app. "You have 1 strike. One more failed delivery without reason may suspend your store."
- Strike 2: "Your store will be suspended for 7 days on next failure."
- Strike 3: "Your store has been permanently removed from DHAV."
- Suspension screen: "Your store is suspended until [date]. Contact support."

---

## 7. PLATFORM 3 — ADMIN DASHBOARD (Web)

### 7.1 Login
- Email + Password (Firebase Auth)
- Role-based access: super_admin | operations | support

---

### 7.2 Dashboard Home

Key metrics visible immediately:
- Total active stores in Pune
- Total orders today / this week / this month
- Orders delivered vs failed (success rate %)
- Platform fee collected today
- New stores registered this week
- Map view: all active stores plotted on Pune map

---

### 7.3 Store Management

**Store List View:**
- Table: Store Name | Owner | Area | Status | Orders Total | Strike Count | Last Active | Actions
- Filters: Active | Suspended | Pending Verification | All
- Search by store name, area, owner name

**Store Detail View (clicking a store):**
- All store info
- Full order history for this store
- Strike log with reasons
- Inventory: which items they have ticked
- Manual actions:
  - Verify store ✅
  - Suspend store (enter reason + duration)
  - Remove suspension early
  - Add strike manually (with reason)
  - Remove store permanently
  - Edit store details

**Onboard New Store:**
- Form: Owner name, shop name, phone, address (map picker), area, operating hours
- Create Google account for store or link existing
- Select items from master catalog on behalf of store
- Upload shop photo
- Submit → Store goes live

---

### 7.4 Customer Management

**Customer List View:**
- Table: Name | Email | Area | Total Orders | Last Order Date | Joined Date
- Search by name, email

**Customer Detail View:**
- Profile info
- Full order history
- Saved addresses
- Manual actions: Deactivate account, view issue reports

---

### 7.5 Order Management

**Order List View:**
- Table: Order ID | Customer | Store | Items | Amount | Status | Date
- Filters: All | Broadcasting | Active | Delivered | Failed | Cancelled
- Real-time updates (Firebase listener)

**Order Detail View:**
- Full order breakdown
- Timeline of status changes with timestamps
- Customer info + store info
- Issue reports linked to this order
- Manual actions:
  - Mark as delivered manually
  - Issue refund (platform fee refund)
  - Cancel order
  - Add note

---

### 7.6 Catalog Management

- Master item list (500+ items)
- Add new item: Name, Hindi name, Marathi name, Category, Unit, Photo
- Edit existing items
- Activate / deactivate items
- Categories management: add / rename categories

---

### 7.7 Platform Fee & Revenue

- Daily platform fee collection summary
- Option A (UPI paid online): auto-tracked
- Option B (COD collected): manually tracked or reported by store
- Weekly settlement tracking per store
- Export to CSV

---

### 7.8 Analytics

- Order volume by area (heatmap on Pune map)
- Peak hours chart
- Most ordered items
- Store performance rankings
- Failed order reasons breakdown
- Customer retention (repeat orders %)

---

### 7.9 Notifications Center

- Send push notification to all customers
- Send push notification to all stores
- Target by area / pincode

---

## 8. CORE BUSINESS LOGIC (FastAPI Backend)

---

### 8.1 GEOFENCING SYSTEM

Geofencing is the core mechanism that determines WHICH stores receive a broadcast for any given order. It uses **Geohash-based spatial indexing** stored in Firebase for extremely fast lookups without expensive geo queries.

#### 8.1.1 How Geohash Works in DHAV

```
Every store's location is converted to a Geohash string at registration.
Geohash precision 6 = ~1.2km × 0.6km grid cell accuracy.
Geohash precision 5 = ~4.9km × 4.9km grid cell accuracy.

Example:
  Store in Kothrud, Pune → lat: 18.5074, lng: 73.8077
  Geohash (precision 6) = "tf1r3p"

Firebase index:
  /geofence_index/tf1r3p/{store_id} = { lat, lng, is_active, zone_id, ... }
```

#### 8.1.2 Store Registration — Geofence Indexing

```python
# On store registration or location update:
def index_store_geofence(store_id, lat, lng):
    geohash_6 = geohash.encode(lat, lng, precision=6)  # ~1.2km cell
    geohash_5 = geohash.encode(lat, lng, precision=5)  # ~5km cell

    # Write to Firebase flat index
    db.reference(f'/geofence_index/{geohash_6}/{store_id}').set({
        'store_id': store_id,
        'lat': lat,
        'lng': lng,
        'geohash_6': geohash_6,
        'geohash_5': geohash_5,
        'is_active': True,
        'is_verified': True,
        'is_suspended': False
    })
```

#### 8.1.3 Finding Nearby Stores for a Customer Order

When a customer places an order at lat/lng:

```python
def find_nearby_stores(customer_lat, customer_lng, radius_km=1.0):
    """
    Uses geohash neighbor lookup — finds all geohash cells
    that overlap with the radius circle, then filters by
    exact Haversine distance.
    """
    center_geohash = geohash.encode(customer_lat, customer_lng, precision=6)

    # Get center cell + all 8 surrounding neighbor cells
    # This ensures no store near a cell boundary is missed
    neighbor_cells = geohash.neighbors(center_geohash)
    all_cells = [center_geohash] + list(neighbor_cells.values())

    candidate_stores = []
    for cell in all_cells:
        stores_in_cell = db.reference(f'/geofence_index/{cell}').get()
        if stores_in_cell:
            candidate_stores.extend(stores_in_cell.values())

    # Filter by exact Haversine distance
    nearby = []
    for store in candidate_stores:
        distance_km = haversine(
            customer_lat, customer_lng,
            store['lat'], store['lng']
        )
        if distance_km <= radius_km:
            store['distance_km'] = round(distance_km, 2)
            nearby.append(store)

    # Sort by distance ascending (nearest first)
    return sorted(nearby, key=lambda x: x['distance_km'])
```

#### 8.1.4 Haversine Distance Formula (in services/geo.py)

```python
import math

def haversine(lat1, lng1, lat2, lng2) -> float:
    """Returns distance in kilometers between two GPS points."""
    R = 6371  # Earth radius in km
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (math.sin(d_lat/2)**2 +
         math.cos(math.radians(lat1)) *
         math.cos(math.radians(lat2)) *
         math.sin(d_lng/2)**2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c
```

#### 8.1.5 Geofence Zones (Admin-defined areas in Pune)

Admin defines named zones (Kothrud, Aundh, Wakad, etc.) as polygons on a map. These are used for:
- Analytics (orders per zone)
- Store coverage gaps detection
- Zone-level notifications ("New stores in your area!")

```python
def point_in_polygon(lat, lng, polygon_coords) -> bool:
    """Ray casting algorithm — checks if GPS point is inside a polygon zone."""
    n = len(polygon_coords)
    inside = False
    x, y = lng, lat
    j = n - 1
    for i in range(n):
        xi, yi = polygon_coords[i]['lng'], polygon_coords[i]['lat']
        xj, yj = polygon_coords[j]['lng'], polygon_coords[j]['lat']
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
            inside = not inside
        j = i
    return inside
```

---

### 8.2 ORDER BROADCASTING ALGORITHM (Full Detail)

This is the core "Ola/Uber ring" mechanic of DHAV.

#### 8.2.1 Complete Broadcasting Flow

```
STEP 1: Customer places order → POST /orders
         │
         ▼
STEP 2: Validate order items exist in master catalog
         │
         ▼
STEP 3: Save order to Firebase with status = "broadcasting", wave = 1
         │
         ▼
STEP 4: GEOFENCE LOOKUP — find all stores within 1km radius
        Filter stores by:
        ✅ is_active = true
        ✅ is_verified = true
        ✅ is_suspended = false
        ✅ current time is within store's operating_hours
        ✅ store has AT LEAST 1 item from the order in their inventory
        ✅ store has NOT been added to rejected_store_ids already
         │
         ▼
STEP 5: Are qualifying stores found?
        YES → STEP 6
        NO  → STEP 9 (expand radius or fail)
         │
         ▼
STEP 6: Send HIGH PRIORITY FCM notification to ALL qualifying stores SIMULTANEOUSLY
        (This is NOT sequential — all stores ring at the same time like Ola)
        Store notification payload:
        {
          "order_id": "...",
          "items": [...],
          "customer_distance_km": 0.8,
          "payment": "Cash on Delivery",
          "timeout_seconds": 45,
          "wave": 1
        }
         │
         ▼
STEP 7: Start 45-second acceptance window (background async task in FastAPI)
        Any store calls POST /orders/{id}/accept?store_id=xxx
         │
         ▼
STEP 8: First store to accept → ORDER LOCKED to that store
        │
        ├── Send "Order Accepted" notification to customer (with store name, ETA)
        ├── Send "Order Taken" notification to all OTHER stores that were rung
        ├── Update order: status = "accepted", accepted_by_store_id = store_id
        └── END BROADCAST for this order
         │
         (If 45 seconds pass with no acceptance → STEP 9)
         ▼
STEP 9: WAVE ESCALATION
        wave 1 timed out (1km, 45s) → Launch wave 2
        wave 2 timed out (2km, 45s) → Launch wave 3
        wave 3 timed out (3km, 60s) → ORDER FAILED
         │
         ▼
STEP 10: ORDER FAILED
         Update order: status = "failed", failure_reason = "no_stores_available"
         Notify customer: "No kirana store available right now. Try again later."
         No platform fee charged (no store accepted, no delivery happened)
```

#### 8.2.2 Wave Configuration

```python
BROADCAST_WAVES = [
    { "wave": 1, "radius_km": 1.0, "timeout_seconds": 45 },
    { "wave": 2, "radius_km": 2.0, "timeout_seconds": 45 },
    { "wave": 3, "radius_km": 3.0, "timeout_seconds": 60 },
]
# If no acceptance after wave 3 → order fails
```

#### 8.2.3 Preventing Race Conditions (Two Stores Accepting Simultaneously)

```python
# In FastAPI — POST /orders/{order_id}/accept
async def accept_order(order_id: str, store_id: str):

    order_ref = db.reference(f'/orders/{order_id}')

    # Firebase transaction — atomic read + write
    # Only ONE store can win, even if two hit the endpoint at same millisecond
    def accept_transaction(current_order):
        if current_order is None:
            return  # abort
        if current_order.get('status') != 'broadcasting':
            return  # abort — already accepted by someone else
        # Atomically update
        current_order['status'] = 'accepted'
        current_order['accepted_by_store_id'] = store_id
        current_order['accepted_at'] = datetime.utcnow().isoformat()
        return current_order

    result = order_ref.transaction(accept_transaction)

    if result and result.get('accepted_by_store_id') == store_id:
        # This store WON the transaction
        await notify_customer_order_accepted(order_id, store_id)
        await notify_other_stores_order_taken(order_id, store_id)
        return {"success": True, "message": "Order accepted"}
    else:
        # Another store was faster — this store lost
        return {"success": False, "message": "Order already taken"}
```

---

### 8.3 ORDER LIFECYCLE — FULL STATE MACHINE

```
pending
   │
   ▼
broadcasting ──(wave 1, 45s)──► wave 2 ──(45s)──► wave 3 ──(60s)──► failed
   │
   ▼ (store accepts)
accepted
   │
   ▼ (store taps "Order Packed")
packed
   │
   ▼ (store taps "Delivery Boy Dispatched" + enters name & phone)
out_for_delivery
   │
   ├──► delivered  (store taps "Delivered" OR customer confirms)
   │
   └──► failed     (store reports failure OR 3hr timeout auto-fail)
```

**Auto-fail timeout:** If an accepted order stays in `out_for_delivery` for more than 3 hours without being marked delivered → system auto-marks as failed, customer is notified, store gets a strike.

---

### 8.4 PLATFORM FEE — STORE-SIDE COLLECTION (B2B Model)

**Key principle: The customer never sees or pays any platform fee. The fee is a B2B charge between DHAV and the store.**

```
Customer places order
        │
        ▼
Customer pays ONLY product cost + delivery fee → cash to delivery boy
        │
        ▼
Store collects full cash from customer
        │
        ▼
DHAV counts: every successfully DELIVERED order = dynamic percentage fee owed by store
        │
        ▼
Every Monday: System auto-generates weekly settlement for each store
        Settlement = Sum of (Order Total * Platform Fee Percentage)
        │
        ▼
Store pays DHAV via UPI / cash by end of Sunday
        │
        ▼
Admin marks settlement as "settled" in dashboard
        │
        ▼
If store doesn't pay by Sunday:
  → Admin flags store as "payment_overdue"
  → Store is hidden from broadcasts until settled
  → Store gets reminder notification
```

**Platform Fee Rules:**
- Fee is charged ONLY on `delivered` orders — NOT on failed, cancelled, or rejected
- Fee is a dynamic percentage of the order total (managed by Admin)
- Stores agree to fee terms during registration
- No fee during first 30 days (onboarding grace period)

**Delivery Charge Rules:**
- Delivery charge is dynamically calculated based on distance from the accepted store
- Base fee is applied, plus an additional fee per km (managed by Admin from backend)
- Customer sees the delivery charge once the store accepts the order

---

### 8.5 STRIKE & PENALTY LOGIC (Full Detail)

```python
# Trigger: store marks order as failed, OR auto-fail fires after 3hr timeout

async def process_store_failure(order_id: str, store_id: str, reason: str):

    store_ref = db.reference(f'/stores/{store_id}')
    store = store_ref.get()

    new_strike_count = store['strike_count'] + 1

    # Log the strike
    strike_data = {
        'store_id': store_id,
        'order_id': order_id,
        'reason': reason,
        'strike_number': new_strike_count,
        'created_at': now()
    }

    if new_strike_count == 1:
        strike_data['action_taken'] = 'warning'
        store_ref.update({ 'strike_count': 1 })
        await notify_store_warning(store_id, strike_number=1)

    elif new_strike_count == 2:
        strike_data['action_taken'] = 'warning'
        store_ref.update({ 'strike_count': 2 })
        await notify_store_warning(store_id, strike_number=2)

    elif new_strike_count == 3:
        suspension_end = now() + timedelta(days=7)
        strike_data['action_taken'] = 'suspended_7_days'
        store_ref.update({
            'strike_count': 3,
            'is_suspended': True,
            'suspension_end_date': suspension_end.isoformat()
        })
        # Remove store from geofence index immediately
        await remove_store_from_geofence_index(store_id)
        await notify_store_suspended(store_id, until=suspension_end)

    elif new_strike_count >= 5:
        strike_data['action_taken'] = 'permanent_ban'
        store_ref.update({
            'strike_count': new_strike_count,
            'is_active': False,
            'is_suspended': True,
            'suspension_end_date': None
        })
        await remove_store_from_geofence_index(store_id)
        await notify_store_banned(store_id)

    # Save strike log
    db.reference(f'/strikes/{store_id}').push(strike_data)

    # Notify admin
    await notify_admin_store_strike(store_id, strike_data)
```

**Suspension Auto-Lift:**
```python
# Runs daily as a scheduled job (Cloud Scheduler or Railway cron)
async def lift_expired_suspensions():
    stores = db.reference('/stores').order_by_child('is_suspended').equal_to(True).get()
    for store_id, store in stores.items():
        end_date = store.get('suspension_end_date')
        if end_date and datetime.fromisoformat(end_date) < datetime.utcnow():
            db.reference(f'/stores/{store_id}').update({
                'is_suspended': False,
                'suspension_end_date': None
            })
            # Re-add to geofence index
            await index_store_geofence(store_id, store['lat'], store['lng'])
            await notify_store_suspension_lifted(store_id)
```

---

### 8.6 KEY API ENDPOINTS (Updated)

**Auth:**
- `POST /auth/verify-token` — verify Firebase ID token, return role + profile

**Customer:**
- `GET /catalog/items?lat=&lng=&category=&search=` — items available nearby
- `GET /catalog/categories` — all categories
- `POST /orders` — place order, triggers broadcast
- `GET /orders/{id}` — get live order status (poll or Firebase listener)
- `GET /orders/my?page=1` — paginated order history
- `DELETE /orders/{id}` — cancel order (only before `accepted` status)

**Store:**
- `POST /orders/{id}/accept` — accept incoming order (atomic transaction)
- `POST /orders/{id}/reject` — explicitly reject (store won't get another ring for this order)
- `POST /orders/{id}/packed` — mark as packed
- `POST /orders/{id}/dispatched` — dispatched with delivery boy name + phone
- `POST /orders/{id}/delivered` — mark delivered → triggers platform fee counter
- `POST /orders/{id}/report-failure` — report failure with reason
- `GET /store/inventory` — get store's ticked catalog items
- `PUT /store/inventory` — update inventory tick list
- `POST /store/custom-items` — add custom item
- `PUT /store/status` — toggle open/closed (also updates geofence index)
- `GET /store/settlement/current` — this week's fee owed
- `GET /store/settlement/history` — past settlements

**Admin:**
- `GET /admin/stores?status=&zone=&search=` — filtered store list
- `POST /admin/stores` — onboard new store
- `PUT /admin/stores/{id}` — update store
- `POST /admin/stores/{id}/verify` — verify store → adds to geofence
- `POST /admin/stores/{id}/suspend` — manual suspend
- `POST /admin/stores/{id}/lift-suspension` — manual lift
- `GET /admin/orders?status=&zone=&date=` — order management
- `GET /admin/customers` — customer list
- `GET /admin/analytics/overview` — key metrics
- `GET /admin/analytics/zones` — orders + stores by Pune zone
- `GET /admin/config/charges` — view current dynamic charge configurations
- `PUT /admin/config/charges` — update platform fee percentage and delivery charge parameters
- `GET /admin/settlements?status=pending` — pending fee collections
- `POST /admin/settlements/{id}/mark-paid` — mark store payment received
- `GET /admin/catalog` — master catalog
- `POST /admin/catalog` — add item
- `PUT /admin/catalog/{id}` — update item

---

## 9. FIREBASE STRUCTURE

```
/users/{user_id}                          → Customer profiles
/stores/{store_id}                        → Store profiles
/orders/{order_id}                        → All orders (live + history)
/catalog/{item_id}                        → Master catalog items
/custom_items/{store_id}/{item_id}        → Store's custom items
/strikes/{store_id}/{strike_id}           → Strike logs per store
/settlements/{store_id}/{week_start}/     → Weekly fee settlement records
/payment_records/{settlement_id}/{pid}    → Individual payment records
/admin_users/{admin_id}                   → Admin profiles
/notifications/{user_id}/{notif_id}       → Notification inbox
/geofence_zones/{zone_id}                 → Admin-defined Pune area polygons

# GEOFENCE SPATIAL INDEX (flat structure for fast lookup)
/geofence_index/{geohash_6}/{store_id}    → { lat, lng, is_active, zone_id, ... }

# ACTIVE ORDER BROADCAST (real-time, short-lived)
/active_broadcasts/{order_id}            → broadcast state, wave, timeout
```

Firebase Storage:
```
/store_photos/{store_id}.jpg
/catalog_photos/{item_id}.jpg
/custom_item_photos/{store_id}/{item_id}.jpg
/zone_maps/{zone_id}.json                 → polygon coordinates for zones
```

---

## 10. AUTHENTICATION STRATEGY

**Customer App:**
- Google Sign-In (Firebase) — primary
- Email + Password (Firebase) — secondary
- ❌ No OTP (cost saving)

**Store App:**
- Google Sign-In only (set up by admin during onboarding)
- Store owner's personal Google account is linked to their store during onboarding

**Admin Dashboard:**
- Email + Password only (internal team accounts created manually)
- Role assigned in Firestore by super_admin

**Token Flow:**
- All apps get Firebase ID Token after login
- All API calls send `Authorization: Bearer {firebase_id_token}` header
- FastAPI backend verifies token using Firebase Admin SDK
- FastAPI checks role (customer / store / admin) and responds accordingly

---

## 11. NOTIFICATION STRATEGY (FCM — Free)

All notifications via Firebase Cloud Messaging (completely free):

| Event | Recipient | Priority |
|---|---|---|
| New order broadcast | Nearby stores | HIGH (wakes up screen) |
| Order accepted | Customer | NORMAL |
| Delivery boy dispatched | Customer | NORMAL |
| Order delivered | Customer | NORMAL |
| Order failed | Customer | HIGH |
| Strike warning | Store | HIGH |
| Store suspended | Store | HIGH |
| No stores available | Customer | NORMAL |

---

## 12. PAYMENT FLOW

**DHAV uses a pure B2B platform fee model. The customer is never charged a platform fee.**

### Customer Payment (Simple — Always COD):
```
Customer places order
     ↓
Customer pays ONLY product cost in cash to delivery boy at door
     ↓
No platform fee, no UPI required from customer side
```

### Store Payment to DHAV (Weekly Settlement):
```
Store delivers order → dynamic platform fee counter increments
     ↓
Every Monday: System generates WeeklySettlement for each store
  total_fee = Sum of percentage fees for delivered orders
     ↓
Store sees this amount in their Earnings screen
     ↓
Store pays via UPI to DHAV's UPI ID by Sunday
     ↓
Admin confirms payment → marks settlement as "settled"
     ↓
If not settled by Sunday:
  → Store flagged as "payment_overdue"
  → Store hidden from all broadcasts until paid
  → Admin reminder sent to store
```

### Why This Model Works:
- Zero friction for customers — pure COD, no app payment needed
- Stores pay only AFTER they earn — fair and trust-building
- Simple for admin to track — one settlement per store per week
- No payment gateway needed at launch (saving Razorpay integration costs)
- In future: automate via UPI collect requests to stores

---

## 13. LANGUAGE SUPPORT

All 3 platforms must support:
- English (default)
- हिंदी (Hindi)
- मराठी (Marathi — critical for Pune)

Store App: Default to Marathi/Hindi based on phone language setting. Store owner can change in settings.

Customer App: User selects on first launch, can change in profile.

Use Flutter's `intl` package for localization. All strings in `.arb` files.

---

## 14. MVP SCOPE (Phase 1 — Launch in Pune)

Build ONLY these for launch:

**Customer App MVP:**
- Google Sign-In
- Browse catalog by category
- Add to cart
- Place order (Option B — full COD only, to simplify)
- See broadcasting animation
- Order tracking (status updates)
- Order history

**Store App MVP:**
- Google Sign-In
- Full-screen incoming order alert
- Accept / Reject
- Mark packed → dispatched → delivered
- Toggle open/closed
- Basic inventory (tick catalog items)

**Admin Dashboard MVP:**
- Login
- See all stores (list + map)
- Onboard new store manually
- See all orders in real time
- See all customers
- Basic analytics (counts only)

**What to build in Phase 2 (after launch):**
- Option A payment (UPI platform fee)
- Custom item addition by stores
- Store ratings by customers
- Advanced analytics
- Hindi/Marathi full localization
- Reorder feature
- Subscription for daily items

---

## 15. NON-FUNCTIONAL REQUIREMENTS

| Requirement | Target |
|---|---|
| Order broadcast latency | < 3 seconds from placement to store notification |
| App size | < 20MB (Flutter optimized) |
| Offline support | Store App must show last known state offline |
| FCM delivery rate | > 95% within 5 seconds |
| API response time | < 500ms for all endpoints |
| Firebase read costs | Optimized — paginate lists, no unbounded reads |
| Concurrent orders | Support 50 simultaneous broadcasts (Pune pilot scale) |

---

## 16. FOLDER STRUCTURE FOR DEVELOPMENT

```
kirana-mal/
├── customer_app/              # Flutter - Customer App
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── constants.dart
│   │   │   ├── routes.dart
│   │   │   └── theme.dart
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── home/
│   │   │   ├── catalog/
│   │   │   ├── cart/
│   │   │   ├── orders/
│   │   │   │   ├── order_broadcast_screen.dart
│   │   │   │   ├── order_tracking_screen.dart
│   │   │   │   └── order_history_screen.dart
│   │   │   └── profile/
│   │   └── services/
│   │       ├── api_service.dart
│   │       ├── auth_service.dart
│   │       ├── location_service.dart      # GPS + address resolution
│   │       └── notification_service.dart
│   └── pubspec.yaml
│
├── store_app/                 # Flutter - Store App
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── dashboard/
│   │   │   ├── orders/
│   │   │   │   ├── incoming_order_screen.dart   # Full-screen alert
│   │   │   │   ├── active_order_screen.dart
│   │   │   │   └── order_history_screen.dart
│   │   │   ├── inventory/
│   │   │   ├── earnings/
│   │   │   │   ├── earnings_screen.dart
│   │   │   │   └── settlement_screen.dart       # Weekly fee tracker
│   │   │   └── profile/
│   │   └── services/
│   │       ├── api_service.dart
│   │       ├── auth_service.dart
│   │       └── notification_service.dart        # High-priority FCM handler
│   └── pubspec.yaml
│
├── admin_dashboard/           # Flutter Web - Admin Panel
│   ├── lib/
│   │   ├── main.dart
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── dashboard/
│   │   │   ├── stores/
│   │   │   │   ├── store_list_screen.dart
│   │   │   │   ├── store_detail_screen.dart
│   │   │   │   └── onboard_store_screen.dart
│   │   │   ├── customers/
│   │   │   ├── orders/
│   │   │   ├── catalog/
│   │   │   ├── settlements/                     # Weekly fee management
│   │   │   │   ├── settlement_list_screen.dart
│   │   │   │   └── settlement_detail_screen.dart
│   │   │   ├── zones/                           # Geofence zone management
│   │   │   │   ├── zone_map_screen.dart
│   │   │   │   └── zone_editor_screen.dart
│   │   │   └── analytics/
│   └── pubspec.yaml
│
├── backend/                   # FastAPI - Python Backend
│   ├── main.py
│   ├── requirements.txt
│   │     # firebase-admin, fastapi, uvicorn, python-geohash,
│   │     # httpx, apscheduler, python-dotenv
│   ├── config.py
│   ├── firebase_init.py
│   ├── routers/
│   │   ├── auth.py
│   │   ├── customers.py
│   │   ├── stores.py
│   │   ├── orders.py
│   │   ├── catalog.py
│   │   ├── settlements.py                       # Fee settlement routes
│   │   └── admin.py
│   ├── models/
│   │   ├── user.py
│   │   ├── store.py
│   │   ├── order.py
│   │   ├── catalog.py
│   │   └── settlement.py
│   ├── services/
│   │   ├── broadcasting.py        # Wave broadcast logic
│   │   ├── geofencing.py          # Geohash indexing + neighbor lookup
│   │   ├── geo.py                 # Haversine + polygon functions
│   │   ├── notifications.py       # FCM sender (high/normal priority)
│   │   ├── penalties.py           # Strike + suspension logic
│   │   ├── settlements.py         # Weekly fee calculation + tracking
│   │   └── scheduler.py           # Cron jobs (suspension lift, auto-fail)
│   └── utils/
│       └── helpers.py
│
├── firebase/
│   ├── database.rules.json        # Realtime DB security rules
│   ├── storage.rules
│   └── firebase.json
│
└── README.md
```

---

## 17. ENVIRONMENT VARIABLES (Backend)

```
# Firebase
FIREBASE_PROJECT_ID=kirana-mal-pune
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...
FIREBASE_DATABASE_URL=https://kirana-mal-pune-default-rtdb.firebaseio.com
FIREBASE_STORAGE_BUCKET=kirana-mal-pune.appspot.com

# Broadcasting Waves
BROADCAST_WAVE1_RADIUS_KM=1.0
BROADCAST_WAVE1_TIMEOUT_SECONDS=45
BROADCAST_WAVE2_RADIUS_KM=2.0
BROADCAST_WAVE2_TIMEOUT_SECONDS=45
BROADCAST_WAVE3_RADIUS_KM=3.0
BROADCAST_WAVE3_TIMEOUT_SECONDS=60

# Geofencing
GEOHASH_PRECISION=6                      # ~1.2km cell resolution
DEFAULT_CITY_LAT=18.5204                 # Pune center lat
DEFAULT_CITY_LNG=73.8567                 # Pune center lng

# Platform & Delivery Fees (Dynamic configuration usually from DB, fallbacks here)
PLATFORM_FEE_PERCENTAGE=5.0              # 5% fee on product amount
BASE_DELIVERY_FEE=10.0
DELIVERY_FEE_PER_KM=5.0
ONBOARDING_GRACE_DAYS=30                 # No fee for first 30 days

# Penalties
MAX_STRIKES_BEFORE_SUSPEND=3
MAX_TOTAL_STRIKES_BEFORE_BAN=5
SUSPENSION_DAYS=7
AUTO_FAIL_HOURS=3                        # Auto-fail if out_for_delivery > 3hrs

# Settlement
SETTLEMENT_DAY=MONDAY                    # When new settlement is generated
SETTLEMENT_DUE_DAY=SUNDAY               # When store must pay by
```

---

## 18. GO-TO-MARKET (Pune Pilot)

**Month 1:**
- Manually onboard 20–30 kirana stores in ONE area (suggested: Kothrud or Aundh)
- Zero commission period for stores — they just have to deliver
- Distribute flyers in that locality to customers

**Month 2–3:**
- Expand to 3 more Pune localities
- Start collecting platform fees
- Fix UX issues found in pilot

**Month 4+:**
- Citywide Pune expansion
- Add Option A (UPI platform fee)
- Build store ratings feature

---

## 19. SUCCESS METRICS

| Metric | Month 1 Target | Month 3 Target |
|---|---|---|
| Stores onboarded | 30 | 100 |
| Orders per day | 20 | 150 |
| Order success rate | > 70% | > 85% |
| Average delivery time | < 60 min | < 45 min |
| Customer repeat rate | — | > 40% |
| Platform fee collected | ₹0 (free pilot) | ₹2,000/day |

---

## 20. RISKS & MITIGATIONS

| Risk | Mitigation |
|---|---|
| Store doesn't deliver | Strike system: warning → 7-day suspension → permanent ban |
| No stores available in area | 3-wave broadcast (1km → 2km → 3km), notify customer |
| Store owner can't use app | Assisted onboarding, Marathi UI, one-tap accept |
| Store refuses to pay platform fee | Hide store from broadcasts until settlement paid |
| Two stores accept simultaneously | Firebase atomic transaction ensures only one wins |
| Store turns off phone mid-order | Auto-fail after 3 hours, customer notified, store gets strike |
| Geofence misses a store near cell boundary | Geohash neighbor cells (8 surrounding cells always checked) |
| Firebase costs grow with scale | Flat geohash index = O(1) lookups, not full DB scans. Swap to PostGIS later via FastAPI |
| Competition from Kiko Live entering Pune | 6-month head start + local store relationships = moat |
| WebSocket server goes down during delivery | Customer app falls back to polling /orders/{id}/location every 10s. Delivery boy keeps streaming once connection restored |
| Delivery boy phone dies mid-delivery | Customer sees "Connecting…" on map. Customer can still call store owner for update |
| Customer GPS inaccurate (indoors) | Address fields are mandatory. Manual address entry always available |

---

## 21. END-TO-END USER JOURNEYS

These journeys describe the complete experience step-by-step. Use these to build screen flows and write tests.

---

### 21.1 Customer Journey — First Order (Happy Path)

```
1. Priya downloads DHAV from Play Store
2. Opens app → sees splash → "Continue with Google"
3. Picks her Google account → Firebase auth succeeds
4. Profile setup: enters name "Priya", adds home address using map picker
5. Home screen opens → app auto-fetches GPS → "Delivering to: Kothrud, Pune 📍"
6. Sees category chips, taps "Dairy"
7. Adds Amul Butter 100g + Tata Salt 1kg to cart
8. Taps Cart → reviews items → taps "Place Order"
9. Sees broadcasting animation: "Finding your nearest kirana store…"
10. Within 15 seconds → "Sharma Kirana accepted your order"
11. Sees order tracking screen with status timeline
12. After 5 min → "Your order is being packed"
13. After 10 min → "Out for delivery — Raju (delivery boy)"
14. Map appears with live moving pin showing Raju's bike location
15. ETA: "Arriving in 6 minutes"
16. Pin reaches her location → Raju calls
17. Priya receives groceries, pays cash to Raju
18. Raju marks delivered → Priya sees "Delivered ✅"
19. App asks: "Rate your experience" → 5 stars
20. Priya is happy. Sharma Kirana gets dynamic percentage fee added to weekly settlement.
```

---

### 21.2 Customer Journey — No Store Available (Edge Case)

```
1. Priya places order at 11:30 PM (most kiranas closed)
2. Broadcasting animation runs for 45 seconds (1km radius)
3. No store accepts → wave 2 starts (2km radius)
4. Another 45 seconds, no acceptance → wave 3 (3km radius)
5. 60 more seconds, no acceptance
6. Final screen: "Sorry, no stores available right now. Try in some time."
7. Offer: "Notify me when a store opens nearby" (opt-in)
8. Order saved with status: failed
9. No platform fee owed (no delivery happened)
10. Push notification next morning at 8 AM when stores reopen
```

---

### 21.3 Store Owner Journey — Receiving First Order

```
1. Sharma ji is sitting at counter, phone in pocket
2. DHAV app rings loudly (FCM high-priority notification)
3. Vibration + ringtone (audible even on silent mode)
4. He unlocks phone → sees popup: "NEW ORDER REQUEST — 3 items, 0.8km away"
5. Taps "VIEW ORDER DETAILS"
6. Sees: Tata Salt ✅, Amul Butter ✅, Maggi ✅ (all in his inventory)
7. Customer address: Flat 4B, Shivaji Nagar
8. Estimated earning: ₹85
9. Timer shows 31 seconds left
10. Sharma ji taps "ACCEPT ORDER"
11. Confirmation popup: "Can you deliver in 45 minutes?" → YES
12. Active order screen opens
13. He packs the items in a bag
14. Taps "Order Packed ✅"
15. Selects Raju (his registered delivery boy) from dropdown → "Assign"
16. Raju's phone alerts: "New Delivery Assignment"
17. Raju accepts → grabs the bag from Sharma ji
18. Sharma ji taps "Delivery Boy Dispatched 🛵"
19. WebSocket channel opens — Raju's location starts streaming
20. After 15 min, Raju marks delivered
21. Order complete. Percentage fee added to Sharma ji's weekly settlement counter
```

---

### 21.4 Delivery Boy Journey — Raju's Day

```
1. Raju opens DHAV app at 9 AM
2. Logs in with Google account (set up by Sharma ji)
3. Sees simple Home screen: "Hi Raju, Status: 🟢 Available"
4. Toggles Available ON
5. Waits at the store
6. Order assigned → popup: "NEW DELIVERY — Pickup: Sharma Kirana, Drop: Shivaji Nagar"
7. Cash to collect: ₹85
8. Taps ACCEPT
9. Map screen opens — shows route from store to customer
10. Two options: Use in-app map OR tap "Open in Google Maps"
11. Raju prefers Google Maps → taps it → Google Maps opens with navigation
12. While riding, WebSocket continues streaming his GPS (background)
13. Customer Priya sees Raju's pin moving on her app
14. Raju reaches → calls Priya from app
15. Hands over bag, collects ₹85
16. Taps "MARK AS DELIVERED" in DHAV app
17. Confirmation: "Confirm delivery and cash collected?" → Yes
18. Screen returns to Available state
19. By end of day, Raju has done 6 deliveries
20. Sharma ji can pay Raju his own daily wage separately (DHAV doesn't manage delivery boy pay)
```

---

### 21.5 Admin Journey — Weekly Settlement Cycle

```
1. Monday 8 AM — Automated job runs:
   - For each store: calculate total platform fee from last week
   - Create WeeklySettlement entry: total_fee_owed = Sum of (Order Total * Platform Fee Percentage)
   - Send notification to each store
2. Store owners see "₹120 owed for last week" in their app
3. Stores pay via UPI to DHAV's UPI ID
4. Admin user (Rahul) logs into dashboard
5. Goes to Settlements → filters "Pending"
6. Sees 23 pending settlements
7. Bank statement shows: "Sharma Kirana paid ₹120"
8. Rahul finds Sharma in list → taps "Mark as Paid"
9. Enters payment mode (UPI), date, transaction ref
10. Settlement marked "settled"
11. Saturday — 8 stores still pending
12. System auto-sends reminders to those 8 stores
13. Sunday midnight — stores still unpaid get flagged "payment_overdue"
14. Their geofence index entries get is_active = false
15. They are hidden from all broadcasts until paid
16. Admin sees red badge "8 Overdue" — calls them personally
```

---

## 22. EDGE CASES & ERROR HANDLING

Every edge case below MUST be handled explicitly in code:

### 22.1 Order Edge Cases

| Edge Case | Handling |
|---|---|
| Customer places order, then closes app immediately | Order continues broadcasting in background. Customer sees state on reopen |
| Customer cancels while broadcasting | DELETE /orders/{id}/cancel — only allowed if status = broadcasting (not after accept) |
| Customer cancels after store accepted | Not allowed via app. Customer must call store directly. Admin can override |
| Customer's GPS location is inside Pune but no stores near | After wave 3 fails → suggest manual zone change |
| Store accepts but later realizes they don't have an item | Store calls customer from app → customer can accept partial order or cancel |
| Customer phone dies during delivery | Delivery boy still has address + phone. Phone-based call still works |
| Store accepts but app crashes before pack | If no "packed" action within 15 minutes → admin alert. Order auto-cancelled after 30 min |
| Two delivery boys somehow both arrive | UI prevents this — only one assignment per order in atomic Firebase transaction |
| Customer enters wrong address | Customer can edit before order is accepted. After accept, must call store |
| Address has no GPS coordinates (manual entry) | Force map pin drop during address entry — required field |

### 22.2 Network & Connectivity Edge Cases

| Edge Case | Handling |
|---|---|
| Store phone loses internet mid-order | Show offline banner. Cache last known order state. Auto-sync on reconnect |
| Delivery boy enters area with no signal | WebSocket reconnects automatically on signal restore. GPS still tracked locally, sent in batch on reconnect |
| Customer loses internet while tracking | Map shows last known position with "Connecting…" indicator |
| FastAPI backend goes down briefly | Flutter apps use exponential backoff retry (1s, 2s, 4s, 8s) |
| FCM notification doesn't deliver | Backup: poll `/orders/my/incoming` every 30s when store app is open |

### 22.3 Geofencing Edge Cases

| Edge Case | Handling |
|---|---|
| Customer near city boundary | Geohash neighbor cells handle boundary correctly |
| Store moves to new address | Admin updates location → geohash index regenerated, old entry removed |
| Multiple stores in same building | All get indexed in same geohash cell — broadcast fires to all |
| Customer in moving vehicle places order | Snapshot of GPS at order time is locked. Future moves don't affect order |

### 22.4 Race Condition Edge Cases

| Edge Case | Handling |
|---|---|
| Two stores accept order at the same millisecond | Firebase atomic transaction picks one — other gets "Already taken" |
| Customer cancels exactly when store accepts | Transaction checks both states — whichever wrote first wins |
| Store toggles closed during broadcast | Already-sent broadcasts honored. New broadcasts skip them |
| Delivery boy goes offline mid-delivery | Store owner sees "Delivery boy offline" warning. Can reassign |

### 22.5 Data Validation

All API endpoints must validate:
- GPS coordinates: lat in [-90, 90], lng in [-180, 180], and within Pune bounds for orders
- Phone numbers: Indian format `+91XXXXXXXXXX` or `XXXXXXXXXX`
- Quantities: positive numbers only
- Order total: must match sum of item prices
- Address: required fields filled before order
- Inventory toggles: store can only mark items that exist in catalog

---

## 23. FIREBASE SECURITY RULES

These rules MUST be deployed to Firebase Realtime Database:

```json
{
  "rules": {
    "users": {
      "$user_id": {
        ".read": "$user_id === auth.uid",
        ".write": "$user_id === auth.uid"
      }
    },
    "stores": {
      "$store_id": {
        ".read": "auth != null",
        ".write": "root.child('admin_users').child(auth.uid).exists() || data.child('owner_uid').val() === auth.uid"
      }
    },
    "orders": {
      "$order_id": {
        ".read": "auth != null && (data.child('customer_id').val() === auth.uid || data.child('accepted_by_store_id').val() === auth.uid || root.child('admin_users').child(auth.uid).exists())",
        ".write": "root.child('admin_users').child(auth.uid).exists()"
      }
    },
    "catalog": {
      ".read": "auth != null",
      ".write": "root.child('admin_users').child(auth.uid).exists()"
    },
    "geofence_index": {
      ".read": "auth != null",
      ".write": "root.child('admin_users').child(auth.uid).exists()"
    },
    "strikes": {
      "$store_id": {
        ".read": "$store_id === auth.uid || root.child('admin_users').child(auth.uid).exists()",
        ".write": "root.child('admin_users').child(auth.uid).exists()"
      }
    },
    "settlements": {
      "$store_id": {
        ".read": "$store_id === auth.uid || root.child('admin_users').child(auth.uid).exists()",
        ".write": "root.child('admin_users').child(auth.uid).exists()"
      }
    },
    "admin_users": {
      ".read": "root.child('admin_users').child(auth.uid).exists()",
      ".write": "root.child('admin_users').child(auth.uid).child('role').val() === 'super_admin'"
    }
  }
}
```

**Storage Rules:**
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /store_photos/{storeId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && (request.auth.uid == storeId || isAdmin());
    }
    match /catalog_photos/{itemId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }
    function isAdmin() {
      return firestore.exists(/databases/(default)/documents/admin_users/$(request.auth.uid));
    }
  }
}
```

**Key principle:** All writes to critical data (orders, geofence, strikes, settlements) go through FastAPI — NEVER direct Firebase writes from Flutter apps. The apps only READ from Firebase.

---

## 24. TESTING STRATEGY

### 24.1 Unit Tests (Backend — FastAPI)

Required test coverage:
- `services/geofencing.py` — geohash encoding, neighbor lookup, distance calculation
- `services/broadcasting.py` — wave escalation, store filtering, atomic acceptance
- `services/penalties.py` — strike incrementing, suspension logic, auto-lift
- `services/settlements.py` — fee calculation, weekly aggregation
- `routers/orders.py` — order placement validation, cancellation rules

```bash
# Run with pytest
pip install pytest pytest-asyncio
pytest backend/tests/ -v
```

### 24.2 Integration Tests

- Order broadcast end-to-end: place order → simulate store accept → verify Firebase state
- Race condition test: two stores accept simultaneously → only one wins
- Strike escalation: simulate 3 failures → verify suspension
- WebSocket: connect delivery boy + customer → send GPS → verify customer receives

### 24.3 Flutter Widget Tests

For each app:
- Login flows
- Order placement
- Order acceptance popup with timer
- Map rendering
- Offline state handling

### 24.4 Manual QA Checklist (Before Each Release)

Customer App:
- [ ] Google Sign-In works on Android + iOS
- [ ] Auto-location fetches correctly
- [ ] Cart calculation accurate
- [ ] Order broadcasting animation smooth
- [ ] Live map updates smoothly (no jumps)

Store App (Owner role):
- [ ] FCM ring sound plays in silent mode
- [ ] Order popup appears even when app is killed
- [ ] 45-second timer accurate
- [ ] Accept button responds instantly
- [ ] Inventory toggle persists

Store App (Delivery Boy role):
- [ ] Sees only delivery view, no store data
- [ ] Google Maps launch button works
- [ ] GPS streams every 3 seconds
- [ ] Mark delivered closes WebSocket

Admin Dashboard:
- [ ] Real-time order updates work
- [ ] Store onboarding flow complete
- [ ] Settlement marking works
- [ ] Map shows all stores

---

## 25. DEPLOYMENT GUIDE

### 25.1 Backend (FastAPI)

**Recommended: Railway.app or Google Cloud Run**

```bash
# Railway deployment (easiest)
1. Push backend/ to GitHub repo
2. Connect Railway to repo
3. Add environment variables from section 17
4. Railway auto-detects Python + FastAPI
5. Deploy → get URL like https://DHAVl-backend.up.railway.app
```

```dockerfile
# Dockerfile for backend (if using Cloud Run)
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

### 25.2 Firebase Setup

```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login
firebase init

# Enable in Firebase Console:
# - Authentication (Google + Email/Password)
# - Realtime Database
# - Storage
# - Cloud Messaging (FCM)

# Deploy security rules
firebase deploy --only database
firebase deploy --only storage
```

### 25.3 Customer App + Store App (Flutter)

```bash
# Build Android APK
cd customer_app
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Build iOS (Mac only)
flutter build ios --release

# Upload to Play Store / App Store via Fastlane or manually
```

### 25.4 Admin Dashboard (Flutter Web)

```bash
cd admin_dashboard
flutter build web
firebase deploy --only hosting
# Output: hosted at https://kirana-mal-pune.web.app
```

### 25.5 Scheduled Jobs (Cron)

Use APScheduler inside FastAPI or external scheduler:

```python
# In backend/services/scheduler.py
from apscheduler.schedulers.asyncio import AsyncIOScheduler

scheduler = AsyncIOScheduler()

# Daily 6 AM IST — lift expired suspensions
scheduler.add_job(lift_expired_suspensions, 'cron', hour=6, minute=0)

# Daily every 30 min — auto-fail stuck orders
scheduler.add_job(auto_fail_stuck_orders, 'interval', minutes=30)

# Every Monday 8 AM — generate weekly settlements
scheduler.add_job(generate_weekly_settlements, 'cron', day_of_week='mon', hour=8)

# Every Sunday midnight — flag overdue payments
scheduler.add_job(flag_overdue_settlements, 'cron', day_of_week='sun', hour=23, minute=59)

scheduler.start()
```

---

## 26. USE CASES

These are real scenarios the system must handle. Each is a test case.

### UC-1: Happy Path Order
**Actor:** Customer  
**Scenario:** Customer in Kothrud orders groceries at 6 PM. 5 stores nearby. First store accepts in 8 seconds. Delivery boy delivers in 22 minutes.  
**Expected:** Order succeeds. Store gets percentage fee added to settlement. Customer rates 5 stars.

### UC-2: All Nearby Stores Closed
**Actor:** Customer  
**Scenario:** Customer orders at 1 AM. No stores within 3km are open.  
**Expected:** All 3 broadcast waves fail. Order marked failed. Customer notified to try in morning. No fee charged to anyone.

### UC-3: Store Accepts but Doesn't Deliver
**Actor:** Store  
**Scenario:** Store accepts order, packs it, dispatches delivery boy, but delivery boy never reaches customer (got distracted).  
**Expected:** After 3 hours, auto-fail triggers. Customer notified. Store gets 1 strike. Counter increments to 1.

### UC-4: Store Gets 3 Strikes
**Actor:** Store + Admin  
**Scenario:** Store accumulates 3 failed deliveries over 2 weeks.  
**Expected:** On 3rd strike, store auto-suspended for 7 days. Removed from geofence index. After 7 days, auto-lifted, re-added to index.

### UC-5: Two Stores Tap Accept Simultaneously
**Actor:** Two stores  
**Scenario:** Order broadcasts to 4 stores. Two stores tap Accept at nearly the same time.  
**Expected:** Firebase atomic transaction selects winner. Loser gets "Order already taken" message. Customer sees only winner's info.

### UC-6: Customer Tracks Delivery Live
**Actor:** Customer  
**Scenario:** Delivery boy is on the way. Customer opens tracking screen.  
**Expected:** Google Map shows delivery boy's pin moving every 3 seconds. ETA updates dynamically. No flicker — smooth animation. Pin doesn't disappear if internet briefly drops.

### UC-7: Delivery Boy Uses External Google Maps
**Actor:** Delivery Boy  
**Scenario:** Delivery boy prefers Google Maps navigation over in-app map.  
**Expected:** Tap "Open in Google Maps" → external app opens with destination. WebSocket continues streaming GPS in background. Customer still sees live position.

### UC-8: Store Refuses to Pay Weekly Fee
**Actor:** Store + Admin  
**Scenario:** Sharma Kirana doesn't pay ₹120 fee by Sunday.  
**Expected:** Monday morning → store flagged "payment_overdue" → removed from geofence index → no broadcasts received until paid. Admin sees alert.

### UC-9: Customer Tries to Order Outside Pune
**Actor:** Customer  
**Scenario:** Customer enables location while in Mumbai, opens app.  
**Expected:** App detects location outside Pune service area → shows message: "We're only in Pune currently. Stay tuned!" → no broadcast possible.

### UC-10: Store Owner Adds Second Delivery Boy
**Actor:** Store Owner  
**Scenario:** Sharma ji wants to add his cousin as second delivery boy.  
**Expected:** Goes to Manage Delivery Boys → adds name + phone + Google email → system creates account → cousin gets SMS with app link → logs in → sees delivery boy view only.

### UC-11: New Store Onboarding by Admin
**Actor:** Admin (Rahul)  
**Scenario:** Rahul visits a new kirana store in Aundh. Spends 20 minutes onboarding.  
**Expected:** Rahul opens admin dashboard → "Onboard New Store" → fills form with shop photo, owner Google account, operating hours, location pin → ticks 80 catalog items the store has → submits → store is live immediately → first test order works.

### UC-12: Customer Reorders Past Order
**Actor:** Returning Customer  
**Scenario:** Priya orders the same items she ordered last week.  
**Expected:** Goes to Order History → finds last week's order → taps "Reorder" → cart auto-populates → checkout → new broadcast starts (may go to different store this time).

### UC-13: Power Outage at Store
**Actor:** Store  
**Scenario:** Power goes off, store owner's phone is on battery, no internet.  
**Expected:** Store app shows "Offline" banner. Doesn't receive new broadcasts. Doesn't get strike (system detects offline gracefully). When back online, sees missed orders summary.

### UC-14: Admin Adds New Catalog Item
**Actor:** Admin  
**Scenario:** New product "Patanjali Honey 500g" needs to be added.  
**Expected:** Admin → Catalog → Add Item → enters English/Hindi/Marathi names, category Dairy → uploads photo → activates → all stores immediately see it in their inventory tick list.

### UC-15: Customer Reports Issue
**Actor:** Customer  
**Scenario:** Delivery boy was rude, customer wants to complain.  
**Expected:** Order History → tap the order → "Report Issue" → select reason → submit → admin sees issue in dashboard linked to order → admin can call customer or store → action taken.

---

## 🚀 FINAL NOTES FOR CLAUDE CLI

When generating code from this PRD:

1. **Build in this order:**
   - First: FastAPI backend (most complex, foundation)
   - Second: Firebase setup + security rules
   - Third: Store App (owner + delivery boy views)
   - Fourth: Customer App
   - Fifth: Admin Dashboard

2. **Critical files to start with:**
   - `backend/services/geofencing.py` (geohash + Haversine)
   - `backend/services/broadcasting.py` (3-wave logic + atomic transactions)
   - `backend/services/location_ws.py` (WebSocket relay)
   - `customer_app/lib/features/orders/order_tracking_screen.dart` (live map)
   - `store_app/lib/features/orders/incoming_order_screen.dart` (FCM popup with timer)

3. **Don't skip:**
   - Firebase atomic transactions for order acceptance
   - WebSocket in-memory relay (don't store GPS in DB)
   - High-priority FCM with sound for store alerts
   - Geohash neighbor cells (not just center cell)
   - Strike auto-lift cron job
   - Settlement weekly cron job

4. **Use these exact packages:**
   - Flutter: `google_maps_flutter`, `geolocator`, `firebase_auth`, `firebase_messaging`, `firebase_database`, `web_socket_channel`, `url_launcher`, `intl`
   - FastAPI: `firebase-admin`, `fastapi`, `uvicorn`, `python-geohash`, `apscheduler`, `python-dotenv`, `websockets`

5. **Localization:**
   - Default English. Hindi + Marathi `.arb` files in `/lib/l10n/`
   - Store app defaults to Marathi for Pune

---

*End of PRD — DHAV v4.0 (FINAL)*

*This document is complete and ready for development.*

**Summary of key product decisions:**
- B2B platform fee (store pays DHAV weekly, customer never sees fee)
- Geohash-based geofencing for O(1) store lookup
- 3-wave broadcasting (1km → 2km → 3km) with atomic Firebase transactions
- WebSocket-based live location (in-memory relay, no DB writes — like Zomato/Uber)
- Delivery Boy is a separate role inside Store App (same APK, different UI)
- Customer auto-location on app open
- Order popup with "View Details" and "Quick Accept" options
- Strike system: warning → 7-day suspension → permanent ban
- Pune-only at launch, expand later

**Ready to feed to Claude CLI. Start with the backend.**
