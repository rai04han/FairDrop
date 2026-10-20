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
const zoneRoutes = require('./modules/zones/zone.routes');
const riderRoutes = require('./modules/riders/rider.routes');
const restaurantRoutes = require('./modules/restaurants/restaurant.routes');
const grievanceRoutes = require('./modules/grievances/grievance.routes');

const app = express();

// ── Middleware ──────────────────────────────────────────────────────────────

// Parse JSON request bodies
app.use(express.json());

// Allow requests from Flutter app (any origin for prototype)
app.use(cors());

// ── Routes ─────────────────────────────────────────────────────────────────

app.use('/api/auth', authRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/zones', zoneRoutes);
app.use('/api/riders', riderRoutes);
app.use('/api/rider', riderRoutes);
app.use('/api/restaurants', restaurantRoutes);
app.use('/api/grievances', grievanceRoutes);

// Health check — useful for verifying the server is running
app.get(['/health', '/api/health'], (req, res) => {
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
