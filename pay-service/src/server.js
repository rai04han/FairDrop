// FairDrop Pay Service — Express Server Entry Point
// Owner: Raihan
// Port: 3001 (configurable via .env)
//
// This server wraps the pure pay engine (payEngine.js) with:
//   - HTTP endpoints (POST /api/pay/calculate, GET/PUT /api/admin/pay-config)
//   - MySQL persistence (deliveries, earnings, pay_configs tables)
//   - Health check endpoint (GET /api/health)
//
// The pay engine itself has zero knowledge of HTTP or databases.
// This separation keeps the engine fully testable without a running server.

const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

// Load environment variables before any module that depends on them
dotenv.config();

const { testConnection } = require('./db');
const payRoutes = require('./routes/payRoutes');
const adminRoutes = require('./routes/adminRoutes');

const app = express();
const PORT = process.env.PORT || 3001;

// ── Middleware ──────────────────────────────────────────────────────────────

// Parse JSON request bodies (required for POST /api/pay/calculate)
app.use(express.json());

// Enable CORS — allows Flutter app (running on emulator or different port)
// and Harikrishnan's servers (Ports 3003, 3004) to call this API.
app.use(cors());

// ── Routes ─────────────────────────────────────────────────────────────────

// Health check — verifies server is up and MySQL is reachable.
// Useful for debugging during integration testing (Week 10).
app.get('/api/health', async (req, res) => {
  try {
    await testConnection();
    return res.status(200).json({
      status: 'ok',
      service: 'fairdrop-pay-service',
      port: PORT,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(503).json({
      status: 'error',
      service: 'fairdrop-pay-service',
      message: 'MySQL connection failed: ' + error.message,
    });
  }
});

// Pay calculation endpoints (POST /api/pay/calculate, GET /api/pay/history/:rider_id)
app.use('/api/pay', payRoutes);

// Admin config endpoints (GET /api/admin/pay-config, PUT /api/admin/pay-config)
app.use('/api/admin', adminRoutes);

// ── 404 handler ────────────────────────────────────────────────────────────
// Catches requests to undefined routes with a helpful message.
app.use((req, res) => {
  return res.status(404).json({
    error: 'Not found',
    message: `${req.method} ${req.originalUrl} is not a valid endpoint`,
    available_endpoints: [
      'GET  /api/health',
      'POST /api/pay/calculate',
      'GET  /api/pay/history/:rider_id',
      'GET  /api/admin/pay-config',
      'PUT  /api/admin/pay-config',
    ],
  });
});

// ── Global error handler ───────────────────────────────────────────────────
// Catches unhandled errors thrown by any route handler.
// Express requires all 4 parameters (err, req, res, next) to recognize
// this as an error-handling middleware.
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err.message);
  return res.status(500).json({
    error: 'Internal server error',
    message: err.message,
  });
});

// ── Start server ───────────────────────────────────────────────────────────
app.listen(PORT, async () => {
  console.log(`\n  FairDrop Pay Service`);
  console.log(`  ─────────────────────────────`);
  console.log(`  Port:     ${PORT}`);
  console.log(`  Database: ${process.env.DB_NAME || 'fairdrop_pay'}`);
  console.log(`  ─────────────────────────────\n`);

  try {
    await testConnection();
  } catch (error) {
    console.error('✗ Failed to connect to MySQL:', error.message);
    console.error('  Make sure MySQL is running and .env is configured correctly.');
    process.exit(1);
  }
});

module.exports = app;
