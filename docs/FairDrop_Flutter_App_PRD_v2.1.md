# FairDrop Flutter App — Product Requirements Document

**Version:** 2.1 (decisions locked, build-ready)
**Platform:** Flutter/Dart, Android (demo target)
**Project:** MCA Mini Project (23MCAM307), TKM College of Engineering, Kollam
**Visual design:** the project's Stitch designs, read through the Stitch MCP server. There is no `Design.md`.

**Ownership (for the project report)**

| Area | Owner |
|---|---|
| Login, Home, Order Acceptance, Active Delivery, Zone Map | Hari |
| Delivery Summary, Rider Dashboard, Analytics, Admin Pay Config | Raihan |
| Rider Signup, Customer, Restaurant, app shell, API clients, Provider setup | Shared |

All implementation is done by AI agents in Antigravity on Hari's laptop. The table above records who owns each area academically; it does not assign coding work.

**Changes from v2.0**

- Every **[TBC]** item is now decided (Section 11). Nothing in this document is left open.
- pay-service stays on **port 3001** (v2.0 said 3004; the code, `.env` and app already use 3001).
- Design source is Stitch via MCP, not `Design.md`.
- Demo hosting is fixed: everything runs on Hari's laptop, with USB `adb reverse` as the primary transport (Section 10.1).
- Order lifecycle states and rider-polling behaviour are defined precisely (FR-67).
- New requirements FR-72 to FR-74 (allocation on going online, out-of-zone cap, idempotent delivery).

---

## 1. Overview

The FairDrop app is the mobile interface of a gig-delivery platform designed around transparent, worker-fair pay. Riders see how their pay is calculated before they accept an order, how each delivery was paid afterwards, and whether the platform is meeting a minimum earnings floor. Admins edit the pay configuration under a 7-day advance-notice rule.

The app also carries the customer and restaurant sides of the order, so the whole workflow can be shown in one demo: a customer orders food listed by a restaurant, a rider accepts and delivers it, and the rider's pay is shown with its full derivation.

The app makes the backend's fairness policies visible and verifiable. If a policy isn't shown in the UI, an examiner can't see it.

## 2. Goals and Non-Goals

**Goals**

- G1. Show the pay formula and an estimate before the rider accepts an order (Problem 4).
- G2. Show a line-by-line pay breakdown after every delivery (Problem 4).
- G3. Show zone assignment, zone changes after out-of-zone deliveries, and the out-of-zone cap (Problem 2).
- G4. Show delay flags and whether each was verified (Problem 3).
- G5. Show hourly earnings against the minimum wage floor (Problems 1 and 6, partial).
- G6. Show a FairDrop-vs-cliff-bonus comparison for the same rider (the core academic contribution).
- G7. Let an admin change pay constants with mandatory notice and a recorded reason.
- G8. Complete an end-to-end demo with no manual database edits. A documented seed script is allowed (Section 10.1).
- G9. Complete the full order lifecycle in the app: restaurant maintains its menu, customer orders, rider accepts, delivers and sees the pay breakdown.

**Non-goals (deliberate decisions)**

- Real-time GPS tracking, payment gateway, websockets, background idle timers, app store release, union recognition.
- Live order tracking for the customer. Customer and restaurant screens refresh on demand only.
- Manual restaurant accept/reject and manual "mark ready" actions.
- Signup screens for customer, restaurant and admin.
- Road-distance routing. Distance is straight-line.
- Localization (Malayalam) and iOS builds.
- A delivery fee line, multi-restaurant carts, and extra menu fields (description, category, image).

## 3. Users and Roles

| Role | In the app | How the account is created |
|---|---|---|
| Rider | Yes, primary | Signs up in the app |
| Customer | Yes | Seeded |
| Restaurant | Yes | Seeded |
| Admin | Yes, config screens only | Seeded |

The backend auth module keeps all four roles (`customer`, `rider`, `restaurant`, `admin`).

- After login the app reads the role from the token and routes to the matching shell: rider, customer, restaurant or admin.
- A token with any other role shows a "This role isn't supported in the mobile app" screen with a logout button. No session is kept.
- The same app build runs on both demo devices. The role is never chosen in the app; it comes from the account.

## 4. Screen Inventory and Priority

| # | Screen | Role | Owner | Priority |
|---|---|---|---|---|
| 1 | Splash | All | Shared | P0 |
| 2 | Login | All | Hari | P0 |
| 3 | Rider Signup | Rider | Shared | P0 |
| 4 | Home (online toggle, incoming order) | Rider | Hari | P0 |
| 5 | Order Acceptance (formula + estimate) | Rider | Hari | P0 |
| 6 | Active Delivery (status steps) | Rider | Hari | P0 |
| 7 | Delivery Summary (pay breakdown) | Rider | Raihan | P0 |
| 8 | Zone Map | Rider | Hari | P0 |
| 9 | Rider Dashboard | Rider | Raihan | P0 |
| 10 | Analytics (FairDrop vs cliff), separate screen | Rider | Raihan | P0 |
| 11 | Customer: Delivery Location (map pin) | Customer | Shared | P0 |
| 12 | Customer: Restaurant List | Customer | Shared | P0 |
| 13 | Customer: Menu | Customer | Shared | P0 |
| 14 | Customer: Cart | Customer | Shared | P0 |
| 15 | Customer: Mock Payment | Customer | Shared | P0 |
| 16 | Customer: Order Confirmation | Customer | Shared | P0 |
| 17 | Restaurant: Menu Management | Restaurant | Shared | P0 |
| 18 | Restaurant: Add/Edit Menu Item | Restaurant | Shared | P0 |
| 19 | Restaurant: Orders | Restaurant | Shared | P0 |
| 20 | Admin: Pay Config (active, history, new) | Admin | Raihan | P1 |
| 21 | Onboarding (policy + safety checklist) | Rider | Shared | P1 |
| 22 | Customer: Order History | Customer | Shared | P1 |
| 23 | Profile | Rider | Hari | P1 |
| 24 | Grievance / feedback form | Rider | Shared | P2 |

Onboarding is P1 but carries two Fairwork principles. Build it before Profile.

## 5. Functional Requirements

### 5.1 Splash and Login (P0)

- FR-1. Splash checks for a stored JWT. A valid token (verified with the backend) routes by role; otherwise to Login.
- FR-2. Login takes email and password and calls the core-service auth endpoint. Login offers a link to Rider Signup (FR-51).
- FR-3. On success the JWT and role are stored in secure storage.
- FR-4. A 401 or expired token anywhere in the app clears the session and returns to Login.
- FR-5. Errors show inline messages (invalid credentials, network unreachable). No raw exception text.
- FR-6. Role routing follows Section 3: rider, customer, restaurant and admin each go to their own shell.

### 5.2 Home (P0)

- FR-7. An Online/Offline toggle is the sole source of active-hours accounting. The app sends the state change to core-service, which records session timestamps and derives `active_hours_today` (including any open session). The app never computes hours itself. Logging out sets the rider Offline (FR-54).
- FR-8. When online, the app polls for the rider's current order at a configurable interval (default 10 seconds). No websockets. The response covers an order allocated to this rider but not yet answered, and an order already accepted and in progress, so the app can resume at the right screen (FR-67).
- FR-9. Shows the current zone name, today's earnings so far, and an hourly-earnings-vs-floor indicator. The app never shows NaN, Infinity or a division error when hours are very small.
- FR-10. An allocated order the rider has not answered opens Order Acceptance. An order already accepted opens Active Delivery at its current step.

### 5.3 Order Acceptance (P0)

- FR-11. Shows restaurant, drop-off area, and distance in km, labelled as a straight-line approximation (FR-70).
- FR-12. Shows the pay formula using the live constants (read from the non-admin config endpoint, FR-75 in Section 6): base + (distance × per-km rate) + surge (if active) + wait compensation (if restaurant wait exceeds the threshold).
- FR-13. Shows an estimated pay covering base, distance and surge only. A visible note says wait compensation and floor top-up are calculated after delivery. The estimate is never presented as final.
- FR-14. If the order is out of zone, shows an out-of-zone badge, the distance beyond the zone boundary (computed by core-service), and a plain-language statement of the consent rule, with a consent checkbox that must be ticked before Accept is enabled.
- FR-15. Accept and Decline buttons. Declining shows no penalty language anywhere. A declined order is released and reallocated to another online rider, excluding the decliner (FR-68). If no other rider exists it stays unallocated.
- FR-16. If the constants can't be loaded, Accept is disabled with an explanation and a Retry. A rider is never asked to accept without seeing the formula.

### 5.4 Active Delivery (P0)

- FR-17. Linear status steps: Assigned → Arrived at Restaurant → Picked Up → Delivered. "Assigned" means the rider has accepted. An "Order ready" indicator, driven by the backend ready flag (FR-69), is shown alongside the steps. It informs the rider and does not gate any step: "Picked Up" can be tapped any time after "Arrived at Restaurant".
- FR-18. "Arrived at Restaurant" and "Picked Up" are recorded with **server** timestamps. Restaurant wait is picked-up time minus arrived time, computed server-side, and sent to pay-service as `restaurant_wait_mins` rounded **up** to whole minutes (so wait exceeds an integer threshold exactly when the rounded value does). The app sends no wait value and runs no timer.
- FR-19. Optional "Report a delay" with type (traffic / restaurant / railway). The backend sets `delay_context` with `verified` and `source` (verification is mocked server-side). The app displays them as returned. A rider cannot self-verify.
- FR-20. "Delivered" triggers pay calculation on the backend. The app shows a loading state, then navigates to Delivery Summary carrying the pay result (or the pending state, FR-24).

### 5.5 Delivery Summary (P0)

- FR-21. Line-by-line breakdown from the pay response: `base_rate`, `distance_pay`, `surge_bonus`, `wait_compensation`, `total_delivery_pay`, `floor_topup`, `hourly_earnings_so_far`. The screen displays the result passed from Active Delivery; it is not a manual calculator.
- FR-22. Zero-value lines are shown as ₹0.00 with a one-line reason (for example "No surge on this order"), not hidden.
- FR-23. All money is formatted with ₹ and two decimals.
- FR-24. If the delivery completed but the pay call failed, shows "Pay calculation pending" with Retry (calls the backend retry endpoint). It never shows a fabricated total.
- FR-25. If the delivery had a delay flag, the verified state and source are shown next to the breakdown.

### 5.6 Zone Map (P0)

- FR-26. Renders the rider's current zone polygon and the other Kollam zones using `flutter_map`.
- FR-27. Shows the current zone and, after an out-of-zone delivery, the new zone with a short notice.
- FR-28. GeoJSON arrives as `[longitude, latitude]`. Conversion to `LatLng(lat, lng)` happens in one parsing function with a unit test. The same function is used wherever the app reads or writes coordinates, including the customer's drop-off pin (FR-55).
- FR-29. No live rider location. Any marker shown is the last delivery endpoint.

### 5.7 Rider Dashboard (P0)

- FR-30. Today's summary: deliveries, total earned, active hours, hourly earnings.
- FR-31. Per-delivery list. Each row expands to the same breakdown as FR-21.
- FR-32. Minimum wage floor status: hourly earnings against the floor value (from config), and the day's top-up total.
- FR-33. Refresh is pull-to-refresh plus automatic refresh when returning from Delivery Summary.

### 5.8 Analytics (P0)

- FR-34. Separate screen, reachable from the Dashboard. Compares FairDrop incentive policy against illustrative target platform incentive ladders (Zomato ladder as example data from 28 Jun single source screenshot: 19 orders = ₹306, 23 = ₹383, 25 = ₹434, 27 = ₹510; labelled "illustrative example", replacing the old 10-delivery/₹500 cliff model) using `fl_chart`. Since base pay, distance pay, monsoon, and return pay are identical on both sides, the screen specifically compares incentives and clearly states this scope on screen.
- FR-35. States illustrative model assumptions and parameters transparently on screen: FairDrop linear incentive rate formula `incentive(n) = rate × n + peak_bonus` where rate is configurable (default (510 − 50) / 27 ≈ ₹17.04 per order), peak bonus (₹25 × 2 windows: 7–9 PM, 12–2 PM = ₹50) with interactive toggle for "peak windows covered", and benchmark order targets.
- FR-36. Pay Analytics must show the FairDrop policy winning fairly, removing "Cliff Wins" framing and the unsourced "over 80% of shifts fail quota" claim:
  1. Chart of cumulative incentive vs orders 0–30 with the Zomato step line, FairDrop with peak, and FairDrop without peak.
  2. Parity table showing orders needed to earn the same incentive: With peak: 16, 20, 23, 27; Without peak: 18, 23, 26, 30.
  3. Equal pay benchmark reached at 27 orders with peak bonus.
  4. Stated explanatory notes on screen:
     - Peak bonus assumes the rider is online in both windows (7–9 PM, 12–2 PM).
     - The rate varies by day like Zomato's.
     - The platform's break-even rate = expected Zomato incentive spend ÷ expected orders per rider.
  5. Implemented as a separate analytics calculation without modifying `payEngine.js` formulas or the `/api/pay/calculate` backend contract. Prefer reading values from existing config or using a clearly labelled constants file (`incentive_analytics.dart`).

### 5.9 Admin: Pay Config (P1)

- FR-37. Admin shell is separate from the other shells and shows only config screens.
- FR-38. Shows the active config: base rate, per-km rate, surge bonus, wait threshold (minutes), wait compensation, minimum wage per hour, effective-from date.
- FR-39. Shows config history (newest first) with effective-from date, created-by and change reason. Read-only. The seeded baseline appears first in time.
- FR-40. "New config" form with the six constants pre-filled from the active config.
- FR-41. Effective-from date picker cannot select earlier than today + 7 days.
- FR-42. Change reason is mandatory and non-empty.
- FR-43. Client-side validation: numeric fields non-negative; wait threshold is a whole number. Server validation is authoritative and its errors are displayed.
- FR-44. Before submitting, a confirmation dialog shows old → new values for every changed field and the effective date.
- FR-45. Existing configs cannot be edited or deleted from the app.

### 5.10 Onboarding and Profile (P1)

- FR-46. Onboarding shows the pay policy, the 7-day notice commitment and a safety checklist. Acknowledging the checklist sets `safety_checklist_acknowledged` **on the server**.
- FR-47. Profile shows name, zone, vehicle type, and a link back to the policy summary.
- FR-48. If a scheduled config exists with a future effective date, riders see an "Upcoming pay change" notice on Home or Profile, showing the new values and the effective date.
- FR-49. Deactivation-reason display is documented only unless time remains.

### 5.11 Grievance Form (P2)

- FR-50. A single text form posting to core-service. Build only if all P0 and P1 items are done.

### 5.12 Rider Signup and Logout (P0)

- FR-51. Rider Signup is reached from Login. It collects name, email, password and vehicle type, and creates a rider account through core-service. There is no role selector; signup always creates a rider and ignores any client-sent role or zone.
- FR-52. The backend assigns the new rider's zone: the zone with the fewest riders; ties go to the lowest `zone_id`. The app neither asks for nor sends a zone. The assigned zone is shown on Home, Zone Map and Profile.
- FR-53. After signup the rider is signed in and goes to Onboarding (if built), otherwise to Home.
- FR-54. Logging out as a rider sends the Offline state change to core-service as part of logout, then clears the session. If that call fails, the session is still cleared.

### 5.13 Customer (new)

- FR-55 (P0). **Delivery Location.** First screen after customer login. A `flutter_map` map where the customer taps to place a drop-off pin. Confirming continues to the Restaurant List. Coordinates are handled by the single parsing function from FR-28.
- FR-56 (P0). **Restaurant List.** Shows all restaurants, unfiltered.
- FR-57 (P0). **Menu.** Shows the selected restaurant's items with name and price. An unavailable item cannot be added to the cart.
- FR-58 (P0). **Cart.** Add, remove, change quantity; shows the items total. A cart holds items from one restaurant only; adding from another restaurant asks the customer to clear the cart first.
- FR-59 (P0). **Mock Payment.** Shows the items total, a Pay button and the label "Demo payment. No money is charged." Pay places the order. No card or payment details are collected, no gateway is called. There is no delivery fee line; the total is the sum of item prices.
- FR-60 (P0). **Order Confirmation.** After placement shows the order ID, restaurant, items and total. No live tracking, no polling. If the backend returns `allocation: "no_rider_available"`, the screen shows "Order placed. No rider is available yet." and the order is allocated when a rider goes online (FR-72).
- FR-61 (P1). **Order History.** Lists the customer's orders with status as of the last refresh. Pull-to-refresh only.

### 5.14 Restaurant (new, P0)

- FR-62. **Menu Management.** Lists the restaurant's own items with name, price, preparation time in seconds and availability.
- FR-63. **Add/Edit Item.** Fields: name, price, preparation time (whole seconds), availability toggle. No other fields. Client validation: price non-negative number; preparation time whole number; name non-empty. Server validation is authoritative and its errors are displayed.
- FR-64. Availability can be switched on or off for any item. Deleting items is not in scope. A restaurant can only change its own items.
- FR-65. **Orders.** Lists the restaurant's orders with items and status as reported by the backend (accepted, ready, picked up, delivered). Pull-to-refresh only.
- FR-66. Orders are accepted automatically on placement. The restaurant has no accept, reject or mark-ready action.

### 5.15 Order Lifecycle (backend behaviour the app relies on, new)

- FR-67. Lifecycle and states. `status` takes the values `accepted`, `assigned`, `arrived`, `picked_up`, `delivered`, `cancelled` (`placed` appears only in `status_history`). Flow: placed → accepted (automatic, at placement) → rider allocated (`rider_id` set, `rider_ack = pending`, status stays `accepted`) → rider accepts (`rider_ack = accepted`, status `assigned`) → arrived → picked_up → delivered. `is_ready` is a derived flag (FR-69), independent of status. The rider's polling endpoint returns the single order with `rider_id` = this rider and status in {accepted with `rider_ack = pending`, assigned, arrived, picked_up}, or null.
- FR-68. Allocation, run at placement. Match by the zone containing the **restaurant's location**. Choose one online rider in that zone with no open order (least recently assigned first), skipping riders who declined this order and riders for whom the out-of-zone cap (FR-73) fails. If none, fall back to any online rider with no open order who passes the cap. If still none, the order stays `accepted` and unallocated and the placement response carries `allocation: "no_rider_available"`.
- FR-69. `is_ready` = now ≥ `accepted_at` + the longest item `prep_time_seconds`. It is computed when the order is read. No timers or schedulers. It is shown on rider Active Delivery (FR-17) and restaurant Orders (FR-65) and gates no action.
- FR-70. `distance_km` is the straight-line (haversine) distance between the restaurant's location and the customer's drop-off pin, rounded to 2 decimals, computed by core-service, and labelled as approximate wherever shown. It is the `distance_km` sent to pay-service.
- FR-71. Restaurant wait stays as FR-18. Because "Picked Up" is not gated on ready, wait compensation in the demo depends on the rider's own pace between "Arrived" and "Picked Up".
- FR-72. When a rider goes Online, any unallocated `accepted` orders are run through allocation (FR-68), oldest first.
- FR-73. Out-of-zone cap. An order is out of zone when the drop-off pin lies outside the allocated rider's current zone polygon. The distance beyond the boundary is computed server-side and returned. A rider is not allocated an order whose drop-off is farther beyond their zone boundary than the zone's `max_out_of_zone_radius_km`. After such a delivery, the rider's `current_zone_id` becomes the zone containing the drop-off pin if there is one; otherwise it is unchanged.
- FR-74. Idempotency. Repeating "Delivered" (double tap, retry) never creates a second delivery or a second pay record. Pay calculation is idempotent per `order_id`.

## 6. Backend Dependencies

Every row must be checked against the actual code before work starts, then marked EXISTS / BROKEN / MISSING in the implementation plan. "Build or fix" means the agent builds it if missing and repairs it if broken.

| Need | Provider | Rule |
|---|---|---|
| Auth: login, token, role (four roles) | core-service (3003) | Verify |
| Rider signup; zone assignment (FR-51/52); creates the MySQL `riders` row with `rider_id` = MongoDB `_id` string; if the MySQL step fails, roll back the Mongo user | core-service ↔ pay-service | Build or fix |
| Online/Offline with session timestamps, derived `active_hours_today`, Offline on logout, allocation on Online (FR-72) | core-service | Build or fix |
| Today's stats for Home (earnings, hours, zone) | core-service | Build or fix |
| Restaurant list; menu read incl. availability | core-service | Build or fix |
| Menu create/edit/availability (restaurant role only, own items only); prep time in whole seconds | core-service | Build or fix |
| Order placement: item IDs and quantities, **prices read from the DB (never trusted from the client)**, unavailable items rejected, drop-off coordinates required, haversine distance, auto-accept, allocation (FR-68) | core-service | Build or fix |
| Rider current-order poll; accept; decline (ownership checked) | core-service | Build or fix |
| Status transitions with server timestamps; valid order enforced; rider ownership enforced; idempotent delivered (FR-74) | core-service | Build or fix |
| Delay report and server-set `delay_context` | core-service | Verify, fix |
| On delivered: call pay-service forwarding the caller's JWT, store `pay_calculation_result` and `pay_status` (`calculated` / `pending`); retry endpoint | core-service | Build or fix |
| Order lists for customer and for restaurant, with `is_ready` | core-service | Build or fix |
| Zone data, point-in-polygon, current-zone update (FR-73) | core-service | Verify, fix |
| JWT verification on ALL pay-service routes (shared `JWT_SECRET`); admin role check on admin routes; `created_by` taken from the token; a rider may read only their own history | pay-service (3001) | Build or fix |
| FR-75. Active config and any scheduled (future) config, read-only, for any authenticated user; active config chosen by `effective_from ≤ now` with no scheduler | pay-service | Build or fix |
| Dashboard summary and per-delivery history with the full FR-21 breakdown | pay-service | Build or fix |
| Analytics: actual FairDrop vs cliff comparison, cliff assumptions, and the cliff-wins scenario (FR-36) | pay-service | Build or fix |
| Pay config list and create, admin only; server enforces `effective_from ≥ today + 7 days`, non-empty reason, non-negative numbers, whole-number wait threshold | pay-service | Verify, fix |
| `POST /api/pay/calculate` idempotent per `order_id`; upserts the rider row if missing | pay-service | Build or fix |

**Pay calculation contract (locked):** `POST /api/pay/calculate`, called by core-service on delivery completion.

Request:

```json
{
  "rider_id": "string",
  "order_id": "ORD-{YYYYMMDD}-{4-digit-seq}",
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

Response:

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

`payEngine.js` formulas are not changed. core-service never sends `active_hours_today` as 0 (it sends at least 0.0001).

**Kerala baseline constants (admin-configurable; the app reads them, never hardcodes them):**

| Constant | Value |
|---|---|
| Base rate | ₹15 per delivery |
| Per-km rate | ₹6/km |
| Surge bonus | ₹20 flat |
| Wait threshold | 10 minutes (demo seed: **1 minute**) |
| Wait compensation | ₹10 flat |
| Minimum wage floor | ₹70/hr |

## 7. Architecture

- **State management:** Provider. Minimum providers: auth/session, rider state, cart, menu/orders. Typed Dart models for User, Order, MenuItem, PayConfig, PayResult and Zone; no raw `Map` in new code. Existing screens are migrated as they are touched.
- **Layers:** `models/`, `services/` (one API client per backend), `providers/`, `screens/` (grouped by role shell: rider, customer, restaurant, admin), `widgets/`, `theme/`.
- **Theme:** colours, typography and spacing are extracted once from the Stitch designs into `lib/theme/app_theme.dart`. Screens are built from the Stitch screens through the Stitch MCP. If a PRD screen has no Stitch design, it is created in the same Stitch project first, then implemented. UI work never changes logic or API calls.
- **Base URLs:** core-service (3003) and pay-service (3001), in one config file `lib/config/app_config.dart`. Switching between USB `adb reverse` (host `127.0.0.1`) and hotspot (host `192.168.137.1`) is a one-line change.
- **Android release build:** the manifest declares the `INTERNET` permission and allows cleartext HTTP (backends are plain `http://`). The installed release APK must be verified, not only `flutter run`.
- **Storage:** JWT in `flutter_secure_storage`.
- **Charts:** `fl_chart`. **Maps:** `flutter_map` (no API key), used by the rider Zone Map and the customer Delivery Location screen.
- **HTTP:** one HTTP package used consistently across both clients, with a timeout on every call.
- **Navigation:** role-based shell chosen after login.
- **Backends:** core-service is Express 5 + Mongoose + MongoDB Atlas; pay-service is Express 4 + mysql2 + local MySQL. They talk only over HTTP. Both listen on `0.0.0.0`.
- **Testing:** Node built-in test runner for both backends; Flutter unit tests for the GeoJSON parser, money formatting, and role routing across all four roles plus an unknown role; one scripted end-to-end smoke test (Section 10.4).

## 8. Non-Functional Requirements

- Cold start to Login or Home within 3 seconds on the demo device.
- Every network call has a timeout and a visible error state. No infinite spinners.
- No secrets or backend URLs hardcoded outside the config file and `.env` files. Secrets are never printed in logs or output.
- The app does no rider-pay arithmetic. Money is displayed as the backend sends it, except the labelled estimate in FR-13. Cart and order totals are sums of item prices, not pay figures.
- Every screen that shows a pay number shows how it was derived, or links to the derivation.
- Customer and restaurant screens do not poll. They update on pull-to-refresh or on navigation.
- No NaN, Infinity or null-related crash on any screen when data is empty or tiny.

## 9. Fairwork Mapping (UI Evidence)

| Principle | UI evidence | Status |
|---|---|---|
| Fair Pay P1: earnings floor | Dashboard floor status (FR-32) | Implemented |
| Fair Pay P2: living wage | Floor value from config, shown on Dashboard | Implemented |
| Fair Conditions P1: safety onboarding | Onboarding checklist (FR-46) | P1 |
| Fair Conditions P2: downtime compensation | Zone change notice (FR-27); idle logic is backend | Documented |
| Fair Contracts P1: transparent policy | Onboarding and Profile policy view | P1 |
| Fair Contracts P2: 7-day notice and reason | Admin config form (FR-41, FR-42) and rider notice (FR-48) | P1 |
| Fair Management P1: delay challenge | Delay report and verified state (FR-19, FR-25) | Implemented, verification mocked |
| Fair Management P2: grievance | Grievance form (FR-50) | P2 |
| Fair Representation P1: feedback channel | Same form as above | P2 |
| Fair Representation P2: union recognition | None | Out of scope |

"Designed ≥ 8/10" must be presented honestly in the demo: say which principles have working UI, which are documented only, and which depend on P1/P2 work. In the demo the rider's hourly earnings will read very high because active hours are minutes, so the floor is shown as met; the floor top-up logic is covered by the pay-engine unit tests.

## 10. Demo

### 10.1 Setup

**Where it runs.** Everything runs on Hari's laptop: MySQL, pay-service, core-service (Atlas for MongoDB, so the laptop needs internet and the Atlas IP allowlist must allow the laptop), the Android emulator (rider only, stays logged in and online), and one physical phone (customer, restaurant and admin, switching by logging out and in) running the **installed release APK**.

**Transport (primary: USB `adb reverse`).** The phone is connected to the laptop by USB with USB debugging on. For the phone and the emulator, run `adb reverse tcp:3003 tcp:3003` and `adb reverse tcp:3001 tcp:3001` (per device with `-s`). The app uses host `127.0.0.1` on both devices, so one APK works for both and no network, Wi-Fi or IP is involved. Re-run the commands after any reconnect.

**Fallback transport (hotspot).** Laptop Windows Mobile Hotspot, host `192.168.137.1`: change the host constant in `app_config.dart`, rebuild the APK, reinstall. Windows Firewall must allow ports 3001 and 3003.

**Pre-flight checklist (written into `docs/DEMO_RUNBOOK.md`).** Both `/health` endpoints respond; `adb devices` lists both devices; both reverse rules are set; the installed APK logs in on the phone; the seed has been run on a clean database.

**Seed script (documented, idempotent, one command).** It prepares:

- The existing accounts (`john@fairdrop.in`, `priya@fairdrop.in` customers; `arun@fairdrop.in`, `marina@fairdrop.in` restaurants; `rider1..3@fairdrop.in`; `admin@fairdrop.in`) with the documented passwords. The seeded riders exist in **both** databases with matching ids, offline, one per zone.
- The three Kollam zones.
- Two restaurants with fixed locations verified by point-in-polygon: Hotel Arun inside `KLM-CHK`, Marina inside `KLM-PLY`.
- Menu items: Hotel Arun: Chicken Biryani ₹180 (40 s), Parotta ₹15 (20 s), Fish Curry Meal ₹120 (45 s). Marina: Veg Meals ₹90 (30 s), Masala Dosa ₹60 (25 s). All available.
- The baseline pay config with wait threshold **1 minute**, effective immediately. This is the one documented exception to the 7-day rule (FR-41); it appears first in config history. In the demo, say so: every later config goes through the 7-day rule.
- Two fixed drop-off pins recorded in the runbook with exact coordinates, both verified by script: **Pin A** inside `KLM-CHK` (in-zone) and **Pin B** inside `KLM-PLY`, within the out-of-zone cap of the `KLM-CHK` boundary (out-of-zone).

A new rider signing up on a clean seed lands in `KLM-CHK` (one rider per zone, tie goes to the lowest `zone_id`), the same zone as Hotel Arun.

### 10.2 Sequence

The demo passes if this sequence works with no manual database edits after the seed script has run:

1. **Emulator.** A new rider signs up (name, email, password, vehicle type). The backend assigns `KLM-CHK`, shown in the app. The rider goes through Onboarding (if built) and goes online.
2. **Phone.** The restaurant (Hotel Arun) logs in, adds a menu item with a preparation time in seconds, edits an item, and switches one item's availability off.
3. **Phone.** The restaurant logs out. The customer logs in and taps Pin A on the map. All restaurants are listed. The customer opens Hotel Arun's menu; the unavailable item cannot be added. The customer adds items to the cart.
4. **Phone.** The customer goes through the mock payment screen and places the order. The confirmation screen shows the order ID, restaurant, items and total.
5. **Backend.** The order is accepted automatically and allocated to the rider. It appears on the rider's Home within the polling interval.
6. **Emulator.** Order Acceptance shows the formula, the estimate, and the straight-line distance labelled as approximate. The rider accepts.
7. **Phone (optional).** The restaurant logs in and its Orders screen shows the order as accepted, then ready after pull-to-refresh once the longest item preparation time has elapsed.
8. **Emulator.** The rider taps "Arrived at Restaurant", waits until the wait exceeds 1 minute (the "Order ready" indicator is visible), then taps "Picked Up" and "Delivered".
9. **Emulator.** Delivery Summary shows a breakdown where wait compensation is non-zero and every line matches the pay-service response.
10. **Emulator.** Dashboard reflects the new delivery and floor status. Analytics shows the comparison, including the scenario where the cliff model wins.
11. **Phone and emulator.** A second order is placed with the drop-off at Pin B. Order Acceptance shows the out-of-zone badge, the distance beyond the boundary and the consent statement. After delivery, Zone Map shows the zone change to `KLM-PLY`.
12. **Phone.** The customer logs back in; Order History (if built) shows the orders as delivered after pull-to-refresh.
13. **Phone.** The admin logs in, sees the active config and the history (including the seeded baseline), and creates a new config. A date earlier than 7 days out is rejected; a valid one appears in history with its reason.
14. **Emulator.** The rider logs out and is shown as offline.

### 10.3 Cut order

If time runs short, cut by priority label: P2 first, then P1. P0 screens are not replaced. For a cut item only, a Postman screenshot of the corresponding API call is sufficient evidence.

### 10.4 Automated end-to-end check

`scripts/e2e-smoke.js` plays steps 1 to 13 over HTTP against the running services (using the seeded 1-minute wait threshold and short prep times) and must pass before the demo. It also asserts that a 6-day effective date is rejected and a valid one accepted.

## 11. Locked Decisions (formerly [TBC])

| # | Decision | Where |
|---|---|---|
| D1 | New rider zone = fewest riders, ties by lowest `zone_id` | FR-52 |
| D2 | Allocation matches by the restaurant's zone, falls back to any online rider, else unallocated | FR-68 |
| D3 | Out-of-zone = drop-off outside the rider's current zone; cap enforced; zone switches to the zone containing the drop-off | FR-73 |
| D4 | Cart holds one restaurant; no delivery fee line | FR-58, FR-59 |
| D5 | Menu item fields are only name, price, prep seconds, availability | FR-63 |
| D6 | No rider available: order stays unallocated, response shown as returned, allocated when a rider goes online | FR-60, FR-72 |
| D7 | Decline releases and reallocates, excluding the decliner | FR-15, FR-68 |
| D8 | Ready is derived at read time from the longest prep time | FR-69 |
| D9 | Distance is haversine, 2 decimals, computed in core-service | FR-70 |
| D10 | Wait is server-computed and rounded up to whole minutes before the pay call | FR-18 |
| D11 | Demo seed: wait threshold 1 minute, prep times 20 to 45 s, two restaurants in different zones, fixed Pin A and Pin B | Section 10.1 |
| D12 | MySQL `rider_id` = MongoDB `_id` string, created at signup, rolled back on failure | Section 6 |
| D13 | pay-service stays on port 3001 | Section 7 |
| D14 | Primary demo transport is USB `adb reverse` with host `127.0.0.1`; hotspot is the fallback | Section 10.1 |
