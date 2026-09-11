// FairDrop — Order Controller
// Owner: Hari (25MCA025)
// Module: Orders (Module 2)
//
// Handles the full order lifecycle:
//   1. Customer places order → status: "placed"
//   2. System assigns rider → status: "assigned"
//   3. Rider picks up food → status: "picked_up"
//   4. Rider delivers food → status: "delivered" → triggers pay calculation
//
// Every status change is logged in status_history[] for transparency.

const Order = require('./Order.model');
const Counter = require('./Counter.model');
const User = require('../auth/User.model');
const { calculatePay } = require('./payClient');

// ── Surge hours (from PRD) ─────────────────────────────────────────────────
// Lunch: 12:00–14:00, Dinner: 19:00–21:00

function isSurgeHour() {
  const hour = new Date().getHours();
  return (hour >= 12 && hour < 14) || (hour >= 19 && hour < 21);
}

/**
 * POST /api/orders
 * Role: customer
 *
 * Places a new order. Auto-detects surge pricing based on time of day.
 */
async function createOrder(req, res) {
  try {
    const {
      restaurant_id,
      items,
      delivery_address,
      restaurant_address,
      distance_km,
      restaurant_wait_mins,
      delay_context,
    } = req.body;

    // ── Validate required fields ─────────────────────────────────────
    if (!restaurant_id || !items || !delivery_address || !restaurant_address || !distance_km) {
      return res.status(400).json({
        success: false,
        message: 'restaurant_id, items, delivery_address, restaurant_address, and distance_km are required.',
      });
    }

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'items must be a non-empty array.',
      });
    }

    // ── Verify restaurant exists ─────────────────────────────────────
    const restaurant = await User.findById(restaurant_id);
    if (!restaurant || restaurant.role !== 'restaurant') {
      return res.status(404).json({
        success: false,
        message: 'Restaurant not found.',
      });
    }

    // ── Generate sequential order ID ─────────────────────────────────
    const order_id = await Counter.getNextOrderId();

    // ── Create the order ─────────────────────────────────────────────
    const order = await Order.create({
      order_id,
      customer_id: req.user.id,
      restaurant_id,
      items,
      delivery_address,
      restaurant_address,
      distance_km,
      is_surge_active: isSurgeHour(),
      restaurant_wait_mins: restaurant_wait_mins || 0,
      delay_context: delay_context || { type: 'none', verified: false, source: 'none' },
      status: 'placed',
      status_history: [
        { status: 'placed', changed_by: req.user.id },
      ],
    });

    res.status(201).json({
      success: true,
      message: `Order ${order_id} placed successfully.`,
      order,
    });
  } catch (error) {
    console.error('Create order error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Server error while placing order.',
    });
  }
}

/**
 * GET /api/orders/:id
 * Role: any authenticated user
 *
 * Returns a single order by its order_id (e.g. ORD-20260911-0001).
 */
async function getOrder(req, res) {
  try {
    const order = await Order.findOne({ order_id: req.params.id });

    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found.',
      });
    }

    res.json({ success: true, order });
  } catch (error) {
    console.error('Get order error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * PATCH /api/orders/:id/status
 * Role: rider, restaurant
 *
 * Updates order status. Enforces valid transitions:
 *   placed → assigned → picked_up → delivered
 *
 * On "delivered": calls Raihan's Pay Engine and stores the pay result.
 */
async function updateStatus(req, res) {
  try {
    const { new_status, restaurant_wait_mins, delay_context } = req.body;

    if (!new_status) {
      return res.status(400).json({
        success: false,
        message: 'new_status is required.',
      });
    }

    const order = await Order.findOne({ order_id: req.params.id });

    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found.',
      });
    }

    // ── Enforce valid status transitions ─────────────────────────────
    const allowedNext = Order.VALID_TRANSITIONS[order.status];
    if (!allowedNext || !allowedNext.includes(new_status)) {
      return res.status(400).json({
        success: false,
        message: `Cannot transition from "${order.status}" to "${new_status}". Allowed: [${allowedNext.join(', ')}]`,
      });
    }

    // ── Update order fields ──────────────────────────────────────────
    order.status = new_status;
    order.status_history.push({
      status: new_status,
      changed_by: req.user.id,
    });

    // Assign rider when status changes to "assigned"
    if (new_status === 'assigned' && !order.rider_id) {
      order.rider_id = req.user.id;
    }

    // Update wait time and delay context if provided (typically at pickup/delivery)
    if (restaurant_wait_mins !== undefined) {
      order.restaurant_wait_mins = restaurant_wait_mins;
    }
    if (delay_context) {
      order.delay_context = delay_context;
    }

    // ── On delivery: call Pay Engine ─────────────────────────────────
    if (new_status === 'delivered') {
      try {
        // Get rider's active hours today
        const rider = await User.findById(order.rider_id);
        const activeHours = rider?.rider_profile?.active_hours_today || 1;

        const payResult = await calculatePay(order, activeHours);
        order.pay_calculation_result = payResult;
      } catch (payError) {
        // Pay calculation failed — store the error but don't block delivery
        console.error('Pay calculation failed:', payError.message);
        order.pay_calculation_result = {
          error: true,
          message: payError.message,
          note: 'Pay calculation failed. Needs manual review.',
        };
      }
    }

    await order.save();

    res.json({
      success: true,
      message: `Order ${order.order_id} status updated to "${new_status}".`,
      order,
    });
  } catch (error) {
    console.error('Update status error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * GET /api/orders/rider/active
 * Role: rider
 *
 * Returns the rider's currently active order (assigned or picked_up).
 */
async function getRiderActiveOrder(req, res) {
  try {
    const order = await Order.findOne({
      rider_id: req.user.id,
      status: { $in: ['assigned', 'picked_up'] },
    });

    res.json({
      success: true,
      order: order || null,
      message: order ? 'Active order found.' : 'No active order.',
    });
  } catch (error) {
    console.error('Get active order error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * GET /api/orders/history
 * Role: customer, rider
 *
 * Returns past orders for the logged-in user.
 * Customers see orders they placed; riders see orders they delivered.
 */
async function getOrderHistory(req, res) {
  try {
    const { role, id } = req.user;

    let filter = {};
    if (role === 'customer') {
      filter = { customer_id: id };
    } else if (role === 'rider') {
      filter = { rider_id: id };
    } else {
      // Admin or restaurant — show all (admin) or restaurant's orders
      filter = role === 'admin' ? {} : { restaurant_id: id };
    }

    const orders = await Order.find(filter)
      .sort({ created_at: -1 })
      .limit(50);

    res.json({
      success: true,
      count: orders.length,
      orders,
    });
  } catch (error) {
    console.error('Order history error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

module.exports = {
  createOrder,
  getOrder,
  updateStatus,
  getRiderActiveOrder,
  getOrderHistory,
};
