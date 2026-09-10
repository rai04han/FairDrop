// FairDrop Pay Service — Database Seed Script
// Owner: Raihan
//
// Initializes the MySQL database for the Pay Engine:
//   1. Creates the fairdrop_pay database if it doesn't exist
//   2. Creates tables (riders, pay_configs, deliveries, earnings)
//   3. Seeds the Kerala baseline pay config
//   4. Inserts demo riders for testing
//
// Run: npm run seed (or: node src/seed.js)
// Safe to re-run — uses IF NOT EXISTS and INSERT IGNORE.

const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

dotenv.config();

async function seed() {
  console.log('\n  FairDrop Pay Service — Database Seed');
  console.log('  ─────────────────────────────────────\n');

  // ── Step 1: Connect WITHOUT specifying a database ─────────────────────
  // The database might not exist yet — we create it in the schema.
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    multipleStatements: true, // schema.sql contains multiple statements
  });

  try {
    // ── Step 2: Read and execute schema.sql ──────────────────────────────
    // The schema file is in database/mysql/schema.sql (relative to repo root).
    const schemaPath = path.join(__dirname, '..', '..', 'database', 'mysql', 'schema.sql');
    console.log('  Reading schema from:', schemaPath);

    if (!fs.existsSync(schemaPath)) {
      throw new Error(`Schema file not found: ${schemaPath}`);
    }

    let schema = fs.readFileSync(schemaPath, 'utf-8');

    // Make tables idempotent: add IF NOT EXISTS to CREATE TABLE
    // so the seed can be re-run safely without dropping existing data.
    schema = schema.replace(/CREATE TABLE /g, 'CREATE TABLE IF NOT EXISTS ');

    // Make indexes idempotent: ignore errors on duplicate index creation
    // by converting CREATE INDEX to CREATE INDEX IF NOT EXISTS (MySQL 8.0+).
    // For compatibility, we'll just catch and ignore those errors separately.

    console.log('  Executing schema.sql...');
    await connection.query(schema);
    console.log('  ✓ Database and tables created\n');

    // ── Step 3: Insert demo riders ──────────────────────────────────────
    // INSERT IGNORE skips the insert if rider_id already exists (idempotent).
    console.log('  Seeding demo data...');

    await connection.query(`USE fairdrop_pay`);

    const demoRiders = [
      {
        rider_id: 'rider-001',
        name: 'Arjun Kumar',
        phone: '9876543210',
        zone_id: 'zone-kollam-01',
      },
      {
        rider_id: 'rider-002',
        name: 'Priya Menon',
        phone: '9876543211',
        zone_id: 'zone-kollam-02',
      },
    ];

    for (const rider of demoRiders) {
      await connection.execute(
        `INSERT IGNORE INTO riders (rider_id, name, phone, zone_id)
         VALUES (?, ?, ?, ?)`,
        [rider.rider_id, rider.name, rider.phone, rider.zone_id]
      );
      console.log(`  ✓ Rider: ${rider.rider_id} (${rider.name})`);
    }

    // ── Step 4: Verify seed results ─────────────────────────────────────
    const [riders] = await connection.query('SELECT COUNT(*) AS count FROM riders');
    const [configs] = await connection.query('SELECT COUNT(*) AS count FROM pay_configs WHERE is_active = TRUE');

    console.log(`\n  ── Seed Summary ──`);
    console.log(`  Riders in database:     ${riders[0].count}`);
    console.log(`  Active pay configs:     ${configs[0].count}`);
    console.log(`\n  ✓ Seed completed successfully\n`);

  } catch (error) {
    // Handle duplicate index errors gracefully (re-run scenario)
    if (error.code === 'ER_DUP_KEYNAME') {
      console.log('  ⓘ Indexes already exist (safe to ignore on re-run)');
    } else {
      console.error('  ✗ Seed failed:', error.message);
      process.exit(1);
    }
  } finally {
    await connection.end();
  }
}

seed();
