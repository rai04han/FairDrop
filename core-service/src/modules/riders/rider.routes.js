// FairDrop — Rider Routes
// Owner: Hari (25MCA025)
// Module: Riders (Online/Offline, Shifts & Daily Stats)

const express = require('express');
const router = express.Router();
const {
  setStatus,
  getStats,
  acknowledgeChecklist,
} = require('./rider.controller');
const verifyToken = require('../../middleware/verifyToken');
const requireRole = require('../../middleware/requireRole');

// All rider routes require a valid JWT with role 'rider'
router.use(verifyToken);
router.use(requireRole('rider'));

// ── Online / Offline Status Toggle (FR-7, FR-9, FR-54) ──────────────────────
router.post('/status', setStatus);

// ── Daily Stats & Earnings (FR-8, FR-9) ────────────────────────────────────
router.get('/stats', getStats);
router.get('/stats/today', getStats);

// ── Onboarding Safety Checklist Acknowledgment (FR-46) ─────────────────────
router.post('/checklist', acknowledgeChecklist);
router.post('/onboarding/acknowledge', acknowledgeChecklist);

module.exports = router;
