// FairDrop — Master Idempotent Seed Script (PRD v2.1 §10.1)
//
// Prepares both MongoDB (core-service) and MySQL (pay-service) for the demo.
// Run from project root: node scripts/seed.js
// Safe to re-run multiple times (idempotent clean baseline).

const path = require('path');
const fs = require('fs');

// Resolve dependencies from service directories
const coreModules = path.join(__dirname, '..', 'core-service', 'node_modules');
const payModules = path.join(__dirname, '..', 'pay-service', 'node_modules');

const dotenv = require(path.join(coreModules, 'dotenv'));
const mongoose = require(path.join(coreModules, 'mongoose'));
const mysql = require(path.join(payModules, 'mysql2', 'promise'));

// Load .env configs
dotenv.config({ path: path.join(__dirname, '..', 'core-service', '.env') });
const coreMongoUri = process.env.MONGODB_URI;

dotenv.config({ path: path.join(__dirname, '..', 'pay-service', '.env') });
const mysqlHost = process.env.DB_HOST || 'localhost';
const mysqlPort = parseInt(process.env.DB_PORT, 10) || 3306;
const mysqlUser = process.env.DB_USER || 'root';
const mysqlPassword = process.env.DB_PASSWORD || '';
const mysqlDatabase = process.env.DB_NAME || 'fairdrop_pay';

// Import Mongoose Models from core-service
const User = require(path.join(__dirname, '..', 'core-service', 'src', 'modules', 'auth', 'User.model.js'));
const Zone = require(path.join(__dirname, '..', 'core-service', 'src', 'modules', 'zones', 'Zone.model.js'));
const MenuItem = require(path.join(__dirname, '..', 'core-service', 'src', 'modules', 'orders', 'MenuItem.model.js'));
const Order = require(path.join(__dirname, '..', 'core-service', 'src', 'modules', 'orders', 'Order.model.js'));

// ── Point-in-Polygon & Spatial Math ──────────────────────────────────────────

function pointInPolygon(point, polygon) {
  const [x, y] = point;
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [xi, yi] = polygon[i];
    const [xj, yj] = polygon[j];
    const intersect = yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}

function haversineDistanceKm(p1, p2) {
  const toRad = (x) => (x * Math.PI) / 180;
  const [lon1, lat1] = p1;
  const [lon2, lat2] = p2;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c * 100) / 100;
}

// ── Seed Definitions (PRD v2.1 §10.1) ────────────────────────────────────────

// 3 Kollam Zones
const zonesData = [
  {
    name: 'Chinnakkada',
    zone_id: 'KLM-CHK',
    boundary: {
      type: 'Polygon',
      coordinates: [[
        [76.5800, 8.8800],
        [76.6000, 8.8800],
        [76.6000, 8.8950],
        [76.5800, 8.8950],
        [76.5800, 8.8800],
      ]],
    },
    outOfZoneCapKm: 5,
    returnCompensationIdleWindowMins: 10,
  },
  {
    name: 'Polayathode',
    zone_id: 'KLM-PLY',
    boundary: {
      type: 'Polygon',
      coordinates: [[
        [76.6000, 8.8700],
        [76.6200, 8.8700],
        [76.6200, 8.8850],
        [76.6000, 8.8850],
        [76.6000, 8.8700],
      ]],
    },
    outOfZoneCapKm: 5,
    returnCompensationIdleWindowMins: 15,
  },
  {
    name: 'Kilikolloor',
    zone_id: 'KLM-KLK',
    boundary: {
      type: 'Polygon',
      coordinates: [[
        [76.6100, 8.8900],
        [76.6350, 8.8900],
        [76.6350, 8.9100],
        [76.6100, 8.9100],
        [76.6100, 8.8900],
      ]],
    },
    outOfZoneCapKm: 5,
    returnCompensationIdleWindowMins: 15,
  },
];

// Fixed Pins
const PIN_A = {
  name: 'Pin A (In-zone)',
  coordinates: [76.5920, 8.8860], // [lng, lat]
  zone_id: 'KLM-CHK',
};

const PIN_B = {
  name: 'Pin B (Out-of-zone within cap)',
  coordinates: [76.6050, 8.8800], // [lng, lat]
  zone_id: 'KLM-PLY',
};

async function seed() {
  console.log('\n======================================================');
  console.log('  FairDrop Master Seed (MongoDB + MySQL)');
  console.log('  PRD v2.1 Section 10.1 Alignment');
  console.log('======================================================\n');

  // ── Step 1: Connect to MySQL ───────────────────────────────────────────────
  console.log('⏳ Connecting to MySQL on port ' + mysqlPort + '...');
  const mysqlRootConn = await mysql.createConnection({
    host: mysqlHost,
    port: mysqlPort,
    user: mysqlUser,
    password: mysqlPassword,
    multipleStatements: true,
  });

  // Ensure DB and tables exist
  const schemaPath = path.join(__dirname, '..', 'database', 'mysql', 'schema.sql');
  let schema = fs.readFileSync(schemaPath, 'utf8');
  schema = schema.replace(/CREATE TABLE /g, 'CREATE TABLE IF NOT EXISTS ');
  try {
    await mysqlRootConn.query(schema);
    console.log('  ✓ MySQL schema validated');
  } catch (schemaErr) {
    if (schemaErr.code === 'ER_DUP_KEYNAME') {
      console.log('  ✓ MySQL schema validated (indexes already exist)');
    } else {
      throw schemaErr;
    }
  }

  await mysqlRootConn.query(`USE ${mysqlDatabase}`);

  // Ensure ENUMs in deliveries table are up-to-date (AUDIT-F22)
  try {
    await mysqlRootConn.query(`
      ALTER TABLE deliveries 
        MODIFY COLUMN delay_type ENUM('traffic', 'restaurant', 'railway', 'weather', 'none') NOT NULL DEFAULT 'none',
        MODIFY COLUMN delay_source ENUM('rider_report', 'system_log', 'api_mock', 'none') NOT NULL DEFAULT 'none'
    `);
  } catch (enumErr) {
    // Ignore if table does not exist yet or already altered
  }

  // Clear existing MySQL data for clean baseline
  await mysqlRootConn.query('DELETE FROM floor_topups');
  await mysqlRootConn.query('DELETE FROM earnings');
  await mysqlRootConn.query('DELETE FROM deliveries');
  await mysqlRootConn.query('DELETE FROM riders');
  await mysqlRootConn.query('DELETE FROM pay_configs');
  console.log('  ✓ Cleared existing MySQL tables (floor_topups, deliveries, earnings, riders, pay_configs)');

  // ── Step 2: Seed MySQL Baseline Pay Config (Wait Threshold: 1 minute) ─────
  const baselineConfig = {
    base_rate: 15.00,
    per_km_rate: 6.00,
    surge_bonus: 20.00,
    wait_threshold_mins: 1, // PRD §10.1 Demo Seed: 1 minute!
    wait_compensation: 10.00,
    min_wage_per_hour: 70.00,
    floor_window_minutes: 60,
    effective_from: new Date().toISOString().split('T')[0],
    is_active: true,
    created_by: 'system',
    change_reason: 'Seeded Kerala baseline config (demo 1-minute wait threshold)',
  };

  const [configResult] = await mysqlRootConn.execute(
    `INSERT INTO pay_configs
      (base_rate, per_km_rate, surge_bonus, wait_threshold_mins, wait_compensation, min_wage_per_hour, floor_window_minutes, effective_from, is_active, created_by, change_reason)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      baselineConfig.base_rate,
      baselineConfig.per_km_rate,
      baselineConfig.surge_bonus,
      baselineConfig.wait_threshold_mins,
      baselineConfig.wait_compensation,
      baselineConfig.min_wage_per_hour,
      baselineConfig.floor_window_minutes,
      baselineConfig.effective_from,
      baselineConfig.is_active,
      baselineConfig.created_by,
      baselineConfig.change_reason,
    ]
  );
  console.log(`  ✓ Seeded baseline pay config (Config ID: ${configResult.insertId}, Wait Threshold: 1 min)`);

  // ── Step 3: Connect to MongoDB ─────────────────────────────────────────────
  console.log('\n⏳ Connecting to MongoDB Atlas...');
  await mongoose.connect(coreMongoUri);
  console.log('  ✓ Connected to MongoDB');

  // Clear existing Mongo collections
  await User.deleteMany({});
  await Zone.deleteMany({});
  await MenuItem.deleteMany({});
  await Order.deleteMany({});
  console.log('  ✓ Cleared existing MongoDB collections (users, zones, menuitems, orders)');

  // ── Step 4: Seed Zones ─────────────────────────────────────────────────────
  const createdZones = await Zone.insertMany(zonesData);
  const zoneMap = {};
  createdZones.forEach((z) => {
    zoneMap[z.zone_id] = z;
    console.log(`  📍 Zone: ${z.zone_id} (${z.name})`);
  });

  // Link adjacent zones
  const chk = zoneMap['KLM-CHK'];
  const ply = zoneMap['KLM-PLY'];
  const klk = zoneMap['KLM-KLK'];

  chk.adjacentZones = [ply._id];
  ply.adjacentZones = [chk._id, klk._id];
  klk.adjacentZones = [ply._id];
  await Promise.all([chk.save(), ply.save(), klk.save()]);
  console.log('  ✓ Linked adjacent zones (CHK ↔ PLY ↔ KLK)');

  // ── Step 5: Seed Accounts ──────────────────────────────────────────────────
  // Password for all seeded demo accounts is 'password123'
  const passwordHash = 'password123';

  // 1. Customers
  const john = await User.create({
    name: 'John',
    email: 'john@fairdrop.in',
    phone: '9876543201',
    password_hash: passwordHash,
    role: 'customer',
  });

  const priya = await User.create({
    name: 'Priya',
    email: 'priya@fairdrop.in',
    phone: '9876543202',
    password_hash: passwordHash,
    role: 'customer',
  });
  console.log('  👥 Customers created: john@fairdrop.in, priya@fairdrop.in');

  // 2. Restaurants with fixed locations
  const arunLoc = { label: 'Chinnakkada, Kollam', longitude: 76.5900, latitude: 8.8880 };
  const marinaLoc = { label: 'Polayathode, Kollam', longitude: 76.6100, latitude: 8.8780 };

  const arun = await User.create({
    name: 'Hotel Arun',
    email: 'arun@fairdrop.in',
    phone: '9876543203',
    password_hash: passwordHash,
    role: 'restaurant',
    address: arunLoc,
  });

  const marina = await User.create({
    name: 'Marina',
    email: 'marina@fairdrop.in',
    phone: '9876543204',
    password_hash: passwordHash,
    role: 'restaurant',
    address: marinaLoc,
  });
  console.log('  🍽️  Restaurants created: Hotel Arun (KLM-CHK), Marina (KLM-PLY)');

  // 3. Admin
  const admin = await User.create({
    name: 'Admin',
    email: 'admin@fairdrop.in',
    phone: '9876543208',
    password_hash: passwordHash,
    role: 'admin',
  });
  console.log('  🛡️  Admin created: admin@fairdrop.in');

  // 4. Riders (one per zone, offline, matching Mongo _id and MySQL rider_id)
  const rider1 = await User.create({
    name: 'Rider 1',
    email: 'rider1@fairdrop.in',
    phone: '9876543205',
    password_hash: passwordHash,
    role: 'rider',
    rider_profile: {
      vehicle_type: 'motorcycle',
      zone_id: chk._id,
      current_zone_id: chk._id,
      is_available: false,
      active_hours_today: 0,
    },
  });

  const rider2 = await User.create({
    name: 'Rider 2',
    email: 'rider2@fairdrop.in',
    phone: '9876543206',
    password_hash: passwordHash,
    role: 'rider',
    rider_profile: {
      vehicle_type: 'scooter',
      zone_id: ply._id,
      current_zone_id: ply._id,
      is_available: false,
      active_hours_today: 0,
    },
  });

  const rider3 = await User.create({
    name: 'Rider 3',
    email: 'rider3@fairdrop.in',
    phone: '9876543207',
    password_hash: passwordHash,
    role: 'rider',
    rider_profile: {
      vehicle_type: 'bicycle',
      zone_id: klk._id,
      current_zone_id: klk._id,
      is_available: false,
      active_hours_today: 0,
    },
  });
  console.log('  🛵 Riders created in MongoDB: Rider 1 (CHK), Rider 2 (PLY), Rider 3 (KLK)');

  // ── Step 6: Sync Riders into MySQL with Matching IDs ───────────────────────
  const ridersToSync = [
    { id: rider1._id.toString(), name: rider1.name, phone: rider1.phone, zone_id: 'KLM-CHK' },
    { id: rider2._id.toString(), name: rider2.name, phone: rider2.phone, zone_id: 'KLM-PLY' },
    { id: rider3._id.toString(), name: rider3.name, phone: rider3.phone, zone_id: 'KLM-KLK' },
  ];

  for (const r of ridersToSync) {
    await mysqlRootConn.execute(
      `INSERT INTO riders (rider_id, name, phone, zone_id, is_active)
       VALUES (?, ?, ?, ?, TRUE)`,
      [r.id, r.name, r.phone, r.zone_id]
    );
    console.log(`  ✓ Synced to MySQL riders table: ${r.name} (id: ${r.id})`);
  }

  // ── Step 7: Seed Restaurant Menus ──────────────────────────────────────────
  const arunMenuItems = [
    { restaurant_id: arun._id, name: 'Chicken Biryani', price: 180, prep_time_seconds: 40, is_available: true },
    { restaurant_id: arun._id, name: 'Parotta', price: 15, prep_time_seconds: 20, is_available: true },
    { restaurant_id: arun._id, name: 'Fish Curry Meal', price: 120, prep_time_seconds: 45, is_available: true },
  ];

  const marinaMenuItems = [
    { restaurant_id: marina._id, name: 'Veg Meals', price: 90, prep_time_seconds: 30, is_available: true },
    { restaurant_id: marina._id, name: 'Masala Dosa', price: 60, prep_time_seconds: 25, is_available: true },
  ];

  await MenuItem.insertMany([...arunMenuItems, ...marinaMenuItems]);
  console.log('  🍱 Seeded 3 items for Hotel Arun & 2 items for Marina');

  // ── Step 8: Spatial & Point-in-Polygon Verifications ─────────────────────────
  console.log('\n🔍 Verifying Spatial Constraints...');

  const chkPoly = chk.boundary.coordinates[0];
  const plyPoly = ply.boundary.coordinates[0];

  const arunInChk = pointInPolygon([arunLoc.longitude, arunLoc.latitude], chkPoly);
  const marinaInPly = pointInPolygon([marinaLoc.longitude, marinaLoc.latitude], plyPoly);
  const pinAInChk = pointInPolygon(PIN_A.coordinates, chkPoly);
  const pinBInPly = pointInPolygon(PIN_B.coordinates, plyPoly);
  const pinBOutChk = !pointInPolygon(PIN_B.coordinates, chkPoly);

  // Distance from Hotel Arun to Pin A
  const distArunToPinA = haversineDistanceKm([arunLoc.longitude, arunLoc.latitude], PIN_A.coordinates);
  // Distance from Hotel Arun to Pin B
  const distArunToPinB = haversineDistanceKm([arunLoc.longitude, arunLoc.latitude], PIN_B.coordinates);

  console.log(`  - Hotel Arun inside KLM-CHK: ${arunInChk ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`  - Marina inside KLM-PLY:     ${marinaInPly ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`  - Pin A inside KLM-CHK:      ${pinAInChk ? '✅ PASS' : '❌ FAIL'} (${distArunToPinA} km from Arun)`);
  console.log(`  - Pin B inside KLM-PLY:      ${pinBInPly ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`  - Pin B outside KLM-CHK:     ${pinBOutChk ? '✅ PASS' : '❌ FAIL'} (${distArunToPinB} km from Arun, within 5km cap)`);

  if (!arunInChk || !marinaInPly || !pinAInChk || !pinBInPly || !pinBOutChk) {
    throw new Error('Spatial verification failed! Check coordinates.');
  }

  console.log('\n======================================================');
  console.log('  Demo Seed Complete & Verified!');
  console.log('  Accounts password: password123');
  console.log('  Pin A: ' + JSON.stringify(PIN_A.coordinates) + ' (In-zone)');
  console.log('  Pin B: ' + JSON.stringify(PIN_B.coordinates) + ' (Out-of-zone)');
  console.log('======================================================\n');

  await mysqlRootConn.end();
  await mongoose.disconnect();
}

seed().catch((err) => {
  console.error('\n❌ Seed failed:', err);
  process.exit(1);
});
