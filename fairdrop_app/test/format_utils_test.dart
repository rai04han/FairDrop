// ============================================================================
// FairDrop — Format Utils Unit Tests
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/utils/format_utils.dart';

void main() {
  group('formatCurrency', () {
    test('formats valid numbers with rupee symbol and 2 decimals', () {
      expect(formatCurrency(45), '₹45.00');
      expect(formatCurrency(12.5), '₹12.50');
      expect(formatCurrency(0), '₹0.00');
      expect(formatCurrency(100.999), '₹101.00');
    });

    test('handles null gracefully', () {
      expect(formatCurrency(null), '₹0.00');
    });
  });

  group('formatDistance', () {
    test('formats distance with 2 decimals and km unit', () {
      expect(formatDistance(3.5), '3.50 km');
      expect(formatDistance(0), '0.00 km');
      expect(formatDistance(1.583), '1.58 km');
    });

    test('handles null gracefully', () {
      expect(formatDistance(null), '0.00 km');
    });
  });

  group('formatDurationMinutes', () {
    test('formats plural and singular minutes', () {
      expect(formatDurationMinutes(1), '1 min');
      expect(formatDurationMinutes(12), '12 mins');
      expect(formatDurationMinutes(0), '0 mins');
      expect(formatDurationMinutes(-5), '0 mins');
      expect(formatDurationMinutes(null), '0 mins');
    });
  });

  group('formatPrepTimeSeconds', () {
    test('formats prep time seconds', () {
      expect(formatPrepTimeSeconds(30), '30s');
      expect(formatPrepTimeSeconds(60), '60s');
      expect(formatPrepTimeSeconds(0), '0s');
      expect(formatPrepTimeSeconds(null), '0s');
    });
  });

  group('formatDate and formatDateTime', () {
    final dt = DateTime(2026, 10, 19, 14, 30);

    test('formats date as YYYY-MM-DD', () {
      expect(formatDate(dt), '2026-10-19');
      expect(formatDate(null), '');
    });

    test('formats date and time as YYYY-MM-DD HH:MM', () {
      expect(formatDateTime(dt), '2026-10-19 14:30');
      expect(formatDateTime(null), '');
    });
  });
}
