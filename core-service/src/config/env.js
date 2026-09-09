// FairDrop Core Service — Environment Configuration
// Owner: Hari (25MCA025)
//
// Loads .env variables and validates that all required
// config is present before the server starts.
// Fails fast with a clear message if anything is missing.

const dotenv = require('dotenv');
const path = require('path');

// Load .env from core-service root
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const required = ['PORT', 'MONGODB_URI', 'JWT_SECRET', 'JWT_EXPIRES_IN', 'PAY_SERVICE_URL'];

const missing = required.filter((key) => !process.env[key]);
if (missing.length > 0) {
  console.error(`❌ Missing required environment variables: ${missing.join(', ')}`);
  console.error('   Copy .env.example to .env and fill in the values.');
  process.exit(1);
}

const env = {
  PORT: parseInt(process.env.PORT, 10) || 3003,
  MONGODB_URI: process.env.MONGODB_URI,
  JWT_SECRET: process.env.JWT_SECRET,
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN,
  PAY_SERVICE_URL: process.env.PAY_SERVICE_URL,
};

module.exports = env;
