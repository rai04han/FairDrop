// FairDrop — Pay Engine Client
// Owner: Hari (25MCA025)
// Module: Orders (Module 2)
//
// HTTP client that calls Raihan's Pay Engine when an order is delivered.
// Integration point:
//   core-service (port 3003) ──POST /api/pay/calculate──> pay-service (port 3001)
//
// Forwards the caller's JWT token or generates a valid token with shared JWT_SECRET (FR-244, FR-247).

const jwt = require('jsonwebtoken');
const env = require('../../config/env');

/**
 * Call Raihan's Pay Engine to calculate rider pay for a completed delivery.
 *
 * @param {Object} order - The delivered order document
 * @param {number} activeHoursToday - Rider's total active hours today
 * @param {string} [token] - Optional caller JWT Bearer token
 * @returns {Object} Pay breakdown from pay-service
 * @throws {Error} If pay-service is unreachable or returns an error
 */
async function calculatePay(order, activeHoursToday, token = null) {
  const payload = {
    rider_id: order.rider_id.toString(),
    order_id: order.order_id,
    distance_km: order.distance_km,
    is_surge_active: order.is_surge_active,
    restaurant_wait_mins: order.restaurant_wait_mins,
    active_hours_today: activeHoursToday,
    delay_context: {
      type: order.delay_context?.type || 'none',
      verified: order.delay_context?.verified || false,
      source: order.delay_context?.source || 'none',
    },
  };

  const authToken = token
    ? (token.startsWith('Bearer ') ? token : `Bearer ${token}`)
    : `Bearer ${jwt.sign({ id: order.rider_id, role: 'rider' }, env.JWT_SECRET, { expiresIn: '1h' })}`;

  try {
    const response = await fetch(`${env.PAY_SERVICE_URL}/api/pay/calculate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authToken,
      },
      body: JSON.stringify(payload),
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('Pay Engine error:', data);
      throw new Error(`Pay Engine returned ${response.status}: ${data.message || 'Unknown error'}`);
    }

    return data;
  } catch (error) {
    console.error('Pay Engine call failed:', error.message);
    throw error;
  }
}

module.exports = { calculatePay };
