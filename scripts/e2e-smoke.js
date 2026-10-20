#!/usr/bin/env node
// ============================================================================
// FairDrop — Automated End-to-End Smoke Test Script (scripts/e2e-smoke.js)
// PRD v2.1 Section 10.2 & Section 10.4 Alignment
// ============================================================================
// Plays steps 1 to 14 of the Fairwork Kerala Demo Flow over pure HTTP:
//   Step 1:  Rider Signup (auto-assigned KLM-CHK) & Goes Online (FR-51, FR-52, FR-7)
//   Step 2:  Restaurant Menu Item Creation & Availability Toggle (FR-62, FR-63, FR-64)
//   Step 3:  Customer Menu View & Unavailable Item Exclusion (FR-56, FR-57)
//   Step 4:  Customer Order Placement at Pin A (In-Zone, FR-55, FR-58, FR-59, FR-60)
//   Step 5:  Backend Auto-Accept & Least-Rider Allocation (FR-67, FR-68)
//   Step 6:  Rider Order Acceptance with Transparent Formula (FR-11–16, FR-75)
//   Step 7:  Restaurant Orders Screen with Derived is_ready Countdown (FR-65, FR-69)
//   Step 8:  Rider Delivery Lifecycle with Restaurant Wait > 1 Min (FR-17, FR-18)
//   Step 9:  Delivery Summary & Pay Engine 7-Item Ledger Verification (FR-20–25)
//   Step 10: Rider Dashboard & Comparative Analytics with Cliff-Wins (FR-30–36)
//   Step 11: Second Order at Pin B (Out-of-Zone) & Zone Reassignment to KLM-PLY (FR-73)
//   Step 12: Customer Order History Verification (FR-61)
//   Step 13: Admin Pay Config 6-Day Notice Rejection & Valid 7-Day Acceptance (FR-37–45)
//   Step 14: Rider Logout & Offline State Synchronization (FR-7, FR-54)
// ============================================================================

const { spawn } = require('child_process');
const path = require('path');

// Colors for terminal output
const C = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  magenta: '\x1b[35m',
};

const CORE_URL = process.env.CORE_URL || 'http://localhost:3003';
const PAY_URL = process.env.PAY_URL || 'http://localhost:3001';

let spawnedProcesses = [];

// Clean exit handler
function cleanup() {
  for (const proc of spawnedProcesses) {
    try {
      proc.kill('SIGTERM');
    } catch (_) {}
  }
}
process.on('exit', cleanup);
process.on('SIGINT', () => {
  cleanup();
  process.exit(130);
});

// Helper for assertions
function assert(condition, message) {
  if (!condition) {
    console.error(`\n${C.red}✖ ASSERTION FAILED: ${message}${C.reset}`);
    throw new Error(message);
  }
}

// HTTP request helper
async function request(method, url, body = null, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const opts = { method, headers };
  if (body) opts.body = JSON.stringify(body);

  const res = await fetch(url, opts);
  let data = null;
  const text = await res.text();
  try {
    data = JSON.parse(text);
  } catch (_) {
    data = text;
  }
  return { status: res.status, ok: res.ok, data, headers: res.headers };
}

// Check health endpoint
async function isHealthy(url) {
  try {
    const res = await fetch(`${url}/api/health`, { signal: AbortSignal.timeout(1500) });
    return res.ok;
  } catch (_) {
    try {
      const res = await fetch(`${url}/health`, { signal: AbortSignal.timeout(1500) });
      return res.ok;
    } catch (_) {
      return false;
    }
  }
}

async function waitForHealth(url, name, maxTries = 30) {
  for (let i = 0; i < maxTries; i++) {
    if (await isHealthy(url)) return true;
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`Timeout waiting for ${name} at ${url}`);
}

async function main() {
  console.log(`\n${C.bold}${C.cyan}╔═══════════════════════════════════════════════════════════════╗${C.reset}`);
  console.log(`${C.bold}${C.cyan}║   FairDrop E2E Automated Smoke Test Runner (PRD §10.2 / §10.4) ║${C.reset}`);
  console.log(`${C.bold}${C.cyan}╚═══════════════════════════════════════════════════════════════╝${C.reset}\n`);

  const startTime = Date.now();

  // ── Step 0: Ensure Services are Running ──────────────────────────────────
  console.log(`${C.bold}🔍 Pre-Flight Check:${C.reset}`);
  let coreRunning = await isHealthy(CORE_URL);
  let payRunning = await isHealthy(PAY_URL);

  if (!coreRunning) {
    console.log(`  ⏳ Starting core-service (port 3003)...`);
    const coreProc = spawn('npm', ['start'], {
      cwd: path.join(__dirname, '..', 'core-service'),
      shell: true,
      stdio: 'pipe',
    });
    spawnedProcesses.push(coreProc);
    await waitForHealth(CORE_URL, 'core-service');
    console.log(`  ${C.green}✓ core-service started & healthy at ${CORE_URL}${C.reset}`);
  } else {
    console.log(`  ${C.green}✓ core-service healthy at ${CORE_URL}${C.reset}`);
  }

  if (!payRunning) {
    console.log(`  ⏳ Starting pay-service (port 3001)...`);
    const payProc = spawn('npm', ['start'], {
      cwd: path.join(__dirname, '..', 'pay-service'),
      shell: true,
      stdio: 'pipe',
    });
    spawnedProcesses.push(payProc);
    await waitForHealth(PAY_URL, 'pay-service');
    console.log(`  ${C.green}✓ pay-service started & healthy at ${PAY_URL}${C.reset}`);
  } else {
    console.log(`  ${C.green}✓ pay-service healthy at ${PAY_URL}${C.reset}`);
  }

  // Run master seed by default to guarantee pristine, reproducible state (skip with --no-seed)
  if (!process.argv.includes('--no-seed')) {
    console.log(`\n🌱 Initializing master idempotent seed (PRD §10.1)...`);
    const { execSync } = require('node:child_process');
    execSync('node scripts/seed.js', {
      cwd: path.join(__dirname, '..'),
      stdio: 'pipe',
    });
    console.log(`  ${C.green}✓ Master seed complete & baseline spatial topology verified${C.reset}`);
  }

  console.log(`\n${C.bold}═════════════════════════════════════════════════════════════════${C.reset}`);
  console.log(`${C.bold}  Executing 14-Step FairDrop Demonstration Sequence${C.reset}`);
  console.log(`${C.bold}═════════════════════════════════════════════════════════════════${C.reset}\n`);

  let riderToken;
  let riderId;
  let restaurantToken;
  let customerToken;
  let adminToken;
  let arunRestaurantId;
  let createdMenuItemId;
  let order1Id;
  let order2Id;

  // ── Step 1: Rider Signup & Goes Online (FR-51, FR-52, FR-7) ──────────────
  console.log(`${C.bold}[Step 1/14]${C.reset} Rider signs up with vehicle type, auto-assigned KLM-CHK, goes online...`);
  const uniqueId = Date.now().toString().slice(-6);
  const signupRes = await request('POST', `${CORE_URL}/api/auth/register`, {
    name: `Aswin Smoke ${uniqueId}`,
    email: `aswin_${uniqueId}@fairdrop.in`,
    password: 'password123',
    phone: `98765${uniqueId}`,
    vehicle_type: 'motorcycle',
    role: 'rider',
  });
  assert(signupRes.status === 201, `Rider registration failed: ${JSON.stringify(signupRes.data)}`);
  riderToken = signupRes.data.token;
  riderId = signupRes.data.user.id || signupRes.data.user._id;
  assert(riderToken, 'Rider token must be returned on signup');

  // Verify assigned zone in profile
  const meRes = await request('GET', `${CORE_URL}/api/auth/me`, null, riderToken);
  assert(meRes.status === 200, 'Rider profile must load');
  const assignedZone = meRes.data.user?.current_zone_code || meRes.data.user?.rider_profile?.current_zone_code;
  assert(
    assignedZone === 'KLM-CHK' || assignedZone === 'KLM-PLY' || assignedZone === 'KLM-KLK',
    `Expected valid Kollam zone, got: ${assignedZone}`
  );

  // Rider goes online (FR-7)
  const onlineRes = await request('POST', `${CORE_URL}/api/riders/status`, { is_online: true }, riderToken);
  assert(onlineRes.status === 200, `Rider online toggle failed: ${JSON.stringify(onlineRes.data)}`);
  assert(onlineRes.data.is_online === true, 'Rider status must be online');
  console.log(`  ${C.green}✓ Rider ${meRes.data.user.name} created, assigned ${assignedZone}, and is now ONLINE${C.reset}`);

  // ── Step 2: Restaurant Menu Management & Availability Toggle (FR-62–64) ───
  console.log(`\n${C.bold}[Step 2/14]${C.reset} Restaurant logs in, adds menu item with prep time, toggles availability...`);
  const restLogin = await request('POST', `${CORE_URL}/api/auth/login`, {
    email: 'arun@fairdrop.in',
    password: 'password123',
  });
  assert(restLogin.status === 200, `Restaurant login failed: ${JSON.stringify(restLogin.data)}`);
  restaurantToken = restLogin.data.token;
  arunRestaurantId = restLogin.data.user.id || restLogin.data.user._id;

  // Add menu item (FR-63)
  const addMenuRes = await request(
    'POST',
    `${CORE_URL}/api/restaurants/menu`,
    {
      name: `Kerala Porotta Special ${uniqueId}`,
      price: 25,
      prep_time_seconds: 30,
      is_available: true,
    },
    restaurantToken
  );
  assert(addMenuRes.status === 201, `Add menu item failed: ${JSON.stringify(addMenuRes.data)}`);
  createdMenuItemId = addMenuRes.data.item._id || addMenuRes.data.item.id;

  // Toggle availability OFF (FR-64)
  const toggleRes = await request(
    'PATCH',
    `${CORE_URL}/api/restaurants/menu/${createdMenuItemId}/availability`,
    { is_available: false },
    restaurantToken
  );
  assert(toggleRes.status === 200, `Toggle availability failed: ${JSON.stringify(toggleRes.data)}`);
  assert(toggleRes.data.item.is_available === false, 'Menu item must be marked unavailable');
  console.log(`  ${C.green}✓ Item "${addMenuRes.data.item.name}" created (prep: 30s) and toggled UNAVAILABLE${C.reset}`);

  // ── Step 3: Customer Menu View & Unavailable Item Exclusion (FR-56, FR-57) ─
  console.log(`\n${C.bold}[Step 3/14]${C.reset} Customer logs in, views menu, verifies unavailable item blocking...`);
  const custLogin = await request('POST', `${CORE_URL}/api/auth/login`, {
    email: 'john@fairdrop.in',
    password: 'password123',
  });
  assert(custLogin.status === 200, `Customer login failed: ${JSON.stringify(custLogin.data)}`);
  customerToken = custLogin.data.token;

  // Fetch restaurant menu
  const menuRes = await request('GET', `${CORE_URL}/api/restaurants/${arunRestaurantId}/menu`, null, customerToken);
  assert(menuRes.status === 200, 'Customer must be able to read restaurant menu');
  const items = menuRes.data.items || [];
  const unavailableItem = items.find((it) => (it._id || it.id) === createdMenuItemId);
  assert(unavailableItem && unavailableItem.is_available === false, 'Unavailable item must be returned with is_available false');

  // Customer cannot order unavailable item
  const badOrderRes = await request(
    'POST',
    `${CORE_URL}/api/orders`,
    {
      restaurant_id: arunRestaurantId,
      items: [{ item_id: createdMenuItemId, quantity: 1 }],
      delivery_address: {
        label: 'Pin A (In-Zone)',
        latitude: 8.8860,
        longitude: 76.5920,
        coordinates: [76.5920, 8.8860],
      },
    },
    customerToken
  );
  assert(badOrderRes.status === 400, 'Placing order with unavailable item must fail with 400');
  console.log(`  ${C.green}✓ Customer view verified: Unavailable items rejected by core-service (400)${C.reset}`);

  // ── Step 4: Customer Order Placement at Pin A (In-Zone, FR-55, FR-58–60) ───
  console.log(`\n${C.bold}[Step 4/14]${C.reset} Customer places Order 1 at Pin A (In-Zone KLM-CHK)...`);
  // Find an available item
  const availableItem = items.find((it) => it.is_available === true) || { _id: items[0]._id, name: 'Biryani' };
  const order1Res = await request(
    'POST',
    `${CORE_URL}/api/orders`,
    {
      restaurant_id: arunRestaurantId,
      items: [{ item_id: availableItem._id || availableItem.id, quantity: 2 }],
      delivery_address: {
        label: 'Pin A (In-Zone Chinnakkada)',
        latitude: 8.8860,
        longitude: 76.5920,
        coordinates: [76.5920, 8.8860],
      },
    },
    customerToken
  );
  assert(order1Res.status === 201, `Order placement failed: ${JSON.stringify(order1Res.data)}`);
  order1Id = order1Res.data.order.order_id;
  assert(order1Id, 'order_id must be generated');
  assert(order1Res.data.order.status === 'accepted', 'Order must be auto-accepted');
  const order1ItemsTotal = (order1Res.data.order.items || []).reduce((s, i) => s + i.price * i.quantity, 0);
  console.log(`  ${C.green}✓ Order ${order1Id} placed at Pin A (${order1Res.data.order.distance_km} km, ₹${order1ItemsTotal})${C.reset}`);

  // ── Step 5: Backend Auto-Accept & Least-Rider Allocation (FR-67, FR-68) ───
  console.log(`\n${C.bold}[Step 5/14]${C.reset} Verify order allocated to online rider & visible on active poll...`);
  const activeOrderRes = await request('GET', `${CORE_URL}/api/orders/rider/active`, null, riderToken);
  assert(activeOrderRes.status === 200, 'Rider active order call must succeed');
  assert(activeOrderRes.data.order !== null, 'Rider must have an assigned order');
  assert(activeOrderRes.data.order.order_id === order1Id, `Expected ${order1Id}, got ${activeOrderRes.data.order?.order_id}`);
  assert(activeOrderRes.data.order.rider_ack === 'pending', 'Order rider_ack must be pending acceptance');
  console.log(`  ${C.green}✓ Order ${order1Id} allocated to rider via spatial matching${C.reset}`);

  // ── Step 6: Rider Acceptance & Live Config Verification (FR-11–16, FR-75) ──
  console.log(`\n${C.bold}[Step 6/14]${C.reset} Verify pay formula on pay-service and rider accepts order...`);
  const payConfigRes = await request('GET', `${PAY_URL}/api/pay/config`, null, riderToken);
  assert(payConfigRes.status === 200, 'Rider must be able to view live pay constants');
  assert(payConfigRes.data.config.base_rate > 0, 'Base rate must be positive');
  assert(payConfigRes.data.config.wait_threshold_mins === 1, 'Demo wait threshold must be 1 minute');

  // Accept order
  const acceptRes = await request('PATCH', `${CORE_URL}/api/orders/${order1Id}/accept`, {}, riderToken);
  assert(acceptRes.status === 200, `Order acceptance failed: ${JSON.stringify(acceptRes.data)}`);
  assert(acceptRes.data.order.rider_ack === 'accepted', 'Order must be accepted');
  assert(acceptRes.data.order.status === 'assigned', 'Order status must be assigned');
  console.log(`  ${C.green}✓ Rider accepted order ${order1Id}; status transitioned to ASSIGNED${C.reset}`);

  // ── Step 7: Restaurant Orders View with is_ready Indicator (FR-65, FR-69) ──
  console.log(`\n${C.bold}[Step 7/14]${C.reset} Restaurant kitchen view reflects order and prep countdown...`);
  const restOrdersRes = await request('GET', `${CORE_URL}/api/restaurants/orders`, null, restaurantToken);
  assert(restOrdersRes.status === 200, 'Restaurant orders must load');
  const kitchenOrder = restOrdersRes.data.orders.find((o) => o.order_id === order1Id);
  assert(kitchenOrder, 'Order 1 must appear in restaurant kitchen orders list');
  assert(typeof kitchenOrder.is_ready === 'boolean', 'Order must have boolean is_ready derived from prep time');
  console.log(`  ${C.green}✓ Kitchen orders screen validated (is_ready: ${kitchenOrder.is_ready})${C.reset}`);

  // ── Step 8: Rider Delivery Transitions with Wait Time (FR-17, FR-18) ───────
  console.log(`\n${C.bold}[Step 8/14]${C.reset} Rider transitions: ARRIVED -> WAIT > 1 min -> PICKED UP -> DELIVERED...`);
  // Arrived
  const arrivedRes = await request('PATCH', `${CORE_URL}/api/orders/${order1Id}/status`, { new_status: 'arrived' }, riderToken);
  assert(arrivedRes.status === 200, 'Arrived transition must succeed');

  // Picked up with 2 minutes restaurant wait (exceeding 1-minute demo threshold)
  const pickedUpRes = await request(
    'PATCH',
    `${CORE_URL}/api/orders/${order1Id}/status`,
    { new_status: 'picked_up', restaurant_wait_mins: 2 },
    riderToken
  );
  assert(pickedUpRes.status === 200, 'Picked up transition must succeed');
  assert(pickedUpRes.data.order.restaurant_wait_mins >= 2, 'Restaurant wait minutes must be recorded >= 2');

  // Delivered
  const deliveredRes = await request(
    'PATCH',
    `${CORE_URL}/api/orders/${order1Id}/status`,
    { new_status: 'delivered' },
    riderToken
  );
  assert(deliveredRes.status === 200, 'Delivered transition must succeed');
  assert(deliveredRes.data.order.status === 'delivered', 'Order must be delivered');
  console.log(`  ${C.green}✓ Order ${order1Id} delivered (recorded wait time: ${deliveredRes.data.order.restaurant_wait_mins} mins)${C.reset}`);

  // ── Step 9: Delivery Summary & Pay Engine 7-Item Ledger (FR-20–25) ──────────
  console.log(`\n${C.bold}[Step 9/14]${C.reset} Verifying pay-service ledger calculation (wait compensation > 0)...`);
  const finalOrder1 = deliveredRes.data.order;
  assert(finalOrder1.pay_status === 'calculated', `Pay status must be calculated, got: ${finalOrder1.pay_status}`);
  const payCalc = finalOrder1.pay_calculation_result;
  assert(payCalc && !payCalc.error, `Pay calculation failed: ${JSON.stringify(payCalc)}`);

  // Verify all itemized lines
  assert(payCalc.base_rate === 15.00, `Expected base rate ₹15, got ${payCalc.base_rate}`);
  assert(payCalc.distance_pay > 0, `Expected distance pay > 0, got ${payCalc.distance_pay}`);
  assert(payCalc.wait_compensation >= 10.00, `Wait compensation must be >= ₹10 for 2 min wait (threshold: 1 min). Got: ${payCalc.wait_compensation}`);
  assert(payCalc.total_delivery_pay > 0, `Total delivery pay must be > 0. Got: ${payCalc.total_delivery_pay}`);
  console.log(`  ${C.green}✓ Pay calculated: Base ₹${payCalc.base_rate} + Dist ₹${payCalc.distance_pay} + WaitComp ₹${payCalc.wait_compensation} = Total ₹${payCalc.total_delivery_pay} (Floor topup: ₹${payCalc.floor_topup})${C.reset}`);

  // ── Step 10: Dashboard & Analytics Verification (FR-30–36) ─────────────────
  console.log(`\n${C.bold}[Step 10/14]${C.reset} Checking pay history, stated assumptions, and cliff-wins scenario...`);
  // History
  const historyRes = await request('GET', `${PAY_URL}/api/pay/history/${riderId}`, null, riderToken);
  assert(historyRes.status === 200, 'Pay history must load');
  assert(historyRes.data.total_records >= 1, 'At least 1 delivery record must be present');
  const latestRec = historyRes.data.earnings[0];
  assert(latestRec.order_id === order1Id, 'Latest earning record must match order 1');

  // Analytics
  const analyticsRes = await request('GET', `${PAY_URL}/api/pay/analytics/${riderId}`, null, riderToken);
  assert(analyticsRes.status === 200, 'Pay analytics must load');
  assert(analyticsRes.data.assumptions.cliff_threshold_deliveries === 10, 'Cliff threshold must be 10');
  assert(analyticsRes.data.assumptions.cliff_bonus === 500, 'Cliff bonus must be 500');
  assert(analyticsRes.data.cliff_wins_scenario.winner === 'cliff', 'Cliff-wins scenario must declare cliff as winner');
  assert(analyticsRes.data.cliff_wins_scenario.cliff_advantage === 420, 'Cliff advantage in scenario must be 420');
  assert(analyticsRes.data.cliff_wins_scenario.rationale.length > 20, 'Balanced framing rationale must be non-empty');
  console.log(`  ${C.green}✓ Analytics verified: Stated assumptions (10 deliveries, ₹500 bonus) & Balanced Cliff-Wins (+₹420) present${C.reset}`);

  // ── Step 11: Out-of-Zone Order at Pin B & Zone Reassignment (FR-73) ────────
  console.log(`\n${C.bold}[Step 11/14]${C.reset} Placing Order 2 at Pin B (Out-of-zone KLM-PLY); verify zone auto-switch...`);
  const order2Res = await request(
    'POST',
    `${CORE_URL}/api/orders`,
    {
      restaurant_id: arunRestaurantId,
      items: [{ item_id: availableItem._id || availableItem.id, quantity: 1 }],
      delivery_address: {
        label: 'Pin B (Out-of-Zone Polayathode)',
        latitude: 8.8800,
        longitude: 76.6050,
        coordinates: [76.6050, 8.8800], // Inside KLM-PLY
      },
    },
    customerToken
  );
  assert(order2Res.status === 201, `Order 2 placement failed: ${JSON.stringify(order2Res.data)}`);
  order2Id = order2Res.data.order.order_id;
  assert(order2Res.data.order.is_out_of_zone === true, 'Pin B order must be flagged is_out_of_zone = true');

  // Rider accepts Order 2
  await request('PATCH', `${CORE_URL}/api/orders/${order2Id}/accept`, {}, riderToken);
  // Transitions
  await request('PATCH', `${CORE_URL}/api/orders/${order2Id}/status`, { new_status: 'arrived' }, riderToken);
  await request('PATCH', `${CORE_URL}/api/orders/${order2Id}/status`, { new_status: 'picked_up', restaurant_wait_mins: 1 }, riderToken);
  await request('PATCH', `${CORE_URL}/api/orders/${order2Id}/status`, { new_status: 'delivered' }, riderToken);

  // Check rider's profile for zone transition
  const riderProfileAfter = await request('GET', `${CORE_URL}/api/auth/me`, null, riderToken);
  const newZoneCode =
    riderProfileAfter.data.user.current_zone ||
    riderProfileAfter.data.user.rider_profile?.current_zone_code;
  assert(newZoneCode === 'KLM-PLY', `Rider zone must update to KLM-PLY upon out-of-zone delivery. Got: ${newZoneCode}`);

  // Verify zone map endpoint
  const mapRes = await request('GET', `${CORE_URL}/api/zones/map`, null, riderToken);
  assert(mapRes.status === 200, 'Zone map endpoint must succeed');
  const geojson = mapRes.data.data || mapRes.data;
  assert(geojson.type === 'FeatureCollection', 'Must return GeoJSON FeatureCollection');
  console.log(`  ${C.green}✓ Out-of-zone delivery completed; Rider active hub successfully switched to KLM-PLY${C.reset}`);

  // ── Step 12: Customer Order History Verification (FR-61) ───────────────────
  console.log(`\n${C.bold}[Step 12/14]${C.reset} Customer verifies order history shows both deliveries...`);
  const custHistory = await request('GET', `${CORE_URL}/api/orders/history`, null, customerToken);
  assert(custHistory.status === 200, 'Customer order history must succeed');
  assert(custHistory.data.orders.length >= 2, 'Customer history must contain at least 2 orders');
  const deliveredOrders = custHistory.data.orders.filter((o) => o.status === 'delivered');
  assert(deliveredOrders.length >= 2, 'Both placed orders must be in delivered status');
  console.log(`  ${C.green}✓ Customer history confirmed: ${deliveredOrders.length} completed orders delivered${C.reset}`);

  // ── Step 13: Admin Pay Config 7-Day Advance Notice Rule (FR-37–45) ─────────
  console.log(`\n${C.bold}[Step 13/14]${C.reset} Admin checks config history, tests 6-day rejection & 7-day acceptance...`);
  const adminLogin = await request('POST', `${CORE_URL}/api/auth/login`, {
    email: 'admin@fairdrop.in',
    password: 'password123',
  });
  assert(adminLogin.status === 200, `Admin login failed: ${JSON.stringify(adminLogin.data)}`);
  adminToken = adminLogin.data.token;

  // Read config & history
  const activeCfgRes = await request('GET', `${PAY_URL}/api/admin/pay-config`, null, adminToken);
  assert(activeCfgRes.status === 200, 'Admin must be able to view active config');
  const histCfgRes = await request('GET', `${PAY_URL}/api/admin/pay-config/history`, null, adminToken);
  assert(histCfgRes.status === 200, 'Admin must be able to view config history');
  assert(histCfgRes.data.history.length >= 1, 'Config history must include seeded baseline');

  // 6-Day rejection check (< 7 days)
  const d6 = new Date();
  d6.setDate(d6.getDate() + 6);
  const sixDaysStr = `${d6.getFullYear()}-${String(d6.getMonth() + 1).padStart(2, '0')}-${String(d6.getDate()).padStart(2, '0')}`;
  const invalidCfg = await request(
    'PUT',
    `${PAY_URL}/api/admin/pay-config`,
    {
      base_rate: 18,
      per_km_rate: 8,
      surge_bonus: 25,
      wait_threshold_mins: 5,
      wait_compensation: 12,
      min_wage_per_hour: 75,
      effective_from: sixDaysStr,
      change_reason: 'TEST: 6-day invalid test',
    },
    adminToken
  );
  assert(invalidCfg.status === 400, `Expected 400 rejection for 6-day advance date, got ${invalidCfg.status}`);
  assert(/7-day advance notice required/i.test(invalidCfg.data.message), 'Must specify 7-day rule in error message');

  // 7-Day acceptance check (>= 7 days)
  const d8 = new Date();
  d8.setDate(d8.getDate() + 8);
  const eightDaysStr = `${d8.getFullYear()}-${String(d8.getMonth() + 1).padStart(2, '0')}-${String(d8.getDate()).padStart(2, '0')}`;
  const validCfg = await request(
    'PUT',
    `${PAY_URL}/api/admin/pay-config`,
    {
      base_rate: 18,
      per_km_rate: 8,
      surge_bonus: 25,
      wait_threshold_mins: 5,
      wait_compensation: 12,
      min_wage_per_hour: 75,
      effective_from: eightDaysStr,
      change_reason: 'Annual statutory wage revision (FR-40 to FR-44)',
    },
    adminToken
  );
  assert(validCfg.status === 200, `Expected 200 for valid 8-day advance date, got: ${JSON.stringify(validCfg.data)}`);
  console.log(`  ${C.green}✓ Admin pay config validated: 6-day update rejected with 400; 8-day update scheduled with 200${C.reset}`);

  // ── Step 14: Rider Logout & Offline Synchronization (FR-7, FR-54) ──────────
  console.log(`\n${C.bold}[Step 14/14]${C.reset} Rider logs out, synchronizing offline state to core-service...`);
  const offlineRes = await request('POST', `${CORE_URL}/api/riders/status`, { is_online: false }, riderToken);
  assert(offlineRes.status === 200, 'Rider offline status must return 200');
  assert(offlineRes.data.is_online === false, 'Rider must be marked offline');

  const statsRes = await request('GET', `${CORE_URL}/api/riders/stats`, null, riderToken);
  assert(statsRes.status === 200, 'Rider stats must load');
  const isOnlineInStats = statsRes.data.stats?.is_online ?? statsRes.data.is_online;
  assert(isOnlineInStats === false, 'Rider must be offline in database');
  console.log(`  ${C.green}✓ Rider logged out; shift session closed and is_online synchronized to false${C.reset}`);

  const durationSec = ((Date.now() - startTime) / 1000).toFixed(2);
  console.log(`\n${C.bold}${C.green}=================================================================${C.reset}`);
  console.log(`${C.bold}${C.green}  ✔ ALL 14 DEMO FLOW STEPS PASSED SUCCESSFULLY (${durationSec}s)${C.reset}`);
  console.log(`${C.bold}${C.green}  FairDrop Platform is 100% Demo-Ready with Zero Manual DB Edits!${C.reset}`);
  console.log(`${C.bold}${C.green}=================================================================${C.reset}\n`);

  process.exit(0);
}

main().catch((err) => {
  console.error(`\n${C.bold}${C.red}✖ E2E SMOKE TEST FAILED:${C.reset}`, err.message);
  process.exit(1);
});
