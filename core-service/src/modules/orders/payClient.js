// FairDrop — Pay Engine Client
// Owner: Hari (25MCA025)
// Module: Orders (Module 2)
//
// HTTP client that calls Raihan's Pay Engine when an order is delivered.
// This is the integration point between the two services:
//
//   Hari's core-service (port 3003)
//       ──POST /api/pay/calculate──>
//   Raihan's pay-service (port 3004)
//
// Uses Node's built-in fetch() — no external HTTP library needed.

const env = require('../../config/env');

/**
 * Call Raihan's Pay Engine to calculate rider pay for a completed delivery.
 *
 * @param {Object} order - The delivered order document
 * @param {number} activeHoursToday - Rider's total active hours today
 * @returns {Object} Pay breakdown from pay-service
 * @throws {Error} If pay-service is unreachable or returns an error
 */
async function calculatePay(order, activeHoursToday) {
  // Build the request body matching the API contract exactly
  // See: docs/api-contract.md
  const payload = {
    rider_id: order.rider_id.toString(),
    order_id: order.order_id,
    distance_km: order.distance_km,
    is_surge_active: order.is_surge_active,
    restaurant_wait_mins: order.restaurant_wait_mins,
    active_hours_today: activeHoursToday,
    delay_context: {
      type: order.delay_context.type,
      verified: order.delay_context.verified,
      source: order.delay_context.source,
    },
  };

  try {
    const response = await fetch(`${env.PAY_SERVICE_URL}/api/pay/calculate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('Pay Engine error:', data);
      throw new Error(`Pay Engine returned ${response.status}: ${data.message || 'Unknown error'}`);
    }

    return data;
  } catch (error) {
    // If pay-service is completely down, log but don't crash the order
    console.error('Pay Engine call failed:', error.message);
    throw error;
  }
}

module.exports = { calculatePay };
