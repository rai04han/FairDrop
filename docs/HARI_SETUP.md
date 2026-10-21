# FairDrop — Hari's Rehearsal & Testing Setup Guide

**Document Version:** 1.0 (Demo Rehearsal)  
**Branch:** `demo-rehearsal`  
**Target Tester:** Hari (25MCA025)  
**Academic Lead:** Raihan (25MCA044)  

---

## 1. Prerequisites

Before setting up the project on your development machine, ensure you have installed:
1. **Node.js**: v18.x or v20.x LTS (`node -v` and `npm -v`)
2. **Flutter SDK**: 3.x with Dart (`flutter --version` and `flutter doctor`)
3. **Android SDK & Platform Tools**: `adb` must be available in your PATH (`adb version`)
4. **MySQL Community Server**: Local instance running on port `3306` (`mysql --version`)
5. **MongoDB Atlas Network Access**: Your development machine's public IP address must be added to the MongoDB Atlas IP allowlist. Send your public IP to Raihan privately before starting.

---

## 2. Git Clone & Branching Workflow

1. Clone the repository and checkout the `demo-rehearsal` branch:
   ```bash
   git clone https://github.com/rai04han/FairDrop.git
   cd FairDrop
   git checkout demo-rehearsal
   ```
2. Create your own local testing branch:
   ```bash
   git checkout -b hari-rehearsal
   ```
3. **CRITICAL GIT RULE:**
   - **Never** commit directly to `demo-rehearsal` or `main`.
   - Never push directly to `origin/main`.
   - All tests, experiments, and logging should happen on your private branch (`hari-rehearsal`).

---

## 3. Environment & Security Configuration

> [!CAUTION]
> **CRITICAL SECURITY WARNING: ROTATED CREDENTIALS**  
> Any old credentials previously seen in git history or older documentation (`root123` or `fairdrop-dev-secret-do-not-use-in-production`) have been completely rotated and are **DEAD**. Never attempt to use or restore them.

### Step 3.1: Environment Files Setup
Copy the template example files in both services (and root if running root scripts directly):
```bash
cp core-service/.env.example core-service/.env
cp pay-service/.env.example pay-service/.env
```

### Step 3.2: Configure `core-service/.env`
Fill in the following variables:
- `PORT=3003`
- `MONGODB_URI`: You will receive the MongoDB Atlas connection string from Raihan privately.
  > [!IMPORTANT]
  > **DATABASE NAME ISOLATION:** You MUST configure a **different database name** in your URI from Raihan's (e.g. `.../fairdrop_core_hari?...`). The seed script and test suites wipe collections (`users`, `orders`, `zones`, `menuitems`). If we share a database name, running tests or seeds on either machine will instantly erase the other's test data!
- `JWT_SECRET`: Generate a random secure string (or ask Raihan for the shared secret).
- `JWT_EXPIRES_IN=24h`
- `PAY_SERVICE_URL=http://localhost:3001`

### Step 3.3: Configure `pay-service/.env`
Fill in the following variables:
- `DB_HOST=localhost`
- `DB_PORT=3306`
- `DB_USER=root`
- `DB_PASSWORD`: Set your own local MySQL password.
- `DB_NAME=fairdrop_pay`
- `PORT=3001`
- `JWT_SECRET`: Must be **identical** to the `JWT_SECRET` set in `core-service/.env`.
- `# FLOOR_WINDOW_MINUTES_OVERRIDE=2` (Keep commented out for default 60-min window; uncomment for 2-min rapid testing).

> [!NOTE]
> Never commit `.env` files to git. They are protected by `.gitignore`.

---

## 4. MySQL Database Setup & Recreation

The MySQL schema changed in this release to support the FairDrop per-order incentive (`incentive_per_order` in `pay_configs`) and updated delivery ledger structures.

> [!WARNING]
> This command completely drops and recreates `fairdrop_pay`, wiping any existing local MySQL data.

Run the following commands in PowerShell or Bash:
```bash
mysql -u root -p -e "DROP DATABASE IF EXISTS fairdrop_pay; CREATE DATABASE fairdrop_pay;"
mysql -u root -p fairdrop_pay < database/mysql/schema.sql
```

---

## 5. Install Dependencies & Seed Database

1. Install npm dependencies in all projects:
   ```bash
   npm install
   cd core-service && npm install && cd ..
   cd pay-service && npm install && cd ..
   cd fairdrop_app && flutter pub get && cd ..
   ```

2. Seed the pristine demo data:
   ```bash
   npm run seed
   ```
   *Expected output:* `Demo Seed Complete & Verified!` with verified point-in-polygon spatial constraints for Hotel Arun, Marina, Pin A, and Pin B.

---

## 6. Start Microservices & Verify Health

Open two dedicated terminals:

**Terminal 1 (core-service):**
```bash
cd core-service
npm start
```
*Listens on port 3003.*

**Terminal 2 (pay-service):**
```bash
cd pay-service
npm start
```
*Listens on port 3001.*

**Verification:**
Test both services from a third terminal:
```bash
curl http://localhost:3003/health
curl http://localhost:3001/health
curl http://localhost:3001/api/health
```
All must return HTTP `200 OK`.

---

## 7. Transport Setup (`adb reverse`)

Connect your physical Android phone via USB (with USB Debugging enabled) and start the Android emulator.

1. List attached devices:
   ```bash
   adb devices
   ```
2. Configure port forwarding for each device:
   ```bash
   # For Android Emulator:
   adb -s emulator-5554 reverse tcp:3003 tcp:3003
   adb -s emulator-5554 reverse tcp:3001 tcp:3001

   # For Physical Phone (replace <device_id> with phone ID from adb devices):
   adb -s <device_id> reverse tcp:3003 tcp:3003
   adb -s <device_id> reverse tcp:3001 tcp:3001
   ```

> [!TIP]
> The app is pre-configured with host `127.0.0.1` in `lib/config/app_config.dart`. USB `adb reverse` routes traffic directly through the laptop without relying on local Wi-Fi or router subnet IP changes. If either device disconnects or sleeps, re-run the `adb reverse` commands.

---

## 8. App Installation & Launch

You can run the app directly or install the pre-built release APK:

### Option A: Install Release APK (Recommended for phone)
```bash
adb -s <device_id> install fairdrop_app/build/app/outputs/flutter-apk/app-release.apk
```

### Option B: Flutter Run (Recommended for emulator)
```bash
cd fairdrop_app
flutter run -d emulator-5554
```

---

## 9. Seeded Demo Accounts

All seeded accounts use password: `password123`

| Persona | Email | Purpose / Notes |
|---|---|---|
| **Rider 1** | `rider1@fairdrop.in` | Assigned to `KLM-CHK` (Chinnakkada Hub) |
| **Rider 2** | `rider2@fairdrop.in` | Assigned to `KLM-PLY` (Polayathode Hub) |
| **Rider 3** | `rider3@fairdrop.in` | Assigned to `KLM-KLK` (Kilikolloor Hub) |
| **New Rider** | `rider_new@fairdrop.in` | Clean-state rider with 0 deliveries; tests zero-data home screen & shift card |
| **Customer 1** | `john@fairdrop.in` | Seeded customer placing orders |
| **Customer 2** | `priya@fairdrop.in` | Secondary customer |
| **Restaurant 1** | `arun@fairdrop.in` | Hotel Arun (in `KLM-CHK`); Chicken Biryani ₹180 |
| **Restaurant 2** | `marina@fairdrop.in` | Marina (in `KLM-PLY`); Veg Meals ₹90 |
| **Admin** | `admin@fairdrop.in` | Config revision, 7-day advance notice, wage guarantees |

---

## 10. Demonstration Sequence (PRD §10.2)

1. **Step 1 (Emulator / Rider):** Sign up as a new rider or log in as `rider_new@fairdrop.in`. Verify active hub shows `KLM-CHK` and stats show clean zeros. Tap Go Online.
2. **Step 2 (Phone / Restaurant):** Log in as `arun@fairdrop.in`. Add a menu item with prep time, edit an item, and toggle item `item-102` to UNAVAILABLE.
3. **Step 3 (Phone / Customer):** Log out restaurant, log in as `john@fairdrop.in`. Select Pin A. Confirm unavailable item cannot be added. Add 2 Biryani to cart (subtotal = ₹360, customer fee = ₹0).
4. **Step 4 (Phone / Customer):** Proceed through mock payment and tap Place Order. Order ID generated.
5. **Step 5 (Backend):** Order automatically allocated to online rider in `KLM-CHK`.
6. **Step 6 (Emulator / Rider):** Order offer card appears with upfront formula and `+₹17.04 FairDrop incentive`. Rider accepts order.
7. **Step 7 (Phone / Restaurant):** Pull-to-refresh on Orders screen; order status transitions to ready when prep time passes.
8. **Step 8 (Emulator / Rider):** Rider taps "Arrived at Restaurant", waits > 1 min (threshold), taps "Picked Up", then taps "Delivered".
9. **Step 9 (Emulator / Rider):** Delivery Summary displays full 7-line itemized ledger matching pay-service response with non-zero wait compensation and FairDrop incentive.
10. **Step 10 (Emulator / Rider):** Dashboard reflects completed delivery. Analytics displays balanced comparison with equal pay at 27 orders.
11. **Step 11 (Customer & Rider):** Place second order with drop-off at Pin B. Out-of-zone banner and consent displayed. Upon delivery, Zone Map confirms automatic zone migration to `KLM-PLY`.
12. **Step 12 (Phone / Customer):** Customer checks Order History; orders shown as Delivered.
13. **Step 13 (Phone / Admin):** Log in as `admin@fairdrop.in`. Inspect active config and revision history. Test creating config 6 days out (rejected with 400); test creating config 8 days out (accepted with 200). Tap Logout from AppBar.
14. **Step 14 (Emulator / Rider):** Rider taps Go Offline and logs out. Verify offline status on server.

---

## 11. How to Report Findings

If you encounter any anomaly, layout exception, or failure during rehearsal, report it immediately in this format:

```markdown
### Finding Report
- **Step Number**: Step X (e.g. Step 8: Order Transition)
- **Device**: Physical Phone (e.g. Samsung Galaxy M31, Android 12) / Emulator (API 34)
- **Account**: rider_new@fairdrop.in
- **Expected**: Delivery summary renders 7-line breakdown without RenderFlex overflow.
- **Actual**: Red overflow bar on bottom right (overflowed by 14 pixels).
- **Screenshot**: [Attach image / photo of screen]
- **Service Logs (last 20 lines)**:
  ```text
  [paste output from core-service or pay-service terminal here]
  ```
- **Suspected Component**: fairdrop_app/lib/screens/pay_breakdown_screen.dart
```
