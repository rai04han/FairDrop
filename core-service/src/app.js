// FairDrop — Express App Setup
// Owner: Hari (25MCA025)
//
// Creates and configures the Express application.
// Mounts all route modules and sets up error handling.
// Separated from server.js so it can be imported in tests
// without starting the HTTP server.

const express = require('express');
const cors = require('cors');

const authRoutes = require('./modules/auth/auth.routes');
const orderRoutes = require('./modules/orders/order.routes');

const app = express();

// ── Middleware ──────────────────────────────────────────────────────────────

// Parse JSON request bodies
app.use(express.json());

// Allow requests from Flutter app (any origin for prototype)
app.use(cors());

// ── Routes ─────────────────────────────────────────────────────────────────

app.use('/api/auth', authRoutes);
app.use('/api/orders', orderRoutes);

// Health check — useful for verifying the server is running
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'core-service' });
});

// ── 404 handler ────────────────────────────────────────────────────────────

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

// ── Global error handler ───────────────────────────────────────────────────

app.use((err, req, res, next) => {
  console.error('Unhandled error:', err.message);
  res.status(500).json({
    success: false,
    message: 'Internal server error.',
  });
});

module.exports = app;
