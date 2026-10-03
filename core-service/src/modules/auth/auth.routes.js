// FairDrop — Auth Routes
// Owner: Hari (25MCA025)
// Module: Auth (Module 1)
//
// Defines the API endpoints for authentication.
// Public routes: register, login
// Protected routes: me (requires valid JWT)

const express = require('express');
const router = express.Router();
const { register, login, getMe } = require('./auth.controller');
const verifyToken = require('../../middleware/verifyToken');

// ── Public routes (no token needed) ────────────────────────────────────────

router.post('/register', register);
router.post('/login', login);

// ── Protected routes (valid JWT required) ──────────────────────────────────

router.get('/me', verifyToken, getMe);

module.exports = router;
