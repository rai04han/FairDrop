# FairDrop Monorepo Comprehensive QA & Release Audit Report

**Audited against:** `docs/FairDrop_Flutter_App_PRD_v2.1.md`  
**Date of Audit:** October 20, 2026  
**Auditor:** Senior QA & Release Engineer  
**Scope:** `core-service` (Port 3003), `pay-service` (Port 3001), `fairdrop_app` (Flutter Web & Android), Seed & Smoke Scripts, `docs/DEMO_RUNBOOK.md`

---

## 1. Executive Summary & Verdict

**Verdict:** **CONDITIONAL PASS (3 DEMO BLOCKERS, 5 SHOULD FIX, 1 NICE TO HAVE)** — The backend microservice architecture, pure pay engine, spatial zone topologies, and core 14-step automated smoke suite (`npm run smoke`) pass 100%; however, 3 critical discrepancies (client-side cart fee arithmetic violating FR-59/D4, missing double-delivery idempotency in `core-service` violating FR-74, and a health endpoint URL mismatch in `pay-service` breaking runbook verification) must be resolved prior to examiner presentation.

---

## 2. Test Execution & Build Verification (Step 1)

### 2.1 Backend Health Endpoints
- **core-service (Port 3003):** `curl.exe -i http://localhost:3003/api/health`
  ```http
  HTTP/1.1 200 OK
  Access-Control-Allow-Origin: *
  Content-Type: application/json; charset=utf-8
  Content-Length: 40
  {"status":"ok","service":"core-service"}
  ```
  **Result:** **PASS**

- **pay-service (Port 3001) - `/health`:** `curl.exe -i http://localhost:3001/health`
  ```http
  HTTP/1.1 404 Not Found
  Access-Control-Allow-Origin: *
  Content-Type: application/json; charset=utf-8
  Content-Length: 230
  {"error":"Not found","message":"GET /health is not a valid endpoint","available_endpoints":["GET  /api/health","POST /api/pay/calculate","GET  /api/pay/history/:rider_id","GET  /api/admin/pay-config","PUT  /api/admin/pay-config"]}
  ```
  **Result:** **FAIL** (`pay-service` only registered `/api/health`, but runbook and instructions expect `/health`).
  
- **pay-service (Port 3001) - `/api/health`:** `curl.exe -i http://localhost:3001/api/health`
  ```http
  HTTP/1.1 200 OK
  Access-Control-Allow-Origin: *
  Content-Type: application/json; charset=utf-8
  Content-Length: 101
  {"status":"ok","service":"fairdrop-pay-service","port":"3001","timestamp":"2026-10-20T10:35:35.473Z"}
  ```
  **Result:** **PASS** (via `/api/health`).

### 2.2 Microservice Unit & Integration Suites (`npm test`)
- **`core-service`:** `npm test`
  ```text
  ℹ tests 72
  ℹ suites 21
  ℹ pass 72
  ℹ fail 0
  ℹ cancelled 0
  ℹ skipped 0
  ℹ todo 0
  ℹ duration_ms 26987.585
  ```
  **Result:** **PASS** (72/72 tests passing on Windows).

- **`pay-service`:** `npm test`
  ```text
  ℹ tests 23
  ℹ suites 8
  ℹ pass 23
  ℹ fail 0
  ℹ cancelled 0
  ℹ skipped 0
  ℹ todo 0
  ℹ duration_ms 2485.3512
  ```
  **Result:** **PASS** (23/23 tests passing on Windows covering base rate, surge bonus, wait compensation, floor topup, idempotency, rider isolation, and FairDrop-vs-cliff analytics).

### 2.3 Master Seed & E2E Smoke Suite
- **`npm run seed` (Root):**
  ```text
  🔍 Verifying Spatial Constraints...
    - Hotel Arun inside KLM-CHK: ✅ PASS
    - Marina inside KLM-PLY:     ✅ PASS
    - Pin A inside KLM-CHK:      ✅ PASS (0.31 km from Arun)
    - Pin B inside KLM-PLY:      ✅ PASS
    - Pin B outside KLM-CHK:     ✅ PASS (1.87 km from Arun, within 5km cap)
  ======================================================
    Demo Seed Complete & Verified!
  ```
  **Result:** **PASS** (Clean MySQL + MongoDB reset, pristine sync).

- **`npm run smoke` (Root):**
  ```text
  =================================================================
    ✔ ALL 14 DEMO FLOW STEPS PASSED SUCCESSFULLY (8.09s)
    FairDrop Platform is 100% Demo-Ready with Zero Manual DB Edits!
  =================================================================
  ```
  **Result:** **PASS** (All 14 demo steps simulated and verified over live HTTP).

### 2.4 Flutter Quality & Build Suite (`fairdrop_app`)
- **`flutter pub get`:**
  ```text
  Got dependencies!
  25 packages have newer versions incompatible with dependency constraints.
  ```
  **Result:** **PASS** (Exit code 0).

- **`flutter analyze`:**
  ```text
  Analyzing fairdrop_app...                                       
  No issues found! (ran in 58.3s)
  ```
  **Result:** **PASS** (0 errors, 0 warnings, 0 lints).

- **`flutter test`:**
  ```text
  00:41 +96: Zone Map Screen Widget Tests: Screen 8: Renders last delivery endpoint marker (FR-29)
  00:41 +97: Zone Map Screen Widget Tests: Screen 8: Tapping zone card selects and focuses zone in bottom sheet
  00:42 +98: Zone Map Screen Widget Tests: Screen 8: PayBreakdownScreen: Out-of-zone banner navigates to /zone-map with transition arguments
  00:42 +99: All tests passed!
  ```
  **Result:** **PASS** (99/99 widget & unit tests passing).

- **`flutter build web`:**
  ```text
  Compiling lib\main.dart for the Web...                            134.9s
  √ Built build\web
  ```
  **Result:** **PASS** (Web build compiles and treeshakes cleanly).

- **`flutter build apk --release`:**
  ```text
  Resolving dependencies...
  [!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
  ```
  **Result:** **FAIL** (Host machine environment lacks configured Android SDK / `ANDROID_HOME`).

---

## 3. Comprehensive PRD Checklist Matrix

### 3.1 PRD Section 4: Screen Inventory Verification (All 24 Screens)

| # | Screen Name | Role | File Path | Route in `main.dart` | Shell Reachability | Status |
|---|---|---|---|---|---|---|
| 1 | Splash | All | `lib/screens/splash_screen.dart` | `/splash` (initialRoute) | Accessible on startup | **PASS** |
| 2 | Login | All | `lib/screens/login_screen.dart` | `/login` | From Splash / Logout | **PASS** |
| 3 | Rider Signup | Rider | `lib/screens/rider_signup_screen.dart` | `/rider-signup` | Link on Login Screen | **PASS** |
| 4 | Home | Rider | `lib/screens/rider_home_screen.dart` | `/rider-home` | Rider role shell entry | **PASS** |
| 5 | Order Acceptance | Rider | `lib/screens/order_acceptance_screen.dart` | `/order-acceptance` | Incoming offer modal from Home | **PASS** |
| 6 | Active Delivery | Rider | `lib/screens/active_delivery_screen.dart` | `/active-delivery` | Tapping accepted order on Home | **PASS** |
| 7 | Delivery Summary | Rider | `lib/screens/pay_breakdown_screen.dart` | `/delivery-summary`, `/pay-breakdown` | Auto-nav after "Delivered" | **PASS** |
| 8 | Zone Map | Rider | `lib/screens/zone_map_screen.dart` | `/zone-map` | Home top bar & out-of-zone banner | **PASS** |
| 9 | Rider Dashboard | Rider | `lib/screens/rider_dashboard_screen.dart` | `/rider-dashboard` | Home action button & drawer | **PASS** |
| 10 | Analytics | Rider | `lib/screens/analytics_screen.dart` | `/analytics` | Navigation banner from Dashboard | **PASS** |
| 11 | Delivery Location | Customer | `lib/screens/customer/delivery_location_screen.dart` | `/customer/location` | Customer shell entry tab 1 | **PASS** |
| 12 | Restaurant List | Customer | `lib/screens/customer/restaurant_list_screen.dart` | `/customer/restaurants` | After confirming location pin | **PASS** |
| 13 | Customer Menu | Customer | `lib/screens/customer/restaurant_menu_screen.dart` | `/customer/menu` | Tapping restaurant card | **PASS** |
| 14 | Customer Cart | Customer | `lib/screens/customer/cart_screen.dart` | `/customer/cart` | "View Cart" sticky button | **PASS** |
| 15 | Mock Payment | Customer | `lib/screens/customer/mock_payment_screen.dart` | `/customer/payment` | "Proceed to Checkout" from Cart | **PASS** |
| 16 | Order Confirmation | Customer | `lib/screens/customer/order_confirmation_screen.dart` | `/customer/order-confirmation` | Post-order confirmation | **PASS** |
| 17 | Restaurant Menu Mgmt | Restaurant | `lib/screens/restaurant/menu_management_screen.dart` | `/restaurant/menu` | Restaurant shell entry tab 1 | **PASS** |
| 18 | Add/Edit Menu Item | Restaurant | `lib/screens/restaurant/add_edit_menu_item_screen.dart` | `/restaurant/menu/add` | FAB "+ Add Item" on Menu Mgmt | **PASS** |
| 19 | Restaurant Orders | Restaurant | `lib/screens/restaurant/restaurant_orders_screen.dart` | `/restaurant/orders` | Restaurant shell tab 2 | **PASS** |
| 20 | Admin Pay Config | Admin | `lib/screens/admin_panel_screen.dart` | `/admin-panel` | Admin role shell entry | **PASS** |
| 21 | Onboarding | Rider | `lib/screens/onboarding_screen.dart` | `/onboarding` | Post-signup flow / Profile | **PASS** |
| 22 | Customer Order History | Customer | `lib/screens/customer/customer_order_history_screen.dart` | `/customer/history` | Customer shell tab 2 | **PASS** |
| 23 | Profile | Rider | `lib/screens/profile_screen.dart` | `/profile` | Rider Home app bar action | **PASS** |
| 24 | Grievance Form | Rider | `lib/screens/grievance_screen.dart` | `/grievance` | Profile Help & Grievance action | **PASS** |

---

### 3.2 PRD Section 6: Backend Dependencies Matrix

| Item / Contract Need | Provider | Rule / Expectation | Audit Finding & Evidence | Status |
|---|---|---|---|---|
| Auth: login, token, role (4 roles) | core-service (3003) | JWT contains `id` and `role` claim (`rider`, `customer`, `restaurant`, `admin`) | `core-service/src/modules/auth/auth.controller.js`: login returns JWT with claims. Tested in `core-service/tests/auth.test.js`. | **PASS** |
| Rider signup & MySQL sync/rollback | core-service ↔ pay-service | Assigns zone with fewest riders (tie goes to lowest `zone_id`); creates MySQL rider row with identical id; rolls back Mongo user on MySQL failure (D12) | `auth.controller.js:83-146`: Performs least-rider sorting, calls `pay-service/api/pay/riders`. On error, executes `User.findByIdAndDelete(user._id)`. | **PASS** |
| Online/Offline shift tracking | core-service | Session timestamps, derived `active_hours_today`, Offline on logout, allocation on Online (FR-72) | `rider.controller.js:64-150`: Tracks shift sessions in array; calculates `active_hours_today`. Triggers allocation when online. | **PASS** |
| Today's stats for Home | core-service | Earnings, hours, zone | `rider.controller.js:154-192`: `GET /api/riders/today` returns `deliveries_today`, `earnings_today`, `active_hours_today`, `current_zone`. | **PASS** |
| Restaurant list & menu read | core-service | List partner restaurants; fetch menu with availability status | `order.controller.js:636` (`getRestaurants`) and `restaurant.controller.js:17` (`getRestaurantMenu`). | **PASS** |
| Menu management | core-service | Restaurant role only, own items only, prep time in whole seconds | `restaurant.controller.js:52-168`: Checks `menuItem.restaurant_id === req.user.id`; rejects non-integer prep time with 400. | **PASS** |
| Order placement & pricing | core-service | Item prices read from DB (client price ignored), unavailable rejected, drop-off coords required, haversine distance, auto-accept (FR-68) | `order.controller.js:48-238`: Tested live. Client price 1.00 ignored -> DB price 180 enforced; unavailable item -> 400; missing coords -> 400. | **PASS** |
| Rider current-order poll, accept, decline | core-service | Rider active poll returns unacknowledged or active order; decline reallocates without penalty (FR-15, D7) | `order.controller.js:271-372`: Checks rider allocation ownership; decline pushes to `declined_by` and re-runs allocation. | **PASS** |
| Status transitions & timestamps | core-service | Server timestamps; valid transition enforced; rider ownership enforced; idempotent delivered (FR-74) | `order.controller.js:387-508`: Valid transitions enforced. **Defect:** Duplicate `delivered` returns 400 instead of idempotent 200. | **FAIL** |
| Delay report | core-service | Server-set `delay_context` (`verified`, `source`) | `order.controller.js:452`: Sets `order.delay_context`. Mocked server-side. | **PASS** |
| Delivered pay-service trigger & retry | core-service | Calls pay-service forwarding caller's JWT, stores `pay_calculation_result` & `pay_status`; retry endpoint | `order.controller.js:457-476`: Calls `calculatePay` with bearer token. `retryPay` endpoint at line 516 handles pending pay retry. | **PASS** |
| Customer & Restaurant order lists | core-service | Filtered by user id / restaurant id; derived `is_ready` flag | `order.controller.js:560` and `restaurant.controller.js:171`. `Order.model.js:196` derives `is_ready` from prep time. | **PASS** |
| Zone data & spatial query | core-service | Point-in-polygon, out-of-zone cap calculation, auto-switch zone on out-of-zone delivery (FR-73, D3) | `allocation.service.js:41-104` (ray-casting & boundary distance) and `order.controller.js:487` (updates rider zone to KLM-PLY). | **PASS** |
| JWT verification on pay-service | pay-service (3001) | Shared `JWT_SECRET`; admin role check; `created_by` taken from token; rider isolation on history | `payRoutes.js:19` and `adminRoutes.js:14-15`: All routes use `verifyToken`. History endpoint blocks other riders with 403. | **PASS** |
| FR-75 Pay config read-only | pay-service | Active and scheduled config for any authenticated user; `effective_from <= CURDATE()` with no scheduler | `payRoutes.js:24-58`: `GET /api/pay/config` returns active (`effective_from <= CURDATE()`) and scheduled (`effective_from > CURDATE()`). | **PASS** |
| Dashboard summary & history | pay-service | Summary and per-delivery history with full FR-21 breakdown | `payRoutes.js:268-356`: `GET /api/pay/history/:rider_id` returns ledger breakdown. | **PASS** |
| Analytics (FR-34 to FR-36) | pay-service | Actual FairDrop vs cliff comparison, stated cliff assumptions, cliff-wins scenario | `payRoutes.js:364-478`: `GET /api/pay/analytics/:rider_id` returns assumptions, actual comparison, and balanced cliff-wins (+₹420). | **PASS** |
| Pay config list & create (Admin) | pay-service | `effective_from >= today + 7 days`, non-empty reason, non-negative numbers, whole-number wait threshold | `adminRoutes.js:115-180`: Validates integers, non-empty reason, 7-day rule. **Defect:** Date conversion `.toISOString()` off by -1 day in IST. | **FAIL** |
| `POST /api/pay/calculate` idempotency | pay-service | Idempotent per `order_id`; upserts missing rider | `payRoutes.js:132-161`: `INSERT ... ON DUPLICATE KEY UPDATE` for riders; selects existing `earnings WHERE order_id = ?` and returns `is_cached: true`. | **PASS** |

---

### 3.3 Functional Requirements FR-51 to FR-75 Verification

| Requirement ID | Summary Description | Implementation Location | Test / Verification Evidence | Status |
|---|---|---|---|---|
| **FR-51** | Rider signup collects credentials & vehicle type; ignores client role/zone | `core-service/src/modules/auth/auth.controller.js:77` | `core-service/tests/auth.test.js` | **PASS** |
| **FR-52** | Zone assigned by fewest riders; ties to lowest `zone_id` | `auth.controller.js:83-106` | `core-service/tests/auth.test.js` | **PASS** |
| **FR-53** | Post-signup sign-in routes to Onboarding | `fairdrop_app/lib/screens/rider_signup_screen.dart:98` | Navigates to `/onboarding` | **PASS** |
| **FR-54** | Logout sets rider offline; clears session even if call fails | `fairdrop_app/lib/services/core_api_service.dart:62-76` | `try { setRiderStatus(false) } finally { delete() }` | **PASS** |
| **FR-55** | Customer delivery location map pin with single coordinate parser | `lib/screens/customer/delivery_location_screen.dart` | `customer_flow_test.dart` | **PASS** |
| **FR-56** | Restaurant list shows all restaurants unfiltered | `lib/screens/customer/restaurant_list_screen.dart` | `customer_flow_test.dart` | **PASS** |
| **FR-57** | Menu items with availability; unavailable item cannot be added | `lib/screens/customer/restaurant_menu_screen.dart` | `customer_flow_test.dart` | **PASS** |
| **FR-58** | Cart holds single restaurant; add/remove/qty | `lib/screens/customer/cart_screen.dart` | Single restaurant validation passing | **PASS** |
| **FR-59** | Mock payment shows items total, label "Demo payment. No money is charged."; no delivery fee line | `lib/screens/customer/mock_payment_screen.dart` & `cart_service.dart` | **VIOLATION:** Calculates delivery fee (₹30+₹10/km), platform fee (₹5), GST (5%), and renders 4 payment methods. | **FAIL** |
| **FR-60** | Order confirmation shows order ID and unallocated message if no rider | `lib/screens/customer/order_confirmation_screen.dart` | Shows "No rider is available yet." | **PASS** |
| **FR-61** | Customer order history lists orders; pull-to-refresh only | `lib/screens/customer/customer_order_history_screen.dart` | Pull-to-refresh indicator verified | **PASS** |
| **FR-62** | Menu management lists own items with name, price, prep seconds, availability | `lib/screens/restaurant/menu_management_screen.dart` | `restaurant_flow_test.dart` | **PASS** |
| **FR-63** | Add/edit item: name, price, prep seconds (whole number), availability toggle | `lib/screens/restaurant/add_edit_menu_item_screen.dart` | `restaurant_flow_test.dart` | **PASS** |
| **FR-64** | Availability toggle; restaurant can only change own items | `core-service/src/modules/restaurants/restaurant.controller.js:84` | `restaurants.test.js` (403 on other restaurant) | **PASS** |
| **FR-65** | Restaurant orders list with items and status; pull-to-refresh | `lib/screens/restaurant/restaurant_orders_screen.dart` | `restaurant_flow_test.dart` | **PASS** |
| **FR-66** | Orders auto-accepted on placement; no manual kitchen action | `order.controller.js:202` | `order.status = 'accepted'` on creation | **PASS** |
| **FR-67** | Order lifecycle states; rider active order polling returns single order | `Order.model.js:181`, `order.controller.js:605` | `orders.test.js` | **PASS** |
| **FR-68** | Allocation at placement: match restaurant zone, online idle rider, skip decliner/cap failure | `allocation.service.js:155` | `orders.test.js` | **PASS** |
| **FR-69** | Derived `is_ready` flag: now >= accepted_at + longest prep seconds | `Order.model.js:196` | `orders.test.js`, `restaurants.test.js` | **PASS** |
| **FR-70** | Haversine distance, 2 decimals, computed in core-service | `allocation.service.js:20-34` | Tested: Pin A returns 0.31 km, Pin B returns 1.87 km | **PASS** |
| **FR-71** | Server wait is picked_up minus arrived time, rounded up to whole minutes | `order.controller.js:438` | `Math.ceil(elapsedMs / 60000)` | **PASS** |
| **FR-72** | Rider going online allocates pending unallocated accepted orders | `rider.controller.js:104` | `orders.test.js` | **PASS** |
| **FR-73** | Out-of-zone cap enforced; rider zone switches to drop-off zone | `allocation.service.js:214`, `order.controller.js:487` | `orders.test.js`, `smoke.js` | **PASS** |
| **FR-74** | Repeating "Delivered" idempotent (single delivery, single pay record, same response) | `payRoutes.js:148` (PASS); `order.controller.js:409` (FAIL) | Core-service returns 400 on duplicate status call | **FAIL** |
| **FR-75** | Active & scheduled pay config read-only for any authenticated user | `payRoutes.js:24` | `payConfig.test.js` | **PASS** |

---

### 3.4 Locked Decisions Verification (D1 to D14)

| Decision | Summary | Code Reference | Verification Evidence | Status |
|---|---|---|---|---|
| **D1** | New rider zone = fewest riders, ties by lowest `zone_id` | `auth.controller.js:83-106` | Tested in `core-service/tests/auth.test.js` | **PASS** |
| **D2** | Allocation matches restaurant zone, falls back to any online rider, else unallocated | `allocation.service.js:247-255` | Tested in `core-service/tests/orders.test.js` | **PASS** |
| **D3** | Out-of-zone cap enforced; zone switches to drop-off zone | `allocation.service.js:219`, `order.controller.js:487` | Tested in `e2e-smoke.js` Step 11 | **PASS** |
| **D4** | Cart holds one restaurant; no delivery fee line | `cart_service.dart:112` | CartService has `deliveryFee`, `platformFee`, `GST` | **FAIL** |
| **D5** | Menu item fields: name, price, prep seconds, availability | `MenuItem.model.js:14-25` | Schema contains only specified fields | **PASS** |
| **D6** | No rider available: order stays unallocated, allocated when rider goes online | `order.controller.js:220`, `rider.controller.js:104` | Tested in `orders.test.js` | **PASS** |
| **D7** | Decline reallocates excluding decliner | `order.controller.js:338` | Tested in `orders.test.js` | **PASS** |
| **D8** | Ready derived at read time from longest prep time | `Order.model.js:196-200` | Virtual property on Mongoose schema | **PASS** |
| **D9** | Distance is haversine, 2 decimals, computed in core-service | `allocation.service.js:20-34` | Exact mathematical formula verified | **PASS** |
| **D10** | Wait is server-computed and rounded up to whole minutes | `order.controller.js:438` | `Math.ceil(elapsedMs / 60000)` | **PASS** |
| **D11** | Demo seed: 1 min wait threshold, 20-45s prep, fixed Pin A & Pin B | `scripts/seed.js` | Seeded config has threshold = 1 | **PASS** |
| **D12** | MySQL rider_id = MongoDB _id string, rollback on failure | `auth.controller.js:127-147` | Rollback deletion tested and verified | **PASS** |
| **D13** | pay-service stays on port 3001 | `pay-service/.env`, `app_config.dart` | Both use 3001 consistently | **PASS** |
| **D14** | Primary transport is USB `adb reverse` with host `127.0.0.1` | `fairdrop_app/lib/config/app_config.dart:21` | Centralized `_host = '127.0.0.1'` | **PASS** |

---

## 4. Explicit 16-Point Verification Analysis (Step 3)

1. **Cart & Payment Totals (FR-59, D4):** **FAIL**  
   - `fairdrop_app/lib/services/cart_service.dart` defines `deliveryFee` (₹30 + ₹10/km), `platformFee` (₹5), `taxesAndCharges` (5% GST), and `grandTotal`.
   - `cart_screen.dart` renders line items for Delivery Partner Fee, Platform Fee, and GST.
   - `mock_payment_screen.dart` displays `grandTotal` and 4 payment method radios (UPI, Cards, Net Banking, COD).
   - *Requirement:* PRD Section 2 Non-goals, FR-59, and D4 require zero delivery fees and total = sum of item prices.

2. **Order Creation Validation (Tampered Price, Unavailable Item, Missing Coords):** **PASS**  
   - Real HTTP test against `http://localhost:3003/api/orders`:
     - Client sent `price: 1.00` -> DB price `180` enforced on created order.
     - Unavailable item -> HTTP `400 Bad Request` (`Item "Chicken Biryani" is currently unavailable.`).
     - Missing delivery coordinates -> HTTP `400 Bad Request` (`delivery_address must include latitude and longitude.`).

3. **Pay Formula on Order Acceptance & Numeric Literals:** **FAIL (Label & Fallback Mismatch)**  
   - Numeric literals grep in `lib/`:
     - `order_acceptance_screen.dart:135-156`: Fallback getters hardcode `'30'`, `'10'`, `'15'`, `'2'`, `'75'`, instead of Kerala baselines (15, 6, 20, 10, 70).
     - `rider_home_screen.dart:41,114`: Hardcodes statutory floor fallback as `150.0` and renders text `"State wage floor adjustment ₹150/hr min"`.
   - Wait-compensation label: `order_acceptance_screen.dart:725` renders `"+${formatCurrency(_waitCompensation)}/min if restaurant wait exceeds..."`. In `payEngine.js:115`, wait compensation is awarded as a **flat ₹10 bonus**, NOT per minute!

4. **Client-Side Pay Arithmetic:** **PASS**  
   - In `fairdrop_app`, rider pay derivation is strictly passed through from backend `PayResult` or `ApiService.getPayConfig()`. The only client calculation is the FR-13 estimated payout on `OrderAcceptanceScreen` (`_baseRate + _distancePay + _surgeBonus`). (Customer cart arithmetic issue noted in item 1).

5. **"Delivered" Twice Idempotency & Rider Upsert (FR-74):** **FAIL (core-service) / PASS (pay-service)**  
   - `pay-service/src/routes/payRoutes.js:140`: `POST /api/pay/calculate` is fully idempotent per `order_id` (returns HTTP 200 with `is_cached: true` and cached breakdown). Missing riders are upserted.
   - `core-service/src/modules/orders/order.controller.js:409`: Calling `PATCH /api/orders/:id/status` with `new_status: 'delivered'` on an already delivered order returns `HTTP 400 Bad Request` (`Cannot transition from "delivered" to "delivered". Allowed: []`). It does NOT return the identical 200 response.
   - `order.controller.js:462`: `active_hours_today` is clamped with `Math.max(active_hours_today, 0.0001)`, ensuring it is never 0.

6. **Wait Compensation Server Timestamping (D10):** **PASS**  
   - `core-service/src/modules/orders/order.controller.js:436-444`: Computes `elapsedMs = order.picked_up_at.getTime() - order.arrived_at.getTime()`, and applies `Math.ceil(elapsedMs / 60000)` (rounds up to whole minutes).

7. **Pay-Service Role Enforcement & Isolation:** **PASS**  
   - All routes in `payRoutes.js` and `adminRoutes.js` require valid JWT.
   - Non-admin calling `/api/admin/pay-config` receives HTTP 403 Forbidden.
   - Rider A calling `/api/pay/history/:rider_b` receives HTTP 403 Forbidden.
   - `created_by` in `adminRoutes.js:178` is populated from `req.user.id`.

8. **7-Day Rule Enforcement & Timezone Analysis:** **FAIL (Timezone Bug)**  
   - Server-side check: Tested in `payConfig.test.js`: now+6d returns HTTP 400; now+8d returns HTTP 200; exactly 7 days (`diffDays === 7`) returns HTTP 200 (accepted).
   - Timezone defect: `adminRoutes.js:158,177` constructs `clientDateMidnight = new Date(y, m - 1, d)` (IST midnight = `00:00:00 GMT+0530`), then converts via `clientDateMidnight.toISOString().split('T')[0]`. In UTC, this is `18:30:00Z` of the prior day, so the date stored in MySQL is off by -1 day in IST!

9. **Rider Allocation & Reallocation (FR-72, D7):** **PASS**  
   - When no rider is online, `allocation: "no_rider_available"` is returned.
   - When an eligible rider toggles Online, `rider.controller.js:104` allocates the unallocated order.
   - Declining an order (`order.controller.js:338`) adds rider to `declined_by` and re-runs allocation excluding the decliner.

10. **Pin B Out-of-Zone Order & Hub Switch (FR-73, D3):** **PASS**  
    - Order placed at Pin B (`76.6050, 8.8800`) from Hotel Arun (`KLM-CHK`) computes `out_of_zone_distance_km = 1.87 km` (within 5 km cap).
    - `OrderAcceptanceScreen` renders out-of-zone badge and requires consent checkbox.
    - Upon delivery, `order.controller.js:487` updates rider's `current_zone_id` and `current_zone_code` to `KLM-PLY`.

11. **New Rider Signup on Clean Seed (D12):** **PASS**  
    - On clean seed, all 3 zones have 1 rider. Tie-break sorts by zone code (`KLM-CHK` < `KLM-KLK` < `KLM-PLY`).
    - New rider is assigned to `KLM-CHK`.
    - `auth.controller.js:129` syncs rider to MySQL `riders` table with identical ID; if MySQL fails, MongoDB user is deleted via `findByIdAndDelete`.

12. **Sequential Order IDs (ORD-YYYYMMDD-NNNN):** **PASS**  
    - `core-service/src/modules/orders/Counter.model.js` uses atomic `findOneAndUpdate` with `$inc: { sequence: 1 }` per daily key, formatting as `ORD-${datePart}-${seqPart}`.

13. **Logout Offline Synchronization (FR-54):** **PASS**  
    - `fairdrop_app/lib/services/core_api_service.dart:62-76`: `logout()` invokes `setRiderStatus(isOnline: false)` for riders. If the network call fails or throws, the `finally` block unconditionally wipes `_keyToken`, `_keyRole`, and `_keyUserId`.

14. **Secrets & Credentials Security:** **FAIL (Tracked Password)**  
    - `.env` files are gitignored in both services.
    - `.env.example` files are present in both services.
    - No Atlas URI in tracked files; `git log -p -S "mongodb+srv"` contains only open-source driver package commits.
    - **Defect:** `docs/Application_Guide.md` line 12 contains tracked plaintext database password: `DB_PASSWORD=root123`.

15. **HTTP Timeouts, Error States, and Spinners:** **FAIL (Swallowed Errors)**  
    - Both `ApiService` and `CoreApiService` wrap all calls with 10-second timeouts (`_withTimeout`).
    - **Defect:** `rider_dashboard_screen.dart:143` and `analytics_screen.dart:96` catch network errors silently and populate fake sample data rather than rendering visible error banners with retry triggers.

16. **Windows `npm test` & Pay Engine Test Coverage:** **PASS**  
    - `core-service` tests (72/72 passing) and `pay-service` tests (23/23 passing) execute natively on Windows without shell or platform issues.
    - Tests verify base rate, distance rate, surge bonus, wait compensation, minimum wage floor topup, and FairDrop-vs-cliff comparison.

---

## 5. Chrome & Mobile Phone Readiness (Step 4)

- **CORS Configuration:**  
  - Both `core-service/src/app.js` and `pay-service/src/server.js` use bare `app.use(cors())`, setting `Access-Control-Allow-Origin: *`.
  - OPTIONS preflight verified with curl on both ports (HTTP 204 No Content with `Access-Control-Allow-Headers: Authorization,Content-Type`).
  - *Note:* Backends use wildcard CORS rather than an env-configured origin allowlist.
- **Flutter Web Compatibility:**  
  - Zero imports of `dart:io` or `Platform.*` across `fairdrop_app/lib/`.
  - Zero vibration or audio calls in production code.
  - `flutter_secure_storage` resolves web-compatible storage implementation.
  - `flutter_map` uses HTTPS OpenStreetMap tiles (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`).
- **Base URLs Centralization:**  
  - Both URLs live exclusively in `fairdrop_app/lib/config/app_config.dart` (`http://127.0.0.1:3003` and `http://127.0.0.1:3001`).
- **Android Manifest & Cleartext:**  
  - `fairdrop_app/android/app/src/main/AndroidManifest.xml` line 2 declares `<uses-permission android:name="android.permission.INTERNET" />`.
  - Line 8 declares `android:usesCleartextTraffic="true"`.
  - Backends listen on `0.0.0.0:3003` and `0.0.0.0:3001` (verified via `netstat -ano`).

---

## 6. Demo Runbook Discrepancies (`docs/DEMO_RUNBOOK.md`)

The following line-by-line discrepancies were identified between `docs/DEMO_RUNBOOK.md` and the PRD / actual codebase:

1. **Line 57 (`DEMO_RUNBOOK.md`):**  
   - *Text:* `curl http://localhost:3001/health`  
   - *Correction:* Change to `curl http://localhost:3001/api/health` (or mount `/health` in `pay-service/src/server.js`). Calling `/health` returns HTTP 404.
2. **Line 198 & 210 (`DEMO_RUNBOOK.md`):**  
   - *Text:* `"Cart itemizes Subtotal (₹360), Platform Fee (₹5), Delivery Fee (₹15), and GST... Tap Place Order (₹398)"`  
   - *Correction:* Remove delivery fee, platform fee, and GST. Customer total must be the sum of item prices (₹360), per PRD FR-59 and Decision D4.
3. **Line 209 (`DEMO_RUNBOOK.md`):**  
   - *Text:* `"On the Mock Payment Screen, select UPI / Instant Pay"`  
   - *Correction:* Remove payment method selection; PRD FR-59 mandates a single "Pay" button and label *"Demo payment. No money is charged."*
4. **Line 245 (`DEMO_RUNBOOK.md`):**  
   - *Text:* `"Transparent formula: ₹15.00 Base + ₹7.00/km + Surge + Wait Comp"`  
   - *Correction:* Change `₹7.00/km` to `₹6.00/km`, matching Kerala baseline constants (PRD Section 6) and `payEngine.js`.
5. **Line 282 & Line 424 (`DEMO_RUNBOOK.md`):**  
   - *Text:* `"Over 1 min is compensated at ₹10.00/min."` / `"₹10/min wait compensation"`  
   - *Correction:* Change to `"₹10.00 flat wait compensation"`. In `payEngine.js`, wait compensation is flat ₹10, not per-minute.
6. **Line 304 & Line 306 (`DEMO_RUNBOOK.md`):**  
   - *Text:* `"5. Return Compensation: ₹0.00"`, `"7. Delay Deduction: ₹0.00"`  
   - *Correction:* Remove these two lines. The 7-item ledger contract in PRD lines 277-286 contains only base rate, distance pay, surge bonus, wait compensation, total delivery pay, floor topup, and hourly earnings so far.
7. **Line 227 (`DEMO_RUNBOOK.md`):**  
   - *Text:* `"Audio/vibration cue triggers."`  
   - *Correction:* Remove audio/vibration mention (PRD Non-goals, line 53).
8. **Lines 223, 315, 375, 403 (`DEMO_RUNBOOK.md`):**  
   - *Text:* Lists routes as `/rider/home`, `/rider/dashboard`, `/admin/pay-config`, `/rider/profile`.  
   - *Correction:* Align with `main.dart` routes: `/rider-home`, `/rider-dashboard`, `/admin-panel`, `/profile`.

---

## 7. Actionable Findings & Remediation Plan

### 7.1 DEMO BLOCKERS (Must fix before presentation)

#### Blocker 1: Customer Cart & Payment Screen Display Delivery Fees, Platform Fees, and GST
- **File:** `fairdrop_app/lib/services/cart_service.dart` (lines 112-124), `fairdrop_app/lib/screens/customer/cart_screen.dart` (lines 307-316), and `fairdrop_app/lib/screens/customer/mock_payment_screen.dart` (lines 88-89, 159-174).
- **Root Cause:** `CartService` calculates arbitrary `deliveryFee` (₹30+₹10/km), `platformFee` (₹5), and 5% GST, and `CartScreen`/`MockPaymentScreen` display these fees.
- **Impact:** Directly contradicts PRD Goal Non-goals ("A delivery fee line... is a non-goal"), FR-59 ("There is no delivery fee line; the total is the sum of item prices"), and Decision D4 ("Cart holds one restaurant; no delivery fee line"). Breaks Demo Step 3 and Step 4 presentation.
- **Minimal Fix:** In `cart_service.dart`, set `deliveryFee`, `platformFee`, and `taxesAndCharges` to `0.0`, and `grandTotal => subtotal`. In `cart_screen.dart`, remove the 3 fee rows. In `mock_payment_screen.dart`, display `total = _cart.subtotal`, replace payment method radio buttons with the label *"Demo payment. No money is charged."*, and ensure the order is placed at the exact item subtotal.
- **Risk:** Low (localized entirely to customer cart display).

#### Blocker 2: Duplicate "Delivered" Request Returns HTTP 400 Instead of Idempotent 200 OK
- **File:** `core-service/src/modules/orders/order.controller.js` (lines 408-414).
- **Root Cause:** `Order.VALID_TRANSITIONS['delivered'] = []`. Calling `PATCH /api/orders/:id/status` with `new_status: 'delivered'` on an already delivered order fails transition validation and returns `400 Bad Request`.
- **Impact:** Violates PRD FR-74 and PRD Section 6 Row 9 ("idempotent delivered (FR-74)"). In a live demo, if a presenter accidentally double-taps "Delivered" or network retry occurs, the app throws an error instead of smoothly loading the delivery summary.
- **Minimal Fix:** In `core-service/src/modules/orders/order.controller.js` inside `updateStatus`, before transition validation:
  ```javascript
  if (order.status === 'delivered' && new_status === 'delivered') {
    return res.status(200).json({
      success: true,
      message: `Order ${order.order_id} is already delivered.`,
      order,
    });
  }
  ```
- **Risk:** Very low (clean early-exit returning existing order).

#### Blocker 3: Pay-Service Health Endpoint Mismatch (`/health` vs `/api/health`)
- **File:** `pay-service/src/server.js` (line 40).
- **Root Cause:** `pay-service` registers `app.get('/api/health')` but not `app.get('/health')`.
- **Impact:** Running `curl http://localhost:3001/health` per `docs/DEMO_RUNBOOK.md` step 2.1 returns `HTTP 404 Not Found`, failing pre-flight health verification.
- **Minimal Fix:** In `pay-service/src/server.js`, change `app.get('/api/health', ...)` to `app.get(['/health', '/api/health'], ...)`.
- **Risk:** Zero risk.

---

### 7.2 SHOULD FIX (High Priority Quality & Reliability)

#### Should Fix 1: Timezone Off-by-One Day Bug in Admin Pay Config
- **File:** `pay-service/src/routes/adminRoutes.js` (line 177).
- **Root Cause:** `clientDateMidnight = new Date(y, m - 1, d)` creates local midnight in IST (`00:00:00+05:30`). Calling `.toISOString().split('T')[0]` converts to UTC (`18:30:00Z` previous day), saving the date into MySQL 1 day earlier than selected.
- **Minimal Fix:** Avoid `Date.prototype.toISOString()`; format directly from validated integer parts:
  ```javascript
  const effectiveFromStr = `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  ```
- **Risk:** Very low.

#### Should Fix 2: Order Acceptance Wait Compensation Label Mismatch
- **File:** `fairdrop_app/lib/screens/order_acceptance_screen.dart` (line 725).
- **Root Cause:** Displays `+${formatCurrency(_waitCompensation)}/min`, misleading riders to expect per-minute accumulation rather than the flat ₹10 bonus implemented in `payEngine.js`.
- **Minimal Fix:** Change string to `'+${formatCurrency(_waitCompensation)} flat bonus if restaurant wait exceeds $_waitThresholdMins min (credited on delivery)'`.
- **Risk:** Zero risk.

#### Should Fix 3: Swallowed Network Errors Display Fabricated Sample Data
- **File:** `fairdrop_app/lib/screens/rider_dashboard_screen.dart` (line 143) and `fairdrop_app/lib/screens/analytics_screen.dart` (line 96).
- **Root Cause:** Catch blocks swallow network exceptions and render hardcoded fallback mock data rather than showing visible error states with retry buttons.
- **Minimal Fix:** Set `_errorMessage` and display standard error banners with retry triggers when `autoFetch` is enabled.
- **Risk:** Low.

#### Should Fix 4: Plaintext Password Committed in Documentation
- **File:** `docs/Application_Guide.md` (line with `DB_PASSWORD=root123`).
- **Root Cause:** Plaintext MySQL password committed in git-tracked document.
- **Minimal Fix:** Replace password with `DB_PASSWORD=your_password_here`.
- **Risk:** Zero risk.

#### Should Fix 5: Missing Android SDK in Development Environment
- **File:** Development machine environment configuration.
- **Root Cause:** Flutter CLI cannot locate Android SDK; release APK cannot be built on this machine.
- **Minimal Fix:** Install Android Command-line Tools / SDK platforms and set `ANDROID_HOME` in environment variables.
- **Risk:** None.

---

### 7.3 NICE TO HAVE (Polish & Documentation)

- **`scripts/e2e-smoke.js` (line 299):** Update log expression from `order.items_total` to `order.items.reduce((s, i) => s + i.price * i.quantity, 0)` so it prints real currency instead of `₹undefined`.
- **`docs/DEMO_RUNBOOK.md`:** Correct route names, rates (₹6/km), and remove return compensation / delay deduction rows from ledger notes.
