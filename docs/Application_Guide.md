# FairDrop — Application Guide

**Purpose:** Enable any developer or AI model to understand, run, and modify FairDrop.

---

## 1. Project Structure

```
FairDrop/
├── core-service/            # Node.js + Express 5 + MongoDB (Auth, Orders, Zones)
│   ├── src/
│   │   ├── app.js           # Express app setup, route mounting
│   │   ├── server.js         # HTTP server + DB connect + seed
│   │   ├── config/
│   │   │   ├── db.js         # MongoDB Atlas connection (Mongoose)
│   │   │   └── env.js        # Loads dotenv, exports PORT, MONGODB_URI, JWT_SECRET, etc.
│   │   ├── middleware/
│   │   │   ├── verifyToken.js # JWT verification middleware (adds req.user)
│   │   │   └── requireRole.js # Role-based access control middleware
│   │   ├── modules/
│   │   │   ├── auth/
│   │   │   │   ├── User.model.js    # Mongoose schema: users (all roles)
│   │   │   │   ├── auth.controller.js # register, login, getMe
│   │   │   │   └── auth.routes.js     # POST /register, /login, GET /me
│   │   │   ├── orders/
│   │   │   │   ├── Order.model.js     # Mongoose schema: orders
│   │   │   │   ├── Counter.model.js   # Auto-increment for order_id (ORD-YYYYMMDD-NNNN)
│   │   │   │   ├── order.controller.js # placeOrder, getOrderHistory, updateOrderStatus, etc.
│   │   │   │   ├── order.routes.js     # All order endpoints
│   │   │   │   └── payClient.js        # HTTP client for POST /api/pay/calculate
│   │   │   └── zones/
│   │   │       ├── Zone.model.js       # Mongoose schema: zones (GeoJSON Polygon)
│   │   │       ├── zone.controller.js  # getZones, getZoneMap (GeoJSON FeatureCollection)
│   │   │       └── zone.routes.js      # GET /api/zones, /api/zones/map
│   │   └── seed/
│   │       ├── index.js      # Seeds users + zones on server start if DB is empty
│   │       └── kollam-zones.js # GeoJSON polygon data for 3 Kollam zones
│   ├── .env                  # Real env vars (MongoDB Atlas URI, JWT secret)
│   ├── .env.example
│   └── package.json
│
├── pay-service/             # Node.js + Express 4 + MySQL (Pay Engine)
│   ├── src/
│   │   ├── server.js         # HTTP server + MySQL table creation
│   │   ├── db.js             # MySQL connection pool (mysql2/promise)
│   │   ├── payEngine.js      # Pure function: calculateDeliveryPay() — ZERO dependencies
│   │   ├── seed.js           # Seeds pay_configs + test riders
│   │   └── routes/
│   │       ├── payRoutes.js   # POST /api/pay/calculate, GET /api/pay/history/:rider_id
│   │       └── adminRoutes.js # GET/PUT /api/admin/pay-config, GET /api/admin/config-history
│   ├── config/
│   │   └── constants.js      # Shared SQL queries and column names
│   ├── .env                  # MySQL credentials
│   ├── .env.example
│   └── package.json
│
├── fairdrop_app/            # Flutter (Dart) — Android mobile app
│   ├── lib/
│   │   ├── main.dart         # App entry, Material theme, route table
│   │   ├── config/
│   │   │   └── app_config.dart # Base URLs: coreServiceUrl, payServiceUrl
│   │   ├── services/
│   │   │   ├── api_service.dart       # Pay-service API client (port 3001)
│   │   │   ├── core_api_service.dart  # Core-service API client (port 3003)
│   │   │   └── exceptions.dart        # ApiException class
│   │   └── screens/
│   │       ├── splash_screen.dart         # JWT check → route by role
│   │       ├── login_screen.dart          # Email/password login
│   │       ├── onboarding_screen.dart     # Pay policy + 7-day notice + safety checklist
│   │       ├── rider_home_screen.dart     # Online/Offline toggle, order polling
│   │       ├── order_acceptance_screen.dart # Pay formula + estimate + accept/decline
│   │       ├── active_delivery_screen.dart  # Status stepper + delay report
│   │       ├── pay_breakdown_screen.dart   # Manual pay calculator (NEEDS FIX)
│   │       ├── rider_dashboard_screen.dart # Earnings + FairDrop vs Cliff chart
│   │       ├── zone_map_screen.dart        # flutter_map zone polygons
│   │       ├── order_screen.dart           # Place Order + Order History (2 tabs)
│   │       ├── profile_screen.dart         # User profile + upcoming pay change
│   │       ├── admin_panel_screen.dart     # Admin pay config management
│   │       └── unsupported_role_screen.dart # Customer/restaurant rejection
│   └── pubspec.yaml
│
├── database/
│   ├── mysql/
│   │   └── schema.sql        # Full MySQL schema (riders, pay_configs, deliveries, earnings)
│   └── mongodb/
│       └── collections.md    # MongoDB document shapes (users, orders, zones)
│
└── docs/
    ├── FairDrop_Flutter_App_PRD.md   # Product Requirements Document
    └── api-contract.md               # POST /api/pay/calculate contract
```

---

## 2. How to Run the Application

### Prerequisites

| Software | Version | Purpose |
|---|---|---|
| **Node.js** | ≥ 18 | Backend services |
| **MySQL** | 8.x | Pay Engine database |
| **Flutter** | ≥ 3.13 | Mobile app |
| **Android Emulator / Device** | API 33+ | App runtime |
| **MongoDB** | Atlas (cloud) | Core service database (already configured) |

### Step 1: Set Up MySQL (Pay Service)

```bash
# 1. Start MySQL server
# 2. Create database and tables:
mysql -u root -p < database/mysql/schema.sql

# OR manually:
# CREATE DATABASE fairdrop_pay;
# Then run the schema.sql contents
```

### Step 2: Configure Environment Variables

**pay-service/.env** (already exists):
```
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=root123
DB_NAME=fairdrop_pay
PORT=3001
```

**core-service/.env** (already exists with MongoDB Atlas URI):
```
PORT=3003
MONGODB_URI=mongodb://...  (Atlas connection string — already configured)
JWT_SECRET=fairdrop-dev-secret-do-not-use-in-production
JWT_EXPIRES_IN=24h
PAY_SERVICE_URL=http://localhost:3001
```

### Step 3: Start Backend Services

```bash
# Terminal 1 — Pay Service
cd pay-service
npm install
npm run seed       # Seeds initial pay config + test riders
npm start          # Starts on port 3001

# Terminal 2 — Core Service
cd core-service
npm install
npm start          # Starts on port 3003
                   # Auto-seeds users + zones if DB is empty
```

### Step 4: Configure Flutter App

Edit `fairdrop_app/lib/config/app_config.dart`:
```dart
class AppConfig {
  // For Android Emulator (connects to host machine):
  static const coreServiceUrl = 'http://10.0.2.2:3003';
  static const payServiceUrl  = 'http://10.0.2.2:3001';

  // For Physical Device (use your LAN IP):
  // static const coreServiceUrl = 'http://192.168.1.X:3003';
  // static const payServiceUrl  = 'http://192.168.1.X:3001';
}
```

### Step 5: Run Flutter App

```bash
cd fairdrop_app
flutter pub get
flutter run           # Run on connected device/emulator
```

---

## 3. Seed Data

### Core Service (MongoDB — auto-seeded on first start)

| Email | Password | Role |
|---|---|---|
| `john@fairdrop.in` | `pass1234` | customer |
| `priya@fairdrop.in` | `pass1234` | customer |
| `arun@fairdrop.in` | `pass1234` | restaurant |
| `marina@fairdrop.in` | `pass1234` | restaurant |
| `rider1@fairdrop.in` | `pass1234` | rider |
| `rider2@fairdrop.in` | `pass1234` | rider |
| `rider3@fairdrop.in` | `pass1234` | rider |
| `admin@fairdrop.in` | `admin1234` | admin |

**Zones (seeded):**
- Chinnakkada (zone_id: `KLM-CHK`)
- Polayathode (zone_id: `KLM-PLY`)
- Kilikolloor (zone_id: `KLM-KLK`)

Each rider is assigned to one zone. All zones are in Kollam, Kerala, India.

### Pay Service (MySQL — run `npm run seed` manually)

Seeds into `pay_configs` table:
- Active config with Kerala baseline: base=₹15, per_km=₹6, surge=₹20, wait_threshold=10min, wait_comp=₹10, min_wage=₹70/hr

Seeds into `riders` table:
- `rider-001` (Anil), `rider-002` (Beena), `rider-003` (Chandran)

> [!WARNING]
> **Rider ID Mismatch:** MongoDB riders have auto-generated ObjectId `_id` values, but the pay-service `riders` table expects a `rider_id` string like `rider-001`. The `core_api_service.dart` stores `user_id` from MongoDB. For the demo to work end-to-end, the rider's `_id` from MongoDB must match the `rider_id` in MySQL's `riders` table. The seed scripts currently create DIFFERENT IDs. This needs to be resolved.

---

## 4. All API Endpoints

### Core Service (Port 3003)

| Method | Path | Auth | Role | Purpose |
|---|---|---|---|---|
| `POST` | `/api/auth/register` | None | — | Register a new user |
| `POST` | `/api/auth/login` | None | — | Login → JWT + role |
| `GET` | `/api/auth/me` | JWT | Any | Get current user profile |
| `POST` | `/api/orders` | JWT | customer | Place a new order |
| `GET` | `/api/orders/history` | JWT | Any | Get user's order history |
| `PATCH` | `/api/orders/:id/status` | JWT | rider | Update order status (assigned→picked_up→delivered) |
| `GET` | `/api/orders/restaurants` | JWT | customer/rider/admin | List all restaurant users |
| `GET` | `/api/zones` | JWT | Any | List all zones |
| `GET` | `/api/zones/map` | JWT | Any | GeoJSON FeatureCollection of all zones |
| `GET` | `/api/zones/point` | JWT | Any | Query: which zone contains a point? |
| `GET` | `/health` | None | — | Health check |

**⚠️ MISSING ENDPOINTS (not implemented yet):**

| Method | Path | Called by Flutter | Purpose |
|---|---|---|---|
| `POST` | `/api/rider/status` | `rider_home_screen.dart` | Toggle online/offline |
| `GET` | `/api/orders/rider/active` | `rider_home_screen.dart` | Get rider's current active order |
| `GET` | `/api/rider/stats/today` | `rider_home_screen.dart` | Today's earnings, hours, zone |

### Pay Service (Port 3001)

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/api/pay/calculate` | None* | Calculate pay for a completed delivery |
| `GET` | `/api/pay/history/:rider_id` | None* | Get rider's earnings history |
| `GET` | `/api/admin/pay-config` | None* | Get active pay configuration |
| `PUT` | `/api/admin/pay-config` | None* | Create new pay config (7-day notice enforced) |
| `GET` | `/api/admin/config-history` | None* | Get all pay config history |

*None of the pay-service routes have JWT auth. PRD requires auth on all routes.

---

## 5. Flutter App Routes & Navigation

Defined in [`main.dart`](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/main.dart):

```dart
routes: {
  '/':                  SplashScreen,
  '/login':             LoginScreen,
  '/onboarding':        OnboardingScreen,
  '/rider-home':        RiderHomeScreen,
  '/order-acceptance':  OrderAcceptanceScreen,
  '/active-delivery':   ActiveDeliveryScreen,
  '/pay-breakdown':     PayBreakdownScreen,
  '/rider-dashboard':   RiderDashboardScreen,
  '/zone-map':          ZoneMapScreen,
  '/orders':            OrderScreen,
  '/profile':           ProfileScreen,
  '/admin-panel':       AdminPanelScreen,
  '/unsupported-role':  UnsupportedRoleScreen,
}
```

### Navigation Flow

```
App Start → / (SplashScreen)
  ├── JWT valid + role=rider → /rider-home
  │    ├── → /onboarding (first time)
  │    ├── → /order-acceptance (when order found)
  │    │    └── Accept → /active-delivery
  │    │         └── Delivered → /pay-breakdown
  │    ├── → /rider-dashboard
  │    ├── → /zone-map
  │    ├── → /orders
  │    └── → /profile
  ├── JWT valid + role=admin → /admin-panel
  ├── JWT valid + role=customer/restaurant → /unsupported-role
  └── No JWT → /login
       └── Login success → role-based routing (same as above)
```

---

## 6. Database Schemas

### MongoDB — Collections

**users:**
```json
{
  "_id": "ObjectId",
  "name": "string",
  "email": "string (unique)",
  "phone": "string (unique)",
  "password_hash": "bcrypt string",
  "role": "customer | rider | restaurant | admin",
  "is_active": true,
  "rider_profile": {
    "vehicle_type": "bicycle | motorcycle | scooter",
    "zone_id": "string",
    "current_zone_id": "string",
    "is_available": false,
    "active_hours_today": 0
  },
  "created_at": "ISODate",
  "updated_at": "ISODate"
}
```

**orders:**
```json
{
  "_id": "ObjectId",
  "order_id": "ORD-{YYYYMMDD}-{NNNN}",
  "customer_id": "ObjectId ref",
  "restaurant_id": "ObjectId ref",
  "rider_id": "ObjectId | null",
  "status": "placed | assigned | picked_up | delivered | cancelled",
  "status_history": [{ "status": "string", "timestamp": "ISODate" }],
  "items": [{ "name": "string", "quantity": "number", "unit_price": "number" }],
  "delivery_address": { "line1": "string", "latitude": "number", "longitude": "number" },
  "restaurant_address": { "line1": "string", "latitude": "number", "longitude": "number" },
  "distance_km": "number",
  "zone_id": "string",
  "is_surge_active": false,
  "restaurant_wait_mins": "number | null",
  "delay_context": { "type": "none", "verified": false, "source": "none" },
  "pay_calculation_result": { "total_delivery_pay": 0, "floor_topup": 0 }
}
```

**zones:**
```json
{
  "_id": "ObjectId",
  "zone_id": "string",
  "name": "string",
  "city": "string",
  "geometry": { "type": "Polygon", "coordinates": [[[lng, lat], ...]] },
  "max_out_of_zone_radius_km": 5,
  "return_compensation_idle_window_mins": 15,
  "is_active": true
}
```

### MySQL — Tables

| Table | Purpose |
|---|---|
| `riders` | Minimal rider records (anchor for FKs, pay-relevant state) |
| `pay_configs` | Admin-configurable pay constants (versioned, audit trail) |
| `deliveries` | One row per completed delivery (immutable) |
| `earnings` | Computed pay breakdown per delivery (immutable, 1:1 with deliveries) |

Full schema in [`database/mysql/schema.sql`](file:///c:/Users/Admin/FairDrop/database/mysql/schema.sql).

---

## 7. Pay Calculation Engine

The pay engine ([`payEngine.js`](file:///c:/Users/Admin/FairDrop/pay-service/src/payEngine.js)) is a **pure function** with zero external dependencies.

### Formula

```
distance_pay       = distance_km × per_km_rate
surge_bonus        = is_surge_active ? surge_bonus_constant : 0
wait_compensation  = restaurant_wait_mins > wait_threshold_mins ? wait_comp_constant : 0
total_delivery_pay = base_rate + distance_pay + surge_bonus + wait_compensation

// Floor top-up (minimum wage protection):
cumulative_earnings = sum of all today's delivery_pay for this rider
hourly_earnings     = cumulative_earnings / active_hours_today
floor_shortfall     = (min_wage_per_hour × active_hours_today) - cumulative_earnings
floor_topup         = max(0, floor_shortfall)
```

### Kerala Baseline Defaults

| Constant | Value |
|---|---|
| base_rate | ₹15 per delivery |
| per_km_rate | ₹6 per km |
| surge_bonus | ₹20 flat |
| wait_threshold_mins | 10 minutes |
| wait_compensation | ₹10 flat |
| min_wage_per_hour | ₹70/hr |

All configurable by admin through the Admin Panel.

---

## 8. Critical Rules for Developers / AI Models

1. **GeoJSON ordering is [longitude, latitude]**. Flutter_map LatLng is (latitude, longitude). The conversion happens in `zone_map_screen.dart: _parsePolygon()`.

2. **Order ID format is `ORD-{YYYYMMDD}-{4-digit-seq}`** e.g., `ORD-20261019-0001`. Generated by Counter model in core-service.

3. **7-day advance notice rule**: Admin pay config changes must have `effective_from >= today + 7 days`. Enforced in both the Flutter date picker (client-side) AND `adminRoutes.js` (server-side).

4. **Pay engine is a pure function**: `payEngine.js` has ZERO HTTP or DB dependencies. It takes input, returns output. The Express route in `payRoutes.js` handles DB reads/writes around it.

5. **Two different databases**: Core-service uses MongoDB (document store). Pay-service uses MySQL (relational). They communicate via HTTP, not shared DB access.

6. **Rider ID mismatch**: MongoDB `_id` (ObjectId) ≠ MySQL `rider_id` (string). This MUST be resolved for the end-to-end flow to work. Either:
   - Use the MongoDB `_id.toString()` as the MySQL `rider_id`, OR
   - Add a `user_id` UUID field to MongoDB users and use that in both places.

7. **Android Emulator URL**: Use `10.0.2.2` to reach the host machine. Physical device uses LAN IP.

8. **Express version difference**: Core-service uses Express 5 (`^5.2.1`). Pay-service uses Express 4 (`^4.21.2`). Express 5 has different error handling (returns Promises from middleware). Don't mix patterns.

---

## 9. Testing

### Backend Tests

```bash
# Pay Engine unit tests:
cd pay-service
npm test          # Runs: node --test tests/payEngine.test.js

# Core Service tests:
cd core-service
npm test          # Runs: node --test tests/
```

### Manual Testing via Postman

**Login as customer:**
```http
POST http://localhost:3003/api/auth/login
Content-Type: application/json

{
  "email": "john@fairdrop.in",
  "password": "pass1234"
}
```

**Place an order (with customer token):**
```http
POST http://localhost:3003/api/orders
Authorization: Bearer <customer_jwt>
Content-Type: application/json

{
  "restaurant_id": "<restaurant_mongodb_id>",
  "items": [{"name": "Biryani", "quantity": 1, "price": 180}],
  "delivery_address": {
    "label": "TKM College",
    "latitude": 8.8932,
    "longitude": 76.6141
  },
  "restaurant_address": {
    "label": "Hotel Arun",
    "latitude": 8.8855,
    "longitude": 76.5950
  },
  "distance_km": 3.5
}
```

**Update order status (with rider token):**
```http
PATCH http://localhost:3003/api/orders/<order_id>/status
Authorization: Bearer <rider_jwt>
Content-Type: application/json

{
  "status": "assigned"
}
```

**Calculate pay:**
```http
POST http://localhost:3001/api/pay/calculate
Content-Type: application/json

{
  "rider_id": "rider-001",
  "order_id": "ORD-20261019-0001",
  "distance_km": 5,
  "is_surge_active": false,
  "restaurant_wait_mins": 15,
  "active_hours_today": 4,
  "delay_context": {
    "type": "none",
    "verified": false,
    "source": "none"
  }
}
```

---

## 10. Key File Quick Reference

| Need | File |
|---|---|
| Add a new API route (core) | `core-service/src/app.js` (mount), then new route file |
| Add a new API route (pay) | `pay-service/src/server.js` (mount), then new route file |
| Add a new Flutter screen | Create in `fairdrop_app/lib/screens/`, register in `main.dart` routes |
| Change base URLs | `fairdrop_app/lib/config/app_config.dart` |
| Add core API call | `fairdrop_app/lib/services/core_api_service.dart` |
| Add pay API call | `fairdrop_app/lib/services/api_service.dart` |
| Change pay formula | `pay-service/src/payEngine.js` |
| Change DB schema (MySQL) | `database/mysql/schema.sql` |
| Change DB schema (MongoDB) | `core-service/src/modules/auth/User.model.js` or `Order.model.js` or `Zone.model.js` |
| Seed test data | `core-service/src/seed/index.js` (auto) or `pay-service/src/seed.js` (manual) |
