# 📡 DHAV — API Specifications

Complete reference for all backend endpoints. Use this when building Flutter apps to know exactly what data to send and what to expect back.

**Base URL (dev):** `http://localhost:8000`
**Base URL (prod):** `https://api.DHAVl.com` (update after deployment)

**All endpoints require:** `Authorization: Bearer <Firebase ID Token>` header (except `/auth/verify-token`)

**Response format:** JSON

---

## 🔐 AUTH ENDPOINTS

### POST /auth/verify-token
Verify Firebase ID Token and return user role.

**Request body:** (none — token is in header)

**Response 200:**
```json
{
  "user_id": "abc123",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "customer",
  "is_new_user": false
}
```

**role values:** `customer | store | delivery_boy | admin`

**Response 401:** Invalid token

---

## 👤 CUSTOMER ENDPOINTS

### GET /catalog/items
Get catalog items, optionally filtered.

**Query params:**
- `category` (optional): filter by category
- `search` (optional): search term
- `lat`, `lng` (optional): if provided, returns only items available in stores near this location

**Response 200:**
```json
{
  "items": [
    {
      "item_id": "item_001",
      "name": "Tata Salt 1kg",
      "name_hindi": "टाटा नमक 1 किलो",
      "name_marathi": "टाटा मीठ 1 किलो",
      "category": "Grains",
      "unit": "kg",
      "image_url": "https://...",
      "is_available_nearby": true
    }
  ]
}
```

---

### GET /catalog/categories
Get all categories.

**Response 200:**
```json
{
  "categories": [
    { "name": "Grains", "name_hindi": "अनाज", "icon_url": "..." },
    { "name": "Dairy", "name_hindi": "डेयरी", "icon_url": "..." }
  ]
}
```

---

### POST /orders
Place a new order. Triggers broadcasting.

**Request body:**
```json
{
  "items": [
    { "item_id": "item_001", "quantity": 1 },
    { "item_id": "item_002", "quantity": 2 }
  ],
  "delivery_address": {
    "label": "Home",
    "flat_building": "Flat 4B",
    "street": "Main Road",
    "area": "Kothrud",
    "city": "Pune",
    "pincode": "411038",
    "lat": 18.5074,
    "lng": 73.8077
  }
}
```

**Response 201:**
```json
{
  "order_id": "order_abc123",
  "status": "broadcasting",
  "broadcast_wave": 1,
  "broadcast_radius_km": 1.0,
  "estimated_wait_seconds": 45
}
```

**Response 400:** Invalid items / address out of service area

---

### GET /orders/{order_id}
Get current state of an order.

**Response 200:**
```json
{
  "order_id": "order_abc123",
  "status": "out_for_delivery",
  "items": [...],
  "total_product_amount": 85.0,
  "delivery_fee": 15.0,
  "total_customer_amount": 100.0,
  "accepted_by_store": {
    "store_id": "store_xyz",
    "shop_name": "Sharma Kirana",
    "distance_km": 0.8
  },
  "delivery_boy": {
    "name": "Raju",
    "phone": "+919999999999"
  },
  "estimated_delivery_minutes": 8,
  "ws_channel_id": "order_abc123_location",
  "created_at": "2026-05-16T14:30:00Z",
  "delivered_at": null
}
```

---

### GET /orders/my
Get customer's order history.

**Query params:**
- `page` (default 1)
- `limit` (default 20)
- `status` (optional filter)

**Response 200:**
```json
{
  "orders": [...],
  "total": 47,
  "page": 1,
  "has_more": true
}
```

---

### DELETE /orders/{order_id}
Cancel order. Only allowed if status = `broadcasting`.

**Response 200:**
```json
{ "message": "Order cancelled" }
```

**Response 409:** Cannot cancel (order already accepted)

---

## 🏪 STORE ENDPOINTS

### POST /orders/{order_id}/accept
Accept an incoming order. Atomic — only one store wins.

**Response 200 (WIN):**
```json
{
  "success": true,
  "order_id": "order_abc123",
  "order_details": { ... }
}
```

**Response 409 (LOST):**
```json
{
  "success": false,
  "message": "Order already accepted by another store"
}
```

---

### POST /orders/{order_id}/reject
Explicitly reject this order. Store won't get another ring for the same order.

**Request body:**
```json
{ "reason": "out_of_stock" }
```

---

### POST /orders/{order_id}/packed
Mark order as packed.

**Response 200:**
```json
{ "status": "packed", "next_step": "assign_delivery_boy" }
```

---

### POST /orders/{order_id}/dispatched
Confirm delivery boy is dispatched. Opens WebSocket channel.

**Request body:**
```json
{
  "delivery_boy_id": "db_001",
  "estimated_delivery_minutes": 15
}
```

**Response 200:**
```json
{
  "status": "out_for_delivery",
  "ws_channel_url": "wss://api.DHAVl.com/ws/order/order_abc123/location"
}
```

---

### POST /orders/{order_id}/delivered
Mark delivered. Closes WebSocket. Increments platform fee counter.

**Response 200:**
```json
{
  "status": "delivered",
  "platform_fee_percentage_applied": 5.0,
  "platform_fee_amount_added": 4.25,
  "this_week_total_fee": 124.25
}
```

---

### POST /orders/{order_id}/report-failure
Report delivery failure with reason.

**Request body:**
```json
{
  "reason": "customer_unavailable",
  "notes": "Called 3 times, no answer"
}
```

**reason values:** `customer_unavailable | item_unavailable | address_not_found | delivery_boy_unavailable | other`

---

### GET /store/inventory
Get store's current inventory tick list.

**Response 200:**
```json
{
  "store_id": "store_xyz",
  "available_item_ids": ["item_001", "item_002", "item_004"],
  "custom_items": [
    {
      "custom_item_id": "ci_001",
      "name": "Homemade Pickle",
      "price": 50,
      "unit": "jar",
      "is_available": true
    }
  ]
}
```

---

### PUT /store/inventory
Update inventory tick list.

**Request body:**
```json
{
  "available_item_ids": ["item_001", "item_002", "item_004", "item_007"]
}
```

---

### POST /store/custom-items
Add a custom item to store's catalog.

**Request body:**
```json
{
  "name": "Homemade Pickle",
  "price": 50,
  "unit": "jar",
  "image_url": "https://..."
}
```

---

### PUT /store/status
Toggle store open/closed. Updates geofence index.

**Request body:**
```json
{ "is_open": true }
```

---

### GET /store/settlement/current
Current week's pending fee.

**Response 200:**
```json
{
  "week_start": "2026-05-13",
  "week_end": "2026-05-19",
  "total_orders_delivered": 12,
  "total_fee_owed": 180,
  "status": "pending",
  "due_date": "2026-05-19T23:59:59Z",
  "DHAVl_upi_id": "DHAVl@hdfc"
}
```

---

### GET /store/settlement/history
Past settlements.

**Response 200:**
```json
{
  "settlements": [
    {
      "settlement_id": "settle_001",
      "week_start": "2026-05-06",
      "total_fee_owed": 120,
      "total_fee_paid": 120,
      "status": "settled",
      "paid_on": "2026-05-12"
    }
  ]
}
```

---

### POST /store/delivery-boys
Add a delivery boy to store.

**Request body:**
```json
{
  "name": "Raju Kumar",
  "phone": "+919999999999",
  "google_account_email": "raju@gmail.com"
}
```

**Response 201:**
```json
{
  "delivery_boy_id": "db_001",
  "invitation_sent": true
}
```

---

### DELETE /store/delivery-boys/{delivery_boy_id}
Remove delivery boy.

---

## 🛵 DELIVERY BOY ENDPOINTS

### POST /delivery-boy/assignments/{assignment_id}/accept
Accept a delivery assignment.

**Response 200:**
```json
{
  "success": true,
  "pickup_address": "Sharma Kirana, Near Bus Stop, Kothrud",
  "pickup_lat": 18.5074,
  "pickup_lng": 73.8077,
  "drop_address": "Flat 4B, Shivaji Nagar",
  "drop_lat": 18.5234,
  "drop_lng": 73.8456,
  "customer_phone": "+919999999999",
  "cash_to_collect": 85,
  "ws_url": "wss://api.DHAVl.com/ws/order/order_abc123/location"
}
```

---

### POST /delivery-boy/status
Toggle availability.

**Request body:**
```json
{ "is_available": true }
```

---

### GET /delivery-boy/history
Past deliveries.

---

## 🌐 WEBSOCKET — Live Location

### WSS /ws/order/{order_id}/location
Real-time location channel for delivery tracking.

**Query params (required):**
- `role`: `delivery_boy` or `customer`
- `token`: Firebase ID Token

**Authentication:** Token verified on connect. Invalid → close with code 4001.

**Delivery boy sends (every 3 seconds):**
```json
{
  "lat": 18.5103,
  "lng": 73.8201,
  "timestamp": "2026-05-16T14:32:15Z"
}
```

**Customer receives:** Same JSON payload (real-time relay).

**Connection lifecycle:**
1. Opens when order status → `out_for_delivery`
2. Closes automatically when order status → `delivered` or `failed`
3. Server-side timeout: 30 minutes max

---

## 👑 ADMIN ENDPOINTS

All admin endpoints require role = `admin`.

### GET /admin/stores
List all stores.

**Query params:**
- `status` (optional): active | suspended | pending_verification
- `zone` (optional): zone_id
- `search` (optional): name/area
- `page`, `limit`

---

### POST /admin/stores
Onboard new store.

**Request body:**
```json
{
  "owner_name": "Sharma ji",
  "shop_name": "Sharma Kirana",
  "phone": "+919999999999",
  "google_account_email": "sharma@gmail.com",
  "address": { ... },
  "lat": 18.5074,
  "lng": 73.8077,
  "operating_hours": { "open": "08:00", "close": "22:00" },
  "available_item_ids": ["item_001", "item_002"],
  "shop_photo_url": "https://..."
}
```

---

### PUT /admin/stores/{store_id}
Update store info.

---

### POST /admin/stores/{store_id}/verify
Mark store as verified. Adds to geofence index.

---

### POST /admin/stores/{store_id}/suspend
Manual suspension.

**Request body:**
```json
{
  "reason": "Customer complaints",
  "days": 7
}
```

---

### POST /admin/stores/{store_id}/lift-suspension
Manually lift suspension early.

---

### GET /admin/orders
All orders with filters.

---

### GET /admin/customers
Customer list.

---

### GET /admin/settlements
Settlements with filters (pending, overdue, settled).

---

### POST /admin/settlements/{settlement_id}/mark-paid
Record store payment.

**Request body:**
```json
{
  "amount": 180,
  "payment_mode": "upi",
  "payment_date": "2026-05-19T15:30:00Z",
  "notes": "UPI ref: 123456789"
}
```

---

### GET /admin/analytics/overview
Dashboard key metrics.

**Response 200:**
```json
{
  "total_active_stores": 47,
  "orders_today": 89,
  "orders_this_week": 612,
  "orders_this_month": 2341,
  "success_rate": 92.3,
  "platform_fee_today": 1335,
  "new_stores_this_week": 8,
  "stores_by_zone": [
    { "zone_name": "Kothrud", "count": 15 },
    { "zone_name": "Aundh", "count": 12 }
  ]
}
```

---

### GET /admin/analytics/zones
Per-zone metrics.

---

### GET /admin/catalog
Master catalog.

---

### POST /admin/catalog
Add catalog item.

**Request body:**
```json
{
  "name": "Patanjali Honey 500g",
  "name_hindi": "पतंजलि शहद 500 ग्राम",
  "name_marathi": "पतंजली मध 500 ग्राम",
  "category": "Dairy",
  "unit": "g",
  "image_url": "https://..."
}
```

---

### PUT /admin/catalog/{item_id}
Update catalog item.

---

### POST /admin/zones
Create a new geofence zone (Pune area).

**Request body:**
```json
{
  "zone_name": "Kothrud",
  "center_lat": 18.5074,
  "center_lng": 73.8077,
  "radius_km": 3,
  "polygon_coordinates": null
}
```

---

### GET /admin/config/charges
Get current dynamic fee configurations.

**Response 200:**
```json
{
  "platform_fee_percentage": 5.0,
  "base_delivery_fee": 10.0,
  "delivery_fee_per_km": 5.0,
  "free_delivery_radius_km": 1.0
}
```

---

### PUT /admin/config/charges
Update dynamic fee configurations.

**Request body:**
```json
{
  "platform_fee_percentage": 6.0,
  "base_delivery_fee": 15.0,
  "delivery_fee_per_km": 5.0,
  "free_delivery_radius_km": 1.0
}
```

---

## 📊 STANDARD RESPONSE CODES

| Code | Meaning |
|---|---|
| 200 | OK |
| 201 | Created |
| 400 | Bad request (validation error) |
| 401 | Unauthorized (invalid/missing token) |
| 403 | Forbidden (wrong role) |
| 404 | Not found |
| 409 | Conflict (e.g., order already accepted) |
| 422 | Unprocessable (e.g., out of service area) |
| 429 | Too many requests (rate limited) |
| 500 | Internal server error |

---

## 🔄 ERROR RESPONSE FORMAT

All errors return:
```json
{
  "error": {
    "code": "ORDER_ALREADY_ACCEPTED",
    "message": "This order has been accepted by another store",
    "details": {}
  }
}
```

---

## 🧪 TESTING WITH POSTMAN

Save these collections during development:

1. **Auth flow** — verify token works
2. **Customer flow** — browse → cart → place order → track
3. **Store flow** — accept → pack → dispatch → deliver
4. **Admin flow** — onboard store → manage orders → settle fees
5. **Failure paths** — race conditions, timeouts, invalid data

---

*Keep this file updated as you add new endpoints. Single source of truth for API contracts between backend and apps.*
