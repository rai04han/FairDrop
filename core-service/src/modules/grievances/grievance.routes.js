// ============================================================================
// FairDrop — Grievance Routes (FR-50)
// ============================================================================
// Fairwork Principle 2: Fair Management — Direct grievance & dispute resolution
// ============================================================================

const express = require('express');
const router = express.Router();
const { submitGrievance, getGrievances } = require('./grievance.controller');
const verifyToken = require('../../middleware/verifyToken');

// POST /api/grievances — supports authenticated user or optional authorization header
router.post('/', (req, res, next) => {
  if (req.headers.authorization) {
    return verifyToken(req, res, next);
  }
  next();
}, submitGrievance);

// GET /api/grievances — requires auth
router.get('/', verifyToken, getGrievances);

module.exports = router;
