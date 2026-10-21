// FairDrop — Restaurant Menu & Orders Tests
// Owner: Hari (25MCA025)
// Runner: Node.js built-in test runner (node:test)
// Run: node --test tests/restaurants.test.js

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const app = require('../src/app');
const env = require('../src/config/env');
const User = require('../src/modules/auth/User.model');
const MenuItem = require('../src/modules/orders/MenuItem.model');
const Order = require('../src/modules/orders/Order.model');

let server;
let baseUrl;

let restaurantToken;
let restaurantId;
let otherRestaurantToken;
let otherRestaurantId;
let customerToken;
let createdItemId;

before(async () => {
  const testDbUri = env.MONGODB_URI.replace('fairdrop_core', 'fairdrop_core_test');
  await mongoose.connect(testDbUri);
  await mongoose.connection.db.dropDatabase();

  server = app.listen(0);
  const port = server.address().port;
  baseUrl = `http://localhost:${port}`;

  const register = async (data) => {
    const res = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return res.json();
  };

  const r1 = await register({
    name: 'Hotel Arun',
    email: 'arun@test.com',
    password: 'password123',
    role: 'restaurant',
  });
  restaurantToken = r1.token;
  restaurantId = r1.user._id;

  const r2 = await register({
    name: 'Supreme Bakers',
    email: 'supreme@test.com',
    password: 'password123',
    role: 'restaurant',
  });
  otherRestaurantToken = r2.token;
  otherRestaurantId = r2.user._id;

  const cust = await register({
    name: 'Customer Test',
    email: 'cust@test.com',
    password: 'password123',
    role: 'customer',
  });
  customerToken = cust.token;

  // Seed default menu items matching seed.js and app fallback IDs (AUDIT-F23)
  await MenuItem.create([
    { _id: 'item-101', restaurant_id: restaurantId, name: 'Parotta', price: 15, prep_time_seconds: 20, is_available: true },
    { _id: 'item-102', restaurant_id: restaurantId, name: 'Fish Curry Meal', price: 120, prep_time_seconds: 45, is_available: true },
    { _id: 'item-103', restaurant_id: restaurantId, name: 'Chicken Biryani', price: 180, prep_time_seconds: 40, is_available: true },
  ]);
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

describe('Restaurant Menu Management (FR-62, FR-63, FR-64)', () => {
  test('restaurant creates a menu item with valid fields (FR-63)', async () => {
    const { status, data } = await req('POST', '/api/restaurants/menu', {
      name: 'Kerala Parotta',
      price: 15,
      prep_time_seconds: 30,
      is_available: true,
    }, restaurantToken);

    assert.equal(status, 201);
    assert.equal(data.success, true);
    assert.equal(data.item.name, 'Kerala Parotta');
    assert.equal(data.item.price, 15);
    assert.equal(data.item.prep_time_seconds, 30);
    assert.equal(data.item.is_available, true);
    createdItemId = data.item._id;
  });

  test('rejects menu item with non-integer prep_time_seconds — 400', async () => {
    const { status } = await req('POST', '/api/restaurants/menu', {
      name: 'Tea',
      price: 12,
      prep_time_seconds: 15.5,
    }, restaurantToken);

    assert.equal(status, 400);
  });

  test('rejects menu item with negative price — 400', async () => {
    const { status } = await req('POST', '/api/restaurants/menu', {
      name: 'Tea',
      price: -5,
      prep_time_seconds: 60,
    }, restaurantToken);

    assert.equal(status, 400);
  });

  test('customer cannot add menu items — 403', async () => {
    const { status } = await req('POST', '/api/restaurants/menu', {
      name: 'Tea',
      price: 12,
      prep_time_seconds: 60,
    }, customerToken);

    assert.equal(status, 403);
  });

  test('restaurant fetches its own menu items (FR-62)', async () => {
    const { status, data } = await req('GET', '/api/restaurants/menu', null, restaurantToken);

    assert.equal(status, 200);
    assert.equal(data.success, true);
    assert.ok(data.count >= 1);
    assert.equal(data.items[0].name, 'Kerala Parotta');
  });

  test('customer reads restaurant menu by restaurant ID (FR-57)', async () => {
    const { status, data } = await req('GET', `/api/restaurants/${restaurantId}/menu`, null, customerToken);

    assert.equal(status, 200);
    assert.equal(data.success, true);
    assert.equal(data.restaurant.name, 'Hotel Arun');
    assert.ok(data.items.length >= 1);
  });

  test('restaurant toggles availability of its own item (FR-64)', async () => {
    const { status, data } = await req('PATCH', `/api/restaurants/menu/${createdItemId}`, {
      is_available: false,
    }, restaurantToken);

    assert.equal(status, 200);
    assert.equal(data.item.is_available, false);

    // Verify persisted
    const item = await MenuItem.findById(createdItemId);
    assert.equal(item.is_available, false);
  });

  test('restaurant cannot edit another restaurant\'s item — 403 (FR-64)', async () => {
    const { status, data } = await req('PATCH', `/api/restaurants/menu/${createdItemId}`, {
      price: 99,
    }, otherRestaurantToken);

    assert.equal(status, 403);
    assert.match(data.message, /your own restaurant/i);
  });
});

describe('Restaurant Orders List with Derived is_ready (FR-65, FR-69)', () => {
  test('restaurant reads orders with is_ready flag derived from prep time', async () => {
    // Create an order for this restaurant
    await Order.create({
      order_id: 'ORD-20261019-9988',
      customer_id: new mongoose.Types.ObjectId(),
      restaurant_id: restaurantId,
      items: [{ name: 'Kerala Parotta', quantity: 2, price: 15, prep_time_seconds: 10 }],
      delivery_address: { label: 'Pin A', latitude: 8.8860, longitude: 76.5920 },
      restaurant_address: { label: 'Hotel Arun', latitude: 8.8855, longitude: 76.5950 },
      distance_km: 1.5,
      status: 'accepted',
      accepted_at: new Date(Date.now() - 30000), // Accepted 30s ago (> 10s prep time)
    });

    const { status, data } = await req('GET', '/api/restaurants/orders', null, restaurantToken);

    assert.equal(status, 200);
    assert.equal(data.success, true);
    assert.ok(data.count >= 1);
    assert.equal(data.orders[0].is_ready, true);
  });
});

describe('Menu Item String IDs & Toggle (AUDIT-F23)', () => {
  test('updates and toggles a seeded item by its seeded string ID (item-102)', async () => {
    // 1. Update seeded item
    const updateRes = await req('PATCH', '/api/restaurants/menu/item-102', {
      name: 'Fish Curry Meal Special',
      price: 135,
      prep_time_seconds: 50,
    }, restaurantToken);

    assert.equal(updateRes.status, 200);
    assert.equal(updateRes.data.success, true);
    assert.equal(updateRes.data.item.name, 'Fish Curry Meal Special');
    assert.equal(updateRes.data.item.price, 135);
    assert.equal(updateRes.data.item.prep_time_seconds, 50);

    // 2. Toggle availability of seeded item
    const toggleRes = await req('PATCH', '/api/restaurants/menu/item-102/availability', {
      is_available: false,
    }, restaurantToken);

    assert.equal(toggleRes.status, 200);
    assert.equal(toggleRes.data.item.is_available, false);

    // 3. Verify in DB via findById with string ID
    const dbItem = await MenuItem.findById('item-102');
    assert.ok(dbItem);
    assert.equal(dbItem._id, 'item-102');
    assert.equal(dbItem.name, 'Fish Curry Meal Special');
    assert.equal(dbItem.is_available, false);
  });

  test('updates and toggles a newly created item by its generated ID', async () => {
    // 1. Create new item
    const createRes = await req('POST', '/api/restaurants/menu', {
      name: 'Ghee Roast Dosa',
      price: 80,
      prep_time_seconds: 25,
      is_available: true,
    }, restaurantToken);

    assert.equal(createRes.status, 201);
    const newItemId = createRes.data.item._id;
    assert.ok(newItemId);

    // 2. Update new item
    const updateRes = await req('PATCH', `/api/restaurants/menu/${newItemId}`, {
      name: 'Crispy Ghee Roast Dosa',
      price: 85,
    }, restaurantToken);

    assert.equal(updateRes.status, 200);
    assert.equal(updateRes.data.item.name, 'Crispy Ghee Roast Dosa');
    assert.equal(updateRes.data.item.price, 85);

    // 3. Toggle availability of new item
    const toggleRes = await req('PATCH', `/api/restaurants/menu/${newItemId}/availability`, {
      is_available: false,
    }, restaurantToken);

    assert.equal(toggleRes.status, 200);
    assert.equal(toggleRes.data.item.is_available, false);

    // 4. Verify in DB
    const dbItem = await MenuItem.findById(newItemId);
    assert.ok(dbItem);
    assert.equal(dbItem.is_available, false);
    assert.equal(dbItem.price, 85);
  });
});
