// FairDrop — User Model (MongoDB/Mongoose)
// Owner: Hari (25MCA025)
// Module: Auth (Module 1)
//
// Stores all users across all 4 roles: customer, rider, restaurant, admin.
// Riders have an additional rider_profile subdocument with zone and vehicle info.
// Passwords are hashed with bcrypt before saving — plaintext is never stored.

const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const SALT_ROUNDS = 10;

// ── Rider-specific profile (only present when role = "rider") ──────────────

const riderProfileSchema = new mongoose.Schema(
  {
    vehicle_type: {
      type: String,
      enum: ['bicycle', 'motorcycle', 'scooter'],
      default: 'motorcycle',
    },
    vehicle_number: { type: String, default: '' },
    zone_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Zone', default: null },
    current_zone_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Zone', default: null },
    is_available: { type: Boolean, default: true },
    active_hours_today: { type: Number, default: 0 },
  },
  { _id: false }
);

// ── Main User schema ───────────────────────────────────────────────────────

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
    },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true,
      lowercase: true,
      trim: true,
    },
    phone: {
      type: String,
      default: '',
    },
    password_hash: {
      type: String,
      required: [true, 'Password is required'],
    },
    role: {
      type: String,
      enum: ['customer', 'rider', 'restaurant', 'admin'],
      required: [true, 'Role is required'],
    },
    is_active: {
      type: Boolean,
      default: true,
    },
    rider_profile: {
      type: riderProfileSchema,
      default: null,
    },
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  }
);

// ── Pre-save hook: hash password before storing ────────────────────────────
// This runs every time a user is created or their password is changed.
// bcrypt adds a random salt so even identical passwords produce different hashes.

userSchema.pre('save', async function () {
  // Only hash if the password field was modified (not on every save)
  if (!this.isModified('password_hash')) return;

  this.password_hash = await bcrypt.hash(this.password_hash, SALT_ROUNDS);
});

// ── Instance method: compare a candidate password against the stored hash ──
// Used during login: user submits plaintext password, we check it against the hash.

userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password_hash);
};

// ── Strip password from JSON output ────────────────────────────────────────
// When we send user data to the frontend, the password hash is removed automatically.

userSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.password_hash;
  return obj;
};

// ── Indexes ────────────────────────────────────────────────────────────────

userSchema.index({ role: 1 });
userSchema.index({ 'rider_profile.zone_id': 1 });

const User = mongoose.model('User', userSchema);

module.exports = User;
