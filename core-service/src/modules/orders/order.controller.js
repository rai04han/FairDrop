// FairDrop — Order Controller
// Owner: Hari (25MCA025)
// Module: Orders (Module 2)
//
// Handles the full order lifecycle per PRD v2.1 (FR-58, FR-60, FR-67, FR-68, FR-70, FR-72, FR-73):
//   1. Customer places order → DB item pricing enforced, unavailable rejected, haversine distance computed,
//      auto-accepted (status: "accepted"), allocation runs (FR-68).
//   2. If rider available → order.rider_id set, rider_ack: "pending", allocation: "allocated".
//      If none available → allocation: "no_rider_available", allocated when rider goes online (FR-72).
//   3. Rider accepts → status: "assigned", rider_ack: "accepted".
//      Rider declines → re-allocated excluding decliner (FR-15, D7).
//   4. Rider arrives → status: "arrived", arrived_at recorded.
//   5. Rider picks up → status: "picked_up", picked_up_at recorded.
//   6. Rider delivers → status: "delivered", delivered_at recorded → triggers pay calculation.

const Order = require('./Order.model');
const Counter = require('./Counter.model');
const MenuItem = require('./MenuItem.model');
const User = require('../auth/User.model');
const Zone = require('../zones/Zone.model');
const { calculatePay } = require('./payClient');
const {
  calculateHaversine,
  findZoneForLocation,
  runAllocation,
} = require('./allocation.service');

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
 * Places a new order:
 *   - Verifies restaurant exists
 *   - Fetches item prices from DB (never trusts client prices, FR-240)
 *   - Rejects unavailable items with 400 (FR-57, FR-240)
 *   - Computes straight-line haversine distance in km, 2 decimals (FR-70, D9)
 *   - Auto-accepts order with status = "accepted" (FR-66, FR-67)
 *   - Runs zone-based allocation algorithm (FR-68) with out-of-zone cap check (FR-73)
 *   - If no rider available, sets allocation: "no_rider_available" (FR-60, D6)
 */
async function createOrder(req, res) {
  try {
    const {
      restaurant_id,
      items,
      delivery_address,
      restaurant_address,
      distance_km: clientDistanceKm,
      restaurant_wait_mins,
      delay_context,
    } = req.body;

    // ── 1. Validate required fields ───────────────────────────────────
    if (!restaurant_id || !items || !delivery_address) {
      return res.status(400).json({
        success: false,
        message: 'restaurant_id, items, and delivery_address are required.',
      });
    }

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'items must be a non-empty array.',
      });
    }

    if (delivery_address.coordinates && Array.isArray(delivery_address.coordinates) && delivery_address.coordinates.length >= 2) {
      if (delivery_address.longitude === undefined) delivery_address.longitude = Number(delivery_address.coordinates[0]);
      if (delivery_address.latitude === undefined) delivery_address.latitude = Number(delivery_address.coordinates[1]);
    }

    if (
      delivery_address.latitude === undefined ||
      delivery_address.longitude === undefined
    ) {
      return res.status(400).json({
        success: false,
        message: 'delivery_address must include latitude and longitude.',
      });
    }

    // ── 2. Verify restaurant exists ───────────────────────────────────
    const restaurant = await User.findById(restaurant_id);
    if (!restaurant || restaurant.role !== 'restaurant') {
      return res.status(404).json({
        success: false,
        message: 'Restaurant not found.',
      });
    }

    // Resolve restaurant address & coordinates
    const effectiveRestAddress = {
      label: restaurant_address?.label || restaurant.address?.label || restaurant.name,
      latitude: Number(restaurant_address?.latitude ?? restaurant.address?.latitude ?? 0),
      longitude: Number(restaurant_address?.longitude ?? restaurant.address?.longitude ?? 0),
    };

    // ── 3. Resolve items from DB & enforce availability (FR-57, FR-240) ─
    const resolvedItems = [];
    for (const item of items) {
      const quantity = Number(item.quantity);
      if (!quantity || quantity < 1) {
        return res.status(400).json({
          success: false,
          message: 'Item quantity must be a positive number.',
        });
      }

      let menuItem = null;
      const itemId = item.item_id || item._id || item.id;
      if (itemId) {
        menuItem = await MenuItem.findById(itemId);
      }
      if (!menuItem && item.name) {
        menuItem = await MenuItem.findOne({
          restaurant_id,
          name: item.name,
        });
      }

      if (!menuItem) {
        return res.status(400).json({
          success: false,
          message: `Item "${item.name || itemId}" not found in restaurant menu.`,
        });
      }

      if (menuItem.restaurant_id.toString() !== restaurant_id.toString()) {
        return res.status(400).json({
          success: false,
          message: `Item "${menuItem.name}" does not belong to the selected restaurant.`,
        });
      }

      if (menuItem.is_available === false) {
        return res.status(400).json({
          success: false,
          message: `Item "${menuItem.name}" is currently unavailable.`,
        });
      }

      // Enforce DB price and prep time
      resolvedItems.push({
        item_id: menuItem._id,
        name: menuItem.name,
        quantity,
        price: Number(menuItem.price), // Always DB price!
        prep_time_seconds: Number(menuItem.prep_time_seconds || 0),
      });
    }

    // ── 4. Compute haversine straight-line distance (FR-70, D9) ───────
    let computedDistanceKm = calculateHaversine(
      effectiveRestAddress.latitude,
      effectiveRestAddress.longitude,
      Number(delivery_address.latitude),
      Number(delivery_address.longitude)
    );

    if (computedDistanceKm === 0 && clientDistanceKm) {
      computedDistanceKm = Number(clientDistanceKm);
    }
    const distance_km = Math.round(computedDistanceKm * 100) / 100;

    // ── 5. Generate sequential order ID ───────────────────────────────
    const order_id = await Counter.getNextOrderId();

    // ── 6. Find restaurant zone ───────────────────────────────────────
    const restaurantZone = await findZoneForLocation(
      effectiveRestAddress.latitude,
      effectiveRestAddress.longitude,
      restaurant.assigned_zone_code || restaurant.rider_profile?.assigned_zone_code
    );

    const now = new Date();

    // ── 7. Auto-accept order on placement (FR-66, FR-67) ───────────────
    const order = new Order({
      order_id,
      customer_id: req.user.id,
      restaurant_id,
      items: resolvedItems,
      delivery_address: {
        label: delivery_address.label || '',
        latitude: Number(delivery_address.latitude),
        longitude: Number(delivery_address.longitude),
      },
      restaurant_address: effectiveRestAddress,
      distance_km,
      zone_id: restaurantZone?._id || null,
      is_surge_active: isSurgeHour(),
      restaurant_wait_mins: restaurant_wait_mins || 0,
      delay_context: delay_context || { type: 'none', verified: false, source: 'none' },
      status: 'accepted',
      accepted_at: now,
      rider_ack: 'pending',
      status_history: [
        { status: 'placed', changed_at: now, changed_by: req.user.id },
        { status: 'accepted', changed_at: now, changed_by: req.user.id },
      ],
    });

    // ── 8. Run Allocation algorithm (FR-68, FR-73) ───────────────────
    const alloc = await runAllocation(order, restaurantZone);
    if (alloc.allocated) {
      order.rider_id = alloc.rider._id;
      order.allocation = 'allocated';
      order.is_out_of_zone = alloc.is_out_of_zone;
      order.out_of_zone_distance_km = alloc.out_of_zone_distance_km;
    } else {
      order.rider_id = null;
      order.allocation = 'no_rider_available';
    }

    await order.save();

    res.status(201).json({
      success: true,
      message: `Order ${order_id} placed successfully.`,
      allocation: order.allocation,
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
 * PATCH /api/orders/:id/accept
 * Role: rider
 *
 * Rider accepts the allocated order (FR-15, FR-67).
 * Sets rider_ack = "accepted" and status = "assigned".
 */
async function acceptOrder(req, res) {
  try {
    const order = await Order.findOne({ order_id: req.params.id });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found.' });
    }

    if (!order.rider_id || order.rider_id.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You are not the allocated rider for this order.',
      });
    }

    if (order.status !== 'accepted' && order.status !== 'assigned') {
      return res.status(400).json({
        success: false,
        message: `Order cannot be accepted in status "${order.status}".`,
      });
    }

    order.rider_ack = 'accepted';
    order.status = 'assigned';
    order.status_history.push({
      status: 'assigned',
      changed_at: new Date(),
      changed_by: req.user.id,
    });

    await order.save();

    res.json({
      success: true,
      message: `Order ${order.order_id} accepted.`,
      order,
    });
  } catch (error) {
    console.error('Accept order error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * PATCH /api/orders/:id/decline
 * Role: rider
 *
 * Rider declines the order without penalty (FR-15, D7).
 * Order is released and reallocated to another online idle rider excluding the decliner.
 */
async function declineOrder(req, res) {
  try {
    const order = await Order.findOne({ order_id: req.params.id });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found.' });
    }

    if (!order.rider_id || order.rider_id.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You are not the allocated rider for this order.',
      });
    }

    if (!order.declined_by) order.declined_by = [];
    order.declined_by.push(req.user.id);
    order.rider_id = null;
    order.rider_ack = 'pending';

    // Re-run allocation excluding decliners (FR-15, FR-68, D7)
    const restZone = order.zone_id
      ? await Zone.findById(order.zone_id)
      : await findZoneForLocation(
          order.restaurant_address.latitude,
          order.restaurant_address.longitude
        );

    const alloc = await runAllocation(order, restZone);
    if (alloc.allocated) {
      order.rider_id = alloc.rider._id;
      order.allocation = 'allocated';
      order.is_out_of_zone = alloc.is_out_of_zone;
      order.out_of_zone_distance_km = alloc.out_of_zone_distance_km;
    } else {
      order.rider_id = null;
      order.allocation = 'no_rider_available';
    }

    await order.save();

    res.json({
      success: true,
      message: 'Order declined without penalty and reallocated.',
      allocation: order.allocation,
      order,
    });
  } catch (error) {
    console.error('Decline order error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * PATCH /api/orders/:id/status
 * Role: rider, restaurant
 *
 * Updates order status. Enforces valid transitions:
 *   placed → accepted / assigned
 *   accepted → assigned
 *   assigned → arrived / picked_up
 *   arrived → picked_up
 *   picked_up → delivered
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

    // ── Enforce rider ownership check ────────────────────────────────
    if (req.user.role === 'rider' && order.rider_id && order.rider_id.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You are not the allocated rider for this order.',
      });
    }

    // ── Idempotent delivery completion (FR-74) ───────────────────────
    if (order.status === 'delivered' && new_status === 'delivered') {
      return res.status(200).json({
        success: true,
        message: `Order ${order.order_id} status updated to "delivered".`,
        order,
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

    const now = new Date();

    // ── Update order fields ──────────────────────────────────────────
    order.status = new_status;
    order.status_history.push({
      status: new_status,
      changed_at: now,
      changed_by: req.user.id,
    });

    if (new_status === 'assigned') {
      if (!order.rider_id) {
        order.rider_id = req.user.id;
      }
      order.rider_ack = 'accepted';
    } else if (new_status === 'arrived') {
      order.arrived_at = now;
    } else if (new_status === 'picked_up') {
      order.picked_up_at = now;
      // Server-computed restaurant wait time rounded up to whole minutes (FR-18, D10)
      if (order.arrived_at) {
        const elapsedMs = order.picked_up_at.getTime() - new Date(order.arrived_at).getTime();
        const computedMins = Math.ceil(Math.max(0, elapsedMs) / 60000);
        order.restaurant_wait_mins = restaurant_wait_mins !== undefined
          ? Math.max(computedMins, restaurant_wait_mins)
          : computedMins;
      } else if (restaurant_wait_mins !== undefined) {
        order.restaurant_wait_mins = restaurant_wait_mins;
      }
    } else if (new_status === 'delivered') {
      order.delivered_at = now;
    }

    if (restaurant_wait_mins !== undefined && new_status !== 'picked_up') {
      order.restaurant_wait_mins = restaurant_wait_mins;
    }
    if (delay_context) {
      order.delay_context = delay_context;
    }

    // ── On delivery: call Pay Engine & update zone if out-of-zone (FR-73, D3) ──
    if (new_status === 'delivered') {
      const callerToken = req.headers.authorization;
      try {
        const rider = await User.findById(order.rider_id);
        const activeHours = rider?.rider_profile?.active_hours_today
          ? Math.max(rider.rider_profile.active_hours_today, 0.0001)
          : 1;

        const payResult = await calculatePay(order, activeHours, callerToken);
        order.pay_calculation_result = payResult;
        order.pay_status = 'calculated';
      } catch (payError) {
        console.error('Pay calculation failed:', payError.message);
        order.pay_calculation_result = {
          error: true,
          message: payError.message,
          note: 'Pay calculation failed. Needs manual review.',
        };
        order.pay_status = 'pending';
      }

      // Update rider's current_zone_id if out-of-zone delivery (FR-73, D3)
      try {
        const rider = await User.findById(order.rider_id);
        if (rider && rider.rider_profile) {
          const dropZone = await findZoneForLocation(
            order.delivery_address.latitude,
            order.delivery_address.longitude
          );
          if (dropZone) {
            rider.rider_profile.current_zone_id = dropZone._id;
            rider.rider_profile.current_zone_code = dropZone.zone_id || dropZone.name;
            await rider.save();
          }
        }
      } catch (zoneErr) {
        console.error('Failed to update rider zone after delivery:', zoneErr.message);
      }
    }

    await order.save();

    // FR-60, D6: Allocate queued pending orders as soon as a rider completes delivery
    if (new_status === 'delivered') {
      try {
        const unallocatedOrders = await Order.find({
          rider_id: null,
          status: { $in: ['placed', 'accepted'] },
        }).sort({ created_at: 1 });

        for (const pendingOrder of unallocatedOrders) {
          const restZone = pendingOrder.zone_id
            ? await Zone.findById(pendingOrder.zone_id)
            : await findZoneForLocation(
                pendingOrder.restaurant_address?.latitude,
                pendingOrder.restaurant_address?.longitude
              );

          const alloc = await runAllocation(pendingOrder, restZone);
          if (alloc.allocated) {
            pendingOrder.rider_id = alloc.rider._id;
            pendingOrder.rider_ack = 'pending';
            pendingOrder.allocation = 'allocated';
            pendingOrder.is_out_of_zone = alloc.is_out_of_zone;
            pendingOrder.out_of_zone_distance_km = alloc.out_of_zone_distance_km;
            pendingOrder.status = 'accepted';
            pendingOrder.status_history.push({
              status: 'accepted',
              changed_at: new Date(),
              changed_by: alloc.rider._id,
            });
            await pendingOrder.save();
          }
        }
      } catch (allocErr) {
        console.error('FR-60 Allocation on delivery completion error:', allocErr.message);
      }
    }

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
 * POST /api/orders/:id/retry-pay
 * Role: rider, admin
 *
 * Retries pay calculation for a delivered order whose pay_status is pending or errored (FR-24).
 */
async function retryPay(req, res) {
  try {
    const order = await Order.findOne({ order_id: req.params.id });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found.' });
    }

    if (order.status !== 'delivered') {
      return res.status(400).json({
        success: false,
        message: 'Order must be delivered before pay calculation can be retried.',
      });
    }

    if (req.user.role === 'rider' && order.rider_id?.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You can only retry pay for your own deliveries.',
      });
    }

    const rider = await User.findById(order.rider_id);
    const activeHours = rider?.rider_profile?.active_hours_today
      ? Math.max(rider.rider_profile.active_hours_today, 0.0001)
      : 1;

    const callerToken = req.headers.authorization;
    const payResult = await calculatePay(order, activeHours, callerToken);

    order.pay_calculation_result = payResult;
    order.pay_status = 'calculated';
    await order.save();

    res.json({
      success: true,
      message: 'Pay calculation retried successfully.',
      pay_status: 'calculated',
      order,
    });
  } catch (error) {
    console.error('Retry pay error:', error.message);
    res.status(502).json({
      success: false,
      message: `Pay calculation retry failed: ${error.message}`,
      pay_status: 'pending',
    });
  }
}

/**
 * GET /api/orders/rider/active
 * Role: rider
 *
 * Returns the rider's currently active order (FR-67):
 * Matches an order where rider_id = this rider and:
 *   - status == "accepted" with rider_ack == "pending"
 *   - status in ["assigned", "arrived", "picked_up"]
 */
async function getRiderActiveOrder(req, res) {
  try {
    let order = await Order.findOne({
      rider_id: req.user.id,
      $or: [
        { status: 'accepted', rider_ack: 'pending' },
        { status: { $in: ['assigned', 'arrived', 'picked_up'] } },
      ],
    });

    // If no order currently assigned to this rider, and this rider is online and active,
    // check if there are pending unallocated orders waiting for a rider (FR-60, FR-72, D6)
    if (!order) {
      const rider = await User.findById(req.user.id);
      if (rider && rider.rider_profile?.is_online) {
        const unallocatedOrders = await Order.find({
          rider_id: null,
          status: { $in: ['placed', 'accepted'] },
        }).sort({ created_at: 1 });

        for (const pendingOrder of unallocatedOrders) {
          const restZone = pendingOrder.zone_id
            ? await Zone.findById(pendingOrder.zone_id)
            : await findZoneForLocation(
                pendingOrder.restaurant_address?.latitude,
                pendingOrder.restaurant_address?.longitude
              );

          const alloc = await runAllocation(pendingOrder, restZone);
          if (alloc.allocated && alloc.rider._id.toString() === req.user.id) {
            pendingOrder.rider_id = req.user.id;
            pendingOrder.rider_ack = 'pending';
            pendingOrder.allocation = 'allocated';
            pendingOrder.is_out_of_zone = alloc.is_out_of_zone;
            pendingOrder.out_of_zone_distance_km = alloc.out_of_zone_distance_km;
            pendingOrder.status = 'accepted';
            pendingOrder.status_history.push({
              status: 'accepted',
              changed_at: new Date(),
              changed_by: req.user.id,
            });
            await pendingOrder.save();
            order = pendingOrder;
            break;
          }
        }
      }
    }

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
 * GET /api/orders/restaurants
 * Role: customer, rider, admin
 *
 * Returns all restaurant users (id, name, email, address).
 */
async function getRestaurants(req, res) {
  try {
    const restaurants = await User.find({ role: 'restaurant' })
      .select('_id name email address')
      .sort({ name: 1 });

    res.json({
      success: true,
      count: restaurants.length,
      restaurants,
    });
  } catch (error) {
    console.error('Get restaurants error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * GET /api/orders/history
 * Role: customer, rider, restaurant, admin
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
  acceptOrder,
  declineOrder,
  retryPay,
  getRiderActiveOrder,
  getOrderHistory,
  getRestaurants,
};
