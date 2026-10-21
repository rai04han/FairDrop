// FairDrop Pay Engine — Core Calculation Logic
// Owner: Raihan
//
// This module is pure calculation — no DB calls, no HTTP.
// The Express route handler calls calculatePay() and writes
// results to MySQL separately. Keeping this pure makes it
// fully testable without a DB connection.
//
// Restored from git history (commit 046055b) with the config/constants
// dependency removed — the route handler now reads config from the DB
// and passes it directly.

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

  const VALID_DELAY_TYPES = ['traffic', 'restaurant', 'railway', 'weather', 'none'];
  if (!VALID_DELAY_TYPES.includes(req.delay_context.type)) {
    throw new Error(
      `Invalid delay_context.type: "${req.delay_context.type}". Must be one of: ${VALID_DELAY_TYPES.join(', ')}`
    );
  }

  const VALID_DELAY_SOURCES = ['rider_report', 'system_log', 'api_mock', 'none'];
  if (!VALID_DELAY_SOURCES.includes(req.delay_context.source)) {
    throw new Error(
      `Invalid delay_context.source: "${req.delay_context.source}". Must be one of: ${VALID_DELAY_SOURCES.join(', ')}`
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
 * @param {Object} config - Pay constants from DB (BASE_RATE, PER_KM_RATE, etc.)
 * @param {number} [cumulativeEarningsBeforeThisDelivery=0] - Rider's total
 *   earnings so far today, before this delivery. Used to compute floor top-up.
 *
 * @returns {Object} Pay breakdown — matches POST /api/pay/calculate response shape
 */
function calculatePay(req, config, cumulativeEarningsBeforeThisDelivery = 0) {
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

  // ── Floor top-up (AUDIT-F16 Redesign) ─────────────────────────────────────
  // Per AUDIT-F16, the statutory floor (config MIN_WAGE_PER_HOUR) is evaluated
  // only per completed 60-minute block of engaged time, NOT inside an individual
  // delivery's ledger. The per-delivery ledger goes from 7 lines to 6.
  // Delivery ledger floor_topup is 0.00.
  const floor_topup = 0.00;

  const cumulativeAfter = round2(cumulativeEarningsBeforeThisDelivery + total_delivery_pay);
  let hourly_earnings_so_far = total_delivery_pay;
  if (active_hours_today > 0) {
    hourly_earnings_so_far = round2(cumulativeAfter / active_hours_today);
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
 * Evaluates statutory wage floor top-up across completed blocks of engaged time (AUDIT-F16).
 * Policy:
 * - Minimum wage floor (config.MIN_WAGE_PER_HOUR) is evaluated only per COMPLETED
 *   window (default 60-minute block) of cumulative engaged time.
 * - Engaged time accumulates across orders (assigned/accepted to delivered). Idle time excluded.
 * - A delivery belongs to the block in which it ends on the cumulative engaged timeline.
 * - Top-up for a block = max(0, floor - delivery pay in that block).
 * - Blocks are checked independently (a strong block does not offset a weak one).
 * - Leftover minutes carry over; no pro-rata at shift end.
 *
 * @param {Array<Object>} orders - Completed orders chronologically sorted by delivered_at
 * @param {Object} options
 * @param {number} [options.windowMinutes=60] - Evaluation window length in minutes
 * @param {number} [options.minWagePerHour=70] - Statutory floor per hour
 * @returns {Object} { window_minutes, total_engaged_minutes, num_completed_blocks, carried_minutes, total_topup, completed_blocks }
 */
function evaluateFloorBlocks(orders, options = {}) {
  const windowMinutes = Number(options.windowMinutes || 60);
  const minWagePerHour = Number(options.minWagePerHour !== undefined ? options.minWagePerHour : 70);
  const floorPerBlock = round2((minWagePerHour * windowMinutes) / 60);

  let cumulativeEngagedMinutes = 0;
  const taggedOrders = [];

  for (const order of (orders || [])) {
    let engagedMins = 0;
    if (order.engaged_minutes !== undefined && order.engaged_minutes !== null) {
      engagedMins = Number(order.engaged_minutes);
    } else if (order.delivered_at && (order.assigned_at || order.accepted_at)) {
      const diffMs = new Date(order.delivered_at) - new Date(order.assigned_at || order.accepted_at);
      engagedMins = Math.max(0, diffMs / 60000);
    }

    const startTimeline = cumulativeEngagedMinutes;
    cumulativeEngagedMinutes += engagedMins;
    const endTimeline = cumulativeEngagedMinutes;

    // A delivery belongs to the block in which it ends on the cumulative engaged timeline.
    const blockIndex = endTimeline <= 0 ? 1 : Math.floor((endTimeline - 1e-9) / windowMinutes) + 1;

    const pay = order.total_delivery_pay !== undefined
      ? Number(order.total_delivery_pay)
      : round2(
          Number(order.base_rate || 0) +
          Number(order.distance_pay || 0) +
          Number(order.surge_bonus || 0) +
          Number(order.wait_compensation || 0)
        );

    taggedOrders.push({
      ...order,
      engaged_minutes: engagedMins,
      start_timeline_min: startTimeline,
      end_timeline_min: endTimeline,
      block_index: blockIndex,
      delivery_pay: pay,
    });
  }

  const numCompletedBlocks = Math.floor(cumulativeEngagedMinutes / windowMinutes);
  const carriedMinutes = round2(cumulativeEngagedMinutes - (numCompletedBlocks * windowMinutes));

  const completedBlocks = [];
  let totalTopup = 0;

  for (let b = 1; b <= numCompletedBlocks; b++) {
    const ordersInBlock = taggedOrders.filter((o) => o.block_index === b);
    const deliveryPayInBlock = round2(
      ordersInBlock.reduce((sum, o) => sum + o.delivery_pay, 0)
    );
    const topup = Math.max(0, round2(floorPerBlock - deliveryPayInBlock));
    totalTopup = round2(totalTopup + topup);

    completedBlocks.push({
      block_index: b,
      engaged_minutes: windowMinutes,
      delivery_pay: deliveryPayInBlock,
      floor_amount: floorPerBlock,
      topup_amount: topup,
      orders: ordersInBlock.map((o) => o.order_id).filter(Boolean),
    });
  }

  return {
    window_minutes: windowMinutes,
    total_engaged_minutes: round2(cumulativeEngagedMinutes),
    num_completed_blocks: numCompletedBlocks,
    carried_minutes: carriedMinutes,
    total_topup: totalTopup,
    completed_blocks: completedBlocks,
  };
}

/**
 * Rounds a number to 2 decimal places.
 * Avoids floating-point drift in monetary calculations.
 */
function round2(value) {
  return Math.round(value * 100) / 100;
}

const VALID_DELAY_TYPES = ['traffic', 'restaurant', 'railway', 'weather', 'none'];
const VALID_DELAY_SOURCES = ['rider_report', 'system_log', 'api_mock', 'none'];

module.exports = {
  calculatePay,
  evaluateFloorBlocks,
  validateRequest,
  round2,
  VALID_DELAY_TYPES,
  VALID_DELAY_SOURCES,
};
