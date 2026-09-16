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

    // ── Step 2: Check rider exists in MySQL ─────────────────────────────
    const [riders] = await pool.execute(
      'SELECT rider_id FROM riders WHERE rider_id = ?',
      [rider_id]
    );

    if (riders.length === 0) {
      return res.status(404).json({
        error: 'Rider not found',
        message: `rider_id "${rider_id}" does not exist in Pay Engine database`,
      });
    }

    // ── Step 3: Check for duplicate order_id ────────────────────────────
    const [existingOrder] = await pool.execute(
      'SELECT order_id FROM deliveries WHERE order_id = ?',
      [order_id]
    );

    if (existingOrder.length > 0) {
      return res.status(409).json({
        error: 'Duplicate order',
        message: `order_id "${order_id}" has already been processed`,
      });
    }

    // ── Step 4: Get active pay config from DB ───────────────────────────
    // In production, constants come from admin-configured pay_configs table,
    // not from the hardcoded constants.js file.
    const [configs] = await pool.execute(
      'SELECT * FROM pay_configs WHERE is_active = TRUE LIMIT 1'
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

module.exports = router;
