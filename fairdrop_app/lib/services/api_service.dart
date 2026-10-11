// ============================================================================
// FairDrop Flutter App — Pay Engine API Service
// ============================================================================
// Owner: Shared (both Raihan's and Hari's screens use this file)
//
// Calls Raihan's pay-service (Port 3001) for pay calculation, history,
// admin config. Uses AppConfig for the base URL (single source of truth).
//
// Fixes in this version:
//   BUG-1  — ApiException removed; imported from exceptions.dart
//   BUG-13 — 10-second timeout on every call (NFR §8)
//   AppConfig — URL from central config, not hardcoded here
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exceptions.dart';
import '../config/app_config.dart';

// Re-export ApiException so screens that only import api_service.dart
// can still catch it without also importing exceptions.dart.
export 'exceptions.dart' show ApiException, TimeoutApiException;

class ApiService {
  static String get _baseUrl => AppConfig.payServiceUrl;

  /// Wraps an HTTP future with the configured timeout.
  static Future<http.Response> _withTimeout(Future<http.Response> request) =>
      request.timeout(
        AppConfig.httpTimeout,
        onTimeout: () => throw const TimeoutApiException(),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // calculatePay()
  // POST /api/pay/calculate
  // Called after a delivery is completed (FR-20).
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> calculatePay({
    required String riderId,
    required String orderId,
    required double distanceKm,
    required bool isSurgeActive,
    required int restaurantWaitMins,
    required double activeHoursToday,
    required String delayType,
    required bool delayVerified,
    required String delaySource,
  }) async {
    final response = await _withTimeout(http.post(
      Uri.parse('$_baseUrl/api/pay/calculate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'rider_id': riderId,
        'order_id': orderId,
        'distance_km': distanceKm,
        'is_surge_active': isSurgeActive,
        'restaurant_wait_mins': restaurantWaitMins,
        'active_hours_today': activeHoursToday,
        'delay_context': {
          'type': delayType,
          'verified': delayVerified,
          'source': delaySource,
        },
      }),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // getPayHistory()
  // GET /api/pay/history/:rider_id
  // Called by Rider Dashboard (FR-30).
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getPayHistory(String riderId) async {
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/pay/history/$riderId'),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // getPayConfig()
  // GET /api/admin/pay-config
  // Called by Admin Panel (FR-38) and Order Acceptance (FR-12, FR-13).
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getPayConfig() async {
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/admin/pay-config'),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // updatePayConfig()
  // PUT /api/admin/pay-config
  // Called by Admin Panel (FR-40–FR-44).
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> updatePayConfig({
    required double baseRate,
    required double perKmRate,
    required double surgeBonus,
    required int waitThresholdMins,
    required double waitCompensation,
    required double minWagePerHour,
    required String effectiveFrom,
    required String changeReason,
  }) async {
    final response = await _withTimeout(http.put(
      Uri.parse('$_baseUrl/api/admin/pay-config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'base_rate': baseRate,
        'per_km_rate': perKmRate,
        'surge_bonus': surgeBonus,
        'wait_threshold_mins': waitThresholdMins,
        'wait_compensation': waitCompensation,
        'min_wage_per_hour': minWagePerHour,
        'effective_from': effectiveFrom,
        'change_reason': changeReason,
      }),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // getConfigHistory()
  // GET /api/admin/pay-config/history
  // Called by Admin Panel to show config history (FR-39).
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getConfigHistory() async {
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/admin/pay-config/history'),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // healthCheck()
  // GET /api/health
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> healthCheck() async {
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/health'),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }
}
