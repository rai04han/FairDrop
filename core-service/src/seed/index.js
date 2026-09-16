// FairDrop — Master Seed Script
// Owner: Hari (25MCA025)
//
// Seeds the database with test users and Kollam zones for demo.
// Run: node src/seed/index.js
//
// Creates:
//   - 2 customers, 3 riders (one per zone), 2 restaurants, 1 admin
//   - 4 Kollam delivery zones with GeoJSON boundaries
//   - Links riders to their assigned zones

const mongoose = require('mongoose');
const env = require('../config/env');
const User = require('../modules/auth/User.model');
const Zone = require('../modules/zones/Zone.model');
const kollamZones = require('./kollam-zones');

const seedUsers = [
  { name: 'Hari', email: 'hari@fairdrop.in', password_hash: 'password123', role: 'customer' },
  { name: 'Raihan', email: 'raihan@fairdrop.in', password_hash: 'password123', role: 'customer' },
  { name: 'Ajith (Rider)', email: 'ajith@fairdrop.in', password_hash: 'password123', role: 'rider',
    rider_profile: { vehicle_type: 'motorcycle', is_available: true, active_hours_today: 2 } },
  { name: 'Bibin (Rider)', email: 'bibin@fairdrop.in', password_hash: 'password123', role: 'rider',
    rider_profile: { vehicle_type: 'scooter', is_available: true, active_hours_today: 3 } },
  { name: 'Chandu (Rider)', email: 'chandu@fairdrop.in', password_hash: 'password123', role: 'rider',
    rider_profile: { vehicle_type: 'bicycle', is_available: true, active_hours_today: 1 } },
  { name: 'Hotel Arun', email: 'arun@fairdrop.in', password_hash: 'password123', role: 'restaurant' },
  { name: 'Cafe Marina', email: 'marina@fairdrop.in', password_hash: 'password123', role: 'restaurant' },
  { name: 'Admin', email: 'admin@fairdrop.in', password_hash: 'password123', role: 'admin' },
];

async function seed() {
  try {
    await mongoose.connect(env.MONGODB_URI);
    console.log('✅ Connected to MongoDB');

    // Clear existing data
    await User.deleteMany({});
    await Zone.deleteMany({});
    console.log('🗑️  Cleared existing data');

    // Seed zones
    const createdZones = await Zone.insertMany(kollamZones);
    console.log(`📍 Created ${createdZones.length} zones:`);
    createdZones.forEach((z) => console.log(`   - ${z.name}`));

    // Link adjacent zones (Central ↔ Beach, Central ↔ Chinnakkada, Central ↔ Asramam)
    const [central, beach, chinnakkada, asramam] = createdZones;
    central.adjacentZones = [beach._id, chinnakkada._id, asramam._id];
    beach.adjacentZones = [central._id];
    chinnakkada.adjacentZones = [central._id, beach._id];
    asramam.adjacentZones = [central._id];
    await Promise.all([central.save(), beach.save(), chinnakkada.save(), asramam.save()]);
    console.log('🔗 Linked adjacent zones');

    // Assign riders to zones before creating
    seedUsers[2].rider_profile.zone_id = central._id;        // Ajith → Central
    seedUsers[2].rider_profile.current_zone_id = central._id;
    seedUsers[3].rider_profile.zone_id = beach._id;           // Bibin → Beach
    seedUsers[3].rider_profile.current_zone_id = beach._id;
    seedUsers[4].rider_profile.zone_id = chinnakkada._id;     // Chandu → Chinnakkada
    seedUsers[4].rider_profile.current_zone_id = chinnakkada._id;

    // Seed users
    const createdUsers = await User.create(seedUsers);
    console.log(`👥 Created ${createdUsers.length} users:`);
    createdUsers.forEach((u) => console.log(`   - ${u.name} (${u.role})`));

    console.log('\n══════════════════════════════════════');
    console.log('  Seed complete! Login with:');
    console.log('  Email: admin@fairdrop.in');
    console.log('  Password: password123');
    console.log('══════════════════════════════════════\n');
  } catch (error) {
    console.error('❌ Seed error:', error.message);
  } finally {
    await mongoose.disconnect();
  }
}

seed();
