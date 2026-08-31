# FairDrop — MongoDB Collection Design

**Owner:** Harikrishnan M P (25MCA025)  
**Modules:** Auth, Order Flow, Zone Assignment  
**Database:** MongoDB (document store)

This file documents the intended document shape for each collection. It is not a schema enforcement file — MongoDB is schemaless. Field presence and types should be validated at the application layer (express-validator or equivalent).

---

## Why MongoDB for These Modules

Auth and Order data is document-shaped:
- Rider profiles have variable nested attributes (vehicle info, documents, zone history)
- Orders embed line items, address objects, and status history as nested arrays
- The schema evolves during development without requiring migrations
- No joins needed across these entities — they are queried and written as whole documents

Pay Engine data (Raihan's modules) is relational and uses MySQL. See `database/mysql/schema.sql`.

---

## Collection: `users`

Covers all roles: `customer`, `rider`, `restaurant`, `admin`.

```json
{
  "_id": "ObjectId",
  "user_id": "string (UUID, shared with Pay Engine rider_id for riders)",
  "name": "string",
  "email": "string",
  "phone": "string",
  "password_hash": "string",
  "role": "customer | rider | restaurant | admin",
  "is_active": "boolean",
  "created_at": "ISODate",
  "updated_at": "ISODate",

  "rider_profile": {
    "vehicle_type": "bicycle | motorcycle | scooter",
    "vehicle_number": "string",
    "zone_id": "string",
    "current_zone_id": "string (shifts on out-of-zone delivery completion)",
    "insurance_document_url": "string",
    "safety_checklist_acknowledged": "boolean",
    "is_available": "boolean",
    "active_hours_today": "number"
  }
}
```

**Notes:**
- `rider_profile` is present only when `role = "rider"`
- `user_id` for riders is passed to Raihan's Pay Engine as `rider_id`
- `current_zone_id` implements the dynamic zone reassignment policy (Problem 2): after an out-of-zone delivery, the rider's active zone shifts to the delivery endpoint

**Indexes:**
- `email` — unique
- `phone` — unique
- `role` — for admin queries
- `rider_profile.zone_id` — for zone assignment queries

---

## Collection: `orders`

```json
{
  "_id": "ObjectId",
  "order_id": "string (format: ORD-{YYYYMMDD}-{0000})",
  "customer_id": "string (ref: users._id)",
  "restaurant_id": "string (ref: users._id)",
  "rider_id": "string | null (ref: users._id, null until assigned)",
  "status": "placed | assigned | picked_up | delivered | cancelled",
  "status_history": [
    {
      "status": "string",
      "timestamp": "ISODate",
      "note": "string | null"
    }
  ],
  "items": [
    {
      "item_id": "string",
      "name": "string",
      "quantity": "number",
      "unit_price": "number"
    }
  ],
  "delivery_address": {
    "line1": "string",
    "city": "string",
    "pincode": "string",
    "latitude": "number",
    "longitude": "number"
  },
  "restaurant_address": {
    "line1": "string",
    "city": "string",
    "pincode": "string",
    "latitude": "number",
    "longitude": "number"
  },
  "distance_km": "number",
  "zone_id": "string",
  "is_surge_active": "boolean",
  "restaurant_wait_mins": "number | null (set on pickup)",
  "delay_context": {
    "type": "traffic | restaurant | railway | none",
    "verified": "boolean",
    "source": "system_log | api_mock | none"
  },
  "pay_calculation_result": {
    "total_delivery_pay": "number",
    "floor_topup": "number",
    "calculated_at": "ISODate"
  },
  "created_at": "ISODate",
  "updated_at": "ISODate"
}
```

**Notes:**
- `order_id` format is agreed with Raihan: `ORD-{YYYYMMDD}-{4-digit-sequence}`. This is the key passed to `POST /api/pay/calculate`.
- `delay_context` is populated by the Order Flow module before calling Pay Engine. `verified` is set based on verification logic (mocked in prototype — see API contract).
- `pay_calculation_result` is written back after Pay Engine responds, for order record completeness.

**Indexes:**
- `order_id` — unique
- `customer_id`
- `rider_id`
- `status`
- `zone_id`

---

## Collection: `zones`

```json
{
  "_id": "ObjectId",
  "zone_id": "string",
  "name": "string",
  "city": "string",
  "boundary_coordinates": [
    { "latitude": "number", "longitude": "number" }
  ],
  "max_out_of_zone_radius_km": "number (configurable, default 5)",
  "return_compensation_idle_window_mins": "number (configurable, default 15)",
  "is_active": "boolean",
  "created_at": "ISODate"
}
```

**Notes:**
- `max_out_of_zone_radius_km` implements Problem 2 policy: orders beyond this distance from zone boundary are not assigned without rider consent.
- `return_compensation_idle_window_mins` implements the return compensation trigger: if a rider receives no orders within this window after an out-of-zone delivery, return compensation is logged.

---

## Integration Notes

- When an order reaches `status = "delivered"`, Harikrishnan's Order Flow server sends `POST /api/pay/calculate` to Raihan's Pay Engine.
- The fields sent are drawn from the `orders` document: `rider_id`, `order_id`, `distance_km`, `is_surge_active`, `restaurant_wait_mins`, `active_hours_today` (from `users.rider_profile`), and `delay_context`.
- Full API contract: [`docs/api-contract.md`](../../docs/api-contract.md)
