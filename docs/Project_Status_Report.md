# FairDrop — Complete Project Status Report

**Date:** 2026-10-19  
**Purpose:** Give any AI model or developer full context to continue working on FairDrop without errors.  
**Deadline:** Complete working project needed by 2026-10-21.

---

## 1. Project Overview

FairDrop is a gig-delivery platform with transparent, worker-fair pay. It's an MCA Mini Project (23MCAM307) at TKM College of Engineering, Kollam.

**Team:**
- **Hari (25MCA025):** Login, Home, Order Acceptance, Active Delivery, Zone Map, Profile
- **Raihan (25MCA026):** Pay Breakdown, Rider Dashboard, Analytics, Admin Panel

---

## 2. Architecture Summary

| Component | Tech Stack | Port | Database |
|---|---|---|---|
| **core-service** | Node.js + Express 5 + Mongoose | 3003 | MongoDB Atlas (remote) |
| **pay-service** | Node.js + Express 4 + mysql2 | 3001 | MySQL (local) |
| **fairdrop_app** | Flutter/Dart (Android) | — | flutter_secure_storage (JWT) |

> [!IMPORTANT]
> The PRD says pay-service should be on **port 3004**, but the actual code uses **port 3001**. The Flutter app's `AppConfig` also uses port 3001. This is consistent within the code but differs from the PRD § 7 (`pay-service (3004)`). **Keep using port 3001** — don't change it.

---

## 3. Feature Status — PRD Alignment (FR-1 to FR-50)

### 3.1 Splash and Login (P0) — FR-1 to FR-6

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-1 | Splash checks stored JWT → routes by role | ✅ DONE | [splash_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/splash_screen.dart) — validates token via `GET /api/auth/me`, routes rider→`/rider-home`, admin→`/admin-panel`, customer/restaurant→`/unsupported-role` |
| FR-2 | Login with email/password | ✅ DONE | [login_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/login_screen.dart) — calls `POST /api/auth/login` |
| FR-3 | JWT stored in secure storage | ✅ DONE | [core_api_service.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/services/core_api_service.dart) — uses `flutter_secure_storage` with AES-256 |
| FR-4 | 401 clears session → Login | ✅ DONE | `_handleError()` in `CoreApiService` calls `logout()` on 401 |
| FR-5 | Inline error messages | ✅ DONE | Both login and all API calls show user-friendly errors |
| FR-6 | Role routing per Section 3 | ✅ DONE | [unsupported_role_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/unsupported_role_screen.dart) for customer/restaurant |

### 3.2 Home (P0) — FR-7 to FR-10

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-7 | Online/Offline toggle | ⚠️ FRONTEND DONE, BACKEND MISSING | Flutter UI is done in [rider_home_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/rider_home_screen.dart). Calls `POST /api/rider/status` — but this **endpoint does NOT exist** in core-service. See **BUG-B1** below. |
| FR-8 | Poll for assigned order every 10s | ⚠️ FRONTEND DONE, BACKEND MISSING | Flutter polls `GET /api/orders/rider/active` — this **endpoint does NOT exist** in core-service. See **BUG-B2**. |
| FR-9 | Shows zone, earnings, floor indicator | ⚠️ FRONTEND DONE, BACKEND MISSING | Flutter calls `GET /api/rider/stats/today` — **endpoint does NOT exist** in core-service. See **BUG-B3**. |
| FR-10 | Incoming order → Order Acceptance | ✅ FRONTEND DONE | Navigation logic works: polls → finds order → `pushReplacementNamed('/order-acceptance', arguments: order)` |

### 3.3 Order Acceptance (P0) — FR-11 to FR-16

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-11 | Shows restaurant, drop-off, distance | ✅ DONE | [order_acceptance_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/order_acceptance_screen.dart) |
| FR-12 | Shows live pay formula | ✅ DONE | Loads pay config from `GET /api/admin/pay-config` and displays formula |
| FR-13 | Shows estimated pay (base + distance + surge) | ✅ DONE | Calculates `base + (distance × perKm) + surge`, notes wait/floor are post-delivery |
| FR-14 | Out-of-zone badge + consent | ✅ DONE | Checks `is_out_of_zone`, shows warning + checkbox consent |
| FR-15 | Accept/Decline, no penalty language | ✅ DONE | Decline goes to `/rider-home`, no penalty text |
| FR-16 | Accept disabled if config fails | ✅ DONE | `_canAccept` checks config loaded; retry button available |

### 3.4 Active Delivery (P0) — FR-17 to FR-20

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-17 | Status steps: Assigned → Arrived → Picked Up → Delivered | ✅ DONE | [active_delivery_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/active_delivery_screen.dart) — stepper UI with 4 steps |
| FR-18 | Arrived/Picked Up send timestamps, wait = diff | ✅ DONE | `_arrivedAt` recorded locally; `waitMins = DateTime.now().difference(_arrivedAt!).inMinutes` sent with picked_up |
| FR-19 | Delay report (traffic/restaurant/railway) | ✅ DONE | Delay report UI with ChoiceChip, notes field, and submit. Shows `verified` state |
| FR-20 | "Delivered" triggers pay calculation → Summary | ✅ DONE | Calls `updateOrderStatus(newStatus: 'delivered')` → navigates to `/pay-breakdown` with pay result |

### 3.5 Delivery Summary (P0) — FR-21 to FR-25

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-21 | Line-by-line breakdown | ⚠️ PARTIALLY | [pay_breakdown_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/pay_breakdown_screen.dart) shows breakdown BUT it's a **manual simulation form** — not connected to the actual delivery flow. The ActiveDelivery screen navigates to this with arguments, but PayBreakdownScreen **ignores route arguments** and shows its own input form. See **BUG-B4**. |
| FR-22 | Zero-value lines shown as ₹0 | ❌ NOT DONE | Pay breakdown **hides** surge and wait comp when zero (`if (surgeBonus > 0)`, `if (waitComp > 0)`). PRD says show as ₹0 with reason. See **BUG-B5**. |
| FR-23 | ₹ with two decimals | ✅ DONE | Uses `.toStringAsFixed(2)` everywhere |
| FR-24 | Failed pay shows "pending" + Retry | ❌ NOT DONE | Current screen shows connection error but doesn't handle the case where the delivery completed but pay call failed. See **BUG-B6**. |
| FR-25 | Delay verified state shown | ❌ NOT DONE | Delivery summary doesn't display delay context at all. See **BUG-B7**. |

### 3.6 Zone Map (P0) — FR-26 to FR-29

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-26 | Renders zone polygons with flutter_map | ✅ DONE | [zone_map_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/zone_map_screen.dart) — loads GeoJSON from `GET /api/zones/map` |
| FR-27 | Shows zone change after out-of-zone delivery | ❌ NOT DONE | No "zone change" notification or new zone highlight. See **BUG-B8**. |
| FR-28 | GeoJSON [lng,lat] → LatLng(lat,lng) | ✅ DONE | `_parsePolygon()` correctly swaps: `LatLng(p[1], p[0])` |
| FR-29 | No live location; marker = last delivery | ⚠️ N/A | No marker shown at all (acceptable per PRD, which says "any marker shown is the last delivery endpoint") |

### 3.7 Rider Dashboard (P0) — FR-30 to FR-33

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-30 | Today's summary cards | ✅ DONE | [rider_dashboard_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/rider_dashboard_screen.dart) — Total Earned, Deliveries, Avg Hourly Rate, Floor Top-ups |
| FR-31 | Per-delivery expandable rows | ⚠️ PARTIAL | Shows per-delivery list but **rows don't expand** to show full breakdown like FR-21. See **BUG-B9**. |
| FR-32 | Floor status | ✅ DONE | Avg hourly rate vs ₹70/hr, with color coding |
| FR-33 | Pull-to-refresh + auto-refresh | ⚠️ PARTIAL | Has manual refresh button in AppBar but **no pull-to-refresh** (no `RefreshIndicator`). No auto-refresh when returning from delivery. See **BUG-B10**. |

### 3.8 Analytics (P0) — FR-34 to FR-36

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-34 | FairDrop vs cliff-bonus chart | ✅ DONE | Bar chart in `rider_dashboard_screen.dart` using `fl_chart`. FairDrop (green) vs Cliff (red) |
| FR-35 | Cliff-model assumptions stated | ✅ DONE | Constants shown in code comments and insight text. Cliff: ₹20/delivery, ₹500 bonus at 10 deliveries |
| FR-36 | Includes case where cliff wins | ⚠️ PARTIAL | The chart extends to 11 points (BUG-12 fix), so at delivery #10 the cliff model can visually jump. But there's no explicit test case or dynamic scenario where cliff wins. The insight text doesn't acknowledge cliff can win. See **BUG-B11**. |

> [!NOTE]
> The PRD lists Analytics as a **separate screen (#9)**, but in the code it's combined into the Rider Dashboard screen. This is acceptable but should be noted.

### 3.9 Admin: Pay Config (P1) — FR-37 to FR-45

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-37 | Admin shell separate from rider | ⚠️ PARTIAL | Admin routes to `/admin-panel` but uses the **same navigation routes** — an admin can navigate to rider screens via the `HomeScreen`. No separate admin shell. See **BUG-B12**. |
| FR-38 | Shows active config | ✅ DONE | [admin_panel_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/admin_panel_screen.dart) — loads `GET /api/admin/pay-config` |
| FR-39 | Config history (read-only) | ❌ NOT DONE | The `ApiService.getConfigHistory()` method exists but the admin screen **doesn't show config history list**. See **BUG-B13**. |
| FR-40 | New config form pre-filled | ✅ DONE | Form fields pre-filled from active config |
| FR-41 | Date picker ≥ today + 7 days | ✅ DONE | `firstDate: minDate` where `minDate = DateTime.now().add(Duration(days: 7))` |
| FR-42 | Mandatory change reason | ✅ DONE | Validation checks non-empty before submit |
| FR-43 | Client-side validation: non-negative, whole number | ❌ NOT DONE | No numeric validation — user can enter negative numbers or decimals for wait threshold. See **BUG-B14**. |
| FR-44 | Confirmation dialog shows old → new diff | ⚠️ PARTIAL | Confirmation dialog shows reason and date but **doesn't show old → new value comparison**. See **BUG-B15**. |
| FR-45 | Existing configs can't be edited/deleted | ✅ DONE | No edit/delete functionality in UI |

### 3.10 Onboarding and Profile (P1) — FR-46 to FR-49

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-46 | Onboarding: pay policy, 7-day notice, safety checklist | ✅ DONE | [onboarding_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/onboarding_screen.dart) — 3 pages with checklist. But doesn't set `safety_checklist_acknowledged` on the server. See **BUG-B16**. |
| FR-47 | Profile: name, zone, vehicle, policy link | ✅ DONE | [profile_screen.dart](file:///c:/Users/Admin/FairDrop/fairdrop_app/lib/screens/profile_screen.dart) — shows name, email, role, zone, vehicle, pay policy summary |
| FR-48 | Upcoming pay change notice | ✅ DONE | Profile screen checks config history for future `effective_from` dates and shows amber notice |
| FR-49 | Deactivation-reason display | ❌ NOT DONE | Documented only (acceptable per PRD: "unless time remains") |

### 3.11 Grievance Form (P2) — FR-50

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-50 | Text form posting to core-service | ❌ NOT DONE | P2 priority — only build if all P0/P1 done |

---

## 4. Missing Backend Endpoints (CRITICAL)

These are endpoints the Flutter app calls but that **do NOT exist** in core-service:

| # | Endpoint | Called By | Purpose | Priority |
|---|---|---|---|---|
| **BUG-B1** | `POST /api/rider/status` | `CoreApiService.setRiderStatus()` | Online/Offline toggle (FR-7) | 🔴 CRITICAL |
| **BUG-B2** | `GET /api/orders/rider/active` | `CoreApiService.getRiderActiveOrder()` | Poll for assigned order (FR-8) | 🔴 CRITICAL |
| **BUG-B3** | `GET /api/rider/stats/today` | `CoreApiService.getTodayStats()` | Today's earnings/hours/zone (FR-9) | 🔴 CRITICAL |

### How to Implement These

**BUG-B1: `POST /api/rider/status`**
- Add to core-service routes
- Update user's `rider_profile.is_available` field
- Record `online_at`/`offline_at` timestamps to calculate `active_hours_today`
- Mount under a new `rider.routes.js` or add to `order.routes.js`

**BUG-B2: `GET /api/orders/rider/active`**
- Query `Order.findOne({ rider_id: req.user._id, status: { $in: ['assigned', 'picked_up'] } })`
- Return the order or `{ order: null }` if none active
- Add to `order.routes.js`

**BUG-B3: `GET /api/rider/stats/today`**
- Aggregate today's delivered orders for the rider
- Sum `pay_calculation_result.total_delivery_pay` + `floor_topup`
- Count deliveries
- Read active hours from rider profile timestamps
- Return `{ stats: { total_earnings_today, active_hours_today, deliveries_today, current_zone } }`

> [!IMPORTANT]
> The app also references `GET /api/orders/history` but this endpoint IS implemented in `order.controller.js` as `getOrderHistory` — returns all orders for the logged-in user.

---

## 5. Flutter App Bugs

| Bug ID | File | Issue | Severity |
|---|---|---|---|
| **BUG-B4** | `pay_breakdown_screen.dart` | Ignores route arguments from ActiveDelivery. Shows manual simulation form instead of actual delivery pay result. Should check `ModalRoute.of(context)?.settings.arguments` for a pay result and display it. | 🔴 CRITICAL |
| **BUG-B5** | `pay_breakdown_screen.dart` | Zero-value lines hidden (`if (surgeBonus > 0)`). PRD FR-22 says show as ₹0 with reason. | 🟡 MEDIUM |
| **BUG-B6** | `pay_breakdown_screen.dart` | No "Pay calculation pending" + Retry for post-delivery failures (FR-24). | 🟡 MEDIUM |
| **BUG-B7** | `pay_breakdown_screen.dart` | Doesn't show delay context/verified state (FR-25). | 🟡 MEDIUM |
| **BUG-B8** | `zone_map_screen.dart` | No zone-change notification after out-of-zone delivery (FR-27). | 🟡 MEDIUM |
| **BUG-B9** | `rider_dashboard_screen.dart` | Per-delivery rows don't expand to show full breakdown (FR-31). | 🟡 MEDIUM |
| **BUG-B10** | `rider_dashboard_screen.dart` | No pull-to-refresh; no auto-refresh on return from delivery. | 🟢 LOW |
| **BUG-B11** | `rider_dashboard_screen.dart` | No explicit cliff-wins scenario or acknowledgment in insight text (FR-36). | 🟡 MEDIUM |
| **BUG-B12** | `main.dart` | Admin can navigate to rider screens through HomeScreen. No separate admin shell (FR-37). | 🟡 MEDIUM |
| **BUG-B13** | `admin_panel_screen.dart` | Doesn't display config history list (FR-39). API method exists. | 🟡 MEDIUM |
| **BUG-B14** | `admin_panel_screen.dart` | No client-side numeric validation (non-negative, whole number for threshold) (FR-43). | 🟢 LOW |
| **BUG-B15** | `admin_panel_screen.dart` | Confirmation dialog doesn't show old→new value diff (FR-44). | 🟢 LOW |
| **BUG-B16** | `onboarding_screen.dart` | Stores `onboarding_complete` in SharedPreferences (local only) but doesn't update `safety_checklist_acknowledged` on the server (FR-46). | 🟢 LOW |
| **BUG-B17** | `login_screen.dart` | Imports `shared_preferences` — this should use `flutter_secure_storage` for consistency, or the onboarding flag can stay in SharedPreferences since it's not sensitive. Not a bug per se, but inconsistency. | 🟢 LOW |

---

## 6. Backend Bugs / Issues

| Bug ID | File | Issue | Severity |
|---|---|---|---|
| **BUG-S1** | `core-service/app.js` | No `/api/rider/*` routes mounted. Need `riderRoutes` module. | 🔴 CRITICAL |
| **BUG-S2** | `pay-service` | No JWT verification on any pay-service route. PRD §6 says "JWT verification on all pay-service routes (shared JWT_SECRET), plus role check on admin routes". | 🟡 MEDIUM |
| **BUG-S3** | `order.controller.js` | The `updateOrderStatus` handler for `delivered` calls `payClient.js` to calculate pay, but the response from pay-service needs `rider_id` from the riders table — there's no automatic rider creation in MySQL when a rider registers in MongoDB. | 🟡 MEDIUM |
| **BUG-S4** | `pay-service` | `adminRoutes.js` hardcodes `created_by` as `'admin'` string — doesn't read the actual admin user from the request. No auth at all on admin routes. | 🟡 MEDIUM |
| **BUG-S5** | `payRoutes.js` | `GET /api/pay/history/:rider_id` — no auth check; anyone can read any rider's pay history. | 🟡 MEDIUM |

---

## 7. Provider State Management

> [!WARNING]
> PRD §7 specifies **Provider** for state management. The `provider` package **IS** in `pubspec.yaml` but is **NOT USED** anywhere in the code. All screens use direct `setState()` with static service calls. This is functional but doesn't match the PRD architecture.

**Recommendation:** This is low-priority for demo functionality. All screens work with `setState()`. Refactoring to Provider would be a nice-to-have but not critical for the deadline.

---

## 8. Architecture Gaps (PRD §7)

| PRD Requirement | Actual | Gap |
|---|---|---|
| `models/` layer | ❌ Not present | No Dart model classes; raw `Map<String, dynamic>` used everywhere |
| `providers/` layer | ❌ Not present | No Provider classes; `setState()` only |
| `widgets/` layer | ❌ Not present | Reusable widgets are private methods within screens |
| Separate `services/` per backend | ✅ Done | `api_service.dart` (pay) + `core_api_service.dart` (core) |
| Two base URLs in config | ✅ Done | `app_config.dart` |
| Unit tests | ❌ Not present | No Flutter tests exist |

---

## 9. Priority Fix Order (for deadline)

### 🔴 Day 1 — Critical (must be done first)

1. **Implement 3 missing backend endpoints** (BUG-B1, B2, B3) in core-service
2. **Fix PayBreakdownScreen** (BUG-B4) to handle route arguments from ActiveDelivery
3. **Test the end-to-end demo flow** (PRD §10)

### 🟡 Day 2 — Medium (for demo completeness)

4. Fix zero-value line display (BUG-B5)
5. Add config history to admin panel (BUG-B13)
6. Add old→new diff in admin confirmation dialog (BUG-B15)
7. Handle cliff-wins scenario (BUG-B11)
8. Add pull-to-refresh to dashboard (BUG-B10)
9. Show delay verified state in pay breakdown (BUG-B7)

### 🟢 If Time Allows

10. Add client-side validation in admin panel (BUG-B14)
11. Add zone-change notification (BUG-B8)
12. Expand per-delivery rows in dashboard (BUG-B9)
13. Separate admin shell (BUG-B12)
14. Add JWT auth to pay-service routes (BUG-S2)
15. Grievance form (FR-50)

---

## 10. Demo Flow Test Checklist (PRD §10)

| Step | Description | Ready? |
|---|---|---|
| 1 | Rider logs in and goes online | ❌ — needs `POST /api/rider/status` |
| 2 | Order placed via Postman → appears on Home | ❌ — needs `GET /api/orders/rider/active` |
| 3 | Order Acceptance shows formula + estimate | ✅ — works if order data passed correctly |
| 4 | Rider steps through arrived, picked up, delivered | ✅ — `PATCH /api/orders/:id/status` works |
| 5 | Delivery Summary shows breakdown | ⚠️ — needs BUG-B4 fix |
| 6 | Dashboard reflects delivery + floor | ✅ — if rider has earnings in pay-service DB |
| 7 | Analytics shows comparison | ✅ — chart works |
| 8 | Zone Map shows zone change | ⚠️ — zones display but no "change" notice |
| 9 | Admin creates config with 7-day notice | ✅ — works |
| 10 | Customer/restaurant login → unsupported screen | ✅ — works |
