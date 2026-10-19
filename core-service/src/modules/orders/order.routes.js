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
  acceptOrder,
  declineOrder,
  retryPay,
  getRiderActiveOrder,
  getOrderHistory,
  getRestaurants,
} = require('./order.controller');
const verifyToken = require('../../middleware/verifyToken');
const requireRole = require('../../middleware/requireRole');

// ── All order routes require authentication ────────────────────────────────
router.use(verifyToken);

// ── Specific routes (must be defined BEFORE /:id to avoid conflicts) ───────

// List all restaurants (any authenticated user — needed to place orders)
router.get('/restaurants', requireRole('customer', 'rider', 'admin'), getRestaurants);

// Rider's current active order
router.get('/rider/active', requireRole('rider'), getRiderActiveOrder);

// Order history (customers see their orders, riders see their deliveries)
router.get('/history', requireRole('customer', 'rider', 'admin'), getOrderHistory);

// ── Order actions ──────────────────────────────────────────────────────────

// Rider accepts allocated order (FR-15, FR-67)
router.patch('/:id/accept', requireRole('rider'), acceptOrder);

// Rider declines allocated order without penalty (FR-15, D7)
router.patch('/:id/decline', requireRole('rider'), declineOrder);

// Retry pay calculation for delivered order with pending pay (FR-24)
router.post('/:id/retry-pay', requireRole('rider', 'admin'), retryPay);

// ── CRUD routes ────────────────────────────────────────────────────────────

// Place a new order (customer only)
router.post('/', requireRole('customer'), createOrder);

// Get order by ID (any authenticated user)
router.get('/:id', getOrder);

// Update order status (rider or restaurant)
router.patch('/:id/status', requireRole('rider', 'restaurant'), updateStatus);

module.exports = router;
