// FairDrop Core Service — MongoDB Connection
// Owner: Hari (25MCA025)
//
// Connects to MongoDB using Mongoose.
// Called once at server startup. If the connection fails,
// the server logs the error and exits — no silent failures.

const mongoose = require('mongoose');
const env = require('./env');

async function connectDB() {
  try {
    await mongoose.connect(env.MONGODB_URI);
    console.log(`✅ MongoDB connected: ${mongoose.connection.host}`);
  } catch (error) {
    console.error('❌ MongoDB connection failed:', error.message);
    process.exit(1);
  }
}

module.exports = connectDB;
