// FairDrop — Rider Status & Shift Tests
// Runner: Node.js built-in test runner (node:test)
// Run: node --test tests/riders.test.js

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const app = require('../src/app');
const env = require('../src/config/env');
const User = require('../src/modules/auth/User.model');
const Order = require('../src/modules/orders/Order.model');
const Zone = require('../src/modules/zones/Zone.model');

let server;
let baseUrl;

let customerToken;
let riderToken;
let riderUser;

before(async () => {
  const testDbUri = env.MONGODB_URI.replace('fairdrop_core', 'fairdrop_core_test');
  await mongoose.connect(testDbUri);

  server = app.listen(0);
  const port = server.address().port;
  baseUrl = `http://localhost:${port}`;

  // Helper registration
  const reg = async (u) => {
    const res = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(u),
    });
    return res.json();
  };

  const cust = await reg({
    name: 'Customer Test',
    email: `cust-${Date.now()}@test.com`,
    password: 'password123',
    role: 'customer',
  });
  customerToken = cust.token;

  const r = await reg({
    name: 'Rider Test',
    email: `rider-${Date.now()}@test.com`,
    password: 'password123',
    role: 'rider',
    vehicle_type: 'motorcycle',
  });
  riderToken = r.token;
  riderUser = r.user;
});

after(async () => {
  await mongoose.connection.db.dropDatabase();
  await mongoose.disconnect();
  server.close();
});

describe('Rider Status & Shift API (T6)', () => {
  // ── 1. Auth & Validation ──────────────────────────────────────────────────
  test('rejects unauthenticated POST /api/riders/status with 401', async () => {
    const res = await fetch(`${baseUrl}/api/riders/status`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ is_online: true }),
    });
    assert.strictEqual(res.status, 401);
  });

  test('rejects customer calling POST /api/riders/status with 403', async () => {
    const res = await fetch(`${baseUrl}/api/riders/status`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${customerToken}`,
      },
      body: JSON.stringify({ is_online: true }),
    });
    assert.strictEqual(res.status, 403);
  });

  test('rejects invalid non-boolean is_online with 400', async () => {
    const res = await fetch(`${baseUrl}/api/riders/status`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${riderToken}`,
      },
      body: JSON.stringify({ is_online: 'yes' }),
    });
    assert.strictEqual(res.status, 400);
    const data = await res.json();
    assert.match(data.message, /boolean/i);
  });

  // ── 2. Toggle Status & Shift Tracking (FR-7, FR-9, FR-54) ────────────────
  test('rider goes online: sets is_online true and creates session', async () => {
    const res = await fetch(`${baseUrl}/api/riders/status`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${riderToken}`,
      },
      body: JSON.stringify({ is_online: true }),
    });

    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.strictEqual(data.is_online, true);

    // Verify in MongoDB
    const u = await User.findById(riderUser._id);
    assert.strictEqual(u.rider_profile.is_online, true);
    assert.ok(u.rider_profile.current_session_started_at);
    assert.ok(u.rider_profile.shift_sessions.length >= 1);
  });

  test('rider goes offline: closes session and updates active_hours_today', async () => {
    const res = await fetch(`${baseUrl}/api/rider/status`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${riderToken}`,
      },
      body: JSON.stringify({ is_online: false }),
    });

    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.strictEqual(data.is_online, false);

    const u = await User.findById(riderUser._id);
    assert.strictEqual(u.rider_profile.is_online, false);
    assert.strictEqual(u.rider_profile.current_session_started_at, null);
    assert.ok(u.rider_profile.shift_sessions[0].ended_at);
  });

  // ── 3. GET /api/rider/stats/today (FR-8, FR-9) ───────────────────────────
  test('returns today stats for rider', async () => {
    const res = await fetch(`${baseUrl}/api/rider/stats/today`, {
      headers: { Authorization: `Bearer ${riderToken}` },
    });

    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.ok(data.stats);
    assert.strictEqual(typeof data.stats.active_hours_today, 'number');
    assert.strictEqual(typeof data.stats.deliveries_today, 'number');
    assert.strictEqual(typeof data.stats.total_earnings_today, 'number');
    assert.ok(data.stats.current_zone);
    assert.strictEqual(data.stats.is_online, false);
  });

  // ── 4. Safety Checklist Acknowledgment (FR-46) ───────────────────────────
  test('acknowledges safety checklist on server (FR-46)', async () => {
    const res = await fetch(`${baseUrl}/api/riders/checklist`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${riderToken}`,
      },
    });

    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);

    const u = await User.findById(riderUser._id);
    assert.strictEqual(u.rider_profile.safety_checklist_acknowledged, true);
  });

  // ── 5. Trigger Allocation on Online (FR-72) ──────────────────────────────
  test('triggers allocation of unallocated order when rider goes online (FR-72)', async () => {
    // Create an unallocated order
    const order = await Order.create({
      order_id: `ORD-20261019-${Math.floor(1000 + Math.random() * 9000)}`,
      customer_id: new mongoose.Types.ObjectId(),
      restaurant_id: new mongoose.Types.ObjectId(),
      rider_id: null,
      items: [{ name: 'Biryani', quantity: 1, price: 180 }],
      delivery_address: { label: 'Pin A', latitude: 8.886, longitude: 76.592 },
      restaurant_address: { label: 'Arun', latitude: 8.885, longitude: 76.589 },
      distance_km: 1.5,
      status: 'placed',
      status_history: [{ status: 'placed', changed_at: new Date() }],
    });

    // Rider goes online
    const res = await fetch(`${baseUrl}/api/riders/status`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${riderToken}`,
      },
      body: JSON.stringify({ is_online: true }),
    });

    assert.strictEqual(res.status, 200);

    // Verify order was allocated to this rider
    const updatedOrder = await Order.findById(order._id);
    assert.strictEqual(updatedOrder.rider_id.toString(), riderUser._id.toString());
    assert.ok(['accepted', 'assigned'].includes(updatedOrder.status));
    assert.strictEqual(updatedOrder.rider_ack, 'pending');
  });
});
