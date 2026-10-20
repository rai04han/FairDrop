// FairDrop — Order Module Tests
// Owner: Hari (25MCA025)
// Runner: Node.js built-in test runner (node:test)
// Run: node --test tests/orders.test.js
//
// Integration tests covering:
//   - DB item pricing & unavailable item rejection (FR-58, FR-240)
//   - Haversine distance computation on server (FR-70, D9)
//   - Auto-accept at placement (FR-66, FR-67)
//   - Zone-based allocation & out-of-zone cap (FR-68, FR-73, D2)
//   - Unallocated orders when no rider available (FR-60, D6)
//   - Allocation when rider goes online (FR-72)
//   - Accept & decline actions without penalty (FR-15, D7)
//   - Full status lifecycle transitions & pay trigger

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const app = require('../src/app');
const env = require('../src/config/env');
const User = require('../src/modules/auth/User.model');
const Zone = require('../src/modules/zones/Zone.model');
const MenuItem = require('../src/modules/orders/MenuItem.model');
const Order = require('../src/modules/orders/Order.model');

let server;
let baseUrl;

// Tokens and entities
let customerToken;
let customerId;
let riderToken;
let riderUser;
let secondRiderToken;
let secondRiderUser;
let restaurantToken;
let restaurantId;
let chinnakkadaZone;
let polayathodeZone;
let testOrderId;
let dosaItem;
let unavailableItem;

before(async () => {
  const testDbUri = env.MONGODB_URI.replace('fairdrop_core', 'fairdrop_core_test');
  await mongoose.connect(testDbUri);
  await mongoose.connection.db.dropDatabase();

  server = app.listen(0);
  const port = server.address().port;
  baseUrl = `http://localhost:${port}`;

  // ── Seed Zones ─────────────────────────────────────────────────────
  chinnakkadaZone = await Zone.create({
    name: 'Chinnakkada',
    zone_id: 'KLM-CHK',
    boundary: {
      type: 'Polygon',
      coordinates: [[
        [76.5800, 8.8800],
        [76.6000, 8.8800],
        [76.6000, 8.8950],
        [76.5800, 8.8950],
        [76.5800, 8.8800],
      ]],
    },
    outOfZoneCapKm: 5,
  });

  polayathodeZone = await Zone.create({
    name: 'Polayathode',
    zone_id: 'KLM-PLY',
    boundary: {
      type: 'Polygon',
      coordinates: [[
        [76.6000, 8.8700],
        [76.6200, 8.8700],
        [76.6200, 8.8850],
        [76.6000, 8.8850],
        [76.6000, 8.8700],
      ]],
    },
    outOfZoneCapKm: 5,
  });

  // ── Register test users ────────────────────────────────────────────
  const register = async (data) => {
    const res = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return res.json();
  };

  const customer = await register({
    name: 'Customer',
    email: 'cust@test.com',
    password: 'password123',
    role: 'customer',
  });
  customerToken = customer.token;
  customerId = customer.user._id;

  const restaurant = await register({
    name: 'Hotel Arun',
    email: 'arun@test.com',
    password: 'password123',
    role: 'restaurant',
  });
  restaurantToken = restaurant.token;
  restaurantId = restaurant.user._id;

  // Set restaurant coordinates inside Chinnakkada zone
  await User.findByIdAndUpdate(restaurantId, {
    address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
  });

  // Register Rider 1
  const r1 = await register({
    name: 'Rider One',
    email: 'r1@test.com',
    password: 'password123',
    role: 'rider',
  });
  riderToken = r1.token;
  riderUser = await User.findById(r1.user._id);

  // Set Rider 1 to online in Chinnakkada zone
  riderUser.rider_profile.is_online = true;
  riderUser.rider_profile.is_available = true;
  riderUser.rider_profile.current_zone_id = chinnakkadaZone._id;
  riderUser.rider_profile.current_zone_code = 'KLM-CHK';
  await riderUser.save();

  // Register Rider 2
  const r2 = await register({
    name: 'Rider Two',
    email: 'r2@test.com',
    password: 'password123',
    role: 'rider',
  });
  secondRiderToken = r2.token;
  secondRiderUser = await User.findById(r2.user._id);
  secondRiderUser.rider_profile.is_online = true;
  secondRiderUser.rider_profile.current_zone_id = polayathodeZone._id;
  secondRiderUser.rider_profile.current_zone_code = 'KLM-PLY';
  await secondRiderUser.save();

  // ── Seed Menu Items for Restaurant ─────────────────────────────────
  dosaItem = await MenuItem.create({
    restaurant_id: restaurantId,
    name: 'Masala Dosa',
    price: 60,
    prep_time_seconds: 25,
    is_available: true,
  });

  unavailableItem = await MenuItem.create({
    restaurant_id: restaurantId,
    name: 'Special Biryani',
    price: 180,
    prep_time_seconds: 40,
    is_available: false,
  });
});

after(async () => {
  await mongoose.connection.db.dropDatabase();
  await mongoose.disconnect();
  server.close();
});

// Helper
async function req(method, path, body = null, token = null) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  if (token) opts.headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${baseUrl}${path}`, opts);
  return { status: res.status, data: await res.json() };
}

// ═══════════════════════════════════════════════════════════════════════════

describe('POST /api/orders (placement, pricing & allocation)', () => {
  test('rejects order with unavailable item — 400 (FR-57, FR-240)', async () => {
    const { status, data } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: unavailableItem._id, quantity: 1 }],
      delivery_address: { label: 'Pin A', latitude: 8.8860, longitude: 76.5920 },
      restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
    }, customerToken);

    assert.equal(status, 400);
    assert.match(data.message, /currently unavailable/i);
  });

  test('customer places order: DB price enforced (client price ignored) & haversine computed', async () => {
    const { status, data } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: dosaItem._id, quantity: 2, price: 9999 }], // Tampered client price!
      delivery_address: { label: 'Pin A', latitude: 8.8860, longitude: 76.5920 },
      restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
    }, customerToken);

    assert.equal(status, 201);
    assert.equal(data.success, true);
    assert.match(data.order.order_id, /^ORD-\d{8}-\d{4}$/);
    assert.equal(data.order.status, 'accepted'); // Auto-accepted per FR-67
    assert.equal(data.order.items[0].price, 60); // DB price strictly enforced!
    assert.equal(data.order.items[0].name, 'Masala Dosa');
    assert.ok(data.order.distance_km > 0, 'Distance should be computed via haversine');

    // Allocation check: Rider 1 was online in Chinnakkada (restaurant zone)
    assert.equal(data.allocation, 'allocated');
    assert.equal(data.order.rider_id.toString(), riderUser._id.toString());
    assert.equal(data.order.rider_ack, 'pending');

    testOrderId = data.order.order_id;
  });

  test('rider cannot place an order — 403', async () => {
    const { status } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: dosaItem._id, quantity: 1 }],
      delivery_address: { label: 'Pin A', latitude: 8.8860, longitude: 76.5920 },
    }, riderToken);

    assert.equal(status, 403);
  });

  test('rejects order without delivery address coordinates — 400', async () => {
    const { status, data } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: dosaItem._id, quantity: 1 }],
      delivery_address: { label: 'Nowhere' },
    }, customerToken);

    assert.equal(status, 400);
    assert.equal(data.success, false);
  });

  test('rejects order with non-existent restaurant — 404', async () => {
    const { status } = await req('POST', '/api/orders', {
      restaurant_id: '000000000000000000000000',
      items: [{ name: 'Masala Dosa', quantity: 1 }],
      delivery_address: { label: 'Pin A', latitude: 8.8860, longitude: 76.5920 },
    }, customerToken);

    assert.equal(status, 404);
  });
});

describe('Rider Acceptance & Decline (FR-15, FR-68, D7)', () => {
  test('rider accepts allocated order: rider_ack = accepted, status = assigned', async () => {
    const { status, data } = await req('PATCH', `/api/orders/${testOrderId}/accept`, {}, riderToken);

    assert.equal(status, 200);
    assert.equal(data.order.status, 'assigned');
    assert.equal(data.order.rider_ack, 'accepted');
  });

  test('order decline reallocates to another online idle rider (FR-15, D7)', async () => {
    // Create another order allocated to Rider 2 (since Rider 1 is busy with testOrderId)
    const { data: newOrderData } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: dosaItem._id, quantity: 1 }],
      delivery_address: { label: 'Pin A', latitude: 8.8860, longitude: 76.5920 },
      restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
    }, customerToken);

    assert.equal(newOrderData.allocation, 'allocated');
    const assignedRiderId = newOrderData.order.rider_id;

    // Rider 2 declines
    const { status, data } = await req(
      'PATCH',
      `/api/orders/${newOrderData.order.order_id}/decline`,
      {},
      secondRiderToken
    );

    assert.equal(status, 200);
    // Since Rider 1 is busy and Rider 2 declined, no other rider is available
    assert.equal(data.allocation, 'no_rider_available');
    assert.equal(data.order.rider_id, null);
    assert.ok(data.order.declined_by.map(id => id.toString()).includes(secondRiderUser._id.toString()));
  });
});

describe('Allocation Out-of-zone Cap & Fallback (FR-68, FR-73, D2, D3)', () => {
  test('order at Pin B (out-of-zone within cap) allocates with is_out_of_zone true', async () => {
    // Make Rider 2 available and idle
    await Order.deleteMany({ rider_id: secondRiderUser._id });
    secondRiderUser.rider_profile.is_online = true;
    secondRiderUser.rider_profile.is_available = true;
    secondRiderUser.rider_profile.current_zone_id = chinnakkadaZone._id;
    secondRiderUser.rider_profile.current_zone_code = 'KLM-CHK';
    await secondRiderUser.save();

    // Pin B is at (8.8800, 76.6050) — ~0.55 km outside Chinnakkada (cap 5 km)
    const { status, data } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: dosaItem._id, quantity: 1 }],
      delivery_address: { label: 'Pin B', latitude: 8.8800, longitude: 76.6050 },
      restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
    }, customerToken);

    assert.equal(status, 201);
    assert.equal(data.allocation, 'allocated');
    assert.equal(data.order.is_out_of_zone, true);
    assert.ok(data.order.out_of_zone_distance_km > 0 && data.order.out_of_zone_distance_km <= 5);
  });

  test('order far beyond out-of-zone cap does not allocate — no_rider_available', async () => {
    // Deliver / clear other orders
    await Order.updateMany({}, { status: 'delivered' });

    // Delivery 50 km away (far beyond 5 km cap)
    const { status, data } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: dosaItem._id, quantity: 1 }],
      delivery_address: { label: 'Far Away', latitude: 9.3000, longitude: 77.2000 },
      restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
    }, customerToken);

    assert.equal(status, 201);
    assert.equal(data.allocation, 'no_rider_available');
    assert.equal(data.order.rider_id, null);
  });
});

describe('Allocation Triggered on Rider Going Online (FR-72)', () => {
  test('unallocated accepted order gets allocated when an eligible rider goes online', async () => {
    // 1. Put all riders offline
    await User.updateMany({ role: 'rider' }, { 'rider_profile.is_online': false });

    // 2. Place order while everyone is offline
    const { data: placedData } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: dosaItem._id, quantity: 1 }],
      delivery_address: { label: 'Pin A', latitude: 8.8860, longitude: 76.5920 },
      restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
    }, customerToken);

    assert.equal(placedData.allocation, 'no_rider_available');
    assert.equal(placedData.order.status, 'accepted');
    assert.equal(placedData.order.rider_id, null);

    // 3. Rider 1 goes online
    const onlineRes = await req('POST', '/api/riders/status', { is_online: true }, riderToken);
    assert.equal(onlineRes.status, 200);

    // 4. Verify order was allocated to Rider 1
    const { data: fetchOrder } = await req('GET', `/api/orders/${placedData.order.order_id}`, null, customerToken);
    assert.equal(fetchOrder.order.rider_id.toString(), riderUser._id.toString());
    assert.equal(fetchOrder.order.rider_ack, 'pending');
    assert.equal(fetchOrder.order.allocation, 'allocated');
  });
});

describe('Order Lifecycle Transitions & Active Polling', () => {
  let flowOrderId;

  test('create order for transition flow', async () => {
    // Rider 1 is online and idle
    await Order.deleteMany({ rider_id: riderUser._id });

    const { status, data } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: dosaItem._id, quantity: 1 }],
      delivery_address: { label: 'Pin A', latitude: 8.8860, longitude: 76.5920 },
      restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
    }, customerToken);

    assert.equal(status, 201);
    flowOrderId = data.order.order_id;
  });

  test('GET /api/orders/rider/active returns order with pending ack', async () => {
    const { status, data } = await req('GET', '/api/orders/rider/active', null, riderToken);
    assert.equal(status, 200);
    assert.ok(data.order);
    assert.equal(data.order.order_id, flowOrderId);
  });

  test('rider accepts order: accepted → assigned', async () => {
    const { status, data } = await req('PATCH', `/api/orders/${flowOrderId}/status`, {
      new_status: 'assigned',
    }, riderToken);

    assert.equal(status, 200);
    assert.equal(data.order.status, 'assigned');
    assert.equal(data.order.rider_ack, 'accepted');
  });

  test('assigned → arrived (valid)', async () => {
    const { status, data } = await req('PATCH', `/api/orders/${flowOrderId}/status`, {
      new_status: 'arrived',
    }, riderToken);

    assert.equal(status, 200);
    assert.equal(data.order.status, 'arrived');
    assert.ok(data.order.arrived_at);
  });

  test('arrived → picked_up (valid)', async () => {
    const { status, data } = await req('PATCH', `/api/orders/${flowOrderId}/status`, {
      new_status: 'picked_up',
      restaurant_wait_mins: 8,
      delay_context: { type: 'restaurant', verified: true, source: 'api_mock' },
    }, riderToken);

    assert.equal(status, 200);
    assert.equal(data.order.status, 'picked_up');
    assert.equal(data.order.restaurant_wait_mins, 8);
    assert.ok(data.order.picked_up_at);
  });

  test('picked_up → delivered (valid)', async () => {
    const { status, data } = await req('PATCH', `/api/orders/${flowOrderId}/status`, {
      new_status: 'delivered',
    }, riderToken);

    assert.equal(status, 200);
    assert.equal(data.order.status, 'delivered');
    assert.ok(data.order.delivered_at);
  });

  test('delivered is terminal — transition rejected with 400', async () => {
    const { status } = await req('PATCH', `/api/orders/${flowOrderId}/status`, {
      new_status: 'assigned',
    }, riderToken);

    assert.equal(status, 400);
  });

  test('idempotent delivered (FR-74): sequential and parallel requests return 200 with equal payloads; other rider returns 403', async () => {
    // 1. A different rider attempting delivered returns 403
    const forbiddenRes = await req('PATCH', `/api/orders/${flowOrderId}/status`, {
      new_status: 'delivered',
    }, secondRiderToken);
    assert.equal(forbiddenRes.status, 403);
    assert.match(forbiddenRes.data.message, /not the allocated rider/i);

    // 2. Sequential delivered requests return 200 with equal payloads
    const seq1 = await req('PATCH', `/api/orders/${flowOrderId}/status`, {
      new_status: 'delivered',
    }, riderToken);
    const seq2 = await req('PATCH', `/api/orders/${flowOrderId}/status`, {
      new_status: 'delivered',
    }, riderToken);
    assert.equal(seq1.status, 200);
    assert.equal(seq2.status, 200);
    assert.deepEqual(seq1.data, seq2.data);

    // 3. Parallel delivered requests return 200 with equal payloads
    const [par1, par2] = await Promise.all([
      req('PATCH', `/api/orders/${flowOrderId}/status`, { new_status: 'delivered' }, riderToken),
      req('PATCH', `/api/orders/${flowOrderId}/status`, { new_status: 'delivered' }, riderToken),
    ]);
    assert.equal(par1.status, 200);
    assert.equal(par2.status, 200);
    assert.deepEqual(par1.data, par2.data);
    assert.deepEqual(seq1.data, par1.data);

    // 4. Verify single delivery and single delivered entry in status_history
    const orderDoc = await Order.findOne({ order_id: flowOrderId });
    assert.equal(orderDoc.status, 'delivered');
    const deliveredCount = orderDoc.status_history.filter(h => h.status === 'delivered').length;
    assert.equal(deliveredCount, 1);
  });

  test('out-of-zone delivery updates rider current_zone_id and current_zone_code (FR-73, D3)', async () => {
    // Clean up open orders for Rider 2
    await Order.deleteMany({ rider_id: secondRiderUser._id });

    // Set Rider 1 offline via direct DB update
    await User.findByIdAndUpdate(riderUser._id, {
      'rider_profile.is_online': false,
    });

    // Rider 2 starts in Chinnakkada
    await User.findByIdAndUpdate(secondRiderUser._id, {
      'rider_profile.is_online': true,
      'rider_profile.current_zone_id': chinnakkadaZone._id,
      'rider_profile.current_zone_code': 'KLM-CHK',
    });

    // Place order delivered to Pin B (inside Polayathode)
    const { data: oData } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: dosaItem._id, quantity: 1 }],
      delivery_address: { label: 'Pin B', latitude: 8.8800, longitude: 76.6050 },
      restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
    }, customerToken);

    const bOrderId = oData.order.order_id;
    await req('PATCH', `/api/orders/${bOrderId}/accept`, {}, secondRiderToken);
    await req('PATCH', `/api/orders/${bOrderId}/status`, { new_status: 'arrived' }, secondRiderToken);
    await req('PATCH', `/api/orders/${bOrderId}/status`, { new_status: 'picked_up' }, secondRiderToken);
    await req('PATCH', `/api/orders/${bOrderId}/status`, { new_status: 'delivered' }, secondRiderToken);

    // Verify rider's current zone changed to Polayathode
    const updatedR2 = await User.findById(secondRiderUser._id);
    assert.equal(updatedR2.rider_profile.current_zone_code, 'KLM-PLY');
    assert.equal(updatedR2.rider_profile.current_zone_id.toString(), polayathodeZone._id.toString());
  });

  test('POST /api/orders/:id/retry-pay rejects undelivered order with 400 (FR-24)', async () => {
    const { data: activeO } = await req('POST', '/api/orders', {
      restaurant_id: restaurantId,
      items: [{ item_id: dosaItem._id, quantity: 1 }],
      delivery_address: { label: 'Pin A', latitude: 8.8860, longitude: 76.5920 },
      restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
    }, customerToken);

    const { status, data } = await req('POST', `/api/orders/${activeO.order.order_id}/retry-pay`, {}, riderToken);
    assert.equal(status, 400);
    assert.match(data.message, /must be delivered/i);
  });
});

describe('GET /api/orders/history & GET /api/orders/restaurants', () => {
  test('customer sees their placed orders', async () => {
    const { status, data } = await req('GET', '/api/orders/history', null, customerToken);
    assert.equal(status, 200);
    assert.ok(data.count >= 1);
  });

  test('rider sees their deliveries', async () => {
    const { status, data } = await req('GET', '/api/orders/history', null, riderToken);
    assert.equal(status, 200);
    assert.ok(data.count >= 1);
  });

  test('get restaurants list', async () => {
    const { status, data } = await req('GET', '/api/orders/restaurants', null, customerToken);
    assert.equal(status, 200);
    assert.ok(data.restaurants.length >= 1);
    assert.equal(data.restaurants[0].name, 'Hotel Arun');
  });
});
