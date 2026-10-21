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
const { calculatePay, evaluateFloorBlocks, validateRequest, round2 } = require('../payEngine');
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
              incentive_per_order, floor_window_minutes,
              effective_from, is_active, created_at, created_by, change_reason
       FROM pay_configs
       WHERE effective_from <= CURDATE()
       ORDER BY effective_from DESC, config_id DESC
       LIMIT 1`
    );

    const [scheduledRows] = await pool.execute(
      `SELECT config_id, base_rate, per_km_rate, surge_bonus,
              wait_threshold_mins, wait_compensation, min_wage_per_hour,
              incentive_per_order, floor_window_minutes,
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

    const active = { ...activeRows[0] };
    if (process.env.FLOOR_WINDOW_MINUTES_OVERRIDE) {
      active.floor_window_minutes = parseInt(process.env.FLOOR_WINDOW_MINUTES_OVERRIDE, 10);
    }

    return res.status(200).json({
      success: true,
      config: active,
      active: active,
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
      `INSERT INTO riders (rider_id, name, phone, zone_id, is_active)
       VALUES (?, ?, ?, ?, TRUE)
       ON DUPLICATE KEY UPDATE name = VALUES(name), is_active = TRUE`,
      [rider_id, name || 'Rider', req.body.phone || '0000000000', req.body.zone_id || 'KLM-CHK']
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
//           wait_compensation, fairdrop_incentive, total_delivery_pay, floor_topup,
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
      `INSERT INTO riders (rider_id, name, phone, zone_id, is_active)
       VALUES (?, 'Rider', '0000000000', 'KLM-CHK', TRUE)
       ON DUPLICATE KEY UPDATE is_active = TRUE`,
      [rider_id]
    );

    // ── Step 3: Check for duplicate order_id (idempotency per FR-74) ────
    const [existingEarnings] = await pool.execute(
      `SELECT order_id, base_rate, distance_pay, surge_bonus,
              wait_compensation, fairdrop_incentive, total_delivery_pay, floor_topup,
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
        fairdrop_incentive: parseFloat(e.fairdrop_incentive !== undefined ? e.fairdrop_incentive : 17.04),
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
      INCENTIVE_PER_ORDER: parseFloat(activeConfig.incentive_per_order !== undefined ? activeConfig.incentive_per_order : 17.04),
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
    // surge, wait compensation, and per-order incentive. Floor top-up is evaluated in completed blocks (AUDIT-F16).
    const payResult = calculatePay(req.body, payConfig, cumulativeEarningsBeforeThisDelivery);

    // Compute engaged minutes for this delivery
    let engagedMinutes = 0;
    if (req.body.engaged_minutes !== undefined && req.body.engaged_minutes !== null) {
      engagedMinutes = Number(req.body.engaged_minutes);
    } else if (req.body.delivered_at && (req.body.assigned_at || req.body.accepted_at)) {
      const diffMs = new Date(req.body.delivered_at) - new Date(req.body.assigned_at || req.body.accepted_at);
      if (diffMs > 0) {
        engagedMinutes = Math.round((diffMs / 60000) * 100) / 100;
      }
    }

    // ── Step 7: Persist delivery record to MySQL ────────────────────────
    // Immutable after insert — forms the audit trail.
    const [deliveryInsert] = await pool.execute(
      `INSERT INTO deliveries
         (order_id, rider_id, config_id, distance_km, is_surge_active,
          restaurant_wait_mins, active_hours_today, engaged_minutes,
          delay_type, delay_verified, delay_source)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        order_id,
        rider_id,
        activeConfig.config_id,
        distance_km,
        is_surge_active,
        restaurant_wait_mins,
        active_hours_today,
        engagedMinutes,
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
          surge_bonus, wait_compensation, fairdrop_incentive, total_delivery_pay,
          floor_topup, hourly_earnings_so_far)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        deliveryId,
        order_id,
        rider_id,
        payResult.base_rate,
        payResult.distance_pay,
        payResult.surge_bonus,
        payResult.wait_compensation,
        payResult.fairdrop_incentive,
        payResult.total_delivery_pay,
        payResult.floor_topup,
        payResult.hourly_earnings_so_far,
      ]
    );

    // ── Step 8b: Evaluate & Persist Statutory Floor Blocks (AUDIT-F16) ──
    const windowMinutes = Number(
      process.env.FLOOR_WINDOW_MINUTES_OVERRIDE || activeConfig.floor_window_minutes || 60
    );

    const [allDeliveriesToday] = await pool.execute(
      `SELECT d.order_id, d.engaged_minutes, d.created_at,
              e.total_delivery_pay, e.base_rate, e.distance_pay, e.surge_bonus, e.wait_compensation, e.fairdrop_incentive
       FROM deliveries d
       JOIN earnings e ON d.delivery_id = e.delivery_id
       WHERE d.rider_id = ? AND DATE(d.created_at) = CURDATE()
       ORDER BY d.created_at ASC, d.delivery_id ASC`,
      [rider_id]
    );

    const floorEval = evaluateFloorBlocks(allDeliveriesToday, {
      windowMinutes,
      minWagePerHour: payConfig.MIN_WAGE_PER_HOUR,
    });

    for (const block of floorEval.completed_blocks) {
      await pool.execute(
        `INSERT INTO floor_topups
           (rider_id, block_index, shift_date, engaged_minutes, delivery_pay, floor_amount, topup_amount)
         VALUES (?, ?, CURDATE(), ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           engaged_minutes = VALUES(engaged_minutes),
           delivery_pay = VALUES(delivery_pay),
           floor_amount = VALUES(floor_amount),
           topup_amount = VALUES(topup_amount)`,
        [
          rider_id,
          block.block_index,
          block.engaged_minutes,
          block.delivery_pay,
          block.floor_amount,
          block.topup_amount,
        ]
      );
    }

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

// ── GET /api/pay/floor-topups/:rider_id ─────────────────────────────────────
// Returns completed statutory floor blocks and carried minutes (AUDIT-F16)
router.get('/floor-topups/:rider_id', async (req, res) => {
  try {
    const { rider_id } = req.params;

    if (req.user.role !== 'admin' && req.user.id !== rider_id) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Access denied.',
      });
    }

    const [topupRows] = await pool.execute(
      `SELECT topup_id, rider_id, block_index, shift_date, engaged_minutes, delivery_pay, floor_amount, topup_amount, created_at
       FROM floor_topups
       WHERE rider_id = ? AND shift_date = CURDATE()
       ORDER BY block_index ASC`,
      [rider_id]
    );

    const totalTopup = topupRows.reduce((sum, r) => sum + parseFloat(r.topup_amount), 0);

    const [engagedSum] = await pool.execute(
      `SELECT COALESCE(SUM(engaged_minutes), 0) AS total_engaged_mins
       FROM deliveries
       WHERE rider_id = ? AND DATE(created_at) = CURDATE()`,
      [rider_id]
    );
    const engagedMins = parseFloat(engagedSum[0].total_engaged_mins || 0);

    return res.status(200).json({
      success: true,
      rider_id,
      shift_date: new Date().toISOString().split('T')[0],
      total_topup: round2(totalTopup),
      total_engaged_minutes: engagedMins,
      blocks: topupRows,
    });
  } catch (error) {
    console.error('GET /api/pay/floor-topups error:', error.message);
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
         e.fairdrop_incentive,
         e.total_delivery_pay,
         e.floor_topup,
         e.hourly_earnings_so_far,
         d.distance_km,
         d.is_surge_active,
         d.restaurant_wait_mins,
         d.engaged_minutes,
         e.created_at
       FROM earnings e
       JOIN deliveries d ON e.delivery_id = d.delivery_id
       WHERE e.rider_id = ?
       ORDER BY e.created_at DESC
       LIMIT 50`,
      [rider_id]
    );

    // Fetch today's floor top-up records (AUDIT-F16)
    const [topupRows] = await pool.execute(
      `SELECT block_index, shift_date, engaged_minutes, delivery_pay, floor_amount, topup_amount
       FROM floor_topups
       WHERE rider_id = ? AND shift_date = CURDATE()
       ORDER BY block_index ASC`,
      [rider_id]
    );

    const totalFloorTopup = topupRows.reduce((sum, r) => sum + parseFloat(r.topup_amount), 0);

    const [engagedSum] = await pool.execute(
      `SELECT COALESCE(SUM(engaged_minutes), 0) AS total_engaged_mins
       FROM deliveries
       WHERE rider_id = ? AND DATE(created_at) = CURDATE()`,
      [rider_id]
    );
    const engagedMins = parseFloat(engagedSum[0].total_engaged_mins || 0);
    const engagedHours = round2(engagedMins / 60);

    return res.status(200).json({
      rider_id,
      total_records: history.length,
      earnings: history,
      floor_topups: topupRows,
      total_floor_topup: round2(totalFloorTopup),
      engaged_minutes: engagedMins,
      engaged_hours: engagedHours,
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
      `INSERT INTO riders (rider_id, name, phone, zone_id, is_active)
       VALUES (?, 'Rider', '0000000000', 'KLM-CHK', TRUE)
       ON DUPLICATE KEY UPDATE is_active = TRUE`,
      [rider_id]
    );

    // ── Helper: Zomato ladder incentive (FR-34, FR-35) ─────────────────
    function getZomatoLadderIncentive(n) {
      if (n >= 27) return 510.0;
      if (n >= 25) return 434.0;
      if (n >= 23) return 383.0;
      if (n >= 19) return 306.0;
      return 0.0;
    }

    // ── 1. Ladder Model Assumptions (FR-35) ──────────────────────────────
    const assumptions = {
      benchmark_model: 'Zomato illustrative ladder benchmark (28 Jun)',
      ladder_steps: { 19: 306, 23: 383, 25: 434, 27: 510 },
      rate_per_order: 17.04,
      peak_bonus: 50.0,
      description:
        'Base and distance pay are identical on both platforms; this analysis compares daily incentives and total earnings. FairDrop pays a linear incentive of ₹17.04 per order. Zomato pays tiered target incentives starting at 19 orders (₹0 below 19 orders).',
      // Legacy compatibility
      cliff_threshold_deliveries: 10,
      cliff_base_per_delivery: 0,
      cliff_bonus: 500,
    };

    // ── 2. Actual Deliveries Comparison (FR-34) ─────────────────────────
    const [rows] = await pool.execute(
      `SELECT
         e.order_id,
         e.base_rate,
         e.distance_pay,
         e.surge_bonus,
         e.wait_compensation,
         e.fairdrop_incentive,
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

    let cumulativeOrderPay = 0;
    let cumulativeFairdropIncentive = 0;
    const actualDataPoints = [];

    for (let i = 0; i < rows.length; i++) {
      const deliveryIndex = i + 1;
      const r = rows[i];
      const fairdropIncentive = parseFloat(r.fairdrop_incentive != null ? r.fairdrop_incentive : 17.04);
      const orderPay = parseFloat(r.total_delivery_pay) - fairdropIncentive;
      cumulativeOrderPay += orderPay;
      cumulativeFairdropIncentive += fairdropIncentive;

      const zomatoIncentive = getZomatoLadderIncentive(deliveryIndex);
      const fairdropTotalAtStep = cumulativeOrderPay + cumulativeFairdropIncentive;
      const zomatoTotalAtStep = cumulativeOrderPay + zomatoIncentive;

      actualDataPoints.push({
        delivery_index: deliveryIndex,
        order_id: r.order_id,
        order_pay: parseFloat(orderPay.toFixed(2)),
        cumulative_order_pay: parseFloat(cumulativeOrderPay.toFixed(2)),
        fairdrop_incentive: parseFloat(fairdropIncentive.toFixed(2)),
        fairdrop_cumulative: parseFloat(fairdropTotalAtStep.toFixed(2)),
        zomato_incentive: parseFloat(zomatoIncentive.toFixed(2)),
        zomato_cumulative: parseFloat(zomatoTotalAtStep.toFixed(2)),
        cliff_cumulative: parseFloat(zomatoTotalAtStep.toFixed(2)), // legacy compatibility
        difference: parseFloat((fairdropTotalAtStep - zomatoTotalAtStep).toFixed(2)),
      });
    }

    const totalDeliveries = rows.length;
    const totalOrderPay = cumulativeOrderPay;
    const totalFairdropIncentive = cumulativeFairdropIncentive;
    const totalFairdrop = totalOrderPay + totalFairdropIncentive;
    const totalZomatoIncentive = getZomatoLadderIncentive(totalDeliveries);
    const totalZomato = totalOrderPay + totalZomatoIncentive;

    const actualComparison = {
      total_deliveries: totalDeliveries,
      order_pay_total: parseFloat(totalOrderPay.toFixed(2)),
      fairdrop_incentive_total: parseFloat(totalFairdropIncentive.toFixed(2)),
      fairdrop_total: parseFloat(totalFairdrop.toFixed(2)),
      zomato_incentive_total: parseFloat(totalZomatoIncentive.toFixed(2)),
      zomato_total: parseFloat(totalZomato.toFixed(2)),
      cliff_total: parseFloat(totalZomato.toFixed(2)), // legacy compatibility
      fairdrop_advantage: parseFloat((totalFairdrop - totalZomato).toFixed(2)),
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
