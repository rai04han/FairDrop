// FairDrop — Zone Model (MongoDB/Mongoose)
// Owner: Hari (25MCA025)
// Module: Zones (Module 3)
//
// Defines delivery zones using GeoJSON Polygons.
// MongoDB's 2dsphere index enables spatial queries like:
//   - "Which zone does this restaurant's location fall in?"
//   - "Find the nearest rider within this zone"
//
// IMPORTANT: GeoJSON uses [longitude, latitude] — NOT [lat, lng].
// The Flutter app must flip coordinates when displaying on flutter_map.

const mongoose = require('mongoose');

const zoneSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Zone name is required'],
      unique: true,
      trim: true,
    },

    // ── GeoJSON Polygon boundary ────────────────────────────────────────
    // Format: { type: "Polygon", coordinates: [[[lng, lat], [lng, lat], ...]] }
    // The outer ring must be a closed loop (first point = last point).
    boundary: {
      type: {
        type: String,
        enum: ['Polygon'],
        required: true,
      },
      coordinates: {
        type: [[[Number]]],  // Array of arrays of [lng, lat] pairs
        required: true,
      },
    },

    // ── Zone configuration ──────────────────────────────────────────────
    adjacentZones: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Zone',
      },
    ],

    // Maximum km a rider can be sent outside their assigned zone
    outOfZoneCapKm: {
      type: Number,
      default: 5,
      min: 0,
    },

    // Minutes of idle time before return compensation kicks in
    returnCompensationIdleWindowMins: {
      type: Number,
      default: 15,
      min: 0,
    },

    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  }
);

// ── 2dsphere index for spatial queries ──────────────────────────────────────
// This enables $geoIntersects and $nearSphere queries on the boundary field.

zoneSchema.index({ boundary: '2dsphere' });

const Zone = mongoose.model('Zone', zoneSchema);

module.exports = Zone;
