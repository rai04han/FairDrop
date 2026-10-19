// FairDrop Pay Service — Pay Engine & Analytics Tests
// Tests the pure engine formulas, calculate endpoint idempotency, rider upsert, and analytics.
// Runner: Node.js built-in test runner (node:test)
// Run: node --test tests/payEngine.test.js

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const app = require('../src/server');
const { pool } = require('../src/db');
const { calculatePay, validateRequest } = require('../src/payEngine');

let server;
let baseUrl;

const JWT_SECRET = process.env.JWT_SECRET || 'fairdrop-jwt-secret-key-2025-mca';

function createToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' });
}

const adminToken = createToken({ id: 'admin-test-id', role: 'admin' });
const rider1Token = createToken({ id: 'rider-test-analytics-1', role: 'rider' });
const rider2Token = createToken({ id: 'rider-test-analytics-2', role: 'rider' });

before(async () => {
  server = app.listen(0);
  const port = server.address().port;
  baseUrl = `http://localhost:${port}`;
});

after(async () => {
  try {
    // Clean up test data
    await pool.execute("DELETE FROM earnings WHERE order_id LIKE 'ORD-20261019-9%'");
    await pool.execute("DELETE FROM deliveries WHERE order_id LIKE 'ORD-20261019-9%'");
    await pool.execute("DELETE FROM riders WHERE rider_id LIKE 'rider-test-%'");
  } catch (err) {
    // Ignore cleanup error
  }
  if (server) {
    server.close();
  }
  await pool.end();
});

// ════════════════════════════════════════════════════════════════════════════
// 1. Pure Pay Engine Unit Tests (Zero DB / Zero HTTP)
// ════════════════════════════════════════════════════════════════════════════
describe('Pure Pay Engine Unit Tests (payEngine.js)', () => {
  const mockConfig = {
    BASE_RATE: 15,
    PER_KM_RATE: 6,
    SURGE_BONUS: 20,
    WAIT_THRESHOLD_MINS: 1, // Demo threshold
    WAIT_COMPENSATION: 10,
    MIN_WAGE_PER_HOUR: 70,
  };

  test('validateRequest throws on missing required fields or invalid order_id', () => {
    assert.throws(() => validateRequest({}), /Missing required field/);
    assert.throws(
      () =>
        validateRequest({
          rider_id: 'r1',
          order_id: 'INVALID-ID',
          distance_km: 2,
          is_surge_active: false,
          restaurant_wait_mins: 0,
          active_hours_today: 1,
          delay_context: { type: 'none', verified: false, source: 'none' },
        }),
      /Invalid order_id format/
    );
    assert.throws(
      () =>
        validateRequest({
          rider_id: 'r1',
          order_id: 'ORD-20261019-0001',
          distance_km: -1,
          is_surge_active: false,
          restaurant_wait_mins: 0,
          active_hours_today: 1,
          delay_context: { type: 'none', verified: false, source: 'none' },
        }),
      /distance_km must be a non-negative number/
    );
  });

  test('calculatePay computes linear base + distance pay without surge/wait', () => {
    const request = {
      rider_id: 'r1',
      order_id: 'ORD-20261019-9001',
      distance_km: 3,
      is_surge_active: false,
      restaurant_wait_mins: 0,
      active_hours_today: 1,
      delay_context: { type: 'none', verified: false, source: 'none' },
    };

    const result = calculatePay(request, mockConfig, 0);

    // base_rate = 15, distance_pay = 3 * 6 = 18 -> total_delivery_pay = 33
    // min wage for 1 hour = 70. cumulative so far = 0 + 33 = 33 < 70 -> floor_topup = 37
    // hourly_earnings_so_far = (33 + 37) / 1 = 70
    assert.strictEqual(result.base_rate, 15);
    assert.strictEqual(result.distance_pay, 18);
    assert.strictEqual(result.surge_bonus, 0);
    assert.strictEqual(result.wait_compensation, 0);
    assert.strictEqual(result.total_delivery_pay, 33);
    assert.strictEqual(result.floor_topup, 37);
    assert.strictEqual(result.hourly_earnings_so_far, 33);
  });

  test('calculatePay adds surge bonus and wait compensation when triggered', () => {
    const request = {
      rider_id: 'r1',
      order_id: 'ORD-20261019-9002',
      distance_km: 2,
      is_surge_active: true,
      restaurant_wait_mins: 3, // > 1 min threshold
      active_hours_today: 0.5,
      delay_context: { type: 'restaurant', verified: true, source: 'system_log' },
    };

    const result = calculatePay(request, mockConfig, 50);

    // base = 15, distance = 2 * 6 = 12, surge = 20, wait = 10 -> total_delivery_pay = 57
    // min wage for 0.5 hr = 35. cumulative = 50 + 57 = 107 > 35 -> floor_topup = 0
    // hourly = 107 / 0.5 = 214
    assert.strictEqual(result.base_rate, 15);
    assert.strictEqual(result.distance_pay, 12);
    assert.strictEqual(result.surge_bonus, 20);
    assert.strictEqual(result.wait_compensation, 10);
    assert.strictEqual(result.total_delivery_pay, 57);
    assert.strictEqual(result.floor_topup, 0);
    assert.strictEqual(result.hourly_earnings_so_far, 214);
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 2. HTTP POST /api/pay/calculate Idempotency & Upsert
// ════════════════════════════════════════════════════════════════════════════
describe('POST /api/pay/calculate Idempotency & Rider Upsert (FR-74)', () => {
  const testOrderId = 'ORD-20261019-9101';
  const newRiderId = `rider-test-upsert-1`;

  const payload = {
    rider_id: newRiderId,
    order_id: testOrderId,
    distance_km: 2.5,
    is_surge_active: false,
    restaurant_wait_mins: 2,
    active_hours_today: 1.0,
    delay_context: { type: 'none', verified: false, source: 'none' },
  };

  test('upserts missing rider in MySQL and completes calculation with 200', async () => {
    const res = await fetch(`${baseUrl}/api/pay/calculate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify(payload),
    });

    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.order_id, testOrderId);
    assert.strictEqual(data.base_rate, 15);
    assert.strictEqual(data.distance_pay, 15); // 2.5 * 6
    assert.strictEqual(data.wait_compensation, 10); // 2 min > 1 min seed threshold
    assert.strictEqual(data.total_delivery_pay, 40);

    // Verify rider now exists in MySQL
    const [riders] = await pool.execute('SELECT rider_id FROM riders WHERE rider_id = ?', [
      newRiderId,
    ]);
    assert.strictEqual(riders.length, 1);
  });

  test('duplicate order_id is idempotent: returns 200 and cached calculation without inserting duplicates', async () => {
    // Call a second time with exact same order_id
    const res = await fetch(`${baseUrl}/api/pay/calculate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify(payload),
    });

    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.order_id, testOrderId);
    assert.strictEqual(data.is_cached, true);
    assert.strictEqual(data.total_delivery_pay, 40);

    // Verify delivery table still has only 1 record
    const [deliveries] = await pool.execute(
      'SELECT delivery_id FROM deliveries WHERE order_id = ?',
      [testOrderId]
    );
    assert.strictEqual(deliveries.length, 1);
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 3. HTTP GET /api/pay/analytics/:rider_id (FR-34, FR-35, FR-36)
// ════════════════════════════════════════════════════════════════════════════
describe('GET /api/pay/analytics/:rider_id (FR-34 to FR-36)', () => {
  const riderId = 'rider-test-analytics-1';
  const orderId = 'ORD-20261019-9201';

  before(async () => {
    // Insert a delivery for this rider
    const res = await fetch(`${baseUrl}/api/pay/calculate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({
        rider_id: riderId,
        order_id: orderId,
        distance_km: 4,
        is_surge_active: false,
        restaurant_wait_mins: 0,
        active_hours_today: 0.5,
        delay_context: { type: 'none', verified: false, source: 'none' },
      }),
    });
    assert.strictEqual(res.status, 200);
  });

  test('rejects unauthenticated request with 401', async () => {
    const res = await fetch(`${baseUrl}/api/pay/analytics/${riderId}`);
    assert.strictEqual(res.status, 401);
  });

  test('blocks other rider with 403 (rider isolation)', async () => {
    const res = await fetch(`${baseUrl}/api/pay/analytics/${riderId}`, {
      headers: { Authorization: `Bearer ${rider2Token}` },
    });
    assert.strictEqual(res.status, 403);
    const data = await res.json();
    assert.strictEqual(data.error, 'Forbidden');
  });

  test('returns comparison, assumptions, and cliff-wins scenario for rider (FR-34-36)', async () => {
    const res = await fetch(`${baseUrl}/api/pay/analytics/${riderId}`, {
      headers: { Authorization: `Bearer ${rider1Token}` },
    });

    assert.strictEqual(res.status, 200);
    const data = await res.json();

    assert.strictEqual(data.success, true);
    assert.strictEqual(data.rider_id, riderId);

    // FR-35: Assumptions stated
    assert.ok(data.assumptions);
    assert.strictEqual(data.assumptions.cliff_threshold_deliveries, 10);
    assert.strictEqual(data.assumptions.cliff_base_per_delivery, 20);
    assert.strictEqual(data.assumptions.cliff_bonus, 500);

    // FR-34: Actual comparison
    assert.ok(data.actual_comparison);
    assert.strictEqual(data.actual_comparison.total_deliveries, 1);
    assert.ok(data.actual_comparison.fairdrop_total > 0);
    assert.strictEqual(data.actual_comparison.cliff_total, 20); // 1 delivery * ₹20
    assert.ok(Array.isArray(data.actual_comparison.data_points));
    assert.strictEqual(data.actual_comparison.data_points.length, 1);

    // FR-36: Cliff-wins scenario
    assert.ok(data.cliff_wins_scenario);
    assert.strictEqual(data.cliff_wins_scenario.winner, 'cliff');
    assert.strictEqual(data.cliff_wins_scenario.deliveries_count, 10);
    assert.strictEqual(data.cliff_wins_scenario.fairdrop_total, 280);
    assert.strictEqual(data.cliff_wins_scenario.cliff_total, 700);
    assert.strictEqual(data.cliff_wins_scenario.cliff_advantage, 420);
    assert.strictEqual(data.cliff_wins_scenario.data_points.length, 10);
  });

  test('admin can access any rider analytics', async () => {
    const res = await fetch(`${baseUrl}/api/pay/analytics/${riderId}`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
  });
});
