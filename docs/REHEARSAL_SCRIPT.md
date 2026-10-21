# FairDrop — Live Demonstration Rehearsal Script (PRD §10.2)

**Document Version:** 2.1  
**Target:** Examiner Demonstration & Evaluation  
**Branch:** `demo-rehearsal`  
**Base Live Pay Config (Config #171):**
- **Base Rate:** ₹15.00
- **Per-Km Rate:** ₹6.00 / km
- **Wait Threshold:** 1 minute
- **Wait Compensation:** ₹10.00 flat bonus
- **Surge Bonus:** ₹20.00
- **FairDrop Per-Order Incentive:** ₹17.04
- **Statutory Minimum Wage Floor:** ₹70.00 / hr (Kerala baseline)
- **Floor Evaluation Window:** 60 completed engaged minutes

---

## 1. 14-Step Master Rehearsal Table

| Step # | Device | Persona / Account | Action / Interaction | EXPECTED On-Screen Result | Backend Verification Command |
|---|---|---|---|---|---|
| **1** | Emulator | **Rider**<br>`rider_new@fairdrop.in`<br>`password123` | Log in on Rider Home screen.<br>Verify initial shift stats.<br>Tap **Go Online** toggle. | • Active Hub: `KLM-CHK (Chinnakada Hub)`<br>• Shift Card: `₹0.00` earnings, `0 min active`<br>• Realized Pay: `" — "` with `"after 60 engaged min"` & `"Not enough completed hours today"`<br>• Status badge: `"Not yet evaluated"`<br>• Status toggle switches to **ONLINE** (green banner). | `curl -s -H "Authorization: Bearer <rider_token>" http://localhost:3003/api/riders/today` |
| **2** | Phone | **Restaurant**<br>`arun@fairdrop.in`<br>`password123` | Log in to Restaurant portal.<br>Go to Menu Management.<br>Add new item "Kerala Special Porotta" (₹25, 30s prep).<br>Toggle **Fish Curry Meal** (`item-102`) to **UNAVAILABLE**. | • New item appears in menu list.<br>• Availability switch for `item-102` displays **Unavailable / Off** with grey styling.<br>• No layout overflow on 360px/393px viewports. | `curl -s http://localhost:3003/api/restaurants` |
| **3** | Phone | **Customer**<br>`john@fairdrop.in`<br>`password123` | Log out restaurant.<br>Log in as customer.<br>Select **Pin A** on map.<br>Tap **Hotel Arun**.<br>Attempt to add unavailable item.<br>Add **2 × Chicken Biryani** (₹180 each).<br>Tap **View Cart**. | • Pin A shows in-zone address.<br>• Hotel Arun listed as open partner.<br>• Unavailable item ADD button is disabled or tapping shows `"Item currently unavailable"`.<br>• Cart Item Subtotal: **₹360.00**.<br>• Customer Delivery Fee: **₹0.00** (FR-59).<br>• Platform Fee: **₹0.00**; GST: **₹0.00**.<br>• Total Payable: **₹360.00**.<br>• Sticky VIEW CART button clearly visible. | *(Client cart validation)* |
| **4** | Phone | **Customer**<br>`john@fairdrop.in` | Tap **Checkout**.<br>On Mock Payment screen, tap **Place Order**. | • Confirmation dialog/screen displays generated Order ID (e.g. `ORD-20261022-0001`).<br>• Shows Hotel Arun, 2 items, total ₹360.00.<br>• Order status: `placed` / `allocated`. | `curl -s -H "Authorization: Bearer <customer_token>" http://localhost:3003/api/orders/history` |
| **5** | Backend | **System Dispatch** | Automatic order allocation triggers via point-in-polygon matching inside `KLM-CHK`. | • Order assigned to online rider in `KLM-CHK`.<br>• Rider home screen polls order within 10s. | `curl -s -H "Authorization: Bearer <rider_token>" http://localhost:3003/api/orders/rider/active` |
| **6** | Emulator | **Rider**<br>`rider_new@fairdrop.in` | Rider Home displays incoming Offer Card.<br>Tap **View Offer Details**.<br>Inspect upfront transparent formula.<br>Tap **Accept Order**. | • Offer Card shows Order ID and restaurant name.<br>• Distance: approx **0.31 km**.<br>• Estimated payout formula displayed: Base ₹15 + Dist ₹1.86 + FairDrop Incentive ₹17.04 = **₹33.90**.<br>• Wait comp note: `"+₹10.00 flat bonus if restaurant wait exceeds 1 min"`.<br>• Accepting navigates directly to Active Delivery screen. | `curl -s -H "Authorization: Bearer <rider_token>" http://localhost:3003/api/orders/rider/active`<br>*(Returns status: `assigned`)* |
| **7** | Phone | **Restaurant**<br>`arun@fairdrop.in` | *(Optional visual check)*<br>Log into restaurant portal and view Live Orders screen. | • Order appears under active orders.<br>• Shows items: 2 × Chicken Biryani.<br>• Countdown badge shows kitchen prep time (40s), transitions to `READY` once prep elapsed. | `curl -s -H "Authorization: Bearer <arun_token>" http://localhost:3003/api/restaurants/orders` |
| **8** | Emulator | **Rider**<br>`rider_new@fairdrop.in` | On Active Delivery tracker:<br>1. Tap **Arrived at Restaurant**.<br>2. Wait **> 60 seconds** (exceeding 1-min threshold).<br>3. Tap **Picked Up Order**.<br>4. Tap **Confirm Delivered**. | • Arrival timestamp shows local time (`h:mm a`).<br>• Meter records wait duration > 1 min.<br>• Travel ETA dynamically calculated from distance (20 km/h urban speed).<br>• Order ID wrapped cleanly without truncation.<br>• Tapping Delivered triggers delivery completion. | `curl -s -H "Authorization: Bearer <rider_token>" http://localhost:3003/api/orders/rider/active`<br>*(Returns null / no active order)* |
| **9** | Emulator | **Rider**<br>`rider_new@fairdrop.in` | Inspect **Delivery Summary** screen immediately after delivery. | **7-Line Itemized Ledger (Exact Match to pay-service):**<br>1. Base Pay: **₹15.00**<br>2. Distance Pay (0.31 km @ ₹6/km): **₹1.86**<br>3. Surge Bonus: **₹0.00**<br>4. Wait Compensation (>1 min): **₹10.00**<br>5. FairDrop Incentive: **₹17.04**<br>6. **Total Delivery Pay: ₹43.90** (Bold green highlight)<br>7. Effective Hourly Rate: **" — "** with note *"Floor evaluated after 60 min on orders"*<br>• Clean breakdown with 0 RenderFlex overflow. | `curl -s -H "Authorization: Bearer <rider_token>" http://localhost:3001/api/pay/history/<rider_id>` |
| **10** | Emulator | **Rider**<br>`rider_new@fairdrop.in` | Tap **Done** to return to Home.<br>Check Dashboard tab.<br>Check Analytics tab. | • **Rider Home:** Shift card displays ₹43.90 earnings, 1 delivery completed.<br>• **Dashboard:** 1 delivery listed with 7-line tile; Floor Compliance shows *"Not yet evaluated"* with active minutes count.<br>• **Analytics:** Balanced Zomato ladder comparison (FR-34 to FR-36); parity table shows equality at 27 orders; FairDrop per-order incentive keeps paying beyond 27 orders; peak toggle adds +₹20/order. | `curl -s -H "Authorization: Bearer <rider_token>" http://localhost:3001/api/pay/analytics/<rider_id>` |
| **11** | Phone & Emulator | **Customer & Rider** | 1. Customer places Order 2 with drop-off at **Pin B** (Polayathode, out-of-zone).<br>2. Rider receives offer card with **Out-of-Zone Badge** and distance beyond boundary (1.87 km total).<br>3. Rider checks consent checkbox and accepts.<br>4. Complete delivery.<br>5. Open **Zone Map** tab. | • Order acceptance warns drop-off is in `KLM-PLY` (1.87 km from Arun, within 5 km cap).<br>• Delivery summary computes Base ₹15.00 + Dist ₹11.22 + Incentive ₹17.04 = **₹43.26** (or ₹53.26 with wait comp).<br>• Zone Map displays transition banner: **"Hub Updated: Polayathode Hub (KLM-PLY)"**.<br>• Active hub polygon changes highlight to `KLM-PLY`. | `curl -s -H "Authorization: Bearer <rider_token>" http://localhost:3003/api/riders/me`<br>*(Returns `current_zone_code: "KLM-PLY"`)* |
| **12** | Phone | **Customer**<br>`john@fairdrop.in` | Log back in as customer.<br>Pull-to-refresh on Order History. | • Both completed orders (`ORD-...-0001` and `ORD-...-0002`) appear as **DELIVERED**.<br>• Shows item counts, restaurant names, and order subtotals. | `curl -s -H "Authorization: Bearer <customer_token>" http://localhost:3003/api/orders/history` |
| **13** | Phone | **Admin**<br>`admin@fairdrop.in`<br>`password123` | Log in as Admin.<br>Open Admin Panel.<br>Inspect active config & history.<br>Test 6-day advance notice rule.<br>Test 8-day advance notice rule.<br>Tap Logout button in AppBar. | • Active config shows baseline rates (₹15 base, ₹6/km, 1m wait, ₹17.04 incentive).<br>• History shows Config #171.<br>• Setting date = today + 6 days is **REJECTED with HTTP 400** ("Effective date must be at least 7 days in advance").<br>• Setting date = today + 8 days is **ACCEPTED with HTTP 200** and appears in Scheduled/History list citing Fairwork Principle 3.<br>• Header title visible in white.<br>• Logout confirms dialog and returns to login screen. | `curl -s -H "Authorization: Bearer <admin_token>" http://localhost:3001/api/admin/pay-config/history` |
| **14** | Emulator | **Rider**<br>`rider_new@fairdrop.in` | On Rider Home screen, toggle status to **OFFLINE**.<br>Open Profile tab and tap **Log Out**. | • Shift session is closed.<br>• App returns to Login screen.<br>• Server confirms rider `is_online: false`. | `curl -s -H "Authorization: Bearer <rider_token>" http://localhost:3003/api/riders/today` |

---

## 2. Mathematical Reference Formulas

### Customer Order Total (FR-58, FR-59, D4)
$$\text{Customer Total} = \sum (\text{item.price} \times \text{item.quantity})$$
$$\text{Customer Total} = 2 \times ₹180 = ₹360.00 \quad (\text{Delivery Fee} = ₹0, \text{Platform Fee} = ₹0, \text{GST} = ₹0)$$

### Rider Guaranteed Pay Formula (FR-11, FR-21, FR-31, AUDIT-F24)
$$\text{Delivery Pay} = \text{Base Rate} + (\text{Distance Km} \times \text{Per-Km Rate}) + \text{Surge Bonus} + \text{Wait Comp} + \text{FairDrop Incentive}$$
- **Order 1 (In-zone, 0.31 km, >1 min wait):**
  $$\text{Pay} = ₹15.00 + (0.31 \times ₹6.00) + ₹0.00 + ₹10.00 + ₹17.04 = ₹15.00 + ₹1.86 + ₹10.00 + ₹17.04 = ₹43.90$$
- **Order 2 (Out-of-zone, 1.87 km, <=1 min wait):**
  $$\text{Pay} = ₹15.00 + (1.87 \times ₹6.00) + ₹0.00 + ₹0.00 + ₹17.04 = ₹15.00 + ₹11.22 + ₹17.04 = ₹43.26$$

### Statutory Minimum Wage Floor Evaluation (FR-23, AUDIT-F16)
$$\text{Floor Target} = ₹70.00 / \text{hour (Kerala Baseline)}$$
- Evaluated strictly across completed 60-minute engaged blocks without strong-hour deductions.
- When engaged time < 60 min: Status displays `"Not yet evaluated"`, Effective Rate displays `" — "`.
