// ============================================================================
// FairDrop — Formatting Utilities (FR-21, FR-22, FR-23)
// ============================================================================
// Standard formatting helpers for currency, distance, duration, and dates.
// ============================================================================

/// Formats a monetary amount with the Indian Rupee symbol `₹` and 2 decimal places.
/// Example: `45` -> `₹45.00`, `null` -> `₹0.00`.
String formatCurrency(num? amount) {
  if (amount == null) return '₹0.00';
  final double val = amount.toDouble();
  return '₹${val.toStringAsFixed(2)}';
}

/// Formats a distance in kilometers with 2 decimal places and unit label (FR-70).
/// Example: `3.5` -> `3.50 km`.
String formatDistance(num? distanceKm) {
  if (distanceKm == null) return '0.00 km';
  final double val = distanceKm.toDouble();
  return '${val.toStringAsFixed(2)} km';
}

/// Formats duration in whole minutes.
/// Example: `12` -> `12 mins`, `1` -> `1 min`.
String formatDurationMinutes(num? minutes) {
  if (minutes == null || minutes <= 0) return '0 mins';
  final int m = minutes.round();
  return m == 1 ? '1 min' : '$m mins';
}

/// Formats preparation time in seconds.
/// Example: `30` -> `30s`, `60` -> `60s`.
String formatPrepTimeSeconds(num? seconds) {
  if (seconds == null || seconds <= 0) return '0s';
  final int s = seconds.round();
  return '${s}s';
}

/// Formats a DateTime object as YYYY-MM-DD.
String formatDate(DateTime? date) {
  if (date == null) return '';
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Formats a DateTime object with date and 24h time: YYYY-MM-DD HH:MM.
String formatDateTime(DateTime? date) {
  if (date == null) return '';
  final d = formatDate(date);
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$d $h:$min';
}
