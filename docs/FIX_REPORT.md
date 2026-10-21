# FairDrop Defects Fix Report (Complete: Part 1 & Part 2)

**Date:** October 20, 2026  
**Audited Against:** `docs/FairDrop_Flutter_App_PRD_v2.1.md` and `docs/AUDIT_REPORT.md`  
**Base Tag:** `pre-audit` (`06711b4`)  
**Head Commit:** `064b38f` (before report update)  

---

## 1. Fix Summary Matrix

| Fix ID | Description | Status | Commit | Files Modified | Evidence & Verification |
| --- | --- | --- | --- | --- | --- |
| **F1** | Remove customer fees (delivery, platform, GST); total = item subtotal; simplify mock payment to single Place Order button (FR-59, D4) | **FIXED** | `2364a58` | `fairdrop_app/lib/services/cart_service.dart`<br>`fairdrop_app/lib/screens/customer/cart_screen.dart`<br>`fairdrop_app/lib/screens/customer/mock_payment_screen.dart`<br>`fairdrop_app/test/customer_flow_test.dart` | `flutter analyze`: No issues found;<br>`flutter test`: 99/99 passed;<br>Cart fee lines removed, subtotal ₹360 matches total ₹360 |
| **F2** | Idempotent duplicate `delivered` status calls (HTTP 200) & rider ownership check (HTTP 403) (FR-74) | **FIXED** | `09c2533` | `core-service/src/modules/orders/order.controller.js`<br>`core-service/tests/orders.test.js` | `core-service npm test`: 73/73 passed;<br>`npm run smoke`: 14/14 passed |
| **F3** | Register both `/health` and `/api/health` endpoints on pay-service | **FIXED** | `ca1bb67` | `pay-service/src/server.js` | `curl.exe http://localhost:3001/health`: HTTP 200 OK;<br>`curl.exe http://localhost:3001/api/health`: HTTP 200 OK;<br>`pay-service npm test`: 23/23 passed |
| **F4** | Fix timezone offset bug in 7-day advance notice rule date comparison and storage | **FIXED** | `b04b419` | `pay-service/src/routes/adminRoutes.js`<br>`pay-service/tests/payConfig.test.js` | `pay-service npm test`: 24/24 passed (today+6 -> 400, today+7 -> 200, today+8 -> 200 stored/returned match);<br>`npm run smoke`: 14/14 passed |
| **F5** | Bind state wage floor to pay config `min_wage_per_hour` (Kerala baseline ₹70/hr); remove hardcoded ₹150 fallback; hide text if unconfigured | **FIXED** | `8916103` | `fairdrop_app/lib/screens/rider_home_screen.dart` | `flutter analyze`: No issues found;<br>`flutter test`: 99/99 passed |
| **F6** | Update wait compensation label to indicate flat bonus instead of per-minute rate (`+₹<amount> flat bonus if restaurant wait exceeds <threshold> min`) | **FIXED** | `85d118d` | `fairdrop_app/lib/screens/order_acceptance_screen.dart` | `flutter analyze`: No issues found;<br>`flutter test`: 99/99 passed |
| **F7** | Remove fallback pay constants on order acceptance screen; gate accept button on `_hasValidPayConfig`; add retry button on error banner | **FIXED** | `9f2c014` | `fairdrop_app/lib/screens/order_acceptance_screen.dart` | `flutter analyze`: No issues found;<br>`flutter test`: 99/99 passed |
| **F8** | Remove fallback mock data on network error in rider dashboard & analytics screens; display error banner with Retry; guard division-by-zero for riders with 0 deliveries | **FIXED** | `c872c08` | `fairdrop_app/lib/screens/rider_dashboard_screen.dart`<br>`fairdrop_app/lib/screens/analytics_screen.dart`<br>`fairdrop_app/test/analytics_dashboard_test.dart` | `flutter analyze`: No issues found;<br>`flutter test`: 103/103 passed (4 new widget tests passing) |
| **F9** | Remove plaintext password in docs/Application_Guide.md; fix `items_total` log string in e2e-smoke.js; align docs/DEMO_RUNBOOK.md routes and fees | **FIXED** | `064b38f` | `docs/Application_Guide.md`<br>`scripts/e2e-smoke.js`<br>`docs/DEMO_RUNBOOK.md` | `npm run seed; npm run smoke`: 14/14 steps passed; `items_total` logged as ₹360; documentation aligned with PRD v2.1 |
| **F10** | Add local `minimumSize: Size.zero` to buttons in Rows & AlertDialogs; raise API timeouts to 8s with Retry banner; prevent layout exceptions at 360px & 393px (R3/R4/R5) | **FIXED** | `c2a2709` | `fairdrop_app/lib/screens/customer/restaurant_menu_screen.dart`<br>`fairdrop_app/lib/screens/customer/restaurant_list_screen.dart`<br>`fairdrop_app/lib/screens/restaurant/menu_management_screen.dart`<br>`fairdrop_app/lib/screens/admin_panel_screen.dart`<br>`fairdrop_app/lib/screens/profile_screen.dart`<br>`fairdrop_app/lib/screens/grievance_screen.dart`<br>`fairdrop_app/test/layout_responsive_test.dart` | `flutter analyze`: No issues found;<br>`flutter test test/layout_responsive_test.dart`: 8/8 passed;<br>`flutter test test/customer_flow_test.dart`: 7/7 passed;<br>Zero layout exceptions at 360px and 393px |
| **F11** | Safely parse String and Map delivery/restaurant addresses; prevent blank screen on data errors with Retry and Back buttons; trace full order lifecycle (R7) | **FIXED** | `7c14942` | `fairdrop_app/lib/models/order.dart`<br>`fairdrop_app/lib/screens/order_acceptance_screen.dart`<br>`fairdrop_app/lib/screens/rider_home_screen.dart`<br>`fairdrop_app/lib/screens/active_delivery_screen.dart`<br>`fairdrop_app/test/order_models_parsing_test.dart` | `flutter analyze`: No issues found;<br>`flutter test test/order_models_parsing_test.dart`: 9/9 passed;<br>`flutter test`: 120/120 passed;<br>Acceptance screen and rider home render clean data without blank screen; non-blank error views with Retry and Back |
| **F12** | Remove hardcoded Today's Shift card (₹685, 4.3h, ₹420, ₹95, ₹120, +₹50) and fake incoming offer card (countdown, Instant Match); display real backend stats and config rates with clean zeros for new rider; render offer card only when active pending offer exists (R1/R2) | **FIXED** | `3595881` | `fairdrop_app/lib/screens/rider_home_screen.dart`<br>`fairdrop_app/test/order_models_parsing_test.dart` | `flutter analyze`: No issues found;<br>`flutter test test/order_models_parsing_test.dart`: 10/10 passed;<br>Zero fabricated values; clean zeros for new rider; zero layout overflows on 360px & 393px viewports |
| **F13** | Replace cliff-bonus quota model and >80% failure claims with balanced illustrative Zomato ladder comparison, linear incentive formula `rate × n + peak_bonus`, interactive peak toggle, 0-30 orders cumulative chart, parity table, and break-even notes (R6) | **FIXED** | `591a61b` | `fairdrop_app/lib/screens/analytics_screen.dart`<br>`fairdrop_app/lib/utils/incentive_analytics.dart` (pre-declared constants helper)<br>`fairdrop_app/test/analytics_dashboard_test.dart` | `flutter analyze`: No issues found;<br>`flutter test test/analytics_dashboard_test.dart`: 10/10 passed;<br>Scope notice banner, peak toggle, parity table, and policy notes verified; `payEngine.js` formulas and backend contracts untouched |
| **F14** | Remove rogue call to admin-only `GET /api/admin/pay-config/history` from non-admin `profile_screen.dart`; retain authorized admin access in `AdminPanelScreen` (R8) | **FIXED** | `6c99184`<br>`311470a` | `fairdrop_app/lib/screens/profile_screen.dart`<br>`fairdrop_app/test/profile_screen_test.dart` (pre-declared) | Non-admin riders receive 0 HTTP 403 Forbidden errors;<br>`flutter test test/layout_responsive_test.dart test/admin_panel_test.dart test/profile_screen_test.dart`: all 16 tests passed |

---

## 2. Tests Added and Updated

1. **`fairdrop_app/test/customer_flow_test.dart` (F1):**
   - Updated cart calculations tests to assert customer delivery fee is ₹0, platform fee is ₹0, GST is ₹0, and total equals items subtotal per PRD FR-59 (asserted old wrong fee behaviour).
2. **`core-service/tests/orders.test.js` (F2):**
   - Added test: `PUT /api/orders/:id/status should return 200 idempotent for duplicate delivered status`.
   - Added test: `PUT /api/orders/:id/status should reject delivery update from unauthorized rider (403)`.
3. **`pay-service/tests/payConfig.test.js` (F4):**
   - Added test: `POST /api/admin/pay-config should accept effective_from date 8 days ahead (>= 7 days in local time) and return stored date`.
4. **`fairdrop_app/test/analytics_dashboard_test.dart` (F8, F13):**
   - Added widget test: `RiderDashboardScreen shows error banner with retry button on failure without mock numbers`.
   - Added widget test: `AnalyticsScreen shows error banner with retry button on failure without mock numbers`.
   - Added widget test: `RiderDashboardScreen displays clean zeros for new rider with 0 deliveries`.
   - Added widget test: `AnalyticsScreen displays clean zeros for new rider with 0 deliveries`.
   - Added widget test: `AnalyticsScreen renders scope notice, comparative chart, and benchmark metrics (FR-34)`.
   - Added widget test: `AnalyticsScreen renders stated model parameters, peak toggle, and parity table (FR-35, FR-36)`.
   - Added widget test: `AnalyticsScreen renders policy notes and transparency criteria without fabricated claims (FR-36)`.
5. **`fairdrop_app/test/layout_responsive_test.dart` (F10):**
   - Added responsive widget test for `RestaurantMenuScreen` at 360px & 393px width (verifies 1-line price, visible ADD button, sticky cart VIEW CART button without layout exception).
   - Added responsive widget test for `MenuManagementScreen` at 360px & 393px width (verifies 1-line heading and ADD ITEM button).
   - Added responsive widget test for AlertDialog action buttons with `minimumSize: Size.zero` in `AdminPanelScreen`, `ProfileScreen`, and `GrievanceScreen`.
   - Added widget test for `RestaurantListScreen` 8s timeout and error banner with Retry button.
   - Added widget test for `RestaurantMenuScreen` 8s timeout and error banner with Retry button.
6. **`fairdrop_app/test/order_models_parsing_test.dart` (F11, F12):**
   - Added unit test: `OrderAddress.fromJson` parses Map with label, latitude, longitude.
   - Added unit test: `OrderAddress.fromJson` safely parses raw String `"Kadappakkada Junction"`.
   - Added unit test: `OrderAddress.fromJson` safely handles null and empty map.
   - Added unit test: `Order.fromJson` parses real core-service API order payload with nested address objects.
   - Added unit test: `Order.fromJson` parses payload with string `delivery_address` without `TypeError`.
   - Added widget test: `OrderAcceptanceScreen` renders real API order without exceptions or layout overflow.
   - Added widget test: `OrderAcceptanceScreen` renders string `delivery_address` without `TypeError`.
   - Added widget test: `OrderAcceptanceScreen` renders non-blank error state with Retry and Back buttons on data error.
   - Added widget test: `RiderHomeScreen` renders non-blank error state with Retry and Back buttons on data error.
   - Added widget test: `RiderHomeScreen displays real zeros for new rider and hides offer card when no order is pending (F12)`.
7. **`fairdrop_app/test/profile_screen_test.dart` (F14):**
   - Dynamic 7-day future timestamp calculation to prevent timezone/midnight rollover test flakiness while asserting 7-day notice banner.

### Root Cause Analysis: Blank Screen on Physical Android Phone vs. Chrome (R3/R4/R5)

1. **Unbounded Flex Constraints from Global Theme**: In `lib/config/theme.dart`, `filledButtonTheme` specified `minimumSize: const Size.fromHeight(52)` and `outlinedButtonTheme` specified `minimumSize: const Size.fromHeight(48)`. In Flutter, `Size.fromHeight(h)` evaluates to `Size(double.infinity, h)`. When buttons were used inside unconstrained horizontal flex layouts (`Row` or `AlertDialog.actions`), the buttons demanded infinite width, causing Flutter's layout engine to throw an unhandled assertion exception (`BoxConstraints forces an infinite width`).
2. **Platform Difference (Android Release/Profile vs. Chrome Web)**: On a physical Android device in profile/release mode, an unhandled layout assertion in a widget subtree causes Flutter's release `ErrorWidget` to render a blank grey/white screen, aborting the rendering pipeline. In Chrome (desktop browser), developers/testers ran at wide viewports (1200px+) and widget unit tests in `customer_flow_test.dart` instantiated `MaterialApp` without the app's `FairDropTheme.lightTheme`, completely masking the infinite width theme constraint.
3. **Wi-Fi Network Timeout & Silent Mock Fallback**: In `restaurant_menu_screen.dart` (~L83) and `restaurant_list_screen.dart` (~L77), HTTP calls used a 1-second timeout. Over physical Wi-Fi, network latency routinely exceeded 1.0s, triggering immediate timeouts. The code caught the error and silently loaded hardcoded static fallback items, which then immediately hit the infinite-width button layout crash.

### Root Cause Analysis: TypeError "Kadappakkada Junction" & Rider Accept Blank Screen (F11 / R7)

1. **Source of Value & Unsafe Type Cast**: In `rider_home_screen.dart` (~L169), the fallback argument object passed `'delivery_address': 'Kadappakkada Junction'` as a raw `String`. In `order_acceptance_screen.dart` (~L235), `(_order?['delivery_address'] as Map<String, dynamic>?)?['area']` attempted a direct cast of `String` to `Map<String, dynamic>?`, throwing `TypeError: "Kadappakkada Junction": type 'String' is not a subtype of type 'Map<String, dynamic>?'`. Furthermore, in `order.dart`, `OrderAddress.fromJson(Map<String, dynamic> json)` threw a runtime cast exception whenever an order payload contained a string address.
2. **Backend Response Shape Consistency**: Cross-examination of `core-service/src/modules/orders/order.controller.js` verified that `POST /api/orders` and `GET /api/orders/rider/active` consistently return `delivery_address: { label: string, latitude: number, longitude: number }` and `restaurant_address: { label: string, latitude: number, longitude: number }`. There is no schema inconsistency between backend endpoints; the bug was strictly triggered by client-side fallback/mock arguments and unsafe type-casting in Dart.
3. **Blank Screen Failure Mode**: When unhandled Dart exceptions occur inside a widget's `build()` method, Flutter renders a blank grey error container in release/profile mode. Added explicit error state handling with Retry and Back buttons (`btn_retry_acceptance`, `btn_back_acceptance`, `btn_retry_rider_home`, `btn_back_rider_home`) so malformed data never produces a blank screen.
4. **Additional Files Touched**: `fairdrop_app/lib/screens/active_delivery_screen.dart` was modified to also utilize safe address parsing (`_extractAddress`), preventing an identical `TypeError` crash when the rider accepts the order and transitions to the active delivery tracker.

### Root Cause Analysis: Hardcoded Shift Card and Fake Offer Card on Rider Home (F12 / R1/R2)

1. **Fabricated Shift and Offer Mock Data**: `rider_home_screen.dart` had static fallback variables initialized with mock values (`_todayEarnings = 685.0`, `_activeHoursToday = 4.3`, etc.) and rendered a hardcoded "Today's Shift" card with fake breakdown lines (`₹420`, `₹95`, `₹120`, `+₹50`). In addition, it rendered a hardcoded "Instant Match" offer card with a self-looping local countdown timer even when no order existed on the server.
2. **Narrow Viewport Layout Overflows**: On 360px and 393px mobile screens, unconstrained horizontal rows in the live status strip and shift breakdown card overflowed by 20–56px.
3. **Remediation**:
   - Initialized shift statistics strictly to clean zeros (`_todayEarnings = 0.0`, `_activeHoursToday = 0.0`, `_hourlyRate = 0.0`, `_deliveriesToday = 0`).
   - Dynamically bound all rate cards to pay config (`_baseRate`, `_perKmRate`, `_waitCompensation`, `_waitThresholdMins`, `_surgeBonus`).
   - Rendered the offer card conditionally ONLY when `_isOnline && _incomingOrder != null` with the real backend order details and dynamic payout calculation.
   - Wrapped horizontal header rows and shift breakdown chips in `Expanded`, `Flexible`, and `FittedBox` to completely prevent RenderFlex overflows on mobile viewports.

### Root Cause Analysis: Pay Analytics Balanced Framing and Incentive Calculation (F13 / R6)

1. **Unbalanced Framing and Unsourced Claims**: The original analytics screen presented an artificial 10-delivery / ₹500 "cliff quota trap" model with an unsourced assertion that "over 80% of shifts fail quota".
2. **Illustrative Benchmark Alignment**:
   - Replaced the cliff model with the single-source Zomato incentive ladder (28 Jun screenshot benchmark: 19 orders = ₹306, 23 = ₹383, 25 = ₹434, 27 = ₹510), clearly labeled as an "illustrative example".
   - Implemented FairDrop linear incentive calculation: `incentive(n) = rate × n + peak_bonus`, where `rate = (510 - 50) / 27 ≈ ₹17.04/order` and `peak_bonus = ₹25 × 2 = ₹50`.
   - Added an interactive toggle for peak windows covered (`Key('switch_peak_windows')`).
   - Explicitly documented on screen that base pay, distance pay, monsoon, and return pay are identical on both platforms; this analysis compares daily incentives only.
   - Built an interactive cumulative chart (0–30 orders) showing the Zomato step line, FairDrop with peak, and FairDrop without peak.
   - Built a parity table (`Key('parity_table_card')`) displaying orders needed to match benchmark tiers (With peak: 16, 20, 23, 27; Without peak: 18, 23, 26, 30), highlighting equal pay at 27 orders (₹510 FairDrop = ₹510 Zomato).
   - Displayed mandatory policy notes: peak bonus assumes online presence in both windows; rates vary by day; platform break-even rate = expected incentive spend ÷ expected orders per rider.
3. **Architectural Separation**: Implemented purely in a client-side helper (`fairdrop_app/lib/utils/incentive_analytics.dart`) and `analytics_screen.dart` without modifying backend `payEngine.js` formulas or the `/api/pay/calculate` contract.

### Root Cause Analysis: HTTP 403 Forbidden on GET /api/admin/pay-config/history (F14 / R8)

1. **Endpoint Authorization**: In `pay-service/src/routes/adminRoutes.js`, `GET /api/admin/pay-config/history` is guarded by `verifyToken` and `requireRole('admin')`.
2. **Caller Identification**:
   - `fairdrop_app/lib/screens/admin_panel_screen.dart` calls `ApiService.getConfigHistory()`. When accessed by an admin, the JWT has role `admin` and succeeds with HTTP 200.
   - In `fairdrop_app/lib/screens/profile_screen.dart` (~L71), `_loadProfile()` called `ApiService.getConfigHistory()` as a fallback when looking for scheduled config changes if `configData['scheduled']` was null.
   - Because `profile_screen.dart` is the rider's personal profile screen, sending a rider token triggered `HTTP 403 Forbidden` (`Access denied. Required role: admin`) on `pay-service` during every profile load.
3. **Remediation**:
   - Removed the unauthorized fallback call to `ApiService.getConfigHistory()` from `profile_screen.dart`.
   - `ApiService.getPayConfig()` already returns `{ scheduled: ... }` if an upcoming scheduled change exists and is fully authorized for riders (FR-48/FR-75). If `configData['scheduled']` is null, there is simply no upcoming change.
   - Pre-declared test update in `fairdrop_app/test/profile_screen_test.dart` to use dynamic future timestamp, preventing midnight rollover test flakiness.

---

## 3. Full Gate Verification Results

| Check | Result | Exact Summary Line |
| --- | --- | --- |
| **core-service: npm test** | **PASS** | `ℹ tests 73 \| ℹ suites 21 \| ℹ pass 73 \| ℹ fail 0 \| ℹ cancelled 0 \| ℹ skipped 0 \| ℹ todo 0 \| ℹ duration_ms 33719.4828` |
| **pay-service: npm test** | **PASS** | `ℹ tests 24 \| ℹ suites 8 \| ℹ pass 24 \| ℹ fail 0 \| ℹ cancelled 0 \| ℹ skipped 0 \| ℹ todo 0 \| ℹ duration_ms 6548.7008` |
| **root: npm run seed; npm run smoke** | **PASS** | `✔ ALL 14 DEMO FLOW STEPS PASSED SUCCESSFULLY (8.47s)` |
| **app: flutter analyze** | **PASS** | `No issues found! (ran in 5.7s)` |
| **app: flutter test** | **PASS** | `00:30 +121: All tests passed!` |
| **app: flutter build web** | **PASS** | `√ Built build\web (97.4s)` |

---

## 4. Git Commit History (`pre-audit..HEAD`)

```text
311470a test(profile): use dynamic future timestamp for 7-day notice banner test (AUDIT-F14)
6c99184 fix(auth): remove unauthorized pay-config history call from rider profile (AUDIT-F14)
591a61b fix(analytics): implement balanced zomato incentive ladder comparison and parity table (AUDIT-F13)
53d473b docs(prd): expand FR-36 on 5.8 Analytics with balanced incentive requirements
3595881 fix(rider): remove hardcoded shift card and fake offer card from rider home (AUDIT-F12)
dae5fa5 docs(prd): update FR-34 to FR-36 in 5.8 Analytics for balanced incentive comparison
7d6dced docs: update Part A gate results in FIX_REPORT.md
48fb160 docs: record F11 findings, verification evidence, and commit hash
7c14942 fix(rider): handle string and map delivery address and add error states with retry/back (AUDIT-F11)
643c5ee docs: update F10 commit hash in FIX_REPORT.md
c2a2709 fix(ui): add minimumSize zero to buttons in rows, raise timeouts to 8s and fix responsive layouts (AUDIT-F10)
cf084c4 docs: update fix report with complete fixes and full gate verification
064b38f fix(docs): align demo runbook and documentation with PRD and actual code (AUDIT-F9)
c872c08 fix(rider): show error banner with retry instead of sample data and handle zero deliveries (AUDIT-F8)
9f2c014 fix(rider): remove acceptance constants fallback and add retry on error (AUDIT-F7)
7b02b8f docs: add audit report and part 1 fix report
85d118d fix(rider): label wait compensation as flat bonus rather than per-minute rate (AUDIT-F6)
8916103 fix(rider): bind state wage floor to pay config and remove hardcoded 150 fallback (AUDIT-F5)
b04b419 fix(pay-service): fix timezone bug in 7-day rule date comparison and storage (AUDIT-F4)
ca1bb67 fix(pay-service): register both /health and /api/health endpoints (AUDIT-F3)
09c2533 fix(orders): make duplicate delivered calls idempotent and enforce rider ownership (AUDIT-F2)
2364a58 fix(customer): remove customer fees and simplify mock payment (AUDIT-F1)
```

---

## Live Rehearsal Fix: Rider Order Dispatch & Zone Map Accessibility

### Root Causes

1. **Order Allocation Desync**:
   - `_RiderHomeScreenState` in Flutter hardcoded `_isOnline = true` in Dart state while the database defaulted to `rider_profile.is_online = false`. When the user logged in, the screen displayed "• Online", but MongoDB treated the rider as offline. Orders placed by customers received `allocation: 'no_rider_available'` with `rider_id = null`.
   - When an unallocated queued order was waiting, `GET /api/orders/rider/active` only checked `{ rider_id: req.user.id }` and never evaluated unallocated orders for idle online riders.
   - When orders in progress were in status `assigned`, `arrived`, or `picked_up`, `RiderHomeScreen` displayed a 45-second countdown timer that vanished after 45s, leaving the rider unable to resume and complete the delivery, keeping them forever busy.
2. **Customer "Orders" Button in Rider Bottom Nav**:
   - `BottomNavigationBar` in `RiderHomeScreen` included an `Orders` button targeting `/orders` (the customer ordering screen).
3. **Zone Map Inaccessible After Rider Login**:
   - `/zone-map` was not directly accessible from the bottom navigation or the top header badge.

### Fixes Applied

1. **`fairdrop_app/lib/screens/rider_home_screen.dart`**:
   - In `_loadStats()`, synchronized `_isOnline` with `stats['is_online']` and automatically activated `CoreApiService.setRiderStatus(isOnline: true)` upon entering the active shift.
   - Replaced customer `Orders` item in `BottomNavigationBar` with `Zone Map` (`Icons.map_rounded`, route `/zone-map`).
   - Made the top header Zone Badge (`KL-02` and `_currentZone`) clickable to open `/zone-map` on tap.
   - Added a "View Kollam Zone Map & Boundaries" button in `_buildFairnessGovernanceCard()`.
   - Added `_buildOrderDispatchWidget()` with `_buildActiveDeliveryBanner()` to display active deliveries in progress (`assigned`, `arrived`, `picked_up`) with a "Resume Delivery & Update Status" button leading to `/active-delivery`.
2. **`core-service/src/modules/orders/order.controller.js`**:
   - In `getRiderActiveOrder`: If an online rider has no active order, automatically evaluates pending unallocated orders and allocates queued orders to the eligible rider (FR-60, FR-72, D6).
   - In `updateOrderStatus`: When `new_status === 'delivered'`, automatically evaluates and allocates queued pending orders to available riders.

### Verification Gate Results

| Check | Result | Exact Summary Line |
| --- | --- | --- |
| `core-service: npm test` | **PASS** | `ℹ tests 73 | ℹ suites 21 | ℹ pass 73 | ℹ fail 0 | ℹ duration_ms 57959.6732` |
| `pay-service: npm test` | **PASS** | `ℹ tests 24 | ℹ suites 8 | ℹ pass 24 | ℹ fail 0 | ℹ duration_ms 25014.7686` |
| `Master Seed & Smoke Test` | **PASS** | `✔ ALL 14 DEMO FLOW STEPS PASSED SUCCESSFULLY (10.34s)` |
| `fairdrop_app: flutter analyze` | **PASS** | `No issues found! (ran in 42.1s)` |
| `fairdrop_app: flutter test` | **PASS** | `01:01 +121: All tests passed!` |
| `fairdrop_app: flutter build web` | **PASS** | `√ Built build\web` |

---

## F15: Single Source of Truth for Payout Figures (AUDIT-F15 / R9, R12, R13, R14)

### Payout Figures Source Matrix

| Screen / Card | Payout Figure / Metric | Authoritative Source | Prior Defect / Root Cause | F15 Single-Source-of-Truth Fix |
| --- | --- | --- | --- | --- |
| **Home shift card** (`RiderHomeScreen`) | Total shift pay & itemized rows | `GET /api/riders/stats` (`today_earnings`, `base_pay_today`, `distance_pay_today`, `wait_pay_today`, `surge_pay_today`, `floor_topup_today`) | Placed entire payout under single line "Base Pay & Distance" with rogue "+₹199 buffer" | Split into individual itemized breakdown lines from backend stats; removed rogue "+₹199 buffer". |
| **Home shift card** (`RiderHomeScreen`) | Deliveries count & grammar | `GET /api/riders/stats` (`deliveries_today`) | Grammatical defect: `"1 drops"` | Fixed grammar: `"${_deliveriesToday} ${_deliveriesToday == 1 ? 'drop' : 'drops'}"` |
| **Active Delivery meter** (`ActiveDeliveryScreen`) | Estimated delivery pay | `ApiService.getPayConfig()` + distance formula | Defaulted base rate to ₹30.00; wait comp added ₹2/min continuously; labeled "DELIVERY EARNINGS METER" with "guaranteed min" | Dynamic `_baseRate` from pay-service config (₹15.00); flat wait comp (flat ₹10.00 bonus strictly after wait > 60s threshold, 55s = ₹0); labeled "Estimated delivery pay" (no "guaranteed min"). |
| **Delivery Completed** (`PayBreakdownScreen`) | Total Delivery Pay & Itemized Ledger | `GET /api/orders/:id` (`order.pay_calculation` / `/api/pay/calculate`) | Lines were out of visual summing order; no server verification indicator | Reordered ledger lines so lines 1–4 (Base + Distance + Surge + Wait) visually precede and sum to Line 5 (Total Delivery Pay); added `VERIFIED` badge for live server response, `CACHED` (with interactive Retry) for fallback. |
| **Rider Dashboard** (`RiderDashboardScreen`) | Total earnings, Deliveries, Avg Hourly | `GET /api/riders/stats` & `GET /api/pay/ledger/rider/:id` | Stray `4.3 hrs` constant; computed local figures | Bind to backend stats/ledger; shows "—" when engaged time is 0. |

### Root Causes & Fixes Applied

1. **Active Delivery Screen Defaults & Wait Logic (R9, R12)**:
   - Root Cause: `active_delivery_screen.dart` initialized `_baseRate = 30.0` and computed wait comp as `_elapsedWaitMins * 2.0`.
   - Fix: Bound base rate to `ApiService.getPayConfig()`, defaulting to ₹15.00. Wait compensation is flat ₹10.00 only after exceeding wait threshold (60s), ensuring 55s wait earns ₹0.00. Renamed header to "Estimated delivery pay" without "guaranteed min". Wrapped pay text in `FittedBox` to prevent 80px RenderFlex overflow at 393px.
2. **Rider Home Shift Card Grammar & Ledger Breakdown (R13)**:
   - Root Cause: `rider_home_screen.dart` dumped total pay into "Base Pay & Distance" with an unexplained `"(+₹199 buffer)"` string, and formatted grammar as `"${_deliveriesToday} drops"` even when `_deliveriesToday == 1`.
   - Fix: Updated `core-service/src/modules/riders/rider.controller.js` to return breakdown metrics (`base_pay_today`, `distance_pay_today`, `wait_pay_today`, `surge_pay_today`, `floor_topup_today`). Split the shift card into distinct rows. Fixed grammar to `"1 drop"`. Removed `(+₹199 buffer)`.
3. **Pay Breakdown Screen Visual Sum Order & Verification Badge (R14)**:
   - Root Cause: In `pay_breakdown_screen.dart`, Total Delivery Pay was placed before Wait Time, confusing visual summation, and lacked an authoritative badge distinguishing live server calculation from fallback estimates.
   - Fix: Reordered lines so Base, Distance, Surge, and Wait Comp visually precede and sum to Total Delivery Pay. Added a green `VERIFIED` badge when payload originates from the pay-service server, and an amber `CACHED` badge with an interactive `Retry` button on network error/fallback.

### Files Modified

- `core-service/src/modules/riders/rider.controller.js`
- `fairdrop_app/lib/screens/rider_home_screen.dart`
- `fairdrop_app/lib/screens/active_delivery_screen.dart`
- `fairdrop_app/lib/screens/pay_breakdown_screen.dart`
- `fairdrop_app/test/f15_payout_sources_test.dart`
- `docs/FIX_REPORT.md`

### Verification Evidence

- `core-service npm test`: 73/73 tests passed.
- `fairdrop_app flutter analyze`: No issues found!
- `fairdrop_app flutter test`: 125/125 tests passed (including 4 new widget tests in `f15_payout_sources_test.dart` asserting zero layout exceptions at 393px width).

---

## F16: Statutory Floor Top-Up Redesign (AUDIT-F16 / R10, R11)

### Root Causes

1. **Per-Delivery Ledger Distortion**: Prior to F16, statutory wage floor top-up was embedded inside the itemized per-delivery ledger (7th line item), conflating instantaneous order payouts with shift-level hourly wage guarantees.
2. **Lack of Cumulative Engaged-Time Block Evaluation**: The statutory minimum wage floor (Kerala baseline ₹70/hr, `min_wage_per_hour`) was not evaluated across cumulative engaged time (order assigned/accepted to delivered). Idle online time was improperly conflated, and strong hours were allowed to arbitrarily offset weak hours.
3. **Stray Hardcoded Dashboard Constant**: In `rider_dashboard_screen.dart:57`, active hours was hardcoded as `double get _activeHours => _totalDeliveries > 0 ? 4.25 : 0.0;`, producing a static `"4.3 hrs active"` metric regardless of actual delivery timestamps.

### Architectural Redesign & Policy Implementation

1. **Cumulative Engaged-Time Block Evaluation (`evaluateFloorBlocks`)**:
   - Engaged time is strictly measured as the duration between order assignment/acceptance (`assigned_at`) and delivery completion (`delivered_at`). Idle waiting for dispatches does not count towards engaged time.
   - Cumulative engaged minutes accumulate across orders throughout the shift date.
   - A delivery belongs to the block in which it ends on the cumulative engaged timeline.
   - Floor top-up for a completed block = `max(0, floor − delivery pay in that block)`.
   - Each completed block is evaluated independently: a high-earning block (e.g. ₹120) does not offset or reduce top-up for a subsequent weak block (e.g. ₹30 with ₹70 floor = ₹40 top-up).
   - Leftover engaged minutes (< 60 minutes) carry over to subsequent orders; no pro-rata top-up at shift end.
2. **6-Line Delivery Ledger & Decoupled Floor Record**:
   - Individual delivery ledgers are reduced from 7 lines to 6 lines: Base Rate, Distance Pay, Surge Bonus, Wait Compensation, Total Delivery Pay, Effective Hourly Rate So Far.
   - Floor top-up records are stored in a dedicated MySQL table `floor_topups` with unique constraint `uq_rider_date_block (rider_id, shift_date, block_index)`, guaranteeing absolute idempotency.
   - Floor top-ups are rendered on Home and Dashboard summary metrics, never inside individual delivery breakdowns.
3. **Engaged Hours Transparency**:
   - Home "active" time, dashboard average hourly rate, and effective hourly rate are computed strictly from real cumulative engaged hours.
   - When engaged time is 0, screens render `" — "` instead of `"₹0.0/hr"` or fabricated hours.
   - Stray `"4.3 hrs"` constant completely eradicated from `RiderDashboardScreen`.
   - Order 0001 label `"Hourly statutory minimum met"` updated to `"Floor evaluated after 60 min on orders"`.
4. **Demo Acceleration Override (`FLOOR_WINDOW_MINUTES_OVERRIDE`)**:
   - Added `floor_window_minutes` to `pay_configs` table (default: 60).
   - Supported environment variable override `FLOOR_WINDOW_MINUTES_OVERRIDE` in `payRoutes.js` for rapid evaluation testing during live demonstrations without bypassing the 7-day advance notice requirement (`PUT /api/admin/pay-config`). Documented in `docs/DEMO_RUNBOOK.md`.

### Tests Updated and Added

- **`pay-service/tests/payEngine.test.js`**:
  - Asserted `floor_topup === 0` in per-delivery `calculatePay` (delivery ledger has 6 lines).
  - Added 5 required tests for `evaluateFloorBlocks`:
    - 59 min engaged → no top-up.
    - 60 min with ₹29.80 delivery pay → ₹40.20 top-up.
    - Block 1 ₹120 + Block 2 ₹30 → ₹40.00 top-up (no offset).
    - 100 min engaged → 1 block evaluated, 40 min carried.
    - Idempotent re-running: MySQL floor top-up upsert never duplicates records.
- **`fairdrop_app/test/pay_breakdown_test.dart`**: Updated from 7 lines to 6 lines, removing Floor Top-Up from delivery ledger and asserting `"Floor evaluated after 60 min on orders"`.
- **`fairdrop_app/test/analytics_dashboard_test.dart`**: Removed `breakdown_floor_topup_$order1` assertion from per-delivery ledger, and asserted `" — "` when engaged hours are 0.
- **`fairdrop_app/test/f15_payout_sources_test.dart`**: Updated delivery ledger assertions from 7 lines to 6 lines, ensuring `Floor Top-Up` is absent from individual delivery breakdowns.
- **`fairdrop_app/test/order_models_parsing_test.dart`**: Updated new rider shift active time expectation to `" — active in Kollam"` per F16 specification.
- **`fairdrop_app/test/f16_floor_redesign_test.dart`**: Added widget tests for all 3 touched screens (`PayBreakdownScreen`, `RiderDashboardScreen`, `RiderHomeScreen`) at 393px width with 0 layout exceptions.

### Files Modified

- `database/mysql/schema.sql`
- `scripts/seed.js`
- `pay-service/src/payEngine.js`
- `pay-service/src/routes/payRoutes.js`
- `pay-service/tests/payEngine.test.js`
- `core-service/src/modules/orders/Order.model.js`
- `core-service/src/modules/orders/order.controller.js`
- `core-service/src/modules/orders/payClient.js`
- `core-service/src/modules/riders/rider.controller.js`
- `fairdrop_app/lib/screens/pay_breakdown_screen.dart`
- `fairdrop_app/lib/screens/rider_dashboard_screen.dart`
- `fairdrop_app/lib/screens/rider_home_screen.dart`
- `fairdrop_app/test/pay_breakdown_test.dart`
- `fairdrop_app/test/analytics_dashboard_test.dart`
- `fairdrop_app/test/f15_payout_sources_test.dart`
- `fairdrop_app/test/order_models_parsing_test.dart`
- `fairdrop_app/test/f16_floor_redesign_test.dart`
- `docs/DEMO_RUNBOOK.md`
- `docs/FIX_REPORT.md`

### Verification Evidence

- `core-service npm test`: 73/73 tests passed.
- `pay-service npm test`: 29/29 tests passed.
- `fairdrop_app flutter analyze`: No issues found!
- `fairdrop_app flutter test`: 128/128 tests passed.

---

## F22: Delay Flow Enum Alignment & Delivery Failure Safety (AUDIT-F22)

### 1. Delay Field Tracing Across Layers Matrix

| Layer | Field Name | Allowed / Accepted Values | What Callers Send | Defect / Failure Mode |
| --- | --- | --- | --- | --- |
| **Flutter App** (`active_delivery_screen.dart`, `order.dart`) | `delay_type` (alias: `type`) | `'traffic'`, `'restaurant'`, `'railway'`, `'weather'`, `'none'` | Dialog options: `'traffic'`, `'restaurant'`, `'railway'`, `'weather'` | Allowed `'weather'`, but backend didn't accept it. |
| **Flutter App** (`active_delivery_screen.dart`, `order.dart`) | `source` (alias: `delay_source`) | `'rider_report'`, `'system_log'`, `'api_mock'`, `'none'` | Hardcoded: `'rider_report'` | Mongoose threw validation error; MySQL truncated and threw 500. |
| **core-service Mongoose** (`Order.model.js`) | `delay_context.delay_type` | Prior: `['traffic', 'restaurant', 'railway', 'none']`<br>Fixed: `['traffic', 'restaurant', 'railway', 'weather', 'none']` | Sent by app via `delay_context.delay_type` or `delay_type` | Rejected `'weather'` with Mongoose ValidationError. |
| **core-service Mongoose** (`Order.model.js`) | `delay_context.source` | Prior: `['gps', 'manual', 'sensor', 'system', 'none']`<br>Fixed: `['rider_report', 'system_log', 'api_mock', 'none']` | Sent by app as `'rider_report'` | Threw `Order validation failed: delay_context.source: 'rider_report' is not a valid enum value`. |
| **core-to-pay Request** (`payClient.js` / `order.controller.js`) | `delay_type`, `delay_source`, `delay_minutes`, `wait_time_minutes` | Transmits `order.delay_context` values directly | Transmitted `delay_source: 'rider_report'`, `delay_type` | Passed values down into `pay-service`. |
| **pay-service Validation** (`payEngine.js`) | `delay_type`, `delay_source` | Prior: `delay_source` required `['gps', 'manual', 'sensor', 'system', 'none']`<br>Fixed: `['rider_report', 'system_log', 'api_mock', 'none']` | Received `delay_source: 'rider_report'` | Threw validation error: `"Invalid delay_source: rider_report"`. |
| **MySQL Table** (`deliveries` table) | `delay_type`, `delay_source` | Prior: `delay_source ENUM('gps','manual','sensor','system','none')`<br>Fixed: `ENUM('rider_report','system_log','api_mock','none')` | Inserted from calculation payload | Threw `Data truncated for column 'delay_source'` (MySQL Error 1265) under strict SQL mode. |

### 2. Comprehensive Field Cross-Layer Comparison (core-service to pay-service)

| Payload Field | core-service Type & Value Source | pay-service Validation | MySQL Column Type | Compatibility Status |
| --- | --- | --- | --- | --- |
| `order_id` | String (`String(order._id)`) | Non-empty string/number | `VARCHAR(64) PRIMARY KEY` | Compatible |
| `rider_id` | String (`String(rider.rider_id \|\| rider._id)`) | Non-empty string/number | `VARCHAR(64) NOT NULL` | Compatible |
| `restaurant_id` | String (`String(order.restaurant_id)`) | String/number | `VARCHAR(64) NULL` | Compatible |
| `zone_id` | String (`order.zone_id \|\| 'KLM-CHK'`) | String | `VARCHAR(32) NOT NULL DEFAULT 'KLM-CHK'` | Compatible |
| `distance_km` | Number (`order.pricing?.delivery_distance_km \|\| 0`) | Number >= 0 | `DECIMAL(6,2) NOT NULL` | Compatible |
| `pickup_lat` / `pickup_lng` | Number or null | Optional coordinate | Memory / calculation | Compatible |
| `drop_lat` / `drop_lng` | Number or null | Optional coordinate | Memory / calculation | Compatible |
| `assigned_at` | ISO Date String or null | Optional Date parseable | `TIMESTAMP NULL` | Compatible |
| `delivered_at` | ISO Date String or null | Optional Date parseable | `TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP` | Compatible |
| `wait_time_minutes` | Number (`delay_context?.wait_time_minutes \|\| 0`) | Number >= 0 | `INT NOT NULL DEFAULT 0` | Compatible |
| `delay_type` | String (`delay_context?.delay_type \|\| 'none'`) | `VALID_DELAY_TYPES` | `ENUM('traffic','restaurant','railway','weather','none')` | **Fixed & Aligned** |
| `delay_source` | String (`delay_context?.source \|\| 'none'`) | `VALID_DELAY_SOURCES` | `ENUM('rider_report','system_log','api_mock','none')` | **Fixed & Aligned** |
| `delay_minutes` | Number (`delay_context?.delay_minutes \|\| 0`) | Number >= 0 | `INT NOT NULL DEFAULT 0` | Compatible |

### 3. Failure Safety & Rollback Implementation

- In `core-service/src/modules/orders/order.controller.js`:
  - When `new_status === 'delivered'`, pay calculation is executed before committing status.
  - If `calculatePay(order, rider)` throws (e.g. pay-service unavailable, returns 500, or network drops), the catch block preserves the order at its prior state:
    - Retains previous status (`order.status = previousStatus`, e.g. `picked_up`).
    - Resets `order.delivered_at = null`.
    - Does NOT commit delivery to database.
    - Does NOT trigger out-of-zone zone relocation or unallocated queue evaluation.
    - Returns HTTP 502 with clear error: `Pay calculation failed: <message>. Order status remains ${previousStatus}. Please retry delivery.`
  - When retry request arrives later, `delivered_at` is recalculated, `calculatePay` succeeds, status transitions to `delivered`, and subsequent duplicate requests return HTTP 200 idempotent per F2.

### 4. Verification Evidence

- `pay-service npm test`: 33/33 tests passed (validates canonical delay types/sources, rejects unknown source with 400, validates MySQL persistence for all delay reasons without data truncation).
- `core-service npm test`: 76/76 tests passed (validates 400 on unknown delay source, validates report delay for each reason -> deliver -> pay computed with delay reason preserved, validates simulated pay failure keeping order at picked_up with 502 and subsequent retry succeeding with 200).
- `fairdrop_app flutter test test/f16_floor_redesign_test.dart`: 3/3 passed.

---

## F23: Menu Item String IDs & Toggle (AUDIT-F23)

### 1. Root Cause
- When testing the restaurant menu management flow or when fallback demo items were loaded, `fairdrop_app/lib/screens/restaurant/menu_management_screen.dart` used fallback menu items with string IDs (`item-101`, `item-102`, `item-103`), and `add_edit_menu_item_screen.dart:99` generated string IDs (`item-${DateTime.now().millisecondsSinceEpoch}`).
- When the restaurant attempted to update or toggle availability on item-102 via `PATCH /api/restaurants/menu/item-102`, Mongoose attempted to cast `"item-102"` into an `ObjectId` in `MenuItem.findById(req.params.item_id)`, throwing:
  `updateMenuItem error: Cast to ObjectId failed for value "item-102" (type string) at path "_id" for model "MenuItem"` and returning HTTP 500.

### 2. Implementation & Design Choice
- Checked all references to menu item IDs across `Order.model.js`, `order.controller.js`, `restaurant.controller.js`, tests, and `scripts/e2e-smoke.js`:
  - `MenuItem.model.js`: Defined `_id: { type: String, default: () => new mongoose.Types.ObjectId().toString() }`. This allows explicit string IDs (`item-101`, `item-102`) to be stored without schema errors, while auto-generating a valid string ObjectId for newly created items.
  - `Order.model.js`: Updated `items[].item_id` to `{ type: String, default: null }` so customer orders can reference both seeded string IDs and generated IDs without casting failures.
  - `restaurant.controller.js`: In `updateMenuItem`, added explicit check for `CastError` returning 404 defensively.
  - `scripts/seed.js`: Explicitly assigned `_id: 'item-101'`, `_id: 'item-102'`, `_id: 'item-103'` to Hotel Arun's seeded menu items, and `_id: 'item-201'`, `_id: 'item-202'` to Marina's menu items, making seeded database items and Flutter fallback items 100% identical.

### 3. Verification & Test Evidence
- Added tests to `core-service/tests/restaurants.test.js`:
  - `updates and toggles a seeded item by its seeded string ID (item-102)`: Updates name to `"Fish Curry Meal Special"`, price to 135, prep time to 50s, then toggles `is_available: false` via `PATCH /api/restaurants/menu/item-102/availability`, verifying 200 response and MongoDB persistence.
  - `updates and toggles a newly created item by its generated ID`: Creates a new menu item via `POST /api/restaurants/menu`, updates it, and toggles availability via `PATCH /api/restaurants/menu/:id/availability`, verifying 200 response and MongoDB persistence.
- `core-service npm test`: 78/78 tests passed.

