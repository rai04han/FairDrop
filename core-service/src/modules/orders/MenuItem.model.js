// FairDrop — MenuItem Model (MongoDB/Mongoose)
// Module: Orders / Restaurant Menu
//
// Represents items sold by restaurants in FairDrop.
// PRD D5: Fields are strictly name, price, prep_time_seconds, is_available.

const mongoose = require('mongoose');

const menuItemSchema = new mongoose.Schema(
  {
    _id: {
      type: String,
      default: () => new mongoose.Types.ObjectId().toString(),
    },
    restaurant_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'restaurant_id is required'],
      index: true,
    },
    name: {
      type: String,
      required: [true, 'Item name is required'],
      trim: true,
    },
    price: {
      type: Number,
      required: [true, 'Price is required'],
      min: [0, 'Price must be non-negative'],
    },
    prep_time_seconds: {
      type: Number,
      required: [true, 'Preparation time is required'],
      min: [0, 'Preparation time must be non-negative'],
      validate: {
        validator: Number.isInteger,
        message: 'Preparation time must be a whole number in seconds',
      },
    },
    is_available: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  }
);

menuItemSchema.index({ restaurant_id: 1, is_available: 1 });

const MenuItem = mongoose.model('MenuItem', menuItemSchema);

module.exports = MenuItem;
