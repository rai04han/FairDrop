// FairDrop — Order Module Tests
// Owner: Hari (25MCA025)
// Runner: Node.js built-in test runner (node:test)
// Run: node --test tests/orders.test.js
//
// Integration tests for the full order lifecycle.
// Creates test users first, then tests order CRUD and status transitions.

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const app = require('../src/app');
const env = require('../src/config/env');

let server;
let baseUrl;

// Tokens for different roles
let customerToken;
let riderToken;
let restaurantToken;
let restaurantId;
let testOrderId;

before(async () => {
  const testDbUri = env.MONGODB_URI.replace('fairdrop_core', 'fairdrop_core_test');
  await mongoose.connect(testDbUri);
  await mongoose.connection.db.dropDatabase();

  server = app.listen(0);
  const port = server.address().port;
  baseUrl = `http://localhost:${port}`;

  // ── Register test users ────────────────────────────────────────────
  const register = async (data) => {
    const res = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return res.json();
  };

  const customer = await register({ name: 'Customer', email: 'c@test.com', password: 'pass', role: 'customer' });
  customerToken = customer.token;

  const rider = await register({ name: 'Rider', email: 'r@test.com', password: 'pass', role: 'rider' });
  riderToken = rider.token;

  const restaurant = await register({ name: 'Restaurant', email: 'rest@test.com', password: 'pass', role: 'restaurant' });
  restaurantToken = restaurant.token;
  restaurantId = restaurant.user._id;
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

// ── Test order data ────────────────────────────────────────────────────────

const ORDER_DATA = {
  items: [{ name: 'Dosa', quantity: 2, price: 60 }],
  delivery_address: { label: 'Home', latitude: 8.8932, longitude: 76.6141 },
  restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
  distance_km: 3.5,
};

// ═══════════════════════════════════════════════════════════════════════════

describe('POST /api/orders (place order)', () => {
  test('customer places an order successfully', async () => {
    const { status, data } = await req('POST', '/api/orders', {
      ...ORDER_DATA,
      restaurant_id: restaurantId,
    }, customerToken);

    assert.equal(status, 201);
    assert.equal(data.success, true);
    assert.match(data.order.order_id, /^ORD-\d{8}-\d{4}$/);
    assert.equal(data.order.status, 'placed');
    assert.equal(data.order.items.length, 1);
    assert.equal(data.order.items[0].name, 'Dosa');

    testOrderId = data.order.order_id;
  });

  test('order_id follows ORD-YYYYMMDD-NNNN format', async () => {
    const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    assert.ok(testOrderId.startsWith(`ORD-${today}-`));
  });

  test('rider cannot place an order — 403', async () => {
    const { status } = await req('POST', '/api/orders', {
      ...ORDER_DATA,
      restaurant_id: restaurantId,
    }, riderToken);

    assert.equal(status, 403);
  });

  test('rejects order without required fields — 400', async () => {
    const { status, data } = await req('POST', '/api/orders', {
      items: [],
    }, customerToken);

    assert.equal(status, 400);
    assert.equal(data.success, false);
  });

  test('rejects order with invalid restaurant — 404', async () => {
    const { status } = await req('POST', '/api/orders', {
      ...ORDER_DATA,
      restaurant_id: '000000000000000000000000',
    }, customerToken);

    assert.equal(status, 404);
  });
});

describe('GET /api/orders/:id', () => {
  test('fetch order by order_id', async () => {
    const { status, data } = await req('GET', `/api/orders/${testOrderId}`, null, customerToken);

    assert.equal(status, 200);
    assert.equal(data.order.order_id, testOrderId);
    assert.equal(data.order.distance_km, 3.5);
  });

  test('returns 404 for non-existent order', async () => {
    const { status } = await req('GET', '/api/orders/ORD-00000000-9999', null, customerToken);
    assert.equal(status, 404);
  });
});

describe('PATCH /api/orders/:id/status (transitions)', () => {
  test('placed → assigned (valid)', async () => {
    const { status, data } = await req('PATCH', `/api/orders/${testOrderId}/status`, {
      new_status: 'assigned',
    }, riderToken);

    assert.equal(status, 200);
    assert.equal(data.order.status, 'assigned');
    assert.equal(data.order.status_history.length, 2); // placed + assigned
  });

  test('assigned → placed (invalid — going backwards) — 400', async () => {
    const { status, data } = await req('PATCH', `/api/orders/${testOrderId}/status`, {
      new_status: 'placed',
    }, riderToken);

    assert.equal(status, 400);
    assert.match(data.message, /Cannot transition/);
  });

  test('assigned → delivered (invalid — skipping picked_up) — 400', async () => {
    const { status } = await req('PATCH', `/api/orders/${testOrderId}/status`, {
      new_status: 'delivered',
    }, riderToken);

    assert.equal(status, 400);
  });

  test('assigned → picked_up (valid)', async () => {
    const { status, data } = await req('PATCH', `/api/orders/${testOrderId}/status`, {
      new_status: 'picked_up',
      restaurant_wait_mins: 12,
      delay_context: { type: 'restaurant', verified: true, source: 'api_mock' },
    }, riderToken);

    assert.equal(status, 200);
    assert.equal(data.order.status, 'picked_up');
    assert.equal(data.order.restaurant_wait_mins, 12);
    assert.equal(data.order.delay_context.type, 'restaurant');
  });

  test('picked_up → delivered (valid — pay engine will fail since pay-service is not running)', async () => {
    const { status, data } = await req('PATCH', `/api/orders/${testOrderId}/status`, {
      new_status: 'delivered',
    }, riderToken);

    assert.equal(status, 200);
    assert.equal(data.order.status, 'delivered');
    // Pay engine is not running in tests, so pay_calculation_result stores error
    assert.ok(data.order.pay_calculation_result, 'pay_calculation_result should exist');
    assert.equal(data.order.pay_calculation_result.error, true);
    assert.equal(data.order.status_history.length, 4); // all 4 states recorded
  });

  test('delivered → anything (invalid — terminal state) — 400', async () => {
    const { status } = await req('PATCH', `/api/orders/${testOrderId}/status`, {
      new_status: 'assigned',
    }, riderToken);

    assert.equal(status, 400);
  });

  test('customer cannot update status — 403', async () => {
    // Place a new order first
    const newOrder = await req('POST', '/api/orders', {
      ...ORDER_DATA,
      restaurant_id: restaurantId,
    }, customerToken);

    const { status } = await req('PATCH', `/api/orders/${newOrder.data.order.order_id}/status`, {
      new_status: 'assigned',
    }, customerToken);

    assert.equal(status, 403);
  });
});

describe('GET /api/orders/rider/active', () => {
  test('rider with no active order gets null', async () => {
    // All orders are delivered now
    const { status, data } = await req('GET', '/api/orders/rider/active', null, riderToken);

    assert.equal(status, 200);
    assert.equal(data.order, null);
  });
});

describe('GET /api/orders/history', () => {
  test('customer sees their orders', async () => {
    const { status, data } = await req('GET', '/api/orders/history', null, customerToken);

    assert.equal(status, 200);
    assert.ok(data.count >= 1);
    assert.equal(data.orders[0].items[0].name, 'Dosa');
  });

  test('rider sees their deliveries', async () => {
    const { status, data } = await req('GET', '/api/orders/history', null, riderToken);

    assert.equal(status, 200);
    assert.ok(data.count >= 1);
  });
});
