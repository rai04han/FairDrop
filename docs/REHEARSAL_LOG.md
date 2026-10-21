# FairDrop — Live Rehearsal Execution Log

**Branch:** `demo-rehearsal`  
**Date:** October 22, 2026  
**Auditors / Operators:** Raihan & Hari  

---

## 1. Initial Rehearsal Findings (Pre-Patch)

| Pass | Step | Persona / Device | Expected Result | Actual Result | Status | Suspected Component & Log Excerpt |
|---|---|---|---|---|---|---|
| Pass 1 | Step 4 | Customer / Physical Phone | Order confirmation displays Total: ₹360.00 matching cart items subtotal | Order placed successfully screen displays total paid ₹375.00 | **FAIL (Resolved in F31)** | `fairdrop_app/lib/screens/customer/order_confirmation_screen.dart`<br>Line 56: `(_order?['total_price'] as num?)?.toDouble() ?? 375.0`<br>`POST /api/orders` returns `items: [{ price: 180, quantity: 2 }]` without root `total_price`, triggering fallback `375.0`. |
| Pass 1 | Step 10 | Rider / Chrome | Tapping Earnings displays breakdown for recent delivery | Navigating to `/pay-breakdown` renders "No completed deliveries yet" empty state | **FAIL (Resolved in F31)** | `fairdrop_app/lib/screens/rider_home_screen.dart` & `fairdrop_app/lib/screens/pay_breakdown_screen.dart`<br>Bottom navigation index 2 opens `/pay-breakdown` without arguments. In F26 fake fallback was removed with empty state check `_order == null && _payResult == null`. Screen should fetch latest delivery or redirect to dashboard. |
| Pass 2 | Step 4 | Customer / Chrome (Web) | Order confirmation displays Total: ₹360.00 matching cart items subtotal | Order placed successfully screen displays total paid ₹375.00 | **FAIL (Resolved in F31)** | `fairdrop_app/lib/screens/customer/order_confirmation_screen.dart`<br>Same client-side fallback bug observed on Chrome web (`_order?['total_price'] ?? 375.0`). |
| Pass 2 | Step 7 | Restaurant / Chrome (Web) | Kitchen Live Orders card displays items total ₹360.00 | Kitchen Live Orders card displays `₹0.00` | **FAIL (Resolved in F31)** | `fairdrop_app/lib/screens/restaurant/restaurant_orders_screen.dart`<br>Line 234: `final total = (order['total_price'] as num?)?.toDouble() ?? 0.0;`<br>Order payload contains `items` with prices, but lacks root `total_price`, resulting in default `₹0.00`. |
| Pass 2 | Step 10 | Rider / Physical Phone | Tapping Earnings displays breakdown for recent delivery | Navigating to `/pay-breakdown` renders "No completed deliveries yet"; tapping View Earnings in Dashboard shows itemized ledger | **FAIL (Resolved in F31)** | `fairdrop_app/lib/screens/rider_home_screen.dart` & `fairdrop_app/lib/screens/pay_breakdown_screen.dart`<br>Replicated on physical phone: bottom nav "Earnings" opens bare `/pay-breakdown` showing empty state card; Dashboard tab correctly displays delivery list and itemized ledger. |
| Pass 2 | Step 12 | Customer / Chrome (Web) | Order cards display items total (₹360.00, ₹150.00) | Item prices display correctly, but card footer shows `Total: ₹0.00` | **FAIL (Resolved in F31)** | `fairdrop_app/lib/screens/customer/customer_order_history_screen.dart`<br>Line 210: `double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0`. Backend `Order` schema does not store `total_amount` root field, defaulting to `₹0.00` instead of computing sum of item prices. |

---

## 2. Post-Rehearsal Remediation Matrix (Fix F31)

| Defect ID | Component / File | Remediation Applied | Re-Verification Result |
|---|---|---|---|
| **F31-A** | `fairdrop_app/lib/screens/customer/order_confirmation_screen.dart` | Removed hardcoded fallback `375.0`. Dynamically computes order total by folding item prices and quantities ($\sum price \times qty$). | **PASS** — Displays ₹360.00 matching 2x Biryani order. Verified in `test/f31_rehearsal_ui_bindings_test.dart`. |
| **F31-B** | `fairdrop_app/lib/screens/restaurant/restaurant_orders_screen.dart` | Replaced uncomputed root `total_price` assumption with computed sum across the `items` array. | **PASS** — Displays exact order item total (₹360.00) in kitchen card footer instead of `₹0.00`. |
| **F31-C** | `fairdrop_app/lib/screens/customer/customer_order_history_screen.dart` | Added `itemsTotal` summation across order `items` when root `total_amount` is missing. | **PASS** — Customer order history cards display exact itemized totals instead of `Total: ₹0.00`. |
| **F31-D** | `fairdrop_app/lib/screens/rider_home_screen.dart` & `fairdrop_app/lib/screens/pay_breakdown_screen.dart` | 1) Linked Rider bottom navigation Earnings tab to `_navigateToEarnings()` which queries `CoreApiService.getOrderHistory()` and passes `_latestDeliveredOrder`.<br>2) Added auto-fetch to `PayBreakdownScreen` when opened bare so it fetches the rider's latest delivered order and populates the 7-itemized ledger.<br>3) Configured `/pay-breakdown` route with `autoFetch: true`. | **PASS** — Tapping Earnings now immediately displays the recent delivery's itemized ledger with zero empty-state flicker. |

---

## 3. Final Verification Gate Summary

| Gate | Command / Test | Result | Status |
|---|---|---|---|
| **Gate 1** | `flutter analyze` (`fairdrop_app`) | 0 issues found | **PASS** |
| **Gate 2** | `flutter test` (`fairdrop_app`) | 143 passed, 0 failed | **PASS** |
| **Gate 3** | `npm test` (`core-service`) | 6 suites, 40 passed, 0 failed | **PASS** |
| **Gate 4** | `npm test` (`pay-service`) | 9 suites, 35 passed, 0 failed | **PASS** |
| **Gate 5** | Regression Suite (`f31_rehearsal_ui_bindings_test.dart`) | 3 passed, 0 failed | **PASS** |

---

## 4. Final Verdict

**VERDICT: GO FOR DEMO-READY TAG**  
All 4 UI display bindings and navigation linkages are resolved, verified, and backed by automated widget and unit tests. Zero runtime exceptions. Clean for presentation.
