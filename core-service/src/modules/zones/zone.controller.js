// FairDrop — Zone Controller
// Owner: Hari (25MCA025)
// Module: Zones (Module 3)
//
// Handles zone CRUD, rider assignment, and map data for flutter_map.
//
// Key spatial operations:
//   - assignRider: finds which zone a delivery falls in using $geoIntersects
//   - reassignZone: updates rider's current_zone_id after delivery
//   - getMapData: returns GeoJSON FeatureCollection for flutter_map rendering

const Zone = require('./Zone.model');
const User = require('../auth/User.model');

/**
 * POST /api/zones
 * Role: admin
 *
 * Creates a new delivery zone with GeoJSON polygon boundary.
 */
async function createZone(req, res) {
  try {
    const { name, boundary, adjacentZones, outOfZoneCapKm, returnCompensationIdleWindowMins } = req.body;

    if (!name || !boundary) {
      return res.status(400).json({
        success: false,
        message: 'name and boundary are required.',
      });
    }

    // Validate GeoJSON structure
    if (!boundary.type || boundary.type !== 'Polygon' || !boundary.coordinates) {
      return res.status(400).json({
        success: false,
        message: 'boundary must be a GeoJSON Polygon with type and coordinates.',
      });
    }

    const zone = await Zone.create({
      name,
      boundary,
      adjacentZones: adjacentZones || [],
      outOfZoneCapKm: outOfZoneCapKm || 5,
      returnCompensationIdleWindowMins: returnCompensationIdleWindowMins || 15,
    });

    res.status(201).json({
      success: true,
      message: `Zone "${name}" created.`,
      zone,
    });
  } catch (error) {
    // Handle duplicate zone name
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'A zone with this name already exists.',
      });
    }
    console.error('Create zone error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * GET /api/zones/:id
 * Role: admin
 *
 * Returns a single zone by its MongoDB _id.
 */
async function getZone(req, res) {
  try {
    const zone = await Zone.findById(req.params.id).populate('adjacentZones', 'name');

    if (!zone) {
      return res.status(404).json({ success: false, message: 'Zone not found.' });
    }

    res.json({ success: true, zone });
  } catch (error) {
    console.error('Get zone error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * GET /api/zones/map
 * Role: rider, admin
 *
 * Returns all active zones as a GeoJSON FeatureCollection.
 * This is what flutter_map consumes to render zone polygons on the map.
 */
async function getMapData(req, res) {
  try {
    const zones = await Zone.find({ isActive: true });

    // Convert to GeoJSON FeatureCollection for flutter_map
    const featureCollection = {
      type: 'FeatureCollection',
      features: zones.map((zone) => ({
        type: 'Feature',
        geometry: zone.boundary,
        properties: {
          _id: zone._id,
          name: zone.name,
          outOfZoneCapKm: zone.outOfZoneCapKm,
          returnCompensationIdleWindowMins: zone.returnCompensationIdleWindowMins,
        },
      })),
    };

    res.json({ success: true, data: featureCollection });
  } catch (error) {
    console.error('Get map data error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * PATCH /api/zones/:id/cap
 * Role: admin
 *
 * Updates the out-of-zone cap for a zone.
 */
async function updateCap(req, res) {
  try {
    const { outOfZoneCapKm } = req.body;

    if (outOfZoneCapKm === undefined || outOfZoneCapKm < 0) {
      return res.status(400).json({
        success: false,
        message: 'outOfZoneCapKm must be a non-negative number.',
      });
    }

    const zone = await Zone.findByIdAndUpdate(
      req.params.id,
      { outOfZoneCapKm },
      { returnDocument: 'after' }
    );

    if (!zone) {
      return res.status(404).json({ success: false, message: 'Zone not found.' });
    }

    res.json({
      success: true,
      message: `Out-of-zone cap updated to ${outOfZoneCapKm} km.`,
      zone,
    });
  } catch (error) {
    console.error('Update cap error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * POST /api/zones/assign
 * Role: internal (called by order controller)
 *
 * Finds the zone containing the restaurant's location using $geoIntersects,
 * then finds an available rider in that zone.
 *
 * Fallback: if no rider in the exact zone, checks adjacent zones
 * (respecting the out-of-zone cap).
 */
async function assignRider(req, res) {
  try {
    const { restaurant_longitude, restaurant_latitude, order_id } = req.body;

    if (!restaurant_longitude || !restaurant_latitude || !order_id) {
      return res.status(400).json({
        success: false,
        message: 'restaurant_longitude, restaurant_latitude, and order_id are required.',
      });
    }

    // Step 1: Find which zone the restaurant is in
    const point = {
      type: 'Point',
      coordinates: [restaurant_longitude, restaurant_latitude],
    };

    const zone = await Zone.findOne({
      boundary: { $geoIntersects: { $geometry: point } },
      isActive: true,
    });

    if (!zone) {
      return res.status(404).json({
        success: false,
        message: 'No active zone found for this location.',
      });
    }

    // Step 2: Find an available rider in this zone
    let rider = await User.findOne({
      role: 'rider',
      'rider_profile.is_available': true,
      'rider_profile.current_zone_id': zone._id,
    });

    // Step 3: Fallback — check adjacent zones
    if (!rider && zone.adjacentZones.length > 0) {
      rider = await User.findOne({
        role: 'rider',
        'rider_profile.is_available': true,
        'rider_profile.current_zone_id': { $in: zone.adjacentZones },
      });
    }

    if (!rider) {
      return res.status(404).json({
        success: false,
        message: `No available rider found in zone "${zone.name}" or adjacent zones.`,
        zone_id: zone._id,
      });
    }

    // Step 4: Mark rider as unavailable
    rider.rider_profile.is_available = false;
    await rider.save();

    res.json({
      success: true,
      message: `Rider ${rider.name} assigned from zone "${zone.name}".`,
      rider_id: rider._id,
      zone_id: zone._id,
      zone_name: zone.name,
    });
  } catch (error) {
    console.error('Assign rider error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

/**
 * POST /api/zones/reassign
 * Role: internal (called after delivery completion)
 *
 * Updates the rider's current_zone_id to the zone of the delivery endpoint.
 * Also marks them available again.
 */
async function reassignZone(req, res) {
  try {
    const { rider_id, delivery_longitude, delivery_latitude } = req.body;

    if (!rider_id || !delivery_longitude || !delivery_latitude) {
      return res.status(400).json({
        success: false,
        message: 'rider_id, delivery_longitude, and delivery_latitude are required.',
      });
    }

    // Find which zone the delivery location falls in
    const point = {
      type: 'Point',
      coordinates: [delivery_longitude, delivery_latitude],
    };

    const zone = await Zone.findOne({
      boundary: { $geoIntersects: { $geometry: point } },
      isActive: true,
    });

    // Update rider: set new zone and mark available
    const update = {
      'rider_profile.is_available': true,
      'rider_profile.current_zone_id': zone ? zone._id : null,
    };

    await User.findByIdAndUpdate(rider_id, update);

    res.json({
      success: true,
      message: zone
        ? `Rider reassigned to zone "${zone.name}".`
        : 'Rider marked available (delivery outside all zones).',
      zone_id: zone ? zone._id : null,
    });
  } catch (error) {
    console.error('Reassign zone error:', error.message);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
}

module.exports = {
  createZone,
  getZone,
  getMapData,
  updateCap,
  assignRider,
  reassignZone,
};
