// FairDrop Pay Service — Pay Engine & Analytics Tests
// Tests the pure engine formulas, calculate endpoint idempotency, rider upsert, and analytics.
// Runner: Node.js built-in test runner (node:test)
// Run: node --test tests/payEngine.test.js

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const app = require('../src/server');
const { pool } = require('../src/db');
const { calculatePay, evaluateFloorBlocks, validateRequest } = require('../src/payEngine');

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
    await pool.execute("DELETE FROM floor_topups WHERE rider_id LIKE 'rider-test-%'");
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
    // Under AUDIT-F16: per-delivery ledger has 6 lines; floor top-up is 0.00 inside delivery ledger
    assert.strictEqual(result.base_rate, 15);
    assert.strictEqual(result.distance_pay, 18);
    assert.strictEqual(result.surge_bonus, 0);
    assert.strictEqual(result.wait_compensation, 0);
    assert.strictEqual(result.total_delivery_pay, 33);
    assert.strictEqual(result.floor_topup, 0);
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
    // Under AUDIT-F16: floor_topup is 0 inside delivery ledger
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
// 1b. AUDIT-F16 Statutory Floor Block Engine Unit Tests (Pure Formulas)
// ════════════════════════════════════════════════════════════════════════════
describe('AUDIT-F16 Statutory Floor Block Engine Tests (evaluateFloorBlocks)', () => {
  test('59 min engaged -> no top-up', () => {
    const orders = [
      { order_id: 'ORD-1', engaged_minutes: 59, total_delivery_pay: 30 },
    ];
    const res = evaluateFloorBlocks(orders, { windowMinutes: 60, minWagePerHour: 70 });
    assert.strictEqual(res.num_completed_blocks, 0);
    assert.strictEqual(res.total_topup, 0);
    assert.strictEqual(res.carried_minutes, 59);
    assert.strictEqual(res.completed_blocks.length, 0);
  });

  test('60 min with ₹29.80 -> ₹40.20 top-up', () => {
    const orders = [
      { order_id: 'ORD-20261020-0033', engaged_minutes: 60, total_delivery_pay: 29.80 },
    ];
    const res = evaluateFloorBlocks(orders, { windowMinutes: 60, minWagePerHour: 70 });
    assert.strictEqual(res.num_completed_blocks, 1);
    assert.strictEqual(res.total_topup, 40.20);
    assert.strictEqual(res.carried_minutes, 0);
    assert.strictEqual(res.completed_blocks[0].topup_amount, 40.20);
    assert.strictEqual(res.completed_blocks[0].floor_amount, 70);
    assert.strictEqual(res.completed_blocks[0].delivery_pay, 29.80);
  });

  test('block1 ₹120 + block2 ₹30 -> ₹40 top-up (no offset)', () => {
    const orders = [
      { order_id: 'ORD-B1', engaged_minutes: 60, total_delivery_pay: 120 },
      { order_id: 'ORD-B2', engaged_minutes: 60, total_delivery_pay: 30 },
    ];
    const res = evaluateFloorBlocks(orders, { windowMinutes: 60, minWagePerHour: 70 });
    assert.strictEqual(res.num_completed_blocks, 2);
    assert.strictEqual(res.completed_blocks[0].topup_amount, 0);
    assert.strictEqual(res.completed_blocks[1].topup_amount, 40);
    assert.strictEqual(res.total_topup, 40);
  });

  test('100 min -> 1 block evaluated, 40 carried', () => {
    const orders = [
      { order_id: 'ORD-100-A', engaged_minutes: 60, total_delivery_pay: 50 },
      { order_id: 'ORD-100-B', engaged_minutes: 40, total_delivery_pay: 30 },
    ];
    const res = evaluateFloorBlocks(orders, { windowMinutes: 60, minWagePerHour: 70 });
    assert.strictEqual(res.num_completed_blocks, 1);
    assert.strictEqual(res.carried_minutes, 40);
    assert.strictEqual(res.completed_blocks.length, 1);
    assert.strictEqual(res.completed_blocks[0].engaged_minutes, 60);
    assert.strictEqual(res.completed_blocks[0].delivery_pay, 50);
    assert.strictEqual(res.completed_blocks[0].topup_amount, 20);
  });

  test('re-running evaluation never duplicates (idempotency in MySQL floor_topups)', async () => {
    const testRider = 'rider-test-floor-idempotent';
    await pool.execute(
      `INSERT INTO riders (rider_id, name, phone, zone_id, is_active)
       VALUES (?, 'Floor Rider', '9999999999', 'KLM-CHK', TRUE)
       ON DUPLICATE KEY UPDATE is_active = TRUE`,
      [testRider]
    );

    const block = {
      block_index: 1,
      engaged_minutes: 60,
      delivery_pay: 29.80,
      floor_amount: 70.00,
      topup_amount: 40.20,
    };

    // First insert
    await pool.execute(
      `INSERT INTO floor_topups
         (rider_id, block_index, shift_date, engaged_minutes, delivery_pay, floor_amount, topup_amount)
       VALUES (?, ?, CURDATE(), ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         engaged_minutes = VALUES(engaged_minutes),
         delivery_pay = VALUES(delivery_pay),
         floor_amount = VALUES(floor_amount),
         topup_amount = VALUES(topup_amount)`,
      [testRider, block.block_index, block.engaged_minutes, block.delivery_pay, block.floor_amount, block.topup_amount]
    );

    // Re-run evaluation insert (simulates idempotency on second run)
    await pool.execute(
      `INSERT INTO floor_topups
         (rider_id, block_index, shift_date, engaged_minutes, delivery_pay, floor_amount, topup_amount)
       VALUES (?, ?, CURDATE(), ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         engaged_minutes = VALUES(engaged_minutes),
         delivery_pay = VALUES(delivery_pay),
         floor_amount = VALUES(floor_amount),
         topup_amount = VALUES(topup_amount)`,
      [testRider, block.block_index, block.engaged_minutes, block.delivery_pay, block.floor_amount, block.topup_amount]
    );

    const [rows] = await pool.execute(
      'SELECT * FROM floor_topups WHERE rider_id = ? AND block_index = 1',
      [testRider]
    );
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(parseFloat(rows[0].topup_amount), 40.20);

    // Clean up
    await pool.execute('DELETE FROM floor_topups WHERE rider_id = ?', [testRider]);
    await pool.execute('DELETE FROM riders WHERE rider_id = ?', [testRider]);
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
