// FairDrop Pay Engine — Configurable Constants
// Kerala baseline defaults.
// In production these are read from the active row in pay_configs (MySQL).
// This file is used for unit tests and as the fallback default.

const PAY_CONSTANTS = {
  BASE_RATE: 15,             // ₹ per delivery
  PER_KM_RATE: 6,            // ₹ per km
  SURGE_BONUS: 20,           // ₹ flat, when is_surge_active = true
  WAIT_THRESHOLD_MINS: 10,   // minutes before wait compensation triggers
  WAIT_COMPENSATION: 10,     // ₹ flat, when wait exceeds threshold
  MIN_WAGE_PER_HOUR: 70,     // ₹/hr — Kerala minimum wage notification baseline
};

module.exports = PAY_CONSTANTS;
