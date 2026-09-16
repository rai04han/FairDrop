// FairDrop Pay Service — Admin Pay Config Routes
// Owner: Raihan
//
// GET  /api/admin/pay-config — Returns the currently active pay configuration
// PUT  /api/admin/pay-config — Creates a new config (old row retained for audit)
//
// Policy: 7-day advance notice before any pay structure change.
//         effective_from must be >= 7 days from creation date.
//         change_reason is mandatory (Fairwork P6 — Fair Contracts).
//
// Auth: JWT validation will be provided by Harikrishnan's Auth module.
//       Currently stubbed — see TODO comments below.

const express = require('express');
const router = express.Router();
const { pool } = require('../db');

// ── GET /api/admin/pay-config ──────────────────────────────────────────────
// Returns the active pay configuration row.
// Used by the Flutter Admin Panel to display current constants.

router.get('/pay-config', async (req, res) => {
  try {
    // TODO: Validate admin JWT from Harikrishnan's Auth module (Port 3003)
    // const token = req.headers.authorization?.split(' ')[1];
    // const decoded = await verifyAdminToken(token);

    const [configs] = await pool.execute(
      `SELECT config_id, base_rate, per_km_rate, surge_bonus,
              wait_threshold_mins, wait_compensation, min_wage_per_hour,
              effective_from, is_active, created_at, created_by, change_reason
       FROM pay_configs
       WHERE is_active = TRUE
       LIMIT 1`
    );

    if (configs.length === 0) {
      return res.status(404).json({
        error: 'No active configuration',
        message: 'No active pay configuration found. Run the seed script.',
      });
    }

    return res.status(200).json({
      config: configs[0],
    });

  } catch (error) {
    console.error('GET /api/admin/pay-config error:', error.message);
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message,
    });
  }
});

// ── PUT /api/admin/pay-config ──────────────────────────────────────────────
// Creates a new pay configuration row.
// The old active config is deactivated but RETAINED for audit trail.
//
// Enforces:
//   1. All config fields must be present and valid
//   2. effective_from must be >= 7 days from today (7-day notice policy)
//   3. change_reason is mandatory (audit requirement)

router.put('/pay-config', async (req, res) => {
  try {
    // TODO: Validate admin JWT from Harikrishnan's Auth module (Port 3003)
    // const token = req.headers.authorization?.split(' ')[1];
    // const decoded = await verifyAdminToken(token);

    const {
      base_rate,
      per_km_rate,
      surge_bonus,
      wait_threshold_mins,
      wait_compensation,
      min_wage_per_hour,
      change_reason,
    } = req.body;

    // ── Validate required fields ────────────────────────────────────────
    const requiredFields = [
      'base_rate', 'per_km_rate', 'surge_bonus',
      'wait_threshold_mins', 'wait_compensation',
      'min_wage_per_hour', 'change_reason',
    ];

    for (const field of requiredFields) {
      if (req.body[field] === undefined || req.body[field] === null) {
        return res.status(400).json({
          error: 'Validation failed',
          message: `Missing required field: ${field}`,
        });
      }
    }

    // ── Validate numeric fields are positive ────────────────────────────
    const numericFields = {
      base_rate, per_km_rate, surge_bonus,
      wait_threshold_mins, wait_compensation, min_wage_per_hour,
    };

    for (const [field, value] of Object.entries(numericFields)) {
      if (typeof value !== 'number' || value < 0) {
        return res.status(400).json({
          error: 'Validation failed',
          message: `${field} must be a non-negative number`,
        });
      }
    }

    // ── Validate change_reason is non-empty string ──────────────────────
    if (typeof change_reason !== 'string' || change_reason.trim().length === 0) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'change_reason must be a non-empty string (audit requirement)',
      });
    }

    // ── Enforce 7-day advance notice policy ─────────────────────────────
    // Fairwork P6 (Fair Contracts P2): Workers must receive advance
    // notice before pay structure changes take effect.
    const today = new Date();
    const effectiveFrom = new Date(today);
    effectiveFrom.setDate(today.getDate() + 7);
    const effectiveFromStr = effectiveFrom.toISOString().split('T')[0]; // YYYY-MM-DD

    // ── Deactivate current config + insert new one (transaction) ────────
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      // Deactivate all currently active configs
      await connection.execute(
        'UPDATE pay_configs SET is_active = FALSE WHERE is_active = TRUE'
      );

      // Insert new config as active
      const [result] = await connection.execute(
        `INSERT INTO pay_configs
           (base_rate, per_km_rate, surge_bonus,
            wait_threshold_mins, wait_compensation, min_wage_per_hour,
            effective_from, is_active, created_by, change_reason)
         VALUES (?, ?, ?, ?, ?, ?, ?, TRUE, ?, ?)`,
        [
          base_rate,
          per_km_rate,
          surge_bonus,
          wait_threshold_mins,
          wait_compensation,
          min_wage_per_hour,
          effectiveFromStr,
          'admin', // TODO: Extract from JWT claims when Auth module is integrated
          change_reason,
        ]
      );

      await connection.commit();

      return res.status(200).json({
        message: 'Pay configuration updated successfully',
        config_id: result.insertId,
        effective_from: effectiveFromStr,
        notice: '7-day advance notice applied. New config takes effect on ' + effectiveFromStr,
      });

    } catch (txError) {
      await connection.rollback();
      throw txError;
    } finally {
      connection.release();
    }

  } catch (error) {
    console.error('PUT /api/admin/pay-config error:', error.message);
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message,
    });
  }
});

module.exports = router;
