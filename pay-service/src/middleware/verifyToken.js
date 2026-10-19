// FairDrop Pay Service — JWT Verification Middleware
// Enforces authentication across pay-service routes using shared JWT_SECRET.

const jwt = require('jsonwebtoken');

function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Access denied. No bearer token provided.',
    });
  }

  const token = authHeader.split(' ')[1];

  try {
    const secret = process.env.JWT_SECRET;
    if (!secret) {
      console.error('JWT_SECRET is not configured in pay-service');
      return res.status(500).json({
        error: 'Configuration error',
        message: 'JWT_SECRET missing on server.',
      });
    }

    const decoded = jwt.verify(token, secret);
    req.user = decoded; // Contains id and role
    next();
  } catch (error) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid or expired token.',
    });
  }
}

module.exports = verifyToken;
