// FairDrop — Zone Module Tests
// Owner: Hari (25MCA025)
// Runner: node --test tests/zones.test.js

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const app = require('../src/app');
const env = require('../src/config/env');

let server, baseUrl, adminToken, riderToken, riderId, zoneId;

before(async () => {
  const testDbUri = env.MONGODB_URI.replace('fairdrop_core', 'fairdrop_core_test');
  await mongoose.connect(testDbUri);
  await mongoose.connection.db.dropDatabase();

  server = app.listen(0);
  baseUrl = `http://localhost:${server.address().port}`;

  // Register admin and rider
  const reg = async (d) => {
    const r = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(d),
    });
    return r.json();
  };

  const admin = await reg({ name: 'Admin', email: 'a@test.com', password: 'pass', role: 'admin' });
  adminToken = admin.token;

  const rider = await reg({ name: 'Rider', email: 'r@test.com', password: 'pass', role: 'rider' });
  riderToken = rider.token;
  riderId = rider.user._id;
});

after(async () => {
  await mongoose.connection.db.dropDatabase();
  await mongoose.disconnect();
  server.close();
});

async function req(method, path, body = null, token = null) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  if (token) opts.headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${baseUrl}${path}`, opts);
  return { status: res.status, data: await res.json() };
}

// Test zone (Kollam Central area)
const TEST_ZONE = {
  name: 'Test Zone Central',
  boundary: {
    type: 'Polygon',
    coordinates: [[[76.58, 8.89], [76.60, 8.89], [76.60, 8.905], [76.58, 8.905], [76.58, 8.89]]],
  },
  outOfZoneCapKm: 5,
};

describe('POST /api/zones (create zone)', () => {
  test('admin creates a zone successfully', async () => {
    const { status, data } = await req('POST', '/api/zones', TEST_ZONE, adminToken);
    assert.equal(status, 201);
    assert.equal(data.zone.name, 'Test Zone Central');
    assert.equal(data.zone.boundary.type, 'Polygon');
    zoneId = data.zone._id;
  });

  test('rejects duplicate zone name — 409', async () => {
    const { status } = await req('POST', '/api/zones', TEST_ZONE, adminToken);
    assert.equal(status, 409);
  });

  test('rider cannot create zone — 403', async () => {
    const { status } = await req('POST', '/api/zones', {
      ...TEST_ZONE, name: 'Rider Zone',
    }, riderToken);
    assert.equal(status, 403);
  });

  test('rejects zone without boundary — 400', async () => {
    const { status } = await req('POST', '/api/zones', { name: 'No Boundary' }, adminToken);
    assert.equal(status, 400);
  });
});

describe('GET /api/zones/:id', () => {
  test('admin gets zone by id', async () => {
    const { status, data } = await req('GET', `/api/zones/${zoneId}`, null, adminToken);
    assert.equal(status, 200);
    assert.equal(data.zone.name, 'Test Zone Central');
  });
});

describe('GET /api/zones/map', () => {
  test('returns GeoJSON FeatureCollection', async () => {
    const { status, data } = await req('GET', '/api/zones/map', null, adminToken);
    assert.equal(status, 200);
    assert.equal(data.data.type, 'FeatureCollection');
    assert.ok(data.data.features.length >= 1);
    assert.equal(data.data.features[0].type, 'Feature');
    assert.equal(data.data.features[0].geometry.type, 'Polygon');
  });

  test('rider can access map data', async () => {
    const { status } = await req('GET', '/api/zones/map', null, riderToken);
    assert.equal(status, 200);
  });
});

describe('PATCH /api/zones/:id/cap', () => {
  test('admin updates out-of-zone cap', async () => {
    const { status, data } = await req('PATCH', `/api/zones/${zoneId}/cap`, {
      outOfZoneCapKm: 8,
    }, adminToken);
    assert.equal(status, 200);
    assert.equal(data.zone.outOfZoneCapKm, 8);
  });
});

describe('POST /api/zones/assign (spatial query)', () => {
  test('assigns rider when location is inside zone', async () => {
    // First assign rider to the zone
    const User = require('../src/modules/auth/User.model');
    await User.findByIdAndUpdate(riderId, {
      'rider_profile.current_zone_id': zoneId,
      'rider_profile.is_available': true,
    });

    // Point inside Test Zone Central: [76.59, 8.895]
    const { status, data } = await req('POST', '/api/zones/assign', {
      restaurant_longitude: 76.59,
      restaurant_latitude: 8.895,
      order_id: 'ORD-20260916-0001',
    }, adminToken);

    assert.equal(status, 200);
    assert.equal(data.success, true);
    assert.ok(data.rider_id);
    assert.equal(data.zone_name, 'Test Zone Central');
  });

  test('returns 404 when no rider available', async () => {
    // Rider was marked unavailable by previous test
    const { status, data } = await req('POST', '/api/zones/assign', {
      restaurant_longitude: 76.59,
      restaurant_latitude: 8.895,
      order_id: 'ORD-20260916-0002',
    }, adminToken);

    assert.equal(status, 404);
    assert.match(data.message, /No available rider/);
  });

  test('returns 404 for location outside all zones', async () => {
    const { status } = await req('POST', '/api/zones/assign', {
      restaurant_longitude: 70.0,
      restaurant_latitude: 10.0,
      order_id: 'ORD-20260916-0003',
    }, adminToken);

    assert.equal(status, 404);
  });
});

describe('POST /api/zones/reassign', () => {
  test('reassigns rider to zone after delivery', async () => {
    const { status, data } = await req('POST', '/api/zones/reassign', {
      rider_id: riderId,
      delivery_longitude: 76.59,
      delivery_latitude: 8.90,
    }, adminToken);

    assert.equal(status, 200);
    assert.equal(data.success, true);
    assert.ok(data.zone_id);
  });
});
