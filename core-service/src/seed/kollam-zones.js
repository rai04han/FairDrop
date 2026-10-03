// FairDrop — Seed Data: Kollam Zones
// Owner: Hari (25MCA025)
//
// 4 delivery zones covering Kollam city for the interim demo.
// Coordinates are real GeoJSON polygons around Kollam, Kerala.
// GeoJSON format: [longitude, latitude] — NOT [lat, lng].

const zones = [
  {
    name: 'Kollam Central',
    boundary: {
      type: 'Polygon',
      coordinates: [[
        [76.5800, 8.8900],
        [76.6000, 8.8900],
        [76.6000, 8.9050],
        [76.5800, 8.9050],
        [76.5800, 8.8900],  // closed loop
      ]],
    },
    outOfZoneCapKm: 5,
    returnCompensationIdleWindowMins: 15,
  },
  {
    name: 'Kollam Beach',
    boundary: {
      type: 'Polygon',
      coordinates: [[
        [76.6000, 8.8800],
        [76.6200, 8.8800],
        [76.6200, 8.8950],
        [76.6000, 8.8950],
        [76.6000, 8.8800],
      ]],
    },
    outOfZoneCapKm: 4,
    returnCompensationIdleWindowMins: 15,
  },
  {
    name: 'Chinnakkada',
    boundary: {
      type: 'Polygon',
      coordinates: [[
        [76.5850, 8.8750],
        [76.6050, 8.8750],
        [76.6050, 8.8900],
        [76.5850, 8.8900],
        [76.5850, 8.8750],
      ]],
    },
    outOfZoneCapKm: 5,
    returnCompensationIdleWindowMins: 10,
  },
  {
    name: 'Asramam',
    boundary: {
      type: 'Polygon',
      coordinates: [[
        [76.5700, 8.8950],
        [76.5900, 8.8950],
        [76.5900, 8.9100],
        [76.5700, 8.9100],
        [76.5700, 8.8950],
      ]],
    },
    outOfZoneCapKm: 6,
    returnCompensationIdleWindowMins: 15,
  },
];

module.exports = zones;
