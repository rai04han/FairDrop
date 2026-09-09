// FairDrop — Core Service Entry Point
// Owner: Hari (25MCA025)
//
// Starts the server:
//   1. Connects to MongoDB
//   2. Starts Express on the configured port
//
// Run: node src/server.js

const app = require('./app');
const connectDB = require('./config/db');
const env = require('./config/env');

async function start() {
  // Step 1: Connect to MongoDB (exits if it fails)
  await connectDB();

  // Step 2: Start Express
  app.listen(env.PORT, () => {
    console.log(`🚀 FairDrop core-service running on http://localhost:${env.PORT}`);
  });
}

start();
