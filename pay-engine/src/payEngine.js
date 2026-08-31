// FairDrop Pay Engine — Core Calculation Logic
// Owner: Raihan
//
// This module is pure calculation — no DB calls, no HTTP.
// The Express route handler calls calculatePay() and writes
// results to MySQL separately. Keeping this pure makes it
// fully testable without a DB connection.

const defaults = require('../config/constants');

/**
 * Validates the incoming pay request object.
 * Throws an Error with a descriptive message if invalid.
 *
 * @param {Object} req
 */
function validateRequest(req) {
  const required = [
    'rider_id',
    'order_id',
    'distance_km',
    'is_surge_active',
    'restaurant_wait_mins',
    'active_hours_today',
    'delay_context',
  ];

  for (const field of required) {
    if (req[field] === undefined || req[field] === null) {
      throw new Error(`Missing required field: ${field}`);
    }
  }

  // order_id format: ORD-{YYYYMMDD}-{4-digit-sequence}
  const orderIdPattern = /^ORD-\d{8}-\d{4}$/;
  if (!orderIdPattern.test(req.order_id)) {
    throw new Error(
      `Invalid order_id format: "${req.order_id}". Expected ORD-{YYYYMMDD}-{4-digit-seq}`
    );
  }

  if (typeof req.distance_km !== 'number' || req.distance_km < 0) {
    throw new Error('distance_km must be a non-negative number');
  }

  if (typeof req.active_hours_today !== 'number' || req.active_hours_today < 0) {
    throw new Error('active_hours_today must be a non-negative number');
  }

  if (typeof req.restaurant_wait_mins !== 'number' || req.restaurant_wait_mins < 0) {
    throw new Error('restaurant_wait_mins must be a non-negative number');
  }

  const validDelayTypes = ['traffic', 'restaurant', 'railway', 'none'];
  if (!validDelayTypes.includes(req.delay_context.type)) {
    throw new Error(
      `Invalid delay_context.type: "${req.delay_context.type}". Must be one of: ${validDelayTypes.join(', ')}`
    );
  }

  const validSources = ['system_log', 'api_mock', 'none'];
  if (!validSources.includes(req.delay_context.source)) {
    throw new Error(
      `Invalid delay_context.source: "${req.delay_context.source}". Must be one of: ${validSources.join(', ')}`
    );
  }
}

/**
 * Calculates pay for a completed delivery using FairDrop's linear model.
 *
 * FairDrop replaces cliff-bonus structures with:
 *   - Linear per-delivery pay (base + distance)
 *   - Surge bonus (flat, not tied to delivery count threshold)
 *   - Wait compensation (triggers after configurable threshold)
 *   - Floor top-up (ensures hourly earnings meet minimum wage)
 *
 * @param {Object} req - Pay calculation request (see API contract)
 * @param {Object} [config] - Pay constants (defaults to Kerala baseline)
 * @param {number} [cumulativeEarningsBeforeThisDelivery=0] - Rider's total
 *   earnings so far today, before this delivery. Used to compute floor top-up.
 *
 * @returns {Object} Pay breakdown — matches POST /api/pay/calculate response shape
 */
function calculatePay(req, config = defaults, cumulativeEarningsBeforeThisDelivery = 0) {
  validateRequest(req);

  const {
    order_id,
    distance_km,
    is_surge_active,
    restaurant_wait_mins,
    active_hours_today,
  } = req;

  const {
    BASE_RATE,
    PER_KM_RATE,
    SURGE_BONUS,
    WAIT_THRESHOLD_MINS,
    WAIT_COMPENSATION,
    MIN_WAGE_PER_HOUR,
  } = config;

  // ── Core delivery pay ──────────────────────────────────────────────────────

  const base_rate = BASE_RATE;

  const distance_pay = round2(distance_km * PER_KM_RATE);

  const surge_bonus = is_surge_active ? SURGE_BONUS : 0;

  const wait_compensation =
    restaurant_wait_mins > WAIT_THRESHOLD_MINS ? WAIT_COMPENSATION : 0;

  const total_delivery_pay = round2(
    base_rate + distance_pay + surge_bonus + wait_compensation
  );

  // ── Floor top-up ───────────────────────────────────────────────────────────
  // After this delivery, check if hourly earnings meet minimum wage.
  // If not, add a top-up to cover the shortfall.
  //
  // This implements Problem 6 (Minimum Earnings Floor) — partial scope.
  // The floor applies only when active_hours_today > 0.

  const cumulativeAfter = round2(cumulativeEarningsBeforeThisDelivery + total_delivery_pay);

  let hourly_earnings_so_far = 0;
  let floor_topup = 0;

  if (active_hours_today > 0) {
    hourly_earnings_so_far = round2(cumulativeAfter / active_hours_today);

    const minimumExpected = round2(MIN_WAGE_PER_HOUR * active_hours_today);
    const shortfall = round2(minimumExpected - cumulativeAfter);
    floor_topup = shortfall > 0 ? shortfall : 0;
  }

  return {
    order_id,
    base_rate,
    distance_pay,
    surge_bonus,
    wait_compensation,
    total_delivery_pay,
    floor_topup,
    hourly_earnings_so_far,
  };
}

/**
 * Rounds a number to 2 decimal places.
 * Avoids floating-point drift in monetary calculations.
 */
function round2(value) {
  return Math.round(value * 100) / 100;
}

module.exports = { calculatePay, validateRequest };
