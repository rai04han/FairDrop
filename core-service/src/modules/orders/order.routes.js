// FairDrop — Order Routes
// Owner: Hari (25MCA025)
// Module: Orders (Module 2)
//
// Maps URLs to controller functions with role-based access control.
// Every route requires a valid JWT token (verifyToken).
// Specific routes are restricted by role (requireRole).

const express = require('express');
const router = express.Router();
const {
  createOrder,
  getOrder,
  updateStatus,
  getRiderActiveOrder,
  getOrderHistory,
} = require('./order.controller');
const verifyToken = require('../../middleware/verifyToken');
const requireRole = require('../../middleware/requireRole');

// ── All order routes require authentication ────────────────────────────────
router.use(verifyToken);

// ── Specific routes (must be defined BEFORE /:id to avoid conflicts) ───────

// Rider's current active order
router.get('/rider/active', requireRole('rider'), getRiderActiveOrder);

// Order history (customers see their orders, riders see their deliveries)
router.get('/history', requireRole('customer', 'rider', 'admin'), getOrderHistory);

// ── CRUD routes ────────────────────────────────────────────────────────────

// Place a new order (customer only)
router.post('/', requireRole('customer'), createOrder);

// Get order by ID (any authenticated user)
router.get('/:id', getOrder);

// Update order status (rider or restaurant)
router.patch('/:id/status', requireRole('rider', 'restaurant'), updateStatus);

module.exports = router;
