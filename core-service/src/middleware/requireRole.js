// FairDrop — Role-Based Access Control Middleware
// Owner: Hari (25MCA025)
// Module: Auth (Module 1)
//
// Restricts routes to specific roles.
// Must be used AFTER verifyToken (which sets req.user).
//
// Usage in routes:
//   router.get('/admin-only', verifyToken, requireRole('admin'), handler);
//   router.get('/rider-or-admin', verifyToken, requireRole('rider', 'admin'), handler);

/**
 * Returns a middleware that checks if the logged-in user has one of the allowed roles.
 * If not, returns 403 Forbidden.
 *
 * @param  {...string} allowedRoles - Roles that can access this route
 * @returns {Function} Express middleware
 */
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    // verifyToken must run first and set req.user
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required.',
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Access denied. Required role: ${allowedRoles.join(' or ')}. Your role: ${req.user.role}.`,
      });
    }

    next();
  };
}

module.exports = requireRole;
