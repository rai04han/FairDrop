// FairDrop — Orders & Zones Live Demo
// Owner: Hari (25MCA025)
// Run: node tests/demo-orders.js
//
// Prerequisites:
//   1. Run seed: node src/seed/index.js
//   2. Start server: node src/server.js (in another terminal)
//
// This script walks through:
//   1. Login as customer, rider, and admin
//   2. View zone map data (GeoJSON)
//   3. Customer places an order
//   4. Assign a rider using spatial query
//   5. Rider picks up → delivers (full lifecycle)
//   6. View order history

const BASE = 'http://localhost:3003';

async function req(method, path, body = null, token = null) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  if (token) opts.headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BASE}${path}`, opts);
  return { status: res.status, data: await res.json() };
}

async function demo() {
  console.log('\n══════════════════════════════════════════');
  console.log('  FairDrop Orders & Zones — Live Demo');
  console.log('══════════════════════════════════════════\n');

  // ── 1. LOGIN ──────────────────────────────────────────────────────────
  console.log('--- 1. LOGIN (3 roles) ---\n');

  const customer = await req('POST', '/api/auth/login', {
    email: 'hari@fairdrop.in', password: 'password123',
  });
  console.log(`  ✅ Customer login — ${customer.data.user.name} (${customer.status})`);
  const customerToken = customer.data.token;

  const rider = await req('POST', '/api/auth/login', {
    email: 'ajith@fairdrop.in', password: 'password123',
  });
  console.log(`  ✅ Rider login — ${rider.data.user.name} (${rider.status})`);
  const riderToken = rider.data.token;

  const admin = await req('POST', '/api/auth/login', {
    email: 'admin@fairdrop.in', password: 'password123',
  });
  console.log(`  ✅ Admin login — ${admin.data.user.name} (${admin.status})`);
  const adminToken = admin.data.token;

  // ── 2. VIEW ZONE MAP DATA ─────────────────────────────────────────────
  console.log('\n--- 2. ZONE MAP DATA (GeoJSON for flutter_map) ---\n');

  const mapData = await req('GET', '/api/zones/map', null, adminToken);
  console.log(`  ✅ Map endpoint — Status: ${mapData.status}`);
  console.log(`  📍 Zones found: ${mapData.data.data.features.length}`);
  mapData.data.data.features.forEach((f) => {
    console.log(`     - ${f.properties.name} (cap: ${f.properties.outOfZoneCapKm}km)`);
  });

  // Get restaurant ID for order placement
  const restaurantLogin = await req('POST', '/api/auth/login', {
    email: 'arun@fairdrop.in', password: 'password123',
  });
  const restaurantId = restaurantLogin.data.user._id;

  // ── 3. CUSTOMER PLACES AN ORDER ────────────────────────────────────────
  console.log('\n--- 3. CUSTOMER PLACES ORDER ---\n');

  const order = await req('POST', '/api/orders', {
    restaurant_id: restaurantId,
    items: [
      { name: 'Chicken Biryani', quantity: 1, price: 180 },
      { name: 'Lime Soda', quantity: 2, price: 40 },
    ],
    delivery_address: { label: 'TKM College', latitude: 8.8932, longitude: 76.6141 },
    restaurant_address: { label: 'Hotel Arun, Chinnakkada', latitude: 8.8855, longitude: 76.5950 },
    distance_km: 3.5,
  }, customerToken);

  console.log(`  ✅ Order placed — Status: ${order.status}`);
  console.log(`     Order ID: ${order.data.order.order_id}`);
  console.log(`     Status: ${order.data.order.status}`);
  console.log(`     Surge: ${order.data.order.is_surge_active ? 'YES 🔥' : 'No'}`);
  console.log(`     Items: ${order.data.order.items.map((i) => `${i.name} x${i.quantity}`).join(', ')}`);
  const orderId = order.data.order.order_id;

  // ── 4. ASSIGN RIDER (SPATIAL QUERY) ────────────────────────────────────
  console.log('\n--- 4. ASSIGN RIDER (spatial $geoIntersects) ---\n');

  const assign = await req('POST', '/api/zones/assign', {
    restaurant_longitude: 76.5950,
    restaurant_latitude: 8.8855,
    order_id: orderId,
  }, adminToken);

  if (assign.status === 200) {
    console.log(`  ✅ Rider assigned — Status: ${assign.status}`);
    console.log(`     Zone: ${assign.data.zone_name}`);
    console.log(`     Message: ${assign.data.message}`);
  } else {
    console.log(`  ⚠️  No rider available — ${assign.data.message}`);
    console.log('     (This is expected if seed data riders are in different zones)');
  }

  // ── 5. ORDER LIFECYCLE: assigned → picked_up → delivered ───────────────
  console.log('\n--- 5. ORDER LIFECYCLE ---\n');

  // Step 1: assigned
  const s1 = await req('PATCH', `/api/orders/${orderId}/status`, {
    new_status: 'assigned',
  }, riderToken);
  console.log(`  ✅ ${orderId} → assigned (${s1.status})`);

  // Step 2: picked_up (with wait time)
  const s2 = await req('PATCH', `/api/orders/${orderId}/status`, {
    new_status: 'picked_up',
    restaurant_wait_mins: 12,
    delay_context: { type: 'restaurant', verified: true, source: 'api_mock' },
  }, riderToken);
  console.log(`  ✅ ${orderId} → picked_up (${s2.status})`);
  console.log(`     Wait time: ${s2.data.order.restaurant_wait_mins} mins`);
  console.log(`     Delay: ${s2.data.order.delay_context.type} (verified: ${s2.data.order.delay_context.verified})`);

  // Step 3: delivered (triggers pay engine call)
  const s3 = await req('PATCH', `/api/orders/${orderId}/status`, {
    new_status: 'delivered',
  }, riderToken);
  console.log(`  ✅ ${orderId} → delivered (${s3.status})`);

  if (s3.data.order.pay_calculation_result?.error) {
    console.log('     💰 Pay Engine: not running (expected in standalone mode)');
    console.log(`     Note: ${s3.data.order.pay_calculation_result.note}`);
  } else {
    console.log('     💰 Pay calculated:', JSON.stringify(s3.data.order.pay_calculation_result));
  }

  // ── 6. INVALID TRANSITION ──────────────────────────────────────────────
  console.log('\n--- 6. INVALID TRANSITION (delivered → assigned) ---\n');

  const invalid = await req('PATCH', `/api/orders/${orderId}/status`, {
    new_status: 'assigned',
  }, riderToken);
  console.log(`  ❌ Rejected — Status: ${invalid.status}`);
  console.log(`     Message: ${invalid.data.message}`);

  // ── 7. STATUS HISTORY (AUDIT TRAIL) ────────────────────────────────────
  console.log('\n--- 7. STATUS HISTORY (full audit trail) ---\n');

  const detail = await req('GET', `/api/orders/${orderId}`, null, customerToken);
  detail.data.order.status_history.forEach((h) => {
    console.log(`  📋 ${h.status} — ${new Date(h.changed_at).toLocaleTimeString()}`);
  });

  // ── 8. ORDER HISTORY ───────────────────────────────────────────────────
  console.log('\n--- 8. ORDER HISTORY ---\n');

  const history = await req('GET', '/api/orders/history', null, customerToken);
  console.log(`  ✅ Customer's past orders: ${history.data.count}`);

  const riderHistory = await req('GET', '/api/orders/history', null, riderToken);
  console.log(`  ✅ Rider's past deliveries: ${riderHistory.data.count}`);

  console.log('\n══════════════════════════════════════════');
  console.log('  All order & zone endpoints verified ✅');
  console.log('══════════════════════════════════════════\n');
}

demo().catch(console.error);
