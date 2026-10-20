// FairDrop Pay Service — Pay Config & Auth Tests
// Runner: Node.js built-in test runner (node:test)
// Run: node --test tests/payConfig.test.js

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const app = require('../src/server');
const { pool } = require('../src/db');

let server;
let baseUrl;

const JWT_SECRET = process.env.JWT_SECRET || 'fairdrop-jwt-secret-key-2025-mca';

function createToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' });
}

const adminToken = createToken({ id: 'admin-test-id', role: 'admin' });
const rider1Token = createToken({ id: 'rider-test-1', role: 'rider' });
const rider2Token = createToken({ id: 'rider-test-2', role: 'rider' });
const customerToken = createToken({ id: 'cust-test-1', role: 'customer' });

before(async () => {
  server = app.listen(0);
  const port = server.address().port;
  baseUrl = `http://localhost:${port}`;
});

after(async () => {
  // Clean up any test configs created during tests
  try {
    await pool.execute("DELETE FROM pay_configs WHERE change_reason LIKE 'TEST:%'");
  } catch (err) {
    // Ignore cleanup error
  }
  if (server) {
    server.close();
  }
  await pool.end();
});

describe('Pay Service Authentication & Config API (T3)', () => {

  // ── 1. GET /api/pay/config ────────────────────────────────────────────────
  describe('GET /api/pay/config', () => {
    test('rejects unauthenticated request with 401', async () => {
      const res = await fetch(`${baseUrl}/api/pay/config`);
      assert.strictEqual(res.status, 401);
      const data = await res.json();
      assert.strictEqual(data.error, 'Unauthorized');
    });

    test('allows rider to read active config (FR-75)', async () => {
      const res = await fetch(`${baseUrl}/api/pay/config`, {
        headers: { Authorization: `Bearer ${rider1Token}` },
      });
      assert.strictEqual(res.status, 200);
      const data = await res.json();
      assert.strictEqual(data.success, true);
      assert.ok(data.config || data.active, 'Response must contain active config');
      const cfg = data.config || data.active;
      assert.ok(Number(cfg.base_rate) > 0);
      assert.ok(Number(cfg.min_wage_per_hour) > 0);
    });

    test('allows customer to read active config (FR-75)', async () => {
      const res = await fetch(`${baseUrl}/api/pay/config`, {
        headers: { Authorization: `Bearer ${customerToken}` },
      });
      assert.strictEqual(res.status, 200);
      const data = await res.json();
      assert.strictEqual(data.success, true);
    });
  });

  // ── 2. Admin Route Protection ─────────────────────────────────────────────
  describe('Admin Routes Role Enforcement', () => {
    test('GET /api/admin/pay-config returns 401 without token', async () => {
      const res = await fetch(`${baseUrl}/api/admin/pay-config`);
      assert.strictEqual(res.status, 401);
    });

    test('GET /api/admin/pay-config returns 403 for rider', async () => {
      const res = await fetch(`${baseUrl}/api/admin/pay-config`, {
        headers: { Authorization: `Bearer ${rider1Token}` },
      });
      assert.strictEqual(res.status, 403);
    });

    test('GET /api/admin/pay-config returns 403 for customer', async () => {
      const res = await fetch(`${baseUrl}/api/admin/pay-config`, {
        headers: { Authorization: `Bearer ${customerToken}` },
      });
      assert.strictEqual(res.status, 403);
    });

    test('GET /api/admin/pay-config returns 200 for admin', async () => {
      const res = await fetch(`${baseUrl}/api/admin/pay-config`, {
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      assert.strictEqual(res.status, 200);
      const data = await res.json();
      assert.ok(data.config);
    });

    test('GET /api/admin/pay-config/history returns 200 for admin', async () => {
      const res = await fetch(`${baseUrl}/api/admin/pay-config/history`, {
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      assert.strictEqual(res.status, 200);
      const data = await res.json();
      assert.strictEqual(data.success, true);
      assert.ok(Array.isArray(data.history));
      assert.ok(data.history.length > 0);
    });
  });

  // ── 3. 7-Day Advance Notice & Validation (FR-41, FR-42, FR-43) ────────────
  describe('PUT /api/admin/pay-config validation & 7-day rule', () => {
    function getDateDaysAhead(days) {
      const d = new Date();
      d.setDate(d.getDate() + days);
      const year = d.getFullYear();
      const month = String(d.getMonth() + 1).padStart(2, '0');
      const day = String(d.getDate()).padStart(2, '0');
      return `${year}-${month}-${day}`;
    }

    test('rejects effective_from 6 days out (< 7 days) with 400', async () => {
      const sixDaysAhead = getDateDaysAhead(6);
      const payload = {
        base_rate: 16,
        per_km_rate: 7,
        surge_bonus: 25,
        wait_threshold_mins: 5,
        wait_compensation: 12,
        min_wage_per_hour: 75,
        effective_from: sixDaysAhead,
        change_reason: 'TEST: 6-day test update',
      };

      const res = await fetch(`${baseUrl}/api/admin/pay-config`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`,
        },
        body: JSON.stringify(payload),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.match(data.message, /7-day advance notice required/i);
    });

    test('accepts effective_from 7 days out (>= 7 days) with 200', async () => {
      const sevenDaysAhead = getDateDaysAhead(7);
      const payload = {
        base_rate: 16,
        per_km_rate: 7,
        surge_bonus: 25,
        wait_threshold_mins: 5,
        wait_compensation: 12,
        min_wage_per_hour: 75,
        effective_from: sevenDaysAhead,
        change_reason: 'TEST: 7-day test update valid',
      };

      const res = await fetch(`${baseUrl}/api/admin/pay-config`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`,
        },
        body: JSON.stringify(payload),
      });

      assert.strictEqual(res.status, 200);
      const data = await res.json();
      assert.strictEqual(data.success, true);
      assert.ok(data.config_id);
    });

    test('accepts effective_from 8 days out with 200 and stored/returned effective_from equals exactly date sent', async () => {
      const eightDaysAhead = getDateDaysAhead(8);
      const payload = {
        base_rate: 17,
        per_km_rate: 7,
        surge_bonus: 25,
        wait_threshold_mins: 5,
        wait_compensation: 12,
        min_wage_per_hour: 75,
        effective_from: eightDaysAhead,
        change_reason: 'TEST: 8-day timezone verification',
      };

      const res = await fetch(`${baseUrl}/api/admin/pay-config`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`,
        },
        body: JSON.stringify(payload),
      });

      assert.strictEqual(res.status, 200);
      const data = await res.json();
      assert.strictEqual(data.success, true);
      assert.strictEqual(data.effective_from, eightDaysAhead);

      // Verify stored DB value matches exactly the date sent
      const [rows] = await pool.execute(
        'SELECT effective_from FROM pay_configs WHERE config_id = ?',
        [data.config_id]
      );
      assert.strictEqual(rows.length, 1);
      const dbDate = rows[0].effective_from instanceof Date
        ? `${rows[0].effective_from.getFullYear()}-${String(rows[0].effective_from.getMonth() + 1).padStart(2, '0')}-${String(rows[0].effective_from.getDate()).padStart(2, '0')}`
        : String(rows[0].effective_from).split('T')[0];
      assert.strictEqual(dbDate, eightDaysAhead);
    });

    test('rejects empty change_reason (FR-42)', async () => {
      const tenDaysAhead = getDateDaysAhead(10);
      const payload = {
        base_rate: 16,
        per_km_rate: 7,
        surge_bonus: 25,
        wait_threshold_mins: 5,
        wait_compensation: 12,
        min_wage_per_hour: 75,
        effective_from: tenDaysAhead,
        change_reason: '   ',
      };

      const res = await fetch(`${baseUrl}/api/admin/pay-config`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`,
        },
        body: JSON.stringify(payload),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.match(data.message, /change_reason is mandatory/i);
    });

    test('rejects non-integer wait_threshold_mins (FR-43)', async () => {
      const tenDaysAhead = getDateDaysAhead(10);
      const payload = {
        base_rate: 16,
        per_km_rate: 7,
        surge_bonus: 25,
        wait_threshold_mins: 2.5,
        wait_compensation: 12,
        min_wage_per_hour: 75,
        effective_from: tenDaysAhead,
        change_reason: 'TEST: Fractional wait threshold',
      };

      const res = await fetch(`${baseUrl}/api/admin/pay-config`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`,
        },
        body: JSON.stringify(payload),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.match(data.message, /wait_threshold_mins must be a non-negative whole integer/i);
    });
  });

  // ── 4. Rider Isolation on GET /api/pay/history/:rider_id ──────────────────
  describe('Rider Isolation on GET /api/pay/history/:rider_id', () => {
    test('rider cannot view other rider history (returns 403)', async () => {
      const res = await fetch(`${baseUrl}/api/pay/history/rider-test-2`, {
        headers: { Authorization: `Bearer ${rider1Token}` },
      });
      assert.strictEqual(res.status, 403);
      const data = await res.json();
      assert.strictEqual(data.error, 'Forbidden');
    });

    test('admin can access any rider history endpoint', async () => {
      const res = await fetch(`${baseUrl}/api/pay/history/non-existent-rider`, {
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      // Admin is authorized; rider lookup returns 404 since rider does not exist
      assert.strictEqual(res.status, 404);
    });
  });
});
