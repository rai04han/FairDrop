// FairDrop — Restaurant Routes
// Owner: Hari (25MCA025)
// Module: Restaurants (Menu Management & Orders)

const express = require('express');
const router = express.Router();
const {
  getRestaurantMenu,
  getMyMenu,
  addMenuItem,
  updateMenuItem,
  getRestaurantOrders,
} = require('./restaurant.controller');
const verifyToken = require('../../middleware/verifyToken');
const requireRole = require('../../middleware/requireRole');

// ── All restaurant routes require authentication ───────────────────────────
router.use(verifyToken);

// Read logged-in restaurant's own menu (FR-62)
router.get('/menu', requireRole('restaurant'), getMyMenu);

// Add new menu item (FR-63)
router.post('/menu', requireRole('restaurant'), addMenuItem);

// Update menu item or toggle availability (FR-63, FR-64)
router.patch('/menu/:item_id/availability', requireRole('restaurant'), updateMenuItem);
router.patch('/menu/:item_id', requireRole('restaurant'), updateMenuItem);

// Read restaurant orders list with is_ready (FR-65, FR-69)
router.get('/orders', requireRole('restaurant'), getRestaurantOrders);

// Read menu for any restaurant by restaurant_id (FR-57)
router.get('/:id/menu', getRestaurantMenu);

module.exports = router;
