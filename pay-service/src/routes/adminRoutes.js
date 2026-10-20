// FairDrop Pay Service — Admin Pay Config Routes
// Owner: Raihan
//
// Admin routes for managing platform pay configurations.
// All routes require a valid JWT with the 'admin' role.

const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const verifyToken = require('../middleware/verifyToken');
const requireRole = require('../middleware/requireRole');

// Enforce admin auth on all admin routes
router.use(verifyToken);
router.use(requireRole('admin'));

// ── GET /api/admin/pay-config ──────────────────────────────────────────────
// Returns the active pay configuration row.
router.get('/pay-config', async (req, res) => {
  try {
    const [configs] = await pool.execute(
      `SELECT config_id, base_rate, per_km_rate, surge_bonus,
              wait_threshold_mins, wait_compensation, min_wage_per_hour,
              effective_from, is_active, created_at, created_by, change_reason
       FROM pay_configs
       WHERE effective_from <= CURDATE()
       ORDER BY effective_from DESC, config_id DESC
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

// ── GET /api/admin/pay-config/history ──────────────────────────────────────
// Returns all configurations (newest effective date first) for audit trail (FR-39).
router.get('/pay-config/history', async (req, res) => {
  try {
    const [history] = await pool.execute(
      `SELECT config_id, base_rate, per_km_rate, surge_bonus,
              wait_threshold_mins, wait_compensation, min_wage_per_hour,
              effective_from, is_active, created_at, created_by, change_reason
       FROM pay_configs
       ORDER BY effective_from DESC, config_id DESC`
    );

    return res.status(200).json({
      success: true,
      count: history.length,
      history,
    });
  } catch (error) {
    console.error('GET /api/admin/pay-config/history error:', error.message);
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message,
    });
  }
});

// ── Handler for creating a new pay configuration (PUT or POST) ─────────────
// Enforces 7-day advance notice rule (FR-41), mandatory reason (FR-42),
// and numeric constraints (FR-43).
async function savePayConfig(req, res) {
  try {
    const {
      base_rate,
      per_km_rate,
      surge_bonus,
      wait_threshold_mins,
      wait_compensation,
      min_wage_per_hour,
      effective_from,
      change_reason,
    } = req.body;

    // 1. Validate required fields
    const requiredFields = [
      'base_rate',
      'per_km_rate',
      'surge_bonus',
      'wait_threshold_mins',
      'wait_compensation',
      'min_wage_per_hour',
      'effective_from',
      'change_reason',
    ];

    for (const field of requiredFields) {
      if (req.body[field] === undefined || req.body[field] === null || req.body[field] === '') {
        return res.status(400).json({
          error: 'Validation failed',
          message: `Missing required field: ${field}`,
        });
      }
    }

    // 2. Validate numeric non-negative fields
    const numericFields = {
      base_rate: parseFloat(base_rate),
      per_km_rate: parseFloat(per_km_rate),
      surge_bonus: parseFloat(surge_bonus),
      wait_compensation: parseFloat(wait_compensation),
      min_wage_per_hour: parseFloat(min_wage_per_hour),
    };

    for (const [field, value] of Object.entries(numericFields)) {
      if (isNaN(value) || value < 0) {
        return res.status(400).json({
          error: 'Validation failed',
          message: `${field} must be a non-negative number`,
        });
      }
    }

    // 3. Validate wait_threshold_mins is non-negative whole number (integer)
    const thresholdNum = Number(wait_threshold_mins);
    if (!Number.isInteger(thresholdNum) || thresholdNum < 0) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'wait_threshold_mins must be a non-negative whole integer (minutes)',
      });
    }

    // 4. Validate change_reason is non-empty string
    if (typeof change_reason !== 'string' || change_reason.trim().length === 0) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'change_reason is mandatory and cannot be empty (audit requirement)',
      });
    }

    // 5. Enforce 7-day advance notice rule (FR-41)
    // Date from client must be >= today + 7 days
    const parts = String(effective_from).split('-');
    if (parts.length !== 3) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid effective_from date format. Expected YYYY-MM-DD.',
      });
    }
    const [y, m, d] = parts.map(Number);
    if (!y || !m || !d || isNaN(y) || isNaN(m) || isNaN(d)) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid effective_from date format. Expected YYYY-MM-DD.',
      });
    }

    const clientDateMidnight = new Date(y, m - 1, d);
    if (
      isNaN(clientDateMidnight.getTime()) ||
      clientDateMidnight.getFullYear() !== y ||
      clientDateMidnight.getMonth() !== m - 1 ||
      clientDateMidnight.getDate() !== d
    ) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid effective_from date format. Expected YYYY-MM-DD.',
      });
    }

    // Build the stored date string directly from validated y/m/d parts (consistent with MySQL CURDATE())
    const effectiveFromStr = `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;

    // Comparison using the same local-date basis
    const now = new Date();
    const todayLocal = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const diffDays = Math.round((clientDateMidnight - todayLocal) / (1000 * 60 * 60 * 24));
    if (diffDays < 7) {
      return res.status(400).json({
        error: 'Validation failed',
        message: `7-day advance notice required. Date is ${diffDays} day(s) out; must be at least 7 days from today.`,
      });
    }

    const createdBy = req.user.id ? String(req.user.id) : (req.user.role || 'admin');

    // 6. Insert new config row
    const [result] = await pool.execute(
      `INSERT INTO pay_configs
         (base_rate, per_km_rate, surge_bonus,
          wait_threshold_mins, wait_compensation, min_wage_per_hour,
          effective_from, is_active, created_by, change_reason)
       VALUES (?, ?, ?, ?, ?, ?, ?, FALSE, ?, ?)`,
      [
        numericFields.base_rate,
        numericFields.per_km_rate,
        numericFields.surge_bonus,
        thresholdNum,
        numericFields.wait_compensation,
        numericFields.min_wage_per_hour,
        effectiveFromStr,
        createdBy,
        change_reason.trim(),
      ]
    );

    return res.status(200).json({
      success: true,
      message: 'Pay configuration created successfully with 7-day advance notice.',
      config_id: result.insertId,
      effective_from: effectiveFromStr,
      notice: `New config takes effect on ${effectiveFromStr}`,
    });
  } catch (error) {
    console.error('Save pay-config error:', error.message);
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message,
    });
  }
}

router.put('/pay-config', savePayConfig);
router.post('/pay-config', savePayConfig);

module.exports = router;
