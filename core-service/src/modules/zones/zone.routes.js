// FairDrop — Zone Routes
// Owner: Hari (25MCA025)
// Module: Zones (Module 3)
//
// Admin routes for zone CRUD, plus internal routes for rider assignment.
// Map data endpoint is accessible by riders (for flutter_map display).

const express = require('express');
const router = express.Router();
const {
  createZone,
  getZone,
  getMapData,
  updateCap,
  assignRider,
  reassignZone,
} = require('./zone.controller');
const verifyToken = require('../../middleware/verifyToken');
const requireRole = require('../../middleware/requireRole');

// ── All zone routes require authentication ─────────────────────────────────
router.use(verifyToken);

// ── Map data (riders and admins can view) ──────────────────────────────────
router.get('/map', requireRole('rider', 'admin'), getMapData);

// ── Admin routes ───────────────────────────────────────────────────────────
router.post('/', requireRole('admin'), createZone);
router.get('/:id', requireRole('admin'), getZone);
router.patch('/:id/cap', requireRole('admin'), updateCap);

// ── Internal routes (called by order flow, but also admin-accessible) ──────
router.post('/assign', requireRole('admin', 'rider'), assignRider);
router.post('/reassign', requireRole('admin', 'rider'), reassignZone);

module.exports = router;
