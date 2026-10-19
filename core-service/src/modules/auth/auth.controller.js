// FairDrop — Auth Controller
// Owner: Hari (25MCA025)
// Module: Auth (Module 1)
//
// Handles register, login, and profile retrieval.
// All business logic lives here — routes just call these functions.

const jwt = require('jsonwebtoken');
const User = require('./User.model');
const Zone = require('../zones/Zone.model');
const env = require('../../config/env');

/**
 * Generate a JWT token for a user.
 * The token contains the user's id and role — enough for
 * verifyToken and requireRole to do their job.
 */
function generateToken(user) {
  return jwt.sign(
    { id: user._id, role: user.role },
    env.JWT_SECRET,
    { expiresIn: env.JWT_EXPIRES_IN }
  );
}

/**
 * POST /api/auth/register
 *
 * Creates a new user with the given role.
 * If the role is "rider", assigns the zone with fewest riders (FR-51, FR-52, D1)
 * and syncs to MySQL riders table (D12).
 */
async function register(req, res) {
  try {
    let { name, email, phone, password, role, vehicle_type } = req.body;

    // Default to rider if role omitted but vehicle_type provided
    if (!role && vehicle_type) {
      role = 'rider';
    }

    // ── Validate required fields ─────────────────────────────────────────
    if (!name || !email || !password || !role) {
      return res.status(400).json({
        success: false,
        message: 'name, email, password, and role are required.',
      });
    }

    const validRoles = ['customer', 'rider', 'restaurant', 'admin'];
    if (!validRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        message: `Invalid role. Must be one of: ${validRoles.join(', ')}`,
      });
    }

    // ── Check if email already exists ────────────────────────────────────
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'A user with this email already exists.',
      });
    }

    // ── Create user ──────────────────────────────────────────────────────
    const userData = {
      name,
      email,
      phone: phone || '',
      password_hash: password, // pre-save hook will bcrypt this
      role,
    };

    // Riders get least-rider assigned zone (FR-51, FR-52, D1)
    if (role === 'rider') {
      const zones = await Zone.find();
      let assignedZone = null;

      if (zones.length > 0) {
        // Count active riders per zone
        const riderCounts = await Promise.all(
          zones.map(async (zone) => {
            const count = await User.countDocuments({
              role: 'rider',
              $or: [
                { 'rider_profile.zone_id': zone._id },
                { 'rider_profile.assigned_zone_code': zone.zone_id },
              ],
            });
            return { zone, count };
          })
        );

        // Sort by rider count ASC, then zone_id ASC (tie-breaker D1)
        riderCounts.sort((a, b) => {
          if (a.count !== b.count) {
            return a.count - b.count;
          }
          const codeA = (a.zone.zone_id || a.zone.name || '').toUpperCase();
          const codeB = (b.zone.zone_id || b.zone.name || '').toUpperCase();
          return codeA.localeCompare(codeB);
        });

        assignedZone = riderCounts[0].zone;
      }

      userData.rider_profile = {
        vehicle_type: vehicle_type || 'motorcycle',
        vehicle_number: req.body.vehicle_number || '',
        zone_id: assignedZone ? assignedZone._id : null,
        current_zone_id: assignedZone ? assignedZone._id : null,
        assigned_zone_code: assignedZone ? (assignedZone.zone_id || assignedZone.name) : null,
        current_zone_code: assignedZone ? (assignedZone.zone_id || assignedZone.name) : null,
        is_available: true,
        is_online: false,
        active_hours_today: 0,
        safety_checklist_acknowledged: false,
      };
    }

    const user = await User.create(userData);
    const token = generateToken(user);

    // Sync rider to MySQL via pay-service (D12: rollback Mongo user if MySQL fails)
    if (role === 'rider') {
      try {
        const payRes = await fetch(`${env.PAY_SERVICE_URL}/api/pay/riders`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({
            rider_id: user._id.toString(),
            name: user.name,
          }),
        });

        if (!payRes.ok) {
          await User.findByIdAndDelete(user._id);
          return res.status(500).json({
            success: false,
            message: 'Failed to create MySQL rider record. Registration rolled back.',
          });
        }
      } catch (netErr) {
        // Network error / pay-service not running
        console.warn('Pay service unreachable during rider signup; rider will be auto-upserted on first delivery.');
      }
    }

    const userResponse = user.toJSON();
    if (userResponse.rider_profile) {
      userResponse.assigned_zone = userResponse.rider_profile.assigned_zone_code;
    }

    res.status(201).json({
      success: true,
      message: 'Registration successful.',
      token,
      user: userResponse,
    });
  } catch (error) {
    console.error('Register error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Server error during registration.',
    });
  }
}

/**
 * POST /api/auth/login
 *
 * Authenticates a user by email + password.
 * Returns a JWT token on success.
 */
async function login(req, res) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required.',
      });
    }

    // ── Find user by email ───────────────────────────────────────────────
    // We need to explicitly select password_hash because toJSON strips it
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    // ── Compare password ─────────────────────────────────────────────────
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    const token = generateToken(user);
    const userResponse = user.toJSON();
    if (userResponse.rider_profile) {
      userResponse.assigned_zone =
        userResponse.rider_profile.assigned_zone_code ||
        userResponse.rider_profile.current_zone_code ||
        null;
    }

    res.status(200).json({
      success: true,
      message: 'Login successful.',
      token,
      user: userResponse,
    });
  } catch (error) {
    console.error('Login error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Server error during login.',
    });
  }
}

/**
 * GET /api/auth/me
 *
 * Returns the currently logged-in user's profile.
 * Requires a valid JWT token (verifyToken middleware runs first).
 */
async function getMe(req, res) {
  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found.',
      });
    }

    const userResponse = user.toJSON();
    if (userResponse.rider_profile) {
      userResponse.assigned_zone =
        userResponse.rider_profile.assigned_zone_code ||
        userResponse.rider_profile.current_zone_code ||
        null;
      userResponse.current_zone =
        userResponse.rider_profile.current_zone_code ||
        userResponse.rider_profile.assigned_zone_code ||
        null;
    }

    res.status(200).json({
      success: true,
      user: userResponse,
    });
  } catch (error) {
    console.error('GetMe error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Server error.',
    });
  }
}

module.exports = { register, login, getMe };
