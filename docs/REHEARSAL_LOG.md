# FairDrop — Live Rehearsal Execution Log

**Branch:** `demo-rehearsal`  
**Date:** October 22, 2026  
**Auditors / Operators:** Raihan & Hari  

---

## Rehearsal Log Matrix

| Pass | Step | Persona / Device | Expected Result | Actual Result | Status | Suspected Component & Log Excerpt |
|---|---|---|---|---|---|---|
| Pass 1 | Step 4 | Customer / Physical Phone | Order confirmation displays Total: ₹360.00 matching cart items subtotal | Order placed successfully screen displays total paid ₹375.00 | **FAIL** | `fairdrop_app/lib/screens/customer/order_confirmation_screen.dart:56`<br>Line 56: `(_order?['total_price'] as num?)?.toDouble() ?? 375.0`<br>`POST /api/orders` returns `items: [{ price: 180, quantity: 2 }]` without root `total_price`, triggering fallback `375.0`. |
| Pass 1 | Step 10 | Rider / Chrome | Tapping Earnings displays breakdown for recent delivery | Navigating to `/pay-breakdown` renders "No completed deliveries yet" empty state | **FAIL** | `fairdrop_app/lib/screens/rider_home_screen.dart:1846` & `fairdrop_app/lib/screens/pay_breakdown_screen.dart:216`<br>Bottom navigation index 2 opens `/pay-breakdown` without arguments. In F26 fake fallback was removed with empty state check `_order == null && _payResult == null`. Screen should fetch latest delivery or redirect to dashboard. |
| Pass 2 | Step 4 | Customer / Chrome (Web) | Order confirmation displays Total: ₹360.00 matching cart items subtotal | Order placed successfully screen displays total paid ₹375.00 | **FAIL** | `fairdrop_app/lib/screens/customer/order_confirmation_screen.dart:56`<br>Same client-side fallback bug observed on Chrome web (`_order?['total_price'] ?? 375.0`). |
| Pass 2 | Step 7 | Restaurant / Chrome (Web) | Kitchen Live Orders card displays items total ₹360.00 | Kitchen Live Orders card displays `₹0.00` | **FAIL** | `fairdrop_app/lib/screens/restaurant/restaurant_orders_screen.dart:234`<br>Line 234: `final total = (order['total_price'] as num?)?.toDouble() ?? 0.0;`<br>Order payload contains `items` with prices, but lacks root `total_price`, resulting in default `₹0.00`. |
| Pass 2 | Step 10 | Rider / Physical Phone | Tapping Earnings displays breakdown for recent delivery | Navigating to `/pay-breakdown` renders "No completed deliveries yet"; tapping View Earnings in Dashboard shows itemized ledger | **PARTIAL / FAIL** | `fairdrop_app/lib/screens/rider_home_screen.dart:1846` & `fairdrop_app/lib/screens/pay_breakdown_screen.dart:216`<br>Replicated on physical phone: bottom nav "Earnings" opens bare `/pay-breakdown` showing empty state card; Dashboard tab correctly displays delivery list and itemized ledger. |
| Pass 2 | Step 12 | Customer / Chrome (Web) | Order cards display items total (₹360.00, ₹150.00) | Item prices display correctly, but card footer shows `Total: ₹0.00` | **FAIL** | `fairdrop_app/lib/screens/customer/customer_order_history_screen.dart:210`<br>Line 210: `double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0`. Backend `Order` schema does not store `total_amount` root field, defaulting to `₹0.00` instead of computing sum of item prices. |
