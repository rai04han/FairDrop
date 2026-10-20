# FairDrop Defects Fix Report (Complete: Part 1 & Part 2)

**Date:** October 20, 2026  
**Audited Against:** `docs/FairDrop_Flutter_App_PRD_v2.1.md` and `docs/AUDIT_REPORT.md`  
**Base Tag:** `pre-audit` (`06711b4`)  
**Head Commit:** `064b38f` (before report update)  

---

## 1. Fix Summary Matrix

| Fix ID | Description | Status | Commit | Files Modified | Evidence & Verification |
|---|---|---|---|---|---|
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
|---|---|---|
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
