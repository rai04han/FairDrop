// FairDrop — Restaurant Controller
// Owner: Hari (25MCA025)
// Module: Restaurants (Menu Management & Restaurant Orders)
//
// Handles restaurant portal operations per PRD v2.1:
//   - FR-62: List restaurant's own items with name, price, prep seconds, availability
//   - FR-63: Add/Edit item (strictly name, price, whole-second prep time, availability)
//   - FR-64: Toggle availability for own items (no deletion)
//   - FR-65: Restaurant orders list with items and derived is_ready flag
//   - FR-66: Orders auto-accepted on placement (no restaurant manual accept/mark-ready)

const MenuItem = require('../orders/MenuItem.model');
const Order = require('../orders/Order.model');
const User = require('../auth/User.model');

/**
 * GET /api/restaurants/:id/menu
 * Role: any authenticated user
 *
 * Returns all menu items for a specific restaurant.
 */
async function getRestaurantMenu(req, res) {
  try {
    const restaurantId = req.params.id;
    const restaurant = await User.findById(restaurantId);

    if (!restaurant || restaurant.role !== 'restaurant') {
      return res.status(404).json({
        success: false,
        message: 'Restaurant not found.',
      });
    }

    const items = await MenuItem.find({ restaurant_id: restaurantId }).sort({ name: 1 });

    res.json({
      success: true,
      restaurant: {
        id: restaurant._id,
        name: restaurant.name,
        address: restaurant.address,
      },
      count: items.length,
      items,
    });
  } catch (error) {
    console.error('getRestaurantMenu error:', error.message);
    res.status(500).json({ success: false, message: 'Server error retrieving menu.' });
  }
}

/**
 * GET /api/restaurants/menu
 * Role: restaurant
 *
 * Returns the logged-in restaurant's own menu items (FR-62).
 */
async function getMyMenu(req, res) {
  try {
    const items = await MenuItem.find({ restaurant_id: req.user.id }).sort({ created_at: -1 });

    res.json({
      success: true,
      count: items.length,
      items,
    });
  } catch (error) {
    console.error('getMyMenu error:', error.message);
    res.status(500).json({ success: false, message: 'Server error retrieving your menu.' });
  }
}

/**
 * POST /api/restaurants/menu
 * Role: restaurant
 *
 * Adds a new menu item for the logged-in restaurant (FR-63).
 * Fields: name, price, prep_time_seconds, is_available.
 */
async function addMenuItem(req, res) {
  try {
    const { name, price, prep_time_seconds, is_available } = req.body;

    if (!name || typeof name !== 'string' || name.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'name is required and must be a non-empty string.',
      });
    }

    if (price === undefined || typeof price !== 'number' || price < 0) {
      return res.status(400).json({
        success: false,
        message: 'price must be a non-negative number.',
      });
    }

    if (
      prep_time_seconds === undefined ||
      typeof prep_time_seconds !== 'number' ||
      prep_time_seconds < 0 ||
      !Number.isInteger(prep_time_seconds)
    ) {
      return res.status(400).json({
        success: false,
        message: 'prep_time_seconds must be a non-negative whole integer.',
      });
    }

    const item = await MenuItem.create({
      restaurant_id: req.user.id,
      name: name.trim(),
      price,
      prep_time_seconds,
      is_available: is_available !== undefined ? Boolean(is_available) : true,
    });

    res.status(201).json({
      success: true,
      message: `Menu item "${item.name}" created successfully.`,
      item,
    });
  } catch (error) {
    console.error('addMenuItem error:', error.message);
    res.status(500).json({ success: false, message: 'Server error creating menu item.' });
  }
}

/**
 * PATCH /api/restaurants/menu/:item_id
 * Role: restaurant
 *
 * Updates an existing item or toggles its availability (FR-63, FR-64).
 * Strict ownership: a restaurant can only modify its own items.
 */
async function updateMenuItem(req, res) {
  try {
    const item = await MenuItem.findById(req.params.item_id);

    if (!item) {
      return res.status(404).json({
        success: false,
        message: 'Menu item not found.',
      });
    }

    if (item.restaurant_id.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You can only edit items from your own restaurant menu.',
      });
    }

    const { name, price, prep_time_seconds, is_available } = req.body;

    if (name !== undefined) {
      if (typeof name !== 'string' || name.trim() === '') {
        return res.status(400).json({
          success: false,
          message: 'name must be a non-empty string.',
        });
      }
      item.name = name.trim();
    }

    if (price !== undefined) {
      if (typeof price !== 'number' || price < 0) {
        return res.status(400).json({
          success: false,
          message: 'price must be a non-negative number.',
        });
      }
      item.price = price;
    }

    if (prep_time_seconds !== undefined) {
      if (typeof prep_time_seconds !== 'number' || prep_time_seconds < 0 || !Number.isInteger(prep_time_seconds)) {
        return res.status(400).json({
          success: false,
          message: 'prep_time_seconds must be a non-negative whole integer.',
        });
      }
      item.prep_time_seconds = prep_time_seconds;
    }

    if (is_available !== undefined) {
      item.is_available = Boolean(is_available);
    }

    await item.save();

    res.json({
      success: true,
      message: `Menu item "${item.name}" updated successfully.`,
      item,
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(404).json({ success: false, message: 'Menu item not found.' });
    }
    console.error('updateMenuItem error:', error.message);
    res.status(500).json({ success: false, message: 'Server error updating menu item.' });
  }
}

/**
 * GET /api/restaurants/orders
 * Role: restaurant
 *
 * Lists the restaurant's orders with items and status, including derived is_ready flag (FR-65, FR-69).
 */
async function getRestaurantOrders(req, res) {
  try {
    const orders = await Order.find({ restaurant_id: req.user.id })
      .sort({ created_at: -1 })
      .limit(50);

    res.json({
      success: true,
      count: orders.length,
      orders,
    });
  } catch (error) {
    console.error('getRestaurantOrders error:', error.message);
    res.status(500).json({ success: false, message: 'Server error retrieving restaurant orders.' });
  }
}

module.exports = {
  getRestaurantMenu,
  getMyMenu,
  addMenuItem,
  updateMenuItem,
  getRestaurantOrders,
};
