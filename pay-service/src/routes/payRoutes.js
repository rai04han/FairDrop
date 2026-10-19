// FairDrop Pay Service — Pay Calculation Routes
// Owner: Raihan
//
// POST /api/pay/calculate — Core endpoint. Called by Harikrishnan's
//   Order Flow server (Port 3004) when a delivery is completed.
//   Validates input, calculates pay using the pure engine, persists
//   the delivery and earnings to MySQL, and returns the breakdown.
//
// GET /api/pay/history/:rider_id — Returns earnings history for
//   the Rider Dashboard chart (FairDrop vs cliff comparison).

const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { calculatePay, validateRequest } = require('../payEngine');
const verifyToken = require('../middleware/verifyToken');

// Enforce JWT authentication on all pay routes
router.use(verifyToken);

// ── GET /api/pay/config ────────────────────────────────────────────────────
// FR-75: Active and scheduled config, read-only, for any authenticated user.
// Active config chosen by effective_from <= CURDATE() with no scheduler.
router.get('/config', async (req, res) => {
  try {
    const [activeRows] = await pool.execute(
      `SELECT config_id, base_rate, per_km_rate, surge_bonus,
              wait_threshold_mins, wait_compensation, min_wage_per_hour,
              effective_from, is_active, created_at, created_by, change_reason
       FROM pay_configs
       WHERE effective_from <= CURDATE()
       ORDER BY effective_from DESC, config_id DESC
       LIMIT 1`
    );

    const [scheduledRows] = await pool.execute(
      `SELECT config_id, base_rate, per_km_rate, surge_bonus,
              wait_threshold_mins, wait_compensation, min_wage_per_hour,
              effective_from, is_active, created_at, created_by, change_reason
       FROM pay_configs
       WHERE effective_from > CURDATE()
       ORDER BY effective_from ASC, config_id DESC
       LIMIT 1`
    );

    if (activeRows.length === 0) {
      return res.status(404).json({
        error: 'No active configuration',
        message: 'No active pay configuration found. Run the seed script.',
      });
    }

    return res.status(200).json({
      success: true,
      config: activeRows[0],
      active: activeRows[0],
      scheduled: scheduledRows.length > 0 ? scheduledRows[0] : null,
    });
  } catch (error) {
    console.error('GET /api/pay/config error:', error.message);
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message,
    });
  }
});

// ── POST /api/pay/riders ───────────────────────────────────────────────────
// Upsert rider in MySQL riders table (called on rider signup, FR-51 / D12)
router.post('/riders', async (req, res) => {
  try {
    const { rider_id, name } = req.body;
    if (!rider_id) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'rider_id is required',
      });
    }

    await pool.execute(
      `INSERT INTO riders (rider_id, name, is_active)
       VALUES (?, ?, TRUE)
       ON DUPLICATE KEY UPDATE name = VALUES(name), is_active = TRUE`,
      [rider_id, name || 'Rider']
    );

    return res.status(201).json({
      success: true,
      message: 'Rider created/updated in MySQL',
      rider_id,
    });
  } catch (error) {
    console.error('POST /api/pay/riders error:', error.message);
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message,
    });
  }
});

// ── POST /api/pay/calculate ────────────────────────────────────────────────
// API Contract: docs/api-contract.md
// Request:  rider_id, order_id, distance_km, is_surge_active,
//           restaurant_wait_mins, active_hours_today, delay_context
// Response: order_id, base_rate, distance_pay, surge_bonus,
//           wait_compensation, total_delivery_pay, floor_topup,
//           hourly_earnings_so_far

router.post('/calculate', async (req, res) => {
  try {
    // ── Step 1: Validate request using the pure engine's validator ──────
    try {
      validateRequest(req.body);
    } catch (validationError) {
      return res.status(400).json({
        error: 'Validation failed',
        message: validationError.message,
      });
    }

    const {
      rider_id,
      order_id,
      distance_km,
      is_surge_active,
      restaurant_wait_mins,
      active_hours_today,
      delay_context,
    } = req.body;

    // ── Step 2: Ensure rider exists in MySQL (upsert if missing) ───────
    await pool.execute(
      `INSERT INTO riders (rider_id, name, is_active)
       VALUES (?, 'Rider', TRUE)
       ON DUPLICATE KEY UPDATE is_active = TRUE`,
      [rider_id]
    );

    // ── Step 3: Check for duplicate order_id (idempotency per FR-74) ────
    const [existingEarnings] = await pool.execute(
      `SELECT order_id, base_rate, distance_pay, surge_bonus,
              wait_compensation, total_delivery_pay, floor_topup,
              hourly_earnings_so_far
       FROM earnings WHERE order_id = ?`,
      [order_id]
    );

    if (existingEarnings.length > 0) {
      const e = existingEarnings[0];
      return res.status(200).json({
        order_id: e.order_id,
        base_rate: parseFloat(e.base_rate),
        distance_pay: parseFloat(e.distance_pay),
        surge_bonus: parseFloat(e.surge_bonus),
        wait_compensation: parseFloat(e.wait_compensation),
        total_delivery_pay: parseFloat(e.total_delivery_pay),
        floor_topup: parseFloat(e.floor_topup),
        hourly_earnings_so_far: parseFloat(e.hourly_earnings_so_far),
        is_cached: true,
      });
    }

    // ── Step 4: Get active pay config from DB ───────────────────────────
    // Active config chosen by effective_from <= CURDATE() with no scheduler (FR-75)
    const [configs] = await pool.execute(
      `SELECT * FROM pay_configs
       WHERE effective_from <= CURDATE()
       ORDER BY effective_from DESC, config_id DESC
       LIMIT 1`
    );

    if (configs.length === 0) {
      return res.status(500).json({
        error: 'Configuration error',
        message: 'No active pay configuration found',
      });
    }

    const activeConfig = configs[0];
    const payConfig = {
      BASE_RATE: parseFloat(activeConfig.base_rate),
      PER_KM_RATE: parseFloat(activeConfig.per_km_rate),
      SURGE_BONUS: parseFloat(activeConfig.surge_bonus),
      WAIT_THRESHOLD_MINS: activeConfig.wait_threshold_mins,
      WAIT_COMPENSATION: parseFloat(activeConfig.wait_compensation),
      MIN_WAGE_PER_HOUR: parseFloat(activeConfig.min_wage_per_hour),
    };

    // ── Step 5: Get today's cumulative earnings for this rider ──────────
    // Needed for floor top-up calculation — the engine needs to know
    // how much the rider has already earned today.
    const [earningsRows] = await pool.execute(
      `SELECT COALESCE(SUM(total_delivery_pay), 0) AS cumulative_today
       FROM earnings
       WHERE rider_id = ? AND DATE(created_at) = CURDATE()`,
      [rider_id]
    );

    const cumulativeEarningsBeforeThisDelivery = parseFloat(earningsRows[0].cumulative_today);

    // ── Step 6: Calculate pay using the pure engine ─────────────────────
    // This is the core academic contribution — linear model with
    // surge, wait compensation, and floor top-up.
    const payResult = calculatePay(req.body, payConfig, cumulativeEarningsBeforeThisDelivery);

    // ── Step 7: Persist delivery record to MySQL ────────────────────────
    // Immutable after insert — forms the audit trail.
    const [deliveryInsert] = await pool.execute(
      `INSERT INTO deliveries
         (order_id, rider_id, config_id, distance_km, is_surge_active,
          restaurant_wait_mins, active_hours_today,
          delay_type, delay_verified, delay_source)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        order_id,
        rider_id,
        activeConfig.config_id,
        distance_km,
        is_surge_active,
        restaurant_wait_mins,
        active_hours_today,
        delay_context.type,
        delay_context.verified,
        delay_context.source,
      ]
    );

    const deliveryId = deliveryInsert.insertId;

    // ── Step 8: Persist earnings breakdown to MySQL ─────────────────────
    // One-to-one with deliveries table.
    await pool.execute(
      `INSERT INTO earnings
         (delivery_id, order_id, rider_id, base_rate, distance_pay,
          surge_bonus, wait_compensation, total_delivery_pay,
          floor_topup, hourly_earnings_so_far)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        deliveryId,
        order_id,
        rider_id,
        payResult.base_rate,
        payResult.distance_pay,
        payResult.surge_bonus,
        payResult.wait_compensation,
        payResult.total_delivery_pay,
        payResult.floor_topup,
        payResult.hourly_earnings_so_far,
      ]
    );

    // ── Step 9: Return pay breakdown (matches API contract response) ────
    return res.status(200).json(payResult);

  } catch (error) {
    console.error('POST /api/pay/calculate error:', error.message);
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message,
    });
  }
});

// ── GET /api/pay/history/:rider_id ─────────────────────────────────────────
// Returns earnings history for the Rider Dashboard.
// Used by the FairDrop vs cliff-bonus comparison chart (Week 11).

router.get('/history/:rider_id', async (req, res) => {
  try {
    const { rider_id } = req.params;

    // A rider may read only their own history; admins can view any rider's history
    if (req.user.role !== 'admin' && req.user.id !== rider_id) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Access denied. Riders can only view their own earnings history.',
      });
    }

    // Verify rider exists
    const [riders] = await pool.execute(
      'SELECT rider_id FROM riders WHERE rider_id = ?',
      [rider_id]
    );

    if (riders.length === 0) {
      return res.status(404).json({
        error: 'Rider not found',
        message: `rider_id "${rider_id}" does not exist`,
      });
    }

    // Fetch earnings with delivery details, most recent first
    const [history] = await pool.execute(
      `SELECT
         e.order_id,
         e.base_rate,
         e.distance_pay,
         e.surge_bonus,
         e.wait_compensation,
         e.total_delivery_pay,
         e.floor_topup,
         e.hourly_earnings_so_far,
         d.distance_km,
         d.is_surge_active,
         d.restaurant_wait_mins,
         e.created_at
       FROM earnings e
       JOIN deliveries d ON e.delivery_id = d.delivery_id
       WHERE e.rider_id = ?
       ORDER BY e.created_at DESC
       LIMIT 50`,
      [rider_id]
    );

    return res.status(200).json({
      rider_id,
      total_records: history.length,
      earnings: history,
    });

  } catch (error) {
    console.error('GET /api/pay/history error:', error.message);
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message,
    });
  }
});

// ── GET /api/pay/analytics/:rider_id ───────────────────────────────────────
// FR-34, FR-35, FR-36: FairDrop vs Cliff-Bonus Comparison & Analytics
// Returns actual cumulative comparison, explicit assumptions, and a labelled
// scenario in which the cliff model wins (for balanced framing).

router.get('/analytics/:rider_id', async (req, res) => {
  try {
    const { rider_id } = req.params;

    // A rider may read only their own analytics; admins can view any rider's analytics
    if (req.user.role !== 'admin' && req.user.id !== rider_id) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Access denied. Riders can only view their own analytics.',
      });
    }

    // Ensure rider row exists
    await pool.execute(
      `INSERT INTO riders (rider_id, name, is_active)
       VALUES (?, 'Rider', TRUE)
       ON DUPLICATE KEY UPDATE is_active = TRUE`,
      [rider_id]
    );

    // ── 1. Cliff Model Assumptions (FR-35) ──────────────────────────────
    const assumptions = {
      cliff_threshold_deliveries: 10,
      cliff_base_per_delivery: 20,
      cliff_bonus: 500,
      description:
        'Industry standard cliff-bonus model: ₹20 base pay per delivery with a ₹500 flat bonus upon reaching exactly 10 deliveries. Zero bonus for deliveries 1–9. No distance pay, no wait compensation, no hourly floor.',
    };

    // ── 2. Actual Deliveries Comparison (FR-34) ─────────────────────────
    const [rows] = await pool.execute(
      `SELECT
         e.order_id,
         e.base_rate,
         e.distance_pay,
         e.surge_bonus,
         e.wait_compensation,
         e.total_delivery_pay,
         e.floor_topup,
         e.hourly_earnings_so_far,
         d.distance_km,
         d.is_surge_active,
         d.restaurant_wait_mins,
         e.created_at
       FROM earnings e
       JOIN deliveries d ON e.delivery_id = d.delivery_id
       WHERE e.rider_id = ?
       ORDER BY e.created_at ASC, e.earning_id ASC`,
      [rider_id]
    );

    let cumulativeFairdrop = 0;
    const actualDataPoints = [];

    for (let i = 0; i < rows.length; i++) {
      const deliveryIndex = i + 1;
      const r = rows[i];
      const deliveryPay = parseFloat(r.total_delivery_pay) + parseFloat(r.floor_topup);
      cumulativeFairdrop += deliveryPay;

      const cliffPay =
        deliveryIndex * assumptions.cliff_base_per_delivery +
        (deliveryIndex >= assumptions.cliff_threshold_deliveries ? assumptions.cliff_bonus : 0);

      actualDataPoints.push({
        delivery_index: deliveryIndex,
        order_id: r.order_id,
        fairdrop_delivery_pay: parseFloat(deliveryPay.toFixed(2)),
        fairdrop_cumulative: parseFloat(cumulativeFairdrop.toFixed(2)),
        cliff_cumulative: parseFloat(cliffPay.toFixed(2)),
        difference: parseFloat((cumulativeFairdrop - cliffPay).toFixed(2)),
      });
    }

    const totalDeliveries = rows.length;
    const totalFairdrop = cumulativeFairdrop;
    const totalCliff =
      totalDeliveries * assumptions.cliff_base_per_delivery +
      (totalDeliveries >= assumptions.cliff_threshold_deliveries ? assumptions.cliff_bonus : 0);

    const actualComparison = {
      total_deliveries: totalDeliveries,
      fairdrop_total: parseFloat(totalFairdrop.toFixed(2)),
      cliff_total: parseFloat(totalCliff.toFixed(2)),
      fairdrop_advantage: parseFloat((totalFairdrop - totalCliff).toFixed(2)),
      data_points: actualDataPoints,
    };

    // ── 3. Cliff-Wins Scenario (FR-36) ──────────────────────────────────
    // A realistic scenario in which a rider clears the 10-delivery threshold:
    // 10 short 2 km deliveries with no surge/wait over 4 active hours.
    // Cliff: 10 * ₹20 + ₹500 = ₹700
    // FairDrop: 10 * (₹15 + ₹12) = ₹270 + ₹10 floor topup = ₹280
    // Cliff wins by ₹420!
    const scenarioDeliveries = 10;
    const scenarioDataPoints = [];
    let scenarioFairdropCum = 0;

    for (let i = 1; i <= scenarioDeliveries; i++) {
      const perDeliveryPay = 15 + 2 * 6; // ₹27 per delivery
      scenarioFairdropCum += perDeliveryPay;

      // Add minimum wage floor at step 10 (4 hours @ ₹70/hr = ₹280 floor; ₹270 + ₹10 topup)
      const fairdropAtStep = i === 10 ? 280 : scenarioFairdropCum;

      const cliffAtStep =
        i * assumptions.cliff_base_per_delivery +
        (i >= assumptions.cliff_threshold_deliveries ? assumptions.cliff_bonus : 0);

      scenarioDataPoints.push({
        delivery_index: i,
        fairdrop_cumulative: fairdropAtStep,
        cliff_cumulative: cliffAtStep,
        difference: fairdropAtStep - cliffAtStep,
      });
    }

    const cliffWinsScenario = {
      scenario_name: 'High-Volume Target-Achieved Shift (10 Deliveries)',
      description:
        'A rider completes 10 short deliveries (2 km each) within a 4-hour peak window, clearing the cliff threshold.',
      winner: 'cliff',
      deliveries_count: 10,
      fairdrop_total: 280,
      cliff_total: 700,
      cliff_advantage: 420,
      rationale:
        'When a rider clears the 10-delivery quota, the ₹500 bonus elevates cliff earnings to ₹700 vs FairDrop ₹280. However, Fairwork data shows over 80% of shifts fail to reach quota due to fatigue, weather, or order droughts, resulting in severe cliff penalties.',
      data_points: scenarioDataPoints,
    };

    return res.status(200).json({
      success: true,
      rider_id,
      assumptions,
      actual_comparison: actualComparison,
      cliff_wins_scenario: cliffWinsScenario,
    });
  } catch (error) {
    console.error('GET /api/pay/analytics error:', error.message);
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message,
    });
  }
});

module.exports = router;
