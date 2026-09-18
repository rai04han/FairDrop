// ============================================================================
// FairDrop — Core Service API Client (Port 3003)
// ============================================================================
// Owner: Hari (25MCA025)
//
// PURPOSE:
//   HTTP client for Hari's core-service (auth, orders, zones).
//   Separate from Raihan's api_service.dart which talks to pay-service (3001).
//
// USAGE:
//   final token = await CoreApiService.login('hari@fairdrop.in', 'password123');
//   final zones = await CoreApiService.getZoneMap(token);
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CoreApiService {
  // Core-service runs on port 3003 (Hari's backend)
  // Chrome: localhost, Android emulator: 10.0.2.2, Physical: your WiFi IP
  static const String _baseUrl = 'http://localhost:3003';

  // ── Token storage ─────────────────────────────────────────────────────────

  /// Save JWT token to device storage
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  /// Read JWT token from device storage
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// Save user role for role-based UI
  static Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  /// Get saved user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  /// Clear token and role on logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
  }

  // ── Auth API ──────────────────────────────────────────────────────────────

  /// POST /api/auth/register
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password_hash': password,
        'role': role,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      await saveToken(data['token']);
      await saveUserRole(data['user']['role']);
      return data;
    }
    throw ApiException(response.statusCode, data);
  }

  /// POST /api/auth/login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password_hash': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await saveToken(data['token']);
      await saveUserRole(data['user']['role']);
      return data;
    }
    throw ApiException(response.statusCode, data);
  }

  /// GET /api/auth/me
  static Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }

  // ── Orders API ────────────────────────────────────────────────────────────

  /// POST /api/orders
  static Future<Map<String, dynamic>> placeOrder({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryAddress,
    required Map<String, dynamic> restaurantAddress,
    required double distanceKm,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'restaurant_id': restaurantId,
        'items': items,
        'delivery_address': deliveryAddress,
        'restaurant_address': restaurantAddress,
        'distance_km': distanceKm,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data;
    throw ApiException(response.statusCode, data);
  }

  /// GET /api/orders/:id
  static Future<Map<String, dynamic>> getOrder(String orderId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/orders/$orderId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }

  /// GET /api/orders/history
  static Future<Map<String, dynamic>> getOrderHistory() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/orders/history'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }

  /// GET /api/orders/rider/active
  static Future<Map<String, dynamic>> getRiderActiveOrder() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/orders/rider/active'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }

  /// PATCH /api/orders/:id/status
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String newStatus,
    int? restaurantWaitMins,
    Map<String, dynamic>? delayContext,
  }) async {
    final token = await getToken();
    final body = <String, dynamic>{'new_status': newStatus};
    if (restaurantWaitMins != null) body['restaurant_wait_mins'] = restaurantWaitMins;
    if (delayContext != null) body['delay_context'] = delayContext;

    final response = await http.patch(
      Uri.parse('$_baseUrl/api/orders/$orderId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }

  // ── Zones API ─────────────────────────────────────────────────────────────

  /// GET /api/zones/map — returns GeoJSON FeatureCollection
  static Future<Map<String, dynamic>> getZoneMap() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/zones/map'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw ApiException(response.statusCode, data);
  }
}

// Reuse Raihan's exception pattern for consistency
class ApiException implements Exception {
  final int statusCode;
  final Map<String, dynamic> body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): ${body['message'] ?? body}';
}
