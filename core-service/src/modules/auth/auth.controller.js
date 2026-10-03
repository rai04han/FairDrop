// FairDrop — Auth Controller
// Owner: Hari (25MCA025)
// Module: Auth (Module 1)
//
// Handles register, login, and profile retrieval.
// All business logic lives here — routes just call these functions.

const jwt = require('jsonwebtoken');
const User = require('./User.model');
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
 * If the role is "rider", also initialises an empty rider_profile.
 */
async function register(req, res) {
  try {
    const { name, email, phone, password, role } = req.body;

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

    // Riders get an empty profile that will be filled during onboarding
    if (role === 'rider') {
      userData.rider_profile = {
        vehicle_type: 'motorcycle',
        vehicle_number: '',
        zone_id: null,
        current_zone_id: null,
        is_available: true,
        active_hours_today: 0,
      };
    }

    const user = await User.create(userData);
    const token = generateToken(user);

    res.status(201).json({
      success: true,
      message: 'Registration successful.',
      token,
      user: user.toJSON(),
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

    res.status(200).json({
      success: true,
      message: 'Login successful.',
      token,
      user: user.toJSON(),
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

    res.status(200).json({
      success: true,
      user: user.toJSON(),
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
