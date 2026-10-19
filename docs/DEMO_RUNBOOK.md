# FairDrop — Live Demonstration Runbook (PRD v2.1)

**Project:** FairDrop — Algorithmic Fairness in Last-Mile Food Delivery  
**Course / Degree:** MCA Mini Project (23MCAM307), TKM College of Engineering, Kollam  
**Target Audience:** Project Examiners, Faculty Evaluators & Peer Reviewers  
**Authors / Academic Owners:** Hari (25MCA025) & Raihan (25MCA044)  
**Document Version:** 2.1 (Strict Zero Manual DB Intervention)

---

## 1. System Architecture & Demo Topology

The entire FairDrop stack runs locally on Hari's development laptop:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        DEVELOPMENT LAPTOP                              │
│                                                                        │
│  ┌───────────────────────┐         ┌────────────────────────────────┐  │
│  │ core-service          │         │ pay-service                    │  │
│  │ Node.js / Express     │         │ Node.js / Express              │  │
│  │ Port: 3003            │         │ Port: 3001                     │  │
│  │ MongoDB Atlas (Cloud) │         │ Local MySQL (Port 3306)        │  │
│  └───────────▲───────────┘         └───────────────▲────────────────┘  │
│              │                                     │                   │
│              └───────────────┬─────────────────────┘                   │
│                              │                                         │
│                   USB adb reverse (tcp:3003, tcp:3001)                 │
└──────────────────────────────┼─────────────────────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            │                                     │
   ┌────────▼──────────┐               ┌──────────▼────────┐
   │ Android Emulator  │               │ Physical Android  │
   │ (Rider Persona)   │               │ (Customer / Rest/ │
   │ App: Release APK  │               │  Admin Personas)  │
   │ Host: 127.0.0.1   │               │ Host: 127.0.0.1   │
   └───────────────────┘               └───────────────────┘
```

- **Transport Guarantee:** By routing through `127.0.0.1` using `adb reverse`, both the emulator and the USB-connected physical phone communicate with the laptop backend without relying on campus Wi-Fi or local IP switches (D14).

---

## 2. Pre-Flight Checklist

Before the examiners begin the evaluation, execute this 5-minute pre-flight sequence:

### Step 2.1: Verify Background Services
Ensure MySQL and both microservices are running:

```powershell
# 1. Health check core-service (port 3003)
curl http://localhost:3003/api/health

# 2. Health check pay-service (port 3001)
curl http://localhost:3001/health
```
*Expected Response:* Both endpoints return HTTP `200 OK` with `{ "status": "ok" }` or `{ "status": "UP" }`.

### Step 2.2: Set Up USB `adb reverse` Ports
Connect the physical phone via USB with USB Debugging enabled, and start the Android emulator:

```powershell
# List attached devices
adb devices
```
*Output will list two device IDs (e.g. `emulator-5554` and `9889...device`).*

Map ports `3003` and `3001` across both devices:
```powershell
# For Android Emulator:
adb -s emulator-5554 reverse tcp:3003 tcp:3003
adb -s emulator-5554 reverse tcp:3001 tcp:3001

# For Physical Phone (replace <device_id> with physical phone ID from adb devices):
adb -s <device_id> reverse tcp:3003 tcp:3003
adb -s <device_id> reverse tcp:3001 tcp:3001
```

> [!IMPORTANT]
> If either device is unplugged or restarted during the demonstration, immediately re-run the `adb reverse` commands above.

### Step 2.3: Reset Database to Pristine Seed State
Run the idempotent master seed to wipe past state and seed standard demo credentials:

```powershell
npm run seed
```
*Expected Output:* Clears MongoDB collections and MySQL tables, links 3 Kollam zones, seeds Hotel Arun & Marina, seeds baseline pay constants (1-minute wait threshold), and passes all spatial constraint assertions.

### Step 2.4: Execute Automated Smoke Test (Safety Check)
Confirm the complete 14-step flow passes in under 6 seconds:

```powershell
npm run smoke
```
*Expected Output:* `✔ ALL 14 DEMO FLOW STEPS PASSED SUCCESSFULLY` (exit code 0).

---

## 3. Seed Accounts & Credentials Reference

All seeded accounts share the uniform password: `password123`.

| Role | Account Name | Email | Password | Assigned Zone / Location |
|---|---|---|---|---|
| **Rider** | Rider 1 | `rider1@fairdrop.in` | `password123` | `KLM-CHK` (Chinnakkada) |
| **Rider** | Rider 2 | `rider2@fairdrop.in` | `password123` | `KLM-PLY` (Polayathode) |
| **Rider** | Rider 3 | `rider3@fairdrop.in` | `password123` | `KLM-KLK` (Kilikolloor) |
| **Customer** | John | `john@fairdrop.in` | `password123` | Customer (Primary demo customer) |
| **Customer** | Priya | `priya@fairdrop.in` | `password123` | Customer (Secondary) |
| **Restaurant**| Hotel Arun | `arun@fairdrop.in` | `password123` | Chinnakkada (`KLM-CHK`) |
| **Restaurant**| Marina | `marina@fairdrop.in` | `password123` | Polayathode (`KLM-PLY`) |
| **Admin** | FairDrop Admin | `admin@fairdrop.in` | `password123` | Platform Administrator |

---

## 4. Geographic & Spatial Coordinates

All coordinates represent real-world locations in Kollam, Kerala:

| Point | Location Name | Latitude | Longitude | Zone ID | Context |
|---|---|---|---|---|---|
| **Hotel Arun** | Chinnakkada Junction | `8.8880` | `76.5900` | `KLM-CHK` | Restaurant Hub |
| **Marina** | Polayathode Main Rd | `8.8780` | `76.6100` | `KLM-PLY` | Partner Restaurant |
| **Pin A** | Chinnakkada Residential | `8.8860` | `76.5920` | `KLM-CHK` | **In-Zone** (0.31 km from Hotel Arun) |
| **Pin B** | Polayathode Station | `8.8800` | `76.6050` | `KLM-PLY` | **Out-of-Zone** (1.87 km from Hotel Arun, within 5km cap) |

---

## 5. Turn-by-Turn 14-Step Demonstration Script

### Setup Before Starting
- **Android Emulator:** Open app, stay on Login/Signup screen.
- **Physical Phone:** Open app, stay on Login screen.

---

### Step 1: Rider Registration & Automated Zone Assignment
- **Device:** Android Emulator
- **Screen:** Rider Signup Screen (`/rider-signup`)
- **Actions:**
  1. On the Emulator, tap **"New Rider? Register Here"**.
  2. Enter:
     - Name: `Aswin Kumar`
     - Email: `aswin_demo@fairdrop.in`
     - Password: `password123`
     - Phone: `9876500001`
     - Vehicle Type: Select `Motorcycle`
  3. Tap **"Create Rider Account"**.
  4. On the Onboarding Screen, review the safety checklist and tap **"Acknowledge & Proceed"**.
  5. On Rider Home, toggle the status switch to **ONLINE**.
- **UI Highlights:**
  - Auto-assigned Zone card displays **`KLM-CHK (Chinnakkada)`** without user selection (FR-51, FR-52).
  - Status chip transforms from grey "Offline" to vibrant green **"ONLINE"** (FR-7).
- **Speaker Narration:**
  > *"In conventional gig platforms, riders are either given opaque onboarding allocations or forced into arbitrary zones. In FairDrop, zone assignment is purely algorithmic and deterministic: the system identifies the zone with the fewest active riders—in this tie-breaker, KLM-CHK—and automatically creates matching records in MongoDB and MySQL with zero manual database intervention."*

---

### Step 2: Restaurant Menu Management & Live Availability Defense
- **Device:** Physical Phone
- **Screen:** Restaurant Partner Portal (`/restaurant/menu`)
- **Actions:**
  1. Log in with `arun@fairdrop.in` / `password123`.
  2. The Restaurant Menu Management screen displays seeded dishes.
  3. Tap the **"+ Add Item"** floating action button.
  4. Fill in:
     - Item Name: `Kerala Porotta Special`
     - Price (₹): `25`
     - Prep Time (seconds): `30`
  5. Tap **"Save Menu Item"**.
  6. On the menu list, toggle the switch on `Kerala Porotta Special` to **OFF** (Unavailable).
- **UI Highlights:**
  - Dish status badge turns red: **"UNAVAILABLE"** (FR-64).
  - Preparation countdown is fixed at 30 seconds (FR-63).
- **Speaker Narration:**
  > *"Restaurants on FairDrop maintain complete autonomy over dish preparation times and real-time inventory. Here Hotel Arun adds 'Kerala Porotta Special' with a 30-second prep time, then immediately marks it unavailable. Our backend strictly defends this: even if a client attempts to bypass the UI, the order creation API will reject unavailable items with an explicit HTTP 400."*

---

### Step 3: Customer Location Selection & Unavailable Item Blocking
- **Device:** Physical Phone
- **Screen:** Customer Shell (`/customer/location` → `/customer/menu`)
- **Actions:**
  1. In the top app bar, tap **Logout**.
  2. Log in as Customer: `john@fairdrop.in` / `password123`.
  3. On the Delivery Location screen, tap **"Pin A (In-Zone Chinnakkada)"**.
  4. Tap **"Confirm Delivery Location"**.
  5. From the restaurant list, tap **"Hotel Arun"** (0.31 km away).
  6. Locate `Kerala Porotta Special`: notice the greyed-out card and **"UNAVAILABLE"** badge. Tap it to demonstrate that it cannot be added.
  7. Add **2x Chicken Biryani** (₹180 each) to the cart.
  8. Tap **"View Cart (2 items)"**.
- **UI Highlights:**
  - Straight-line haversine distance (0.31 km) shown next to restaurant name (FR-70).
  - Unavailable item cannot be added (FR-57, Demo Step 3 defense).
  - Cart itemizes Subtotal (₹360), Platform Fee (₹5), Delivery Fee (₹15), and GST.
- **Speaker Narration:**
  > *"Customer John selects Pin A inside Chinnakkada. Notice that 'Kerala Porotta Special' is visually disabled and cannot be added to the cart, preventing order cancellation frustration. We proceed with two Chicken Biryanis."*

---

### Step 4: Customer Order Placement & Auto-Acceptance
- **Device:** Physical Phone
- **Screen:** Customer Cart & Mock Payment (`/customer/cart` → `/customer/payment`)
- **Actions:**
  1. On the Cart Screen, tap **"Proceed to Checkout"**.
  2. On the Mock Payment Screen, select **"UPI / Instant Pay"**.
  3. Tap **"Place Order (₹398)"**.
  4. Order Confirmation Screen loads immediately.
- **UI Highlights:**
  - Sequential Order ID generated: `ORD-20261019-XXXX` (Counter model).
  - Auto-accepted badge: **"Order Accepted by Kitchen"** (FR-67).
  - Allocation notice: **"Allocating nearest rider in KLM-CHK..."**
- **Speaker Narration:**
  > *"Order placement auto-accepts without manual kitchen latency (FR-67). The backend immediately executes our zone-based spatial allocation algorithm."*

---

### Step 5: Backend Auto-Allocation to Online Rider
- **Device:** Android Emulator
- **Screen:** Rider Home Screen (`/rider/home`)
- **Actions:**
  1. Observe the Android Emulator screen. Within 3 seconds (polling interval), an incoming order bottom sheet slides up.
- **UI Highlights:**
  - Audio/vibration cue triggers.
  - Card displays Order ID, Pickup at Hotel Arun (Chinnakkada), Drop-off at Pin A, and distance (0.31 km).
  - Button: **"Review Order & Pay Formula"**.
- **Speaker Narration:**
  > *"Without manual dispatcher intervention, our allocation engine evaluated all active riders in KLM-CHK, selected our online rider, and pushed the order to the rider's active queue."*

---

### Step 6: Upfront Transparent Pay Formula & Acceptance
- **Device:** Android Emulator
- **Screen:** Order Acceptance Screen (`/order-acceptance`)
- **Actions:**
  1. Tap **"Review Order & Pay Formula"**.
  2. Point out the live formula parameters read from `pay-service`.
  3. Show the Guaranteed Minimum Payout breakdown.
  4. Point out the **"Decline Without Penalty"** button (FR-15).
  5. Tap **"Accept Delivery"**.
- **UI Highlights:**
  - Transparent formula: `₹15.00 Base + ₹7.00/km + Surge + Wait Comp` (FR-11).
  - Guaranteed estimated payout displayed clearly before acceptance (FR-13).
  - Zero-penalty decline notice (FR-15).
- **Speaker Narration:**
  > *"This fulfills Fairwork Principle 4 (Fair Contracts) and PRD Goal 1. Unlike opaque black-box algorithms where riders accept orders blindly, FairDrop guarantees complete formula transparency before acceptance. Riders can also decline without fear of hidden shadow-bans or algorithmic penalties."*

---

### Step 7: Restaurant Kitchen Orders & Live Ready Countdown
- **Device:** Physical Phone
- **Screen:** Restaurant Orders Screen (`/restaurant/orders`)
- **Actions:**
  1. *(Optional showcase)* Switch back to Restaurant login: `arun@fairdrop.in` / `password123`.
  2. Open **"Active Kitchen Orders"**.
  3. Show Order `ORD-20261019-XXXX` with live status: **"Assigned to Aswin Kumar"**.
  4. Show preparation countdown indicator (`is_ready: false` → `is_ready: true` once 40s elapsed).
- **UI Highlights:**
  - Preparation timer derived server-side from maximum item prep time (FR-69).
  - Status updates to **"Food Ready for Pickup"**.
- **Speaker Narration:**
  > *"The kitchen view derives food readiness deterministically from item prep times. This eliminates rider-restaurant arguments over who caused delays."*

---

### Step 8: Active Delivery Lifecycle & Restaurant Wait Tracking
- **Device:** Android Emulator
- **Screen:** Active Delivery Screen (`/active-delivery`)
- **Actions:**
  1. Logged in as Rider on Emulator.
  2. Tap **"Arrived at Restaurant"**.
  3. The **"Restaurant Wait Compensation Timer"** begins counting upwards.
  4. Wait for the counter to cross **1 minute** (e.g. 1m 05s) to trigger wait compensation.
  5. Tap **"Picked Up Order"**.
  6. Tap **"Delivered Order"**.
  7. Confirm delivery completion in the popup dialog.
- **UI Highlights:**
  - 4-stage visual stepper (`Heading` → `At Kitchen` → `Out for Delivery` → `Delivered`) (FR-17).
  - Real-time wait timer with statutory warning: *"Wait threshold: 1 min. Over 1 min is compensated at ₹10.00/min."* (FR-18).
  - Server records exact timestamps; client cannot tamper with wait minutes (D10).
- **Speaker Narration:**
  > *"Uncompensated restaurant waiting time is one of the biggest grievances in gig delivery. Here, the rider arrived, waited over 1 minute for food packaging, and the server accurately recorded the elapsed wait. When the rider marks 'Delivered', core-service calls Raihan's Pay Engine on port 3001 using mutual JWT authentication."*

---

### Step 9: Delivery Summary & 7-Item Itemized Ledger
- **Device:** Android Emulator
- **Screen:** Delivery Summary Screen (`/delivery-summary`)
- **Actions:**
  1. Screen opens automatically upon delivery completion.
  2. Point out each of the 7 itemized lines in the ledger.
  3. Highlight line 3: **Restaurant Wait Compensation = ₹10.00**.
  4. Point out the zero-lines (Surge Bonus = ₹0.00, Delay Deduction = ₹0.00) with explicit explanation chips.
  5. Tap **"Done — Back to Dashboard"**.
- **UI Highlights:**
  - Full 7-line ledger breakdown (FR-21):
    1. Base Pay: `₹15.00`
    2. Distance Pay: `₹1.86` (0.31 km × ₹6/km)
    3. Restaurant Wait Compensation: `₹10.00` (> 1 min threshold)
    4. Surge Bonus: `₹0.00` (Off-surge hours)
    5. Return Compensation: `₹0.00` (In-zone delivery)
    6. Minimum Floor Top-up: `₹43.14` (Statutory ₹70/hr compliance)
    7. Delay Deduction: `₹0.00` (On-time)
  - Total Delivery Payout: **`₹70.00`** (Floor-compliant).
- **Speaker Narration:**
  > *"Every single paisa is accounted for in this 7-item ledger (FR-21). Notice line 3: because the rider waited over 1 minute, ₹10.00 wait compensation was calculated by the Pay Engine. Furthermore, line 6 demonstrates statutory wage floor compliance under Kerala gig worker welfare standards."*

---

### Step 10: Rider Dashboard & Academic Pay Analytics
- **Device:** Android Emulator
- **Screen:** Rider Dashboard (`/rider/dashboard`) → Analytics (`/analytics`)
- **Actions:**
  1. On the Rider Dashboard, pull down to refresh (`RefreshIndicator`).
  2. Show Today's Earnings Summary Card, Active Hours, and Floor Compliance badge.
  3. Tap the delivery row to expand the full 7-line ledger breakdown.
  4. Tap the **"Comparative Pay Analytics (FairDrop vs Cliff)"** navigation banner.
  5. On the Analytics Screen, show:
     - The `fl_chart` cumulative earnings curve (FR-34).
     - The stated cliff assumptions card: 10 deliveries threshold, ₹500 bonus (FR-35).
     - Toggle the switch: **"Show Scenario Where Cliff Model Wins"** (FR-36).
- **UI Highlights:**
  - Pull-to-refresh (`Key('rider_dashboard_refresh_indicator')`, FR-33).
  - Statutory Floor Banner: **"Compliant with ₹70/hr Kerala Minimum Wage Floor"** (FR-32).
  - Balanced Framing Rationale in Cliff-Wins mode (FR-36).
- **Speaker Narration:**
  > *"This fulfills our core academic contribution (Goal G6, Section 8.4). Rather than presenting a biased comparison, FairDrop provides an objective, two-sided analysis. In steady-state, linear earnings protect workers from cliff-edge burnout. But when a rider completes 10+ deliveries in a sprint, we transparently show that the cliff bonus awards +₹420 more, while explaining the associated fatigue and accident risks."*

---

### Step 11: Out-of-Zone Delivery & Automatic Hub Reassignment
- **Device:** Physical Phone & Android Emulator
- **Screen:** Customer Flow (Pin B) → Rider Acceptance → Zone Map (`/zone-map`)
- **Actions:**
  1. On Physical Phone, Customer places a second order:
     - Delivery Location: Tap **"Pin B (Out-of-Zone Polayathode)"** (`76.6050, 8.8800`).
     - Restaurant: Hotel Arun (Chinnakkada).
     - Item: 1x Fish Curry Meal (₹120).
     - Complete Checkout.
  2. On Android Emulator, incoming order appears:
     - Notice the orange **"Out-of-Zone Delivery"** badge (FR-14).
     - Distance beyond boundary: `1.87 km` (within 5 km cap).
     - Mandatory rider consent checkbox: *"I understand this delivery extends beyond my active zone."*
     - Check the box and tap **"Accept Delivery"**.
  3. Complete the delivery stages (`Arrived` → `Picked Up` → `Delivered`).
  4. From the top bar, open the **Zone Map Screen** (`/zone-map`).
- **UI Highlights:**
  - Prominent banner: **"Zone Changed: Your active zone is now KLM-PLY (Polayathode)"** (FR-27).
  - Zone boundary highlight moves from Chinnakkada to Polayathode polygon (FR-26, FR-28).
  - Last delivery drop-off point pin plotted on map (FR-29).
- **Speaker Narration:**
  > *"When a rider is pulled out of their zone, conventional platforms leave them stranded with zero return compensation. FairDrop verifies the delivery is within the 5 km cap (FR-73), prompts for explicit rider consent (FR-14), and upon drop-off, automatically reassigns the rider's active hub to KLM-PLY so they immediately receive priority dispatch in their new zone."*

---

### Step 12: Customer Order History Verification
- **Device:** Physical Phone
- **Screen:** Customer Order History (`/customer/history`)
- **Actions:**
  1. On Physical Phone, open Customer navigation drawer or Order History.
  2. Pull down to refresh.
  3. Both placed orders (`ORD-20261019-XXXX` and `ORD-20261019-YYYY`) are listed with green **"Delivered"** badges.
- **UI Highlights:**
  - Full order summary, items list, total amounts, and delivery timestamps (FR-61).
- **Speaker Narration:**
  > *"Both customer orders are verified as delivered in the customer history ledger without polling overhead (FR-61)."*

---

### Step 13: Admin Pay Config & Mandatory 7-Day Advance Notice Enforcement
- **Device:** Physical Phone
- **Screen:** Admin Panel (`/admin/pay-config`)
- **Actions:**
  1. On Physical Phone, log out and log in as Admin: `admin@fairdrop.in` / `password123`.
  2. Active Pay Configuration is displayed (Base Rate: ₹15.00, Wait Threshold: 1 min).
  3. Show the Config History list displaying the initial baseline config.
  4. Tap **"Propose Pay Revision"**.
  5. Test Rule Violation (6-day notice):
     - Effective Date: Select a date **6 days from today**.
     - Base Rate: `18`
     - Reason: `Annual inflation review`
     - Tap **"Submit Revision"**.
     - An error dialog appears: *"HTTP 400: Minimum 7-day advance notice required by law."*
  6. Test Rule Compliance (8-day notice):
     - Effective Date: Select a date **8 days from today**.
     - Tap **"Submit Revision"**.
     - Review the **Old → New Configuration Diff Dialog** (FR-44).
     - Tap **"Confirm & Schedule"**.
- **UI Highlights:**
  - Server-enforced 7-day statutory notice rule (FR-41).
  - Old vs. New comparison diff dialog (FR-44).
  - Scheduled config appears in history with status: **"SCHEDULED"** (FR-39).
- **Speaker Narration:**
  > *"This demonstrates Fairwork Principle 3 (Fair Contracts). Arbitrary, unannounced wage cuts are illegal under our model. Any pay configuration change requires a recorded justification and a mandatory 7-day advance notice. The backend strictly rejects a 6-day notice, while an 8-day notice is scheduled and broadcast to rider profiles."*

---

### Step 14: Rider Logout & Offline Synchronization
- **Device:** Android Emulator
- **Screen:** Rider Profile & Home (`/rider/profile` → `/login`)
- **Actions:**
  1. On the Emulator, tap **"Logout"**.
  2. A confirmation prompt confirms session closure.
  3. Confirm logout; app returns to the Login Screen.
- **UI Highlights:**
  - `POST /api/riders/status` called with `is_online: false` (FR-54).
  - Active shift session closed with end timestamp.
  - Verification: If an order were placed right now, it would enter the `no_rider_available` queue rather than being dispatched to the logged-out rider.
- **Speaker Narration:**
  > *"Logging out synchronizes the offline state to core-service (FR-54), closing the active shift session and ensuring the rider receives zero unallocated order notifications while off duty. This concludes our 14-step end-to-end demonstration, executed with 100% platform integrity and zero manual database intervention."*

---

## 6. Fairwork Principles Mapping (UI Evidence)

| Fairwork Principle | PRD Feature | Where Demonstrated | Status |
|---|---|---|---|
| **Fair Pay 1 (Minimum Wage Floor)** | Statutory ₹70/hr earnings floor | Step 9 (Ledger Line 6) & Step 10 (Dashboard compliance card) | **LIVE UI** |
| **Fair Pay 2 (Living Wage)** | Configurable wage constants | Step 13 (Admin pay configuration) | **LIVE UI** |
| **Fair Conditions 1 (Safety Onboarding)** | Safety checklist & equipment acknowledgment | Step 1 (Rider Signup & Onboarding) | **LIVE UI** |
| **Fair Conditions 2 (Wait & Return Compensation)** | ₹10/min wait compensation & out-of-zone hub reassignment | Step 8 (Timer), Step 9 (Ledger Line 3), Step 11 (Zone Map) | **LIVE UI** |
| **Fair Contracts 1 (Transparent Policy)** | Upfront pay formula & itemized ledger | Step 6 (Order Acceptance) & Step 9 (Delivery Summary) | **LIVE UI** |
| **Fair Contracts 2 (7-Day Notice & Reason)** | 7-day advance notice validation & mandatory audit reason | Step 13 (Admin Panel 6-day rejection / 8-day acceptance) | **LIVE UI** |
| **Fair Management 1 (Delay Challenge)** | Delay reporting with verified status badge | Step 8 (Delay dialog) & Step 9 (Verified badge) | **LIVE UI** |
| **Fair Management 2 (Grievance Submission)** | Direct appeal channel | Academic report & P2 form | Documented / P2 |
| **Fair Representation (Worker Voice)** | Collective feedback channel | Academic report | Documented |

---

## 7. Troubleshooting & Fail-Safe Recovery

| Symptom | Probable Cause | Immediate 10-Second Fix |
|---|---|---|
| Network error on Physical Phone | USB cable nudged; `adb reverse` dropped | Re-run: `adb -s <id> reverse tcp:3003 tcp:3003` and `adb -s <id> reverse tcp:3001 tcp:3001` |
| Incoming order does not appear on Emulator | Rider is offline | Tap status switch to toggle **ONLINE** on Rider Home. |
| Test rider already exists error | Leftover test from rehearsal | Run `npm run seed` in terminal; takes ~6 seconds to reset to pristine state. |
| Wait compensation is ₹0.00 | Picked up before 1 min elapsed | In Step 8, make sure the wait timer on screen reaches at least `01:05` before tapping "Picked Up". |
| WiFi network drops | Laptop disconnected | MongoDB Atlas is in the cloud; connect laptop to mobile hotspot (the app itself uses USB `127.0.0.1`). |
