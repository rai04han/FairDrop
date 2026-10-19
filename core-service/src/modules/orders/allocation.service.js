// FairDrop — Order Allocation & Geometry Service
// Owner: Hari (25MCA025)
// Module: Orders / Allocation (FR-68, FR-70, FR-72, FR-73, D2, D7)
//
// Provides:
//   - calculateHaversine: straight-line distance in km, rounded to 2 decimals (FR-70, D9)
//   - isPointInPolygon: ray-casting point-in-polygon test
//   - distanceToPolygonBoundary: distance beyond boundary in km, rounded to 2 decimals (FR-73)
//   - findZoneForLocation: resolves zone containing a coordinate or falling back to zone code
//   - runAllocation: allocates an order to the best online idle rider (FR-68)

const Zone = require('../zones/Zone.model');
const User = require('../auth/User.model');
const Order = require('./Order.model');

/**
 * Calculates straight-line haversine distance between two coordinates in km.
 * Rounded to 2 decimal places (FR-70, D9).
 */
function calculateHaversine(lat1, lon1, lat2, lon2) {
  if (lat1 === undefined || lon1 === undefined || lat2 === undefined || lon2 === undefined) {
    return 0;
  }
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c * 100) / 100;
}

/**
 * Tests whether a point (lat, lng) is inside a GeoJSON polygon outer ring.
 * Coordinates in polygonCoords are [lng, lat] pairs.
 */
function isPointInPolygon(lat, lng, polygonCoords) {
  if (!polygonCoords || polygonCoords.length < 3) return false;
  let inside = false;
  for (let i = 0, j = polygonCoords.length - 1; i < polygonCoords.length; j = i++) {
    const xi = polygonCoords[i][0], yi = polygonCoords[i][1];
    const xj = polygonCoords[j][0], yj = polygonCoords[j][1];

    const intersect =
      yi > lat !== yj > lat &&
      lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}

/**
 * Calculates the shortest distance from (lat, lng) to the polygon boundary in km.
 * If the point is inside the polygon, returns 0 km.
 * If outside, returns distance to the closest point on the polygon perimeter,
 * rounded to 2 decimal places (FR-73).
 */
function distanceToPolygonBoundary(lat, lng, polygonCoords) {
  if (!polygonCoords || polygonCoords.length < 3) return 0;

  // If inside, distance beyond boundary is 0
  if (isPointInPolygon(lat, lng, polygonCoords)) {
    return 0;
  }

  let minDistance = Infinity;

  for (let i = 0; i < polygonCoords.length - 1; i++) {
    const p1 = polygonCoords[i];     // [lng, lat]
    const p2 = polygonCoords[i + 1]; // [lng, lat]

    const lng1 = p1[0], lat1 = p1[1];
    const lng2 = p2[0], lat2 = p2[1];

    const avgLat = ((lat1 + lat2 + lat) / 3) * (Math.PI / 180);
    const cosLat = Math.cos(avgLat);

    const x = (lng - lng1) * cosLat * 111.32;
    const y = (lat - lat1) * 110.574;

    const dx = (lng2 - lng1) * cosLat * 111.32;
    const dy = (lat2 - lat1) * 110.574;

    const lengthSq = dx * dx + dy * dy;
    let t = 0;
    if (lengthSq > 0) {
      t = Math.max(0, Math.min(1, (x * dx + y * dy) / lengthSq));
    }

    const closestLat = lat1 + t * (lat2 - lat1);
    const closestLng = lng1 + t * (lng2 - lng1);

    const dist = calculateHaversine(lat, lng, closestLat, closestLng);
    if (dist < minDistance) {
      minDistance = dist;
    }
  }

  return Math.round(minDistance * 100) / 100;
}

/**
 * Resolves the zone containing (lat, lng) or matches by zone code/fallback.
 */
async function findZoneForLocation(lat, lng, fallbackZoneCode = null) {
  // If coordinates are provided, test geoIntersects and point-in-polygon
  if (lat && lng && (lat !== 0 || lng !== 0)) {
    try {
      const point = { type: 'Point', coordinates: [lng, lat] };
      const zone = await Zone.findOne({
        boundary: { $geoIntersects: { $geometry: point } },
        isActive: true,
      });
      if (zone) return zone;
    } catch (e) {
      // Ignore geospatial index errors and fallback to ray-casting below
    }

    const activeZones = await Zone.find({ isActive: true });
    for (const z of activeZones) {
      if (z.boundary?.coordinates?.[0]) {
        if (isPointInPolygon(lat, lng, z.boundary.coordinates[0])) {
          return z;
        }
      }
    }
  }

  if (fallbackZoneCode) {
    const zoneByCode = await Zone.findOne({
      $or: [{ zone_id: fallbackZoneCode }, { name: fallbackZoneCode }],
      isActive: true,
    });
    if (zoneByCode) return zoneByCode;
  }

  return null;
}

/**
 * Runs the FairDrop allocation algorithm (FR-68, FR-73, D2).
 *
 * Algorithm:
 * 1. Match by zone containing the restaurant's location.
 * 2. Find online riders with no open order, excluding those who declined this order.
 * 3. Enforce the out-of-zone cap (FR-73) against the rider's current zone.
 * 4. Prioritize riders in the restaurant's zone; fallback to any online rider passing cap.
 * 5. Tie-break: least recently assigned first (rider_profile.last_assigned_at).
 * 6. If none available, return { allocated: false, reason: 'no_rider_available' }.
 */
async function runAllocation(order, restaurantZone = null) {
  const deliveryLat = order.delivery_address?.latitude;
  const deliveryLng = order.delivery_address?.longitude;

  // 1. Find all online, active riders
  const onlineRiders = await User.find({
    role: 'rider',
    is_active: { $ne: false },
    'rider_profile.is_online': true,
  });

  if (!onlineRiders || onlineRiders.length === 0) {
    return { allocated: false, reason: 'no_rider_available' };
  }

  // 2. Find riders who currently have open orders
  // An order is open if it is assigned, arrived, picked_up, or accepted (with rider_ack pending or accepted)
  const busyRiderIds = await Order.distinct('rider_id', {
    _id: { $ne: order._id },
    rider_id: { $ne: null },
    status: { $in: ['accepted', 'assigned', 'arrived', 'picked_up'] },
    rider_ack: { $ne: 'declined' },
  });
  const busySet = new Set(busyRiderIds.map((id) => id.toString()));

  // 3. Skip riders who declined this specific order (FR-15, FR-68, D7)
  const declinedSet = new Set((order.declined_by || []).map((id) => id.toString()));

  // 4. Cache active zones for fast lookup
  const activeZones = await Zone.find({ isActive: true });
  const zoneMap = new Map();
  for (const z of activeZones) {
    zoneMap.set(z._id.toString(), z);
    if (z.zone_id) zoneMap.set(z.zone_id, z);
  }

  // 5. Evaluate each eligible rider and check out-of-zone cap (FR-73)
  const candidates = [];

  for (const rider of onlineRiders) {
    const riderIdStr = rider._id.toString();
    if (busySet.has(riderIdStr)) continue;
    if (declinedSet.has(riderIdStr)) continue;

    const profile = rider.rider_profile || {};
    let riderZone = null;
    if (profile.current_zone_id && zoneMap.has(profile.current_zone_id.toString())) {
      riderZone = zoneMap.get(profile.current_zone_id.toString());
    } else if (profile.current_zone_code && zoneMap.has(profile.current_zone_code)) {
      riderZone = zoneMap.get(profile.current_zone_code);
    } else if (profile.zone_id && zoneMap.has(profile.zone_id.toString())) {
      riderZone = zoneMap.get(profile.zone_id.toString());
    } else if (profile.assigned_zone_code && zoneMap.has(profile.assigned_zone_code)) {
      riderZone = zoneMap.get(profile.assigned_zone_code);
    }

    // Out-of-zone calculation (FR-73)
    let outOfZoneDistance = 0;
    if (riderZone && riderZone.boundary?.coordinates?.[0] && deliveryLat !== undefined && deliveryLng !== undefined) {
      outOfZoneDistance = distanceToPolygonBoundary(
        deliveryLat,
        deliveryLng,
        riderZone.boundary.coordinates[0]
      );
      const cap = riderZone.max_out_of_zone_radius_km || riderZone.outOfZoneCapKm || 5;
      if (outOfZoneDistance > cap) {
        // Exceeds out-of-zone cap — skip this rider!
        continue;
      }
    }

    // Is rider in restaurant's zone?
    const isInRestaurantZone = Boolean(
      restaurantZone &&
      riderZone &&
      (riderZone._id.toString() === restaurantZone._id.toString() ||
        (riderZone.zone_id && riderZone.zone_id === restaurantZone.zone_id))
    );

    candidates.push({
      rider,
      isInRestaurantZone,
      outOfZoneDistance,
      lastAssignedAt: profile.last_assigned_at ? new Date(profile.last_assigned_at).getTime() : 0,
    });
  }

  if (candidates.length === 0) {
    return { allocated: false, reason: 'no_rider_available' };
  }

  // Priority Group 1: Riders in restaurant zone
  const inZone = candidates.filter((c) => c.isInRestaurantZone);
  // Priority Group 2: Fallback riders (D2)
  const fallback = candidates.filter((c) => !c.isInRestaurantZone);

  // Least recently assigned first (lowest timestamp / never assigned comes first)
  inZone.sort((a, b) => a.lastAssignedAt - b.lastAssignedAt);
  fallback.sort((a, b) => a.lastAssignedAt - b.lastAssignedAt);

  const selected = inZone.length > 0 ? inZone[0] : fallback[0];
  const chosenRider = selected.rider;

  // Update rider's last_assigned_at
  if (!chosenRider.rider_profile) chosenRider.rider_profile = {};
  chosenRider.rider_profile.last_assigned_at = new Date();
  await chosenRider.save();

  return {
    allocated: true,
    rider: chosenRider,
    is_out_of_zone: selected.outOfZoneDistance > 0,
    out_of_zone_distance_km: selected.outOfZoneDistance,
  };
}

module.exports = {
  calculateHaversine,
  isPointInPolygon,
  distanceToPolygonBoundary,
  findZoneForLocation,
  runAllocation,
};
