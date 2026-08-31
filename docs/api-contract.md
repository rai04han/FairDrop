# API Contract — POST /api/pay/calculate

**Status:** Finalized. Do not modify without both team members agreeing and updating this file.

**Caller:** Harikrishnan's Order Flow server (Node.js + Express + MongoDB)  
**Receiver:** Raihan's Pay Engine server (Node.js + Express + MySQL)  
**Trigger:** On delivery completion event in Order Flow

---

## Endpoint

```
POST /api/pay/calculate
Content-Type: application/json
```

---

## Request Body

```json
{
  "rider_id": "string",
  "order_id": "string",
  "distance_km": 0,
  "is_surge_active": false,
  "restaurant_wait_mins": 0,
  "active_hours_today": 0,
  "delay_context": {
    "type": "traffic | restaurant | railway | none",
    "verified": false,
    "source": "system_log | api_mock | none"
  }
}
```

### Field Definitions

| Field | Type | Required | Description |
|---|---|---|---|
| `rider_id` | string | yes | Rider identifier from Auth module |
| `order_id` | string | yes | Format: `ORD-{YYYYMMDD}-{4-digit-seq}` e.g. `ORD-20260901-0042` |
| `distance_km` | number | yes | Total delivery distance in kilometres |
| `is_surge_active` | boolean | yes | Whether surge pricing is active for this order |
| `restaurant_wait_mins` | number | yes | Minutes rider waited at restaurant before pickup |
| `active_hours_today` | number | yes | Total active hours logged by rider today (used for floor top-up calculation) |
| `delay_context.type` | enum | yes | Cause of delivery delay: `traffic`, `restaurant`, `railway`, or `none` |
| `delay_context.verified` | boolean | yes | Whether delay was verified by an external source |
| `delay_context.source` | enum | yes | Verification source: `system_log`, `api_mock`, or `none` |

### `order_id` Format (Agreed)

```
ORD-{YYYYMMDD}-{4-digit-zero-padded-sequence}
```

Examples: `ORD-20260901-0001`, `ORD-20260901-0042`, `ORD-20261231-0999`

Harikrishnan's server generates this format. Raihan's Pay Engine validates this format on receipt. No deviation.

### `delay_context` Notes

The `verified` flag is set by Harikrishnan's Order Flow module. Verification logic (Google Maps API, HERE Maps API, railway gate schedule, restaurant system log) is documented as production architecture but implemented as a mock in this prototype. `delay_context.verified = true` with `source = "api_mock"` is the prototype representation of a verified delay.

---

## Response Body

```json
{
  "order_id": "string",
  "base_rate": 15,
  "distance_pay": 0,
  "surge_bonus": 0,
  "wait_compensation": 0,
  "total_delivery_pay": 0,
  "floor_topup": 0,
  "hourly_earnings_so_far": 0
}
```

### Field Definitions

| Field | Type | Description |
|---|---|---|
| `order_id` | string | Echoed from request for correlation |
| `base_rate` | number | Fixed base pay per delivery (₹) |
| `distance_pay` | number | `distance_km × per_km_rate` (₹) |
| `surge_bonus` | number | Surge bonus if `is_surge_active = true`, else 0 (₹) |
| `wait_compensation` | number | Compensation if `restaurant_wait_mins > wait_threshold_mins`, else 0 (₹) |
| `total_delivery_pay` | number | `base_rate + distance_pay + surge_bonus + wait_compensation` (₹) |
| `floor_topup` | number | Additional pay if hourly earnings fall below minimum wage floor (₹) |
| `hourly_earnings_so_far` | number | Cumulative earnings ÷ active hours today, after this delivery (₹/hr) |

---

## Pay Formula (Kerala Baseline Constants)

```
base_rate           = ₹15  (per delivery)
per_km_rate         = ₹6   (per km)
surge_bonus         = ₹20  (flat, when is_surge_active = true)
wait_threshold_mins = 10   (minutes before compensation triggers)
wait_compensation   = ₹10  (flat, when wait exceeds threshold)
min_wage_per_hour   = ₹70  (Kerala minimum wage notification baseline)
```

All constants are admin-configurable via `pay_configs` table. The values above are the Kerala baseline defaults.

### Calculation Steps

```
distance_pay        = distance_km × per_km_rate
surge_bonus         = is_surge_active ? surge_bonus_constant : 0
wait_compensation   = restaurant_wait_mins > wait_threshold_mins ? wait_compensation_constant : 0
total_delivery_pay  = base_rate + distance_pay + surge_bonus + wait_compensation

# After recording this delivery:
cumulative_earnings = sum of total_delivery_pay for all deliveries today
hourly_earnings     = cumulative_earnings / active_hours_today
floor_shortfall     = (min_wage_per_hour × active_hours_today) - cumulative_earnings
floor_topup         = max(0, floor_shortfall)
```

---

## Error Responses

| HTTP Status | Condition |
|---|---|
| 400 | Missing required fields, invalid `order_id` format, negative `distance_km` |
| 404 | `rider_id` not found in Pay Engine database |
| 500 | Internal server error |

---

## Verified Delay — Production Architecture (Out of Prototype Scope)

In production, `delay_context.verified` would be set only after:

- **traffic** — Google Maps / HERE Maps API confirms congestion on route at delivery time
- **restaurant** — Restaurant POS system log confirms order was not ready at estimated time
- **railway** — Railway gate schedule (Indian Railways API or known gate timings) confirms gate was closed

Verified delays suppress negative customer rating impact and are shown in the customer's order status screen. This architecture is documented but not implemented in the prototype. The prototype accepts `verified = true` as a trusted flag from the calling system.
