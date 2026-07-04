# DHAV Backend — Complete API Reference

> Base URL (Production): `https://dhav-backend.onrender.com` (Render)  
> All endpoints require `Authorization: Bearer <Firebase ID Token>` unless marked **Public**

---

## Authentication Header
```
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
```
Obtain the Firebase ID Token from `FirebaseAuth.instance.currentUser.getIdToken()` in Flutter.

---

## Router: `/auth`

### POST `/auth/verify-token`
**Purpose:** Verify Firebase token + bootstrap user profile on first login  
**Auth:** Firebase ID Token (Bearer)  
**Roles:** Any authenticated Firebase user

**Behavior:**
- Verifies JWT with Firebase Admin SDK (clock_skew_seconds=60)
- If user node doesn't exist in RTDB → creates it
- First-login detection: scans `delivery_boys` for matching `google_account_email` → assigns `delivery` role
- Returns user's current role

**Response:**
```json
{
  "uid": "abc123",
  "email": "user@example.com",
  "display_name": "Ravi Kumar",
  "role": "customer",
  "is_active": true
}
```

---

## Router: `/customers`

### GET `/customers/me`
**Roles:** `customer`  
**Purpose:** Get own profile from Firebase RTDB

### PATCH `/customers/me`
**Roles:** `customer`  
**Purpose:** Update profile fields  
**Allowed fields:** `display_name`, `phone`, `default_address`, `fcm_token`, `language`

### POST `/customers/me/addresses`
**Roles:** `customer`  
**Purpose:** Add a saved address  
**Body:** `{ label, flat_building, area, city, pincode, lat, lng }`

### PATCH `/customers/me/addresses/{index}`
**Roles:** `customer`  
**Purpose:** Update an address by array index  
**Allowed fields:** `label`, `flat_building`, `floor`, `area`, `landmark`, `city`, `pincode`

### DELETE `/customers/me/addresses/{index}`
**Roles:** `customer`  
**Purpose:** Remove an address by array index

---

## Router: `/stores`

### POST `/stores`
**Roles:** `admin`  
**Purpose:** Admin creates a store for an existing user  
**Body:**
```json
{
  "owner_uid": "uid123",
  "owner_name": "Ramesh Patil",
  "shop_name": "Patil Kirana",
  "phone": "9876543210",
  "email": "ramesh@example.com",
  "address": "FC Road, Pune",
  "lat": 18.5204,
  "lng": 73.8567,
  "operating_hours": { "open": "09:00", "close": "22:00" }
}
```
**Side effects:** Sets user role to `store_owner`, encodes geohash, indexes in geofence

### POST `/stores/register`
**Roles:** Any authenticated user (not `delivery`)  
**Purpose:** Store owner self-registers — starts unverified  
**Body:** Same as above minus `owner_uid` (inferred from token), **plus mandatory
`"store_type": "grocery|fruits|electronics|pharmacy"`** — determines which marketplace
catalog the store sees and which orders it receives. Optional `"self_delivery": true`
— store delivers its own orders (owner rides + shares live GPS, no delivery partner;
defaults `false`).  
**Note:** NOT indexed in geofence until admin verifies

### GET `/stores/me`
**Roles:** `store_owner`  
**Purpose:** Get own store profile

### PATCH `/stores/me/profile`
**Roles:** `store_owner`  
**Purpose:** Update store name, phone, hours, address, location, or `self_delivery`  
**Body (all optional):** `shop_name`, `owner_name`, `phone`, `address`, `lat`, `lng`,
`operating_hours`, `self_delivery` (bool — toggle self-delivery on/off)  
**Note:** If location changes and store is open → re-indexes geofence

### PATCH `/stores/me/toggle`
**Roles:** `store_owner`  
**Purpose:** Open or close the store  
**Body:** `{ "is_open": true }`  
**Guards:** Cannot open if suspended or unverified  
**Side effects:** Adds/removes from geofence_index

### PATCH `/stores/me/fcm-token`
**Roles:** `store_owner`  
**Body:** `{ "fcm_token": "..." }`  
**Purpose:** Save FCM token for push notifications

### PATCH `/stores/me/inventory`
**Roles:** `store_owner`  
**Body:** `{ "available_item_ids": ["id1", "id2"] }`  
**Purpose:** Set which catalog items are available in this store

### GET `/stores/me/orders`
**Roles:** `store_owner`  
**Query params:** `status` (filter), `limit` (default 50, max 200)  
**Purpose:** Get orders accepted by this store

### GET `/stores/me/delivery-boys`
**Roles:** `store_owner`  
**Purpose:** List delivery boys belonging to this store

### POST `/stores/me/delivery-boys`
**Roles:** `store_owner`  
**Body:** `{ "name": "Suresh", "phone": "9898989898", "google_account_email": "suresh@gmail.com" }`  
**Note:** `google_account_email` is used to match the delivery boy when they first log in

### DELETE `/stores/me/delivery-boys/{delivery_boy_id}`
**Roles:** `store_owner`

### POST `/stores/me/upload-image`
**Roles:** `store_owner`  
**Purpose:** Multipart `file` → uploads a product photo to Supabase Storage
(`requests/{store_id}/…`, max 5 MB) → `{url, path}`. Used by the barcode
submission flow (≤3 images per product).

### POST `/stores/me/custom-items`
**Roles:** `store_owner`  
**Purpose:** Submit a product for admin review (usually prefilled by a barcode
scan). On approval it enters the global catalog and is auto-stocked for this store.  
**Body:** `{ "name", "name_hindi?", "name_marathi?", "category?", "unit", "price",
"mrp?", "notes?", "barcode?", "brand?", "description?", "images?": ["≤3 Supabase URLs"],
"external_image_urls?": ["barcode-API image URLs"], "marketplace_type",
"category_id", "subcategory_id" }`  
**409** `{"detail": {"code": "already_in_catalog", "catalog_item_id", "item_name"}}`
when the barcode already exists — add that item to inventory instead.

### GET `/stores/me/custom-items`
**Roles:** `store_owner`  
**Purpose:** List own product submissions with `status`
(pending|approved|rejected), `rejection_reason`, `catalog_item_id`

### GET `/stores/{store_id}`
**Roles:** Any authenticated user  
**Purpose:** Get a specific store profile

---

## Router: `/orders`

### POST `/orders`
**Roles:** `customer`  
**Purpose:** Place a new order — triggers wave broadcasting  
**Body:**
```json
{
  "customer_address": {
    "label": "Home",
    "flat_building": "A-101",
    "area": "Kothrud",
    "city": "Pune",
    "lat": 18.5204,
    "lng": 73.8567
  },
  "items": [
    {
      "item_id": "item123",
      "item_name": "Tata Salt",
      "quantity": 2,
      "unit": "kg",
      "price_per_unit": 25.0,
      "total_price": 50.0
    }
  ]
}
```
**Plus:** `"marketplace_type": "grocery|fruits|electronics|pharmacy"` (default `grocery`) —
the cart's marketplace. The order is broadcast **only** to stores of this `store_type`, so an
electronics order never reaches a grocery/fruits/pharmacy store (and vice-versa).  
**Checkout extras (optional, all default empty/0):** `"gstin": "27ABCDE1234F1Z5"`,
`"donation_amount": 5`, `"handling_charge": 5`, `"delivery_instructions": ["avoid_calling","no_bell"]`.
Stored on the order; `total_customer_amount = items + handling + donation`. *(migration 007)*  
**Response:** `{ "order_id": "...", "status": "broadcasting" }`

### POST `/orders/direct`
**Roles:** `customer`  
**Purpose:** Order directly from a specific store (no waves)  
**Body:** Same as above (incl. checkout extras) + `"store_id": "store123"`

### Wishlist — GET/POST/DELETE `/customers/me/wishlist`
**Roles:** `customer`  
- `GET /customers/me/wishlist` → `{ "items": [ <catalog_item> ] }` (saved items, newest first)  
- `POST /customers/me/wishlist/{item_id}` → add (idempotent) → `{ "status": "added" }`  
- `DELETE /customers/me/wishlist/{item_id}` → remove → `{ "status": "removed" }`  
Backed by the `wishlist (uid, item_id)` table *(migration 007)*.

### GET `/orders` or GET `/orders/customer/me`
**Roles:** `customer`  
**Purpose:** Get own order history (both endpoints return same data)

### GET `/orders/{order_id}`
**Roles:** Any authenticated user  
**Purpose:** Get a specific order  
**Guard:** Customer can only see their own order

### POST `/orders/{order_id}/accept`
**Roles:** `store_owner`  
**Purpose:** Accept a broadcasting order (atomic transaction)  
**Side effects:**  
- Firebase transaction (race-condition safe)  
- Delivery fee recalculated with Haversine  
- FCM to customer: "Order accepted"  
- FCM to other stores: "Order taken"  
- `cancel_broadcast()` cancels the asyncio broadcast task

### POST `/orders/{order_id}/reject`
**Roles:** `store_owner`  
**Body:** `{ "reason": "out_of_stock" }` (optional)  
**Purpose:** Record that this store rejected the order

### POST `/orders/{order_id}/assign-delivery-boy`
**Roles:** `store_owner`  
**Body:** `{ "delivery_boy_id": "boy123" }`  
**Purpose:** Assign delivery personnel (must be this store's boy)

### POST `/orders/{order_id}/packed`
**Roles:** `store_owner`  
**Purpose:** Mark order as packed (requires status="accepted")

### POST `/orders/{order_id}/dispatched`
**Roles:** `store_owner`  
**Purpose:** Mark order as out_for_delivery  
**Side effects:** Sets `ws_channel_id`, FCM to customer: "Out for delivery". If the store has
`self_delivery=true` and no delivery partner was assigned, also stamps
`assigned_delivery_boy_id = owner_uid`, `delivery_boy_name = shop name`, `delivery_boy_phone = store phone`
— so the live-location WS authorizes the owner as the rider and the customer's tracking card shows the shop.

### POST `/orders/{order_id}/delivered`
**Roles:** `store_owner` or `delivery`  
**Purpose:** Mark order as delivered  
**Side effects:** Closes WS channel, increments store counter, FCM to customer

### POST `/orders/{order_id}/report-failure`
**Roles:** `store_owner` or `admin`  
**Purpose:** Report order failure → triggers penalty system

### POST `/orders/{order_id}/review`
**Roles:** `customer`  
**Body:** `{ "rating": 4, "comment": "Good service" }`  
**Purpose:** Submit 1–5 star review for delivered order  
**Side effects:** Recalculates store average rating

### GET `/orders/delivery/me`
**Roles:** `delivery`  
**Purpose:** Get delivery boy's assigned orders

---

## Router: `/catalog`

> **Marketplace-aware.** `marketplace_type` ∈ `grocery | fruits | electronics | pharmacy`.
> Items carry: `marketplace_type`, `category_id`, `subcategory_id`, `brand`, `sku`,
> `description`, `unit`, `price`, `mrp`, `discount_percent`, `stock_quantity`,
> `image_url` (primary), `images` (3–5 URL array), `specs` (key→value map).

### GET `/catalog/search?q=&marketplace_type=&limit=20`
**Auth:** Public  
**Purpose:** Typo-tolerant ranked product search (pg_trgm, migration 015).
Prefix > substring (name/brand/hindi/marathi) > trigram similarity, rating as
tiebreak. Returns `{items: [catalog item shape], category_matches: [{id, name,
marketplace_type}]}` for "browse category" shortcuts.

### GET `/catalog/popular?marketplace_type=&limit=10`
**Auth:** Public  
**Purpose:** Most-rated products for the search idle state → `{items}`. Cached 5 min.

### GET `/catalog/barcode/{code}`
**Roles:** `store_owner`, `admin`  
**Purpose:** Resolve a scanned barcode.
`{found_in_catalog: true, item}` → the product already exists globally (offer
"add to inventory"). `{found_in_catalog: false, prefill, source}` → `prefill =
{name, brand, description, quantity_text, image_urls[≤3]}` from free public DBs
(Open Food Facts → Open Beauty Facts → Open Products Facts → optional UPCitemdb),
cached 24 h. `prefill: null` → manual entry.

### GET `/catalog/fees`
**Auth:** Public  
**Purpose:** The fee card the apps use to build the customer bill (never hardcode
amounts client-side). Returns `{ platform_fee_flat, handling_charge,
delivery_fee_mode ("free"|"flat"|"per_km"), base_delivery_fee, delivery_fee_per_km }`.
Bill = items + platform_fee_flat + handling_charge + donation + delivery (₹0 while
`delivery_fee_mode` = `"free"`).

### GET `/catalog/marketplaces`
**Auth:** Public  
**Purpose:** DB-driven marketplace verticals (admin-configurable). Returns enabled
verticals ordered by `sort_order`: `{ wire, name, tab_label, emoji, color_primary,
color_primary_dark, color_accent, color_header_top, color_header_bottom, color_tint,
sort_order, is_enabled }`. Falls back to the built-in 4 if the `marketplaces` table is
missing/empty. *(migration 008)* Admin CRUD: `GET/POST/PATCH/DELETE /admin/marketplaces`
(+`/{wire}`); writes invalidate the catalog cache so the app updates on next load.

### GET `/catalog/categories`
**Auth:** Public  
**Query params:** `marketplace_type` (optional)  
**Purpose:** DB-driven categories (admin-managed `categories` table) — enabled + ordered.
Falls back to derived category strings only if the table is empty.

### GET `/catalog/subcategories`
**Auth:** Public  
**Query params:** `category_id` (optional), `marketplace_type` (optional)  
**Purpose:** Subcategories (the left rail on the category page).

### GET `/catalog/items`
**Auth:** Public  
**Query params:** `category`, `category_id`, `subcategory_id`, `marketplace_type`, `brand`, `search`, `limit` (default 50, max 500)  
**Note:** Search matches name, brand, name_hindi, name_marathi

### GET `/catalog/stores/nearby`
**Auth:** Public  
**Query params:** `lat`, `lng`, `radius_km` (default 5.0, max 20.0), `marketplace_type` (optional)  
**Purpose:** Find active, verified, non-suspended stores near a coordinate; when
`marketplace_type` is set, only stores of that type are returned.  
**Returns:** Stores sorted by distance ascending (each includes `store_type`)

### GET `/catalog/stores/nearby/all`
**Auth:** Public  
**Query params:** `lat`, `lng`, `radius_km`  
**Purpose:** All stores including inactive/suspended (for map display)

### GET `/catalog/stores/{store_id}`
**Auth:** Public  
**Purpose:** Get store profile + available items

### GET `/catalog/items/nearby`
**Auth:** Public  
**Query params:** `lat`, `lng`, `radius_km`, `category`, `category_id`, `subcategory_id`, `marketplace_type`  
**Purpose:** Items available across all nearby stores (type-filtered when `marketplace_type` set)

### POST `/catalog/items`
**Roles:** `admin`  
**Purpose:** Add item to master catalog

### PATCH `/catalog/items/{item_id}`
**Roles:** `admin`

### DELETE `/catalog/items/{item_id}`
**Roles:** `admin`  
**Purpose:** Soft-delete (sets is_active=False)

---

## Router: `/admin`

### Store Management

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/admin/stores` | List all stores (filters: is_active, is_suspended) |
| GET | `/admin/stores/{id}` | Get single store |
| POST | `/admin/stores/onboard` | Create store + Firebase Auth user |
| PUT | `/admin/stores/{id}` | Update any store field |
| DELETE | `/admin/stores/{id}` | Soft-delete (deactivate + remove from geofence) |
| PATCH | `/admin/stores/{id}/verify` | Verify store → enables it to go live |
| PATCH | `/admin/stores/{id}/suspend` | Suspend store for N days |
| PATCH | `/admin/stores/{id}/unsuspend` | Lift suspension, reset strike_count |
| GET | `/admin/stores/{id}/inventory` | View inventory with catalog items |
| PUT | `/admin/stores/{id}/inventory` | Update store inventory |
| GET | `/admin/stores/{id}/reviews` | View reviews + avg_rating |
| DELETE | `/admin/stores/{id}/reviews/{rev_id}` | Delete a review |
| GET | `/admin/stores/{id}/stats` | Order stats + revenue |

### Order Management

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/admin/orders` | List all orders (filter by status, limit) |
| POST | `/admin/orders/{id}/force-fail` | Force-fail + issue strike to store |

### Customer Management

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/admin/customers` | List all customers |
| GET | `/admin/customers/{uid}` | Get customer profile |
| GET | `/admin/customers/{uid}/orders` | Customer's order history + stats |

### Catalog Management (Admin)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/admin/catalog/items` | All items including inactive (with search/filter) |
| POST | `/admin/catalog/items` | Create catalog item (accepts marketplace_type, category_id, subcategory_id, brand, sku, description, price, mrp, discount_percent, stock_quantity, unit, image_url, images[], specs{}) |
| PATCH | `/admin/catalog/items/{id}` | Update item (same fields) |
| DELETE | `/admin/catalog/items/{id}` | Deactivate (soft) or permanent delete |

### Category / Subcategory CMS (Admin — DB-driven, replaces hardcoded categories)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/admin/categories?marketplace_type=` | List categories (incl. disabled), ordered |
| POST | `/admin/categories` | Create category `{marketplace_type, name, image_url, sort_order, is_enabled}` |
| PATCH | `/admin/categories/{id}` | Edit (name/image/marketplace/sort/enable) |
| DELETE | `/admin/categories/{id}?permanent=` | Disable (soft) or permanent delete (+ its subcategories) |
| POST | `/admin/categories/reorder` | `{order: [id,...]}` → set sort_order by index |
| GET | `/admin/subcategories?category_id=&marketplace_type=` | List subcategories |
| POST | `/admin/subcategories` | Create `{category_id, name, image_url, marketplace_type?, sort_order, is_enabled}` |
| PATCH | `/admin/subcategories/{id}` | Edit |
| DELETE | `/admin/subcategories/{id}?permanent=` | Disable or delete |

### Image Upload (Admin)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/admin/upload-image?folder=` | Multipart `file` → uploads to Supabase Storage bucket `dhav-images`, returns `{url, path}`. Needs `SUPABASE_SERVICE_KEY` + public bucket. |

### Product Requests (barcode onboarding approval queue)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/admin/product-requests?status=pending\|approved\|rejected\|all` | Store submissions with `store_name` joined |
| POST | `/admin/product-requests/{id}/approve` | Publish into the global catalog (body = optional field overrides). Sideloads barcode-API images to Supabase, dedupes by barcode (links instead of duplicating), auto-stocks the submitting store, FCM-notifies the owner |
| POST | `/admin/product-requests/{id}/reject` | `{reason}` → status=rejected + FCM notify |

### Analytics

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/admin/analytics/summary` | Platform-wide stats: stores, orders, fees |

### Settlements

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/admin/settlements` | List settlements (filter by status) |
| POST | `/admin/settlements/run` | Manually trigger the weekly settlement sweep (idempotent; same job as the Monday cron) → `{settlements_created}` |

### Admin Notifications

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/admin/notifications/broadcast` | Send push + persist to target audience |
| GET | `/admin/notifications/history` | View notification history |

**Broadcast body:**
```json
{
  "target": "all_customers",
  "title": "Summer Sale!",
  "message": "Get 20% off on all orders today",
  "type": "offer"
}
```
**target options:** `all_customers` | `all_stores` | `specific_store` | `specific_customer`

---

## Router: `/settlements`

> Money model: every order carries a **flat ₹10 platform fee** (`platform_fee_amount`,
> set at placement from `PLATFORM_FEE_FLAT`). The customer pays it at checkout; the
> store collects it (COD) and owes it to DHAV. The weekly sweep (Mon 08:00 IST, or
> `POST /admin/settlements/run`) groups all **unsettled** delivered orders
> (`orders.settlement_id IS NULL`, delivered before this week's Monday) into one
> settlement per store and stamps `orders.settlement_id`.

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/settlements/store/current` | Store owner: latest settlement + `unsettled_orders[]` (live accruing week) + `unsettled_fee_total` |
| GET | `/settlements/store/history` | Store owner: all own settlements, newest first |
| GET | `/settlements/{id}/orders` | Order-wise breakdown of a settlement (owning store or admin): `{order_id, delivered_at, total_product_amount, platform_fee_amount, delivery_fee, total_customer_amount}` |
| POST | `/settlements/{id}/mark-paid` | **Admin.** Record a payment: `{amount, payment_mode, notes?}` → updates `balance_due`/`status` (pending → partially_paid → settled) |

---

## Router: `/delivery`

### PATCH `/delivery/me/fcm-token`
**Roles:** `delivery`  
**Body:** `{ "fcm_token": "..." }`  
**Purpose:** Update FCM token for delivery boy

### GET `/delivery/me/profile`
**Roles:** `delivery`  
**Purpose:** Get own profile including store info

---

## Router: `/notifications`

### GET `/notifications/me`
**Roles:** Any authenticated user  
**Query:** `limit` (default 100)  
**Purpose:** Get own notifications, newest first  
**Response:**
```json
{
  "notifications": [...],
  "total": 45,
  "unread": 3
}
```

### PATCH `/notifications/{notif_id}/read`
**Roles:** Any authenticated user  
**Purpose:** Mark single notification as read

### PATCH `/notifications/me/read-all`
**Roles:** Any authenticated user  
**Purpose:** Mark all notifications as read

### DELETE `/notifications/me`
**Roles:** Any authenticated user  
**Purpose:** Clear all notifications

### DELETE `/notifications/{notif_id}`
**Roles:** Any authenticated user  
**Purpose:** Delete a single notification

---

## WebSocket: `/ws/order/{order_id}/location`

**Purpose:** Real-time delivery location streaming  
**Protocol:** WebSocket over HTTPS (wss://)

**Connection flow:**
```
1. Connect to wss://backend/ws/order/{order_id}/location
2. Send JSON: { "token": "<Firebase ID Token>", "role": "delivery_boy" | "customer" }
3. Receive: { "status": "connected", "role": "..." }

Delivery boy then sends every 3s:
{ "lat": 18.5204, "lng": 73.8567, "ts": 1716800000000 }

Customer receives:
{ "lat": 18.5204, "lng": 73.8567, "ts": 1716800000000 }
```

**Persistence / late-join seed:** the live fan-out is in-memory, but the rider's
position is also checkpointed to `orders.last_lat/last_lng/last_location_at` at
most every ~15 s. On connect, a customer is immediately sent the last-known
checkpoint (if written within the last 5 min) so the map isn't blank until the
next live ping. Migration: `011_order_location_persist.sql`.

**Keepalive:** the customer side sends a periodic text frame (~25 s); the backend
treats any customer→server text as a no-op ping (keeps idle proxies from dropping
the socket).

**Error codes:**
- `4000`: Bad init message
- `4001`: Invalid/missing token
- `4002`: Order not in out_for_delivery status
- `4003`: Forbidden (wrong user for this order)
- `4004`: Invalid role string

---

## GET `/health`
**Auth:** Public  
**Purpose:** Health check  
**Response:** `{ "status": "ok", "service": "dhav-backend", "version": "0.2.0" }`

---

## Call Masking (privacy-preserving deliverer ⇄ customer calls)

Bridges the deliverer and the customer through a **virtual number** so neither sees the other's real
phone. Provider-agnostic (`call_provider` = `exotel` | `mock`; falls back to `mock` until Exotel
credentials are set). Real numbers are resolved server-side from the order and are **never** returned
to the apps. See SYSTEM_DESIGN_NOTES Concept 25.

### POST `/calls/order/{order_id}`
**Auth:** Any authenticated user (customer, store_owner, or delivery) associated with the order  
**Purpose:** Place a masked call about this order. The **caller (initiator) is rung first** (leg A),
then the other party (leg B). Direction is inferred from the caller's role:
- `customer` → calls the deliverer (`order.delivery_boy_phone`)
- `store_owner` / `delivery` → calls the customer (`users.phone`)

**Preconditions:**
- Order status ∈ `accepted | packed | out_for_delivery` (else `409`).
- Both numbers must exist. Missing customer phone → `422` ("Add your phone number…"); missing
  deliverer phone → `422`.

**Response:**
```json
{ "ok": true, "status": "initiated", "masked": true,
  "call_id": "<uuid>", "virtual_number": "+91XXXXXXXXXX" }
```
**Errors:** `403` (not your order) · `409` (order not in a callable state) · `422` (a number is
missing) · `502` (provider failed to place the call) · `503` (no virtual number configured).

### POST `/calls/provider/callback`
**Auth:** Public (telephony provider posts here; matched by `CallSid`). **Not app-facing.**  
**Purpose:** Receives the provider's end-of-call status; updates `call_logs.status`,
`duration_seconds`, `ended_at`. Passed to Exotel automatically as the **StatusCallback**
(`{backend_public_url}/calls/provider/callback`).

### GET `/calls/logs?order_id=&limit=`
**Auth:** Admin  
**Purpose:** Audit log of masked calls (who/when/duration/status). `order_id` optional filter;
`limit` 1–500 (default 100).

**Config (env vars):** `CALL_MASKING_ENABLED`, `CALL_PROVIDER`, `CALL_VIRTUAL_NUMBERS` (comma-sep
ExoPhone pool), `EXOTEL_SID`, `EXOTEL_API_KEY`, `EXOTEL_API_TOKEN`, `EXOTEL_SUBDOMAIN`,
`BACKEND_PUBLIC_URL`.

---

## HTTP Error Reference

| Code | Meaning |
|------|---------|
| 400 | Bad request (e.g., store inactive) |
| 401 | Missing/invalid/expired token |
| 403 | Wrong role, account inactive, store suspended |
| 404 | Resource not found |
| 409 | Conflict (order already accepted, already reviewed, etc.) |
| 422 | Validation error (missing required fields) |
| 500 | Internal server error (Firebase failures, etc.) |
