// ============================================================================
// FairDrop — Grievance Model (FR-50)
// ============================================================================
// Fairwork Principle 2: Fair Management — Direct grievance & dispute resolution
// ============================================================================

const mongoose = require('mongoose');

const grievanceSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: false,
    },
    user_role: {
      type: String,
      default: 'rider',
    },
    category: {
      type: String,
      required: true,
      trim: true,
    },
    order_id: {
      type: String,
      default: null,
      trim: true,
    },
    subject: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      required: true,
      trim: true,
    },
    status: {
      type: String,
      enum: ['submitted', 'in_review', 'resolved'],
      default: 'submitted',
    },
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  }
);

module.exports = mongoose.model('Grievance', grievanceSchema);
