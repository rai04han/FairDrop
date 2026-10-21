// FairDrop — Rider Controller
// Owner: Hari (25MCA025)
// Module: Riders (Online/Offline, Shifts & Daily Stats)
//
// Handles rider status toggles, shift tracking, and daily dashboard statistics.

const User = require('../auth/User.model');
const Order = require('../orders/Order.model');
const Zone = require('../zones/Zone.model');
const { findZoneForLocation, runAllocation } = require('../orders/allocation.service');

/**
 * Calculates active hours for today from session timestamps (FR-9).
 * Active hours is the sum of today's completed sessions plus
 * the elapsed time of any currently open session.
 *
 * @param {Object} riderProfile
 * @returns {number} Active hours rounded to 2 decimal places
 */
function calculateActiveHours(riderProfile) {
  if (!riderProfile) return 0;
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  let totalMs = 0;
  const sessions = riderProfile.shift_sessions || [];

  for (const s of sessions) {
    if (!s.started_at) continue;
    const sessionStart = new Date(s.started_at);
    const sessionEnd = s.ended_at ? new Date(s.ended_at) : new Date();

    const effectiveStart = Math.max(sessionStart.getTime(), today.getTime());
    const effectiveEnd = Math.max(sessionEnd.getTime(), today.getTime());

    if (effectiveEnd > effectiveStart) {
      totalMs += effectiveEnd - effectiveStart;
    }
  }

  // If online right now but no unclosed session in shift_sessions, also count current_session_started_at
  if (riderProfile.is_online && riderProfile.current_session_started_at) {
    const hasOpen = sessions.some((s) => !s.ended_at);
    if (!hasOpen) {
      const now = Date.now();
      const start = Math.max(new Date(riderProfile.current_session_started_at).getTime(), today.getTime());
      if (now > start) {
        totalMs += now - start;
      }
    }
  }

  const hours = totalMs / (1000 * 60 * 60);
  return Math.round(hours * 100) / 100;
}

/**
 * POST /api/riders/status (and /api/rider/status)
 * Role: rider
 *
 * Toggles rider online/offline status and manages shift session timestamps (FR-7, FR-9, FR-54).
 * If going online, triggers allocation of pending unallocated orders (FR-72).
 */
async function setStatus(req, res) {
  try {
    const { is_online } = req.body;

    if (typeof is_online !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'is_online must be a boolean (true or false).',
      });
    }

    const rider = await User.findById(req.user.id);
    if (!rider || rider.role !== 'rider') {
      return res.status(404).json({
        success: false,
        message: 'Rider not found.',
      });
    }

    if (!rider.rider_profile) {
      rider.rider_profile = {};
    }

    const wasOnline = rider.rider_profile.is_online || false;
    const now = new Date();

    if (is_online && !wasOnline) {
      // Transition Offline -> Online
      rider.rider_profile.is_online = true;
      rider.rider_profile.is_available = true;
      rider.rider_profile.current_session_started_at = now;
      if (!Array.isArray(rider.rider_profile.shift_sessions)) {
        rider.rider_profile.shift_sessions = [];
      }
      rider.rider_profile.shift_sessions.push({ started_at: now, ended_at: null });

      await rider.save();

      // Trigger allocation for pending unallocated orders (FR-72)
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
        console.error('FR-72 Allocation on online error:', allocErr.message);
      }
    } else if (!is_online && wasOnline) {
      // Transition Online -> Offline
      rider.rider_profile.is_online = false;
      rider.rider_profile.is_available = false;

      // Close open session
      const sessions = rider.rider_profile.shift_sessions || [];
      const openSession = sessions.find((s) => !s.ended_at);
      if (openSession) {
        openSession.ended_at = now;
      } else if (rider.rider_profile.current_session_started_at) {
        sessions.push({
          started_at: rider.rider_profile.current_session_started_at,
          ended_at: now,
        });
      }

      rider.rider_profile.current_session_started_at = null;
      rider.rider_profile.active_hours_today = calculateActiveHours(rider.rider_profile);
      await rider.save();
    }

    const activeHours = calculateActiveHours(rider.rider_profile);

    return res.status(200).json({
      success: true,
      is_online: rider.rider_profile.is_online,
      active_hours_today: activeHours,
      message: `Rider is now ${rider.rider_profile.is_online ? 'online' : 'offline'}.`,
    });
  } catch (error) {
    console.error('setStatus error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Server error updating rider status.',
    });
  }
}

/**
 * GET /api/riders/stats (and /api/rider/stats/today)
 * Role: rider
 *
 * Returns today's active hours, completed deliveries, earnings, and zone (FR-8, FR-9).
 */
async function getStats(req, res) {
  try {
    const rider = await User.findById(req.user.id);
    if (!rider || rider.role !== 'rider') {
      return res.status(404).json({
        success: false,
        message: 'Rider not found.',
      });
    }

    const profile = rider.rider_profile || {};
    const activeHours = calculateActiveHours(profile);

    // Get today's delivered orders for this rider
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const deliveredOrders = await Order.find({
      rider_id: rider._id,
      status: 'delivered',
      updated_at: { $gte: today },
    });

    // Calculate engaged hours from delivered orders today (AUDIT-F16)
    let engagedMsToday = 0;
    for (const order of deliveredOrders) {
      const assignedTime = order.assigned_at || order.accepted_at || order.created_at;
      const deliveredTime = order.delivered_at || order.updated_at;
      if (assignedTime && deliveredTime) {
        const diff = new Date(deliveredTime).getTime() - new Date(assignedTime).getTime();
        if (diff > 0) engagedMsToday += diff;
      }
    }
    const engagedHours = Math.round((engagedMsToday / (1000 * 60 * 60)) * 100) / 100;

    const deliveriesToday = deliveredOrders.length;
    let totalDeliveryPayToday = 0;
    let basePayToday = 0;
    let distancePayToday = 0;
    let waitPayToday = 0;
    let surgePayToday = 0;
    let incentivePayToday = 0;

    for (const order of deliveredOrders) {
      if (order.pay_calculation_result) {
        const base = parseFloat(order.pay_calculation_result.base_rate || 0);
        const dist = parseFloat(order.pay_calculation_result.distance_pay || 0);
        const wait = parseFloat(order.pay_calculation_result.wait_compensation || 0);
        const surge = parseFloat(order.pay_calculation_result.surge_bonus || 0);
        const incentive = parseFloat(order.pay_calculation_result.fairdrop_incentive !== undefined ? order.pay_calculation_result.fairdrop_incentive : 17.04);
        const deliveryPay = parseFloat(
          order.pay_calculation_result.total_delivery_pay !== undefined
            ? order.pay_calculation_result.total_delivery_pay
            : (base + dist + wait + surge + incentive)
        );

        basePayToday += base;
        distancePayToday += dist;
        waitPayToday += wait;
        surgePayToday += surge;
        incentivePayToday += incentive;
        totalDeliveryPayToday += deliveryPay;
      }
    }

    // Fetch statutory floor topups today from pay-service (AUDIT-F16)
    let floorTopupToday = 0;
    try {
      const payServiceUrl = process.env.PAY_SERVICE_URL || 'http://localhost:3001';
      const payRes = await fetch(`${payServiceUrl}/api/pay/floor-topups/${rider._id}`, {
        headers: { Authorization: req.headers.authorization },
      });
      if (payRes.ok) {
        const payData = await payRes.json();
        floorTopupToday = parseFloat(payData.total_topup || 0);
      }
    } catch (_) {}

    const totalEarningsToday = Math.round((totalDeliveryPayToday + floorTopupToday) * 100) / 100;
    const baseDistancePayToday = Math.round((basePayToday + distancePayToday) * 100) / 100;
    waitPayToday = Math.round(waitPayToday * 100) / 100;
    surgePayToday = Math.round(surgePayToday * 100) / 100;
    incentivePayToday = Math.round(incentivePayToday * 100) / 100;
    floorTopupToday = Math.round(floorTopupToday * 100) / 100;
    const currentZone = profile.current_zone_code || profile.assigned_zone_code || 'KLM-CHK';
    const hourlyRate = engagedHours > 0 ? Math.round((totalEarningsToday / engagedHours) * 100) / 100 : 0;

    return res.status(200).json({
      success: true,
      stats: {
        active_hours_today: engagedHours,
        engaged_hours_today: engagedHours,
        deliveries_today: deliveriesToday,
        total_earnings_today: totalEarningsToday,
        base_pay_today: Math.round(basePayToday * 100) / 100,
        distance_pay_today: Math.round(distancePayToday * 100) / 100,
        base_distance_pay_today: baseDistancePayToday,
        wait_pay_today: waitPayToday,
        surge_pay_today: surgePayToday,
        incentive_pay_today: incentivePayToday,
        fairdrop_incentive_today: incentivePayToday,
        floor_topup_today: floorTopupToday,
        current_zone: currentZone,
        current_zone_id: profile.current_zone_id || profile.zone_id || null,
        is_online: profile.is_online || false,
        hourly_rate: hourlyRate,
      },
    });
  } catch (error) {
    console.error('getStats error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Server error retrieving rider stats.',
    });
  }
}

/**
 * POST /api/riders/checklist (and /api/rider/onboarding/acknowledge)
 * Role: rider
 *
 * Sets safety_checklist_acknowledged to true on the server (FR-46).
 */
async function acknowledgeChecklist(req, res) {
  try {
    const rider = await User.findById(req.user.id);
    if (!rider || rider.role !== 'rider') {
      return res.status(404).json({
        success: false,
        message: 'Rider not found.',
      });
    }

    if (!rider.rider_profile) {
      rider.rider_profile = {};
    }

    rider.rider_profile.safety_checklist_acknowledged = true;
    await rider.save();

    return res.status(200).json({
      success: true,
      message: 'Safety checklist acknowledged successfully.',
    });
  } catch (error) {
    console.error('acknowledgeChecklist error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Server error acknowledging safety checklist.',
    });
  }
}

module.exports = {
  setStatus,
  getStats,
  acknowledgeChecklist,
  calculateActiveHours,
};
