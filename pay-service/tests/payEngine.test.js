// FairDrop Pay Engine — Unit Tests
// Runner: Node.js built-in test runner (node:test) — no external dependencies
// Run: node --test pay-engine/tests/payEngine.test.js

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { calculatePay, validateRequest } = require('../src/payEngine');

// ── Shared test fixtures ───────────────────────────────────────────────────

const BASE_REQUEST = {
  rider_id: 'rider-001',
  order_id: 'ORD-20260901-0001',
  distance_km: 5,
  is_surge_active: false,
  restaurant_wait_mins: 0,
  active_hours_today: 4,
  delay_context: {
    type: 'none',
    verified: false,
    source: 'none',
  },
};

const TEST_CONFIG = {
  BASE_RATE: 15,
  PER_KM_RATE: 6,
  SURGE_BONUS: 20,
  WAIT_THRESHOLD_MINS: 10,
  WAIT_COMPENSATION: 10,
  MIN_WAGE_PER_HOUR: 70,
};

// ── Tests ──────────────────────────────────────────────────────────────────

describe('calculatePay — base delivery (no surge, no wait, no delay)', () => {
  test('returns correct base_rate', () => {
    const result = calculatePay(BASE_REQUEST, TEST_CONFIG, 0);
    assert.equal(result.base_rate, 15);
  });

  test('returns correct distance_pay for 5km', () => {
    // 5 km × ₹6/km = ₹30
    const result = calculatePay(BASE_REQUEST, TEST_CONFIG, 0);
    assert.equal(result.distance_pay, 30);
  });

  test('surge_bonus is 0 when is_surge_active = false', () => {
    const result = calculatePay(BASE_REQUEST, TEST_CONFIG, 0);
    assert.equal(result.surge_bonus, 0);
  });

  test('wait_compensation is 0 when wait is below threshold', () => {
    const result = calculatePay(BASE_REQUEST, TEST_CONFIG, 0);
    assert.equal(result.wait_compensation, 0);
  });

  test('total_delivery_pay = base_rate + distance_pay', () => {
    // ₹15 + ₹30 = ₹45
    const result = calculatePay(BASE_REQUEST, TEST_CONFIG, 0);
    assert.equal(result.total_delivery_pay, 45);
  });

  test('echoes order_id from request', () => {
    const result = calculatePay(BASE_REQUEST, TEST_CONFIG, 0);
    assert.equal(result.order_id, 'ORD-20260901-0001');
  });
});

describe('calculatePay — surge active', () => {
  test('surge_bonus = SURGE_BONUS constant when is_surge_active = true', () => {
    const req = { ...BASE_REQUEST, is_surge_active: true };
    const result = calculatePay(req, TEST_CONFIG, 0);
    assert.equal(result.surge_bonus, 20);
  });

  test('total_delivery_pay includes surge_bonus', () => {
    // ₹15 + ₹30 + ₹20 = ₹65
    const req = { ...BASE_REQUEST, is_surge_active: true };
    const result = calculatePay(req, TEST_CONFIG, 0);
    assert.equal(result.total_delivery_pay, 65);
  });
});

describe('calculatePay — restaurant wait compensation', () => {
  test('no wait_compensation when wait = wait_threshold_mins exactly', () => {
    // Policy: compensation triggers ABOVE threshold, not at threshold
    const req = { ...BASE_REQUEST, restaurant_wait_mins: 10 };
    const result = calculatePay(req, TEST_CONFIG, 0);
    assert.equal(result.wait_compensation, 0);
  });

  test('wait_compensation triggers when wait > wait_threshold_mins', () => {
    const req = { ...BASE_REQUEST, restaurant_wait_mins: 11 };
    const result = calculatePay(req, TEST_CONFIG, 0);
    assert.equal(result.wait_compensation, 10);
  });

  test('wait_compensation is flat (not proportional to extra wait)', () => {
    const req = { ...BASE_REQUEST, restaurant_wait_mins: 30 };
    const result = calculatePay(req, TEST_CONFIG, 0);
    assert.equal(result.wait_compensation, 10);
  });
});

describe('calculatePay — floor top-up (minimum wage enforcement)', () => {
  test('no floor_topup when earnings exceed minimum wage', () => {
    // After this delivery: cumulative = 0 + 45 = ₹45
    // Minimum expected for 0.5 hours: ₹70 × 0.5 = ₹35
    // ₹45 > ₹35 — no top-up needed
    const req = { ...BASE_REQUEST, active_hours_today: 0.5 };
    const result = calculatePay(req, TEST_CONFIG, 0);
    assert.equal(result.floor_topup, 0);
  });

  test('floor_topup covers shortfall when earnings fall below minimum wage', () => {
    // After this delivery: cumulative = 0 + 45 = ₹45
    // Minimum expected for 4 hours: ₹70 × 4 = ₹280
    // Shortfall: ₹280 - ₹45 = ₹235
    const result = calculatePay(BASE_REQUEST, TEST_CONFIG, 0);
    assert.equal(result.floor_topup, 235);
  });

  test('floor_topup accounts for earnings already made today', () => {
    // Prior earnings: ₹220. This delivery: ₹45. Cumulative: ₹265.
    // Minimum for 4 hours: ₹280. Shortfall: ₹15.
    const result = calculatePay(BASE_REQUEST, TEST_CONFIG, 220);
    assert.equal(result.floor_topup, 15);
  });

  test('floor_topup is 0 when active_hours_today = 0 (cannot divide by zero)', () => {
    const req = { ...BASE_REQUEST, active_hours_today: 0 };
    const result = calculatePay(req, TEST_CONFIG, 0);
    assert.equal(result.floor_topup, 0);
    assert.equal(result.hourly_earnings_so_far, 0);
  });
});

describe('calculatePay — hourly_earnings_so_far', () => {
  test('correct when first delivery of the day', () => {
    // Cumulative after: ₹45. Active hours: 4. Hourly: ₹45 / 4 = ₹11.25
    const result = calculatePay(BASE_REQUEST, TEST_CONFIG, 0);
    assert.equal(result.hourly_earnings_so_far, 11.25);
  });

  test('correct when prior earnings exist', () => {
    // Prior: ₹200. This delivery: ₹45. Cumulative: ₹245. Hours: 4.
    // Hourly: ₹245 / 4 = ₹61.25
    const result = calculatePay(BASE_REQUEST, TEST_CONFIG, 200);
    assert.equal(result.hourly_earnings_so_far, 61.25);
  });
});

describe('validateRequest — input validation', () => {
  test('throws on missing rider_id', () => {
    const req = { ...BASE_REQUEST };
    delete req.rider_id;
    assert.throws(() => validateRequest(req), /Missing required field: rider_id/);
  });

  test('throws on invalid order_id format', () => {
    const req = { ...BASE_REQUEST, order_id: 'INVALID-FORMAT' };
    assert.throws(() => validateRequest(req), /Invalid order_id format/);
  });

  test('accepts valid order_id format', () => {
    assert.doesNotThrow(() => validateRequest(BASE_REQUEST));
  });

  test('throws on negative distance_km', () => {
    const req = { ...BASE_REQUEST, distance_km: -1 };
    assert.throws(() => validateRequest(req), /distance_km must be a non-negative number/);
  });

  test('throws on invalid delay_context.type', () => {
    const req = {
      ...BASE_REQUEST,
      delay_context: { type: 'earthquake', verified: false, source: 'none' },
    };
    assert.throws(() => validateRequest(req), /Invalid delay_context.type/);
  });

  test('accepts verified delay with api_mock source (prototype pattern)', () => {
    const req = {
      ...BASE_REQUEST,
      delay_context: { type: 'traffic', verified: true, source: 'api_mock' },
    };
    assert.doesNotThrow(() => validateRequest(req));
  });
});

describe('FairDrop vs cliff-bonus comparison (5 deliveries, same rider)', () => {
  // Demonstrates the core academic contribution:
  // FairDrop linear model vs cliff-bonus threshold model.
  // Hardcoded scenario: 8km avg delivery, 8 active hours, no surge.

  const deliveries = [
    { distance_km: 7, restaurant_wait_mins: 0 },
    { distance_km: 9, restaurant_wait_mins: 12 }, // wait comp triggers
    { distance_km: 8, restaurant_wait_mins: 0 },
    { distance_km: 6, restaurant_wait_mins: 0 },
    { distance_km: 10, restaurant_wait_mins: 5 },
  ];

  // Cliff-bonus model: ₹15 base + ₹6/km, but bonus of ₹200
  // ONLY if rider completes ≥ 8 deliveries. Below threshold = ₹0 bonus.
  function cliffBonusPay(delivery) {
    return 15 + delivery.distance_km * 6;
  }

  test('FairDrop total >= cliff-bonus total for 5-delivery scenario', () => {
    let cumulative = 0;
    let fairDropTotal = 0;

    for (const d of deliveries) {
      const req = {
        ...BASE_REQUEST,
        distance_km: d.distance_km,
        restaurant_wait_mins: d.restaurant_wait_mins,
        active_hours_today: 8,
      };
      const result = calculatePay(req, TEST_CONFIG, cumulative);
      fairDropTotal += result.total_delivery_pay + result.floor_topup;
      cumulative += result.total_delivery_pay;
    }

    // Cliff-bonus total: 5 deliveries, no bonus (threshold = 8 not reached)
    const cliffTotal = deliveries.reduce((sum, d) => sum + cliffBonusPay(d), 0);

    // FairDrop should always pay >= cliff for sub-threshold scenarios
    assert.ok(
      fairDropTotal >= cliffTotal,
      `FairDrop (₹${fairDropTotal}) should be >= cliff-bonus (₹${cliffTotal}) for 5-delivery sub-threshold scenario`
    );
  });
});
