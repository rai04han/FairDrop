// FairDrop — JWT Verification Middleware
// Owner: Hari (25MCA025)
// Module: Auth (Module 1)
//
// Checks every protected request for a valid JWT token.
// If the token is missing or invalid, the request is rejected with 401.
//
// How it works:
//   1. Client sends: Authorization: Bearer <token>
//   2. This middleware extracts the token, verifies it
//   3. If valid, attaches the decoded user info (id, role) to req.user
//   4. If invalid, returns 401 — request never reaches the route handler

const jwt = require('jsonwebtoken');
const env = require('../config/env');

function verifyToken(req, res, next) {
  // Step 1: Get the Authorization header
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Access denied. No token provided.',
    });
  }

  // Step 2: Extract the token (remove "Bearer " prefix)
  const token = authHeader.split(' ')[1];

  try {
    // Step 3: Verify the token using our secret key
    const decoded = jwt.verify(token, env.JWT_SECRET);

    // Step 4: Attach user info to the request object
    // Now any route handler can access req.user.id and req.user.role
    req.user = decoded;

    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token.',
    });
  }
}

module.exports = verifyToken;
