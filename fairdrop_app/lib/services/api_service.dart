// ============================================================================
// FairDrop Flutter App — Pay Engine API Service
// ============================================================================
// Owner: Shared (both Raihan's and Hari's screens use this file)
//
// PURPOSE:
//   This file is the "middleman" between the Flutter app (frontend) and
//   the Node.js Pay Engine server (backend, running on Port 3001).
//
//   Instead of every screen writing raw HTTP code to call the server,
//   they all call methods from this single file. This pattern is called
//   a "service layer" — it keeps screen code clean and avoids duplication.
//
// EXAMPLE USAGE (from any screen):
//   final result = await ApiService.calculatePay(
//     riderId: 'rider-001',
//     orderId: 'ORD-20260911-0001',
//     distanceKm: 5.0,
//     ...
//   );
//   print(result['total_delivery_pay']); // 45.0
// ============================================================================

// 'dart:convert' gives us jsonEncode() and jsonDecode()
// jsonEncode() converts a Dart Map/List → JSON string (to send to server)
// jsonDecode() converts a JSON string → Dart Map/List (received from server)
import 'dart:convert';

// 'package:http/http.dart' is the HTTP client library.
// We import it with the alias 'http' so we can write http.get(), http.post()
// instead of just get(), post() which could conflict with other names.
import 'package:http/http.dart' as http;

// ============================================================================
// ApiService class — contains all API call methods as static functions.
//
// "static" means you call them directly on the class name:
//   ApiService.calculatePay(...)
// instead of creating an instance first:
//   final service = ApiService();  // NOT needed
//   service.calculatePay(...)      // NOT how we do it
// ============================================================================
class ApiService {
  // ── Base URL Configuration ────────────────────────────────────────────────
  //
  // This is the address of your Pay Engine server.
  //
  // Why different URLs for different platforms:
  //   - Chrome (web):      'http://localhost:3001'    (browser talks directly)
  //   - Android emulator:  'http://10.0.2.2:3001'    (emulator's alias for host)
  //   - Physical phone:    'http://192.168.x.x:3001' (your laptop's WiFi IP)
  //
  // We use localhost because we're developing in Chrome.
  // Change this when testing on Android emulator or physical device.
  static const String _baseUrl = 'http://localhost:3001';

  // ══════════════════════════════════════════════════════════════════════════
  // METHOD 1: calculatePay()
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Calls: POST /api/pay/calculate
  // When:  After a delivery is completed
  // What:  Sends delivery details → receives pay breakdown
  //
  // The 'required' keyword means the caller MUST provide this parameter.
  // 'async' means this function runs in the background (doesn't freeze the UI).
  // 'Future<Map<String, dynamic>>' means it will eventually return a Map
  //   (key-value pairs like {"base_rate": 15, "distance_pay": 30, ...}).
  //
  static Future<Map<String, dynamic>> calculatePay({
    required String riderId,          // e.g., 'rider-001'
    required String orderId,          // e.g., 'ORD-20260911-0001'
    required double distanceKm,       // e.g., 5.0 (kilometres)
    required bool isSurgeActive,      // true if surge pricing is on
    required int restaurantWaitMins,  // minutes waited at restaurant
    required double activeHoursToday, // hours worked today (for floor calc)
    required String delayType,        // 'traffic', 'restaurant', 'railway', or 'none'
    required bool delayVerified,      // was the delay verified?
    required String delaySource,      // 'system_log', 'api_mock', or 'none'
  }) async {

    // http.post() sends a POST request to the server.
    // 'await' pauses this function until the server responds.
    // The response contains: statusCode (200, 400, 404, 500) and body (JSON text).
    final response = await http.post(

      // Uri.parse() converts a string URL into a Uri object (required by http package).
      // '$_baseUrl' inserts the base URL value (string interpolation).
      Uri.parse('$_baseUrl/api/pay/calculate'),

      // Headers tell the server what format our data is in.
      // 'application/json' means we're sending JSON (not form data or XML).
      headers: {'Content-Type': 'application/json'},

      // body: the actual data we're sending.
      // jsonEncode() converts this Dart Map into a JSON string:
      //   {"rider_id": "rider-001", "order_id": "ORD-...", ...}
      // The server expects exactly these field names (defined in api-contract.md).
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
    );

    // Check if the server responded with success (HTTP 200 = OK).
    if (response.statusCode == 200) {
      // jsonDecode() converts the JSON string from the server back into a Dart Map.
      // Example return value:
      //   {"order_id": "ORD-...", "base_rate": 15, "distance_pay": 30,
      //    "surge_bonus": 0, "wait_compensation": 0, "total_delivery_pay": 45,
      //    "floor_topup": 235, "hourly_earnings_so_far": 11.25}
      return jsonDecode(response.body);
    } else {
      // If the server returned an error (400, 404, 500), throw our custom exception.
      // The calling screen can catch this and show an error message to the user.
      throw ApiException(response.statusCode, jsonDecode(response.body));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // METHOD 2: getPayHistory()
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Calls: GET /api/pay/history/:rider_id
  // When:  Rider Dashboard screen loads
  // What:  Fetches past earnings for the FairDrop vs cliff-bonus chart
  //
  static Future<Map<String, dynamic>> getPayHistory(String riderId) async {

    // http.get() sends a GET request (no body needed — rider_id is in the URL).
    // '$riderId' is inserted into the URL path.
    final response = await http.get(
      Uri.parse('$_baseUrl/api/pay/history/$riderId'),
    );

    if (response.statusCode == 200) {
      // Example return value:
      //   {"rider_id": "rider-001", "total_records": 5, "earnings": [...]}
      return jsonDecode(response.body);
    } else {
      throw ApiException(response.statusCode, jsonDecode(response.body));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // METHOD 3: getPayConfig()
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Calls: GET /api/admin/pay-config
  // When:  Admin Panel screen loads
  // What:  Fetches current pay constants (base rate, per km rate, etc.)
  //
  static Future<Map<String, dynamic>> getPayConfig() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/admin/pay-config'),
    );

    if (response.statusCode == 200) {
      // Example return value:
      //   {"config": {"base_rate": "15.00", "per_km_rate": "6.00", ...}}
      return jsonDecode(response.body);
    } else {
      throw ApiException(response.statusCode, jsonDecode(response.body));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // METHOD 4: updatePayConfig()
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Calls: PUT /api/admin/pay-config
  // When:  Admin submits new pay constants from the Admin Panel
  // What:  Server creates new config row, enforces 7-day advance notice
  //
  static Future<Map<String, dynamic>> updatePayConfig({
    required double baseRate,         // e.g., 18.0 (₹ per delivery)
    required double perKmRate,        // e.g., 7.0 (₹ per km)
    required double surgeBonus,       // e.g., 25.0 (₹ flat)
    required int waitThresholdMins,   // e.g., 8 (minutes)
    required double waitCompensation, // e.g., 12.0 (₹ flat)
    required double minWagePerHour,   // e.g., 75.0 (₹/hr)
    required String changeReason,     // e.g., "Updated rates for Q4 2026"
  }) async {

    // http.put() sends a PUT request (used for updates).
    final response = await http.put(
      Uri.parse('$_baseUrl/api/admin/pay-config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'base_rate': baseRate,
        'per_km_rate': perKmRate,
        'surge_bonus': surgeBonus,
        'wait_threshold_mins': waitThresholdMins,
        'wait_compensation': waitCompensation,
        'min_wage_per_hour': minWagePerHour,
        'change_reason': changeReason,
      }),
    );

    if (response.statusCode == 200) {
      // Example return value:
      //   {"message": "Pay configuration updated successfully",
      //    "config_id": 2, "effective_from": "2026-09-18",
      //    "notice": "7-day advance notice applied..."}
      return jsonDecode(response.body);
    } else {
      throw ApiException(response.statusCode, jsonDecode(response.body));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // METHOD 5: healthCheck()
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Calls: GET /api/health
  // When:  App startup, to verify the backend server is running
  // What:  Returns server status and MySQL connection state
  //
  static Future<Map<String, dynamic>> healthCheck() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/health'),
    );

    if (response.statusCode == 200) {
      // Example return value:
      //   {"status": "ok", "service": "fairdrop-pay-service", "port": "3001"}
      return jsonDecode(response.body);
    } else {
      throw ApiException(response.statusCode, jsonDecode(response.body));
    }
  }
}

// ============================================================================
// ApiException — Custom error class for API failures
// ============================================================================
//
// WHY A CUSTOM EXCEPTION?
//   When an API call fails (server returns 400, 404, 500), we don't want
//   the app to crash. Instead, we "throw" this exception, and the calling
//   screen catches it and shows a user-friendly error message.
//
// HOW IT'S USED:
//   try {
//     final result = await ApiService.calculatePay(...);
//     // Show result on screen
//   } catch (e) {
//     if (e is ApiException) {
//       print(e.statusCode);  // 404
//       print(e.body['message']);  // "rider_id not found"
//     }
//   }
//
// 'implements Exception' tells Dart this class IS an exception type,
// so it can be used with try/catch blocks.
// ============================================================================
class ApiException implements Exception {
  // The HTTP status code from the server (400, 404, 500, etc.)
  final int statusCode;

  // The error body from the server, e.g., {"error": "...", "message": "..."}
  final Map<String, dynamic> body;

  // Constructor — takes statusCode and body when creating a new ApiException.
  ApiException(this.statusCode, this.body);

  // toString() is called when you print() or display this exception.
  // It shows a readable error message like:
  //   "ApiException(404): rider_id "rider-001" does not exist"
  @override
  String toString() => 'ApiException($statusCode): ${body['message'] ?? body}';
}
