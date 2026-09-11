// FairDrop — Counter Model (MongoDB/Mongoose)
// Owner: Hari (25MCA025)
// Module: Orders (Module 2)
//
// Atomic counter for generating sequential order IDs.
// Uses findOneAndUpdate with $inc to guarantee no duplicates,
// even under concurrent requests.
//
// Format: ORD-YYYYMMDD-0001, ORD-YYYYMMDD-0002, ...
// The sequence resets each day because the date prefix changes.

const mongoose = require('mongoose');

const counterSchema = new mongoose.Schema({
  _id: { type: String, required: true },    // e.g. "order_2026-09-11"
  sequence: { type: Number, default: 0 },
});

/**
 * Get the next order_id for today.
 *
 * How it works:
 *   1. Builds a key like "order_2026-09-11"
 *   2. Atomically increments the counter (creates it if first order of the day)
 *   3. Returns "ORD-20260911-0001"
 *
 * The atomic $inc ensures two simultaneous orders never get the same number.
 */
counterSchema.statics.getNextOrderId = async function () {
  const today = new Date();
  const dateStr = today.toISOString().slice(0, 10); // "2026-09-11"
  const key = `order_${dateStr}`;

  const counter = await this.findOneAndUpdate(
    { _id: key },
    { $inc: { sequence: 1 } },
    { new: true, upsert: true }
  );

  // Format: ORD-YYYYMMDD-NNNN
  const datePart = dateStr.replace(/-/g, ''); // "20260911"
  const seqPart = String(counter.sequence).padStart(4, '0'); // "0001"

  return `ORD-${datePart}-${seqPart}`;
};

const Counter = mongoose.model('Counter', counterSchema);

module.exports = Counter;
