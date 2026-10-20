// ============================================================================
// FairDrop — Core Service API Client (Port 3003)
// ============================================================================
// Owner: Hari (25MCA025)
//
// Fixes in this version:
//   BUG-1  — Removed duplicate ApiException; now imported from exceptions.dart
//   BUG-4  — null token guard: throws 401 before sending "Bearer null"
//   BUG-7  — FR-3: JWT stored in flutter_secure_storage, not shared_preferences
//   BUG-13 — FR-NFR: 10-second timeout on every HTTP call
//   BUG-15 — 401 global handling: clears session
//   AppConfig — URLs come from app_config.dart (no more scattered localhost)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'exceptions.dart';
import '../config/app_config.dart';

class CoreApiService {
  // Base URL from central config (Android emulator: 10.0.2.2)
  static String get _baseUrl => AppConfig.coreServiceUrl;

  // flutter_secure_storage instance — AES-256 encrypted on Android (Keystore)
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Storage keys
  static const _keyToken = 'jwt_token';
  static const _keyRole  = 'user_role';
  static const _keyUserId = 'user_id';

  // ── Token Storage ─────────────────────────────────────────────────────────

  /// Save JWT token to secure encrypted storage (FR-3)
  static Future<void> saveToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  /// Read JWT token from secure storage.
  /// Returns null if not logged in.
  static Future<String?> getToken() => _storage.read(key: _keyToken);

  /// Save user role for role-based routing
  static Future<void> saveUserRole(String role) =>
      _storage.write(key: _keyRole, value: role);

  /// Get saved user role
  static Future<String?> getUserRole() => _storage.read(key: _keyRole);

  /// Save user ID (used to pass correct rider ID to pay-service)
  static Future<void> saveUserId(String id) =>
      _storage.write(key: _keyUserId, value: id);

  /// Get saved user ID
  static Future<String?> getUserId() => _storage.read(key: _keyUserId);

  /// Clear all auth data on logout or 401 (FR-4, FR-54).
  /// If the current user is a rider, notifies backend to set offline (FR-7, FR-54).
  static Future<void> logout() async {
    try {
      final role = await getUserRole();
      if (role == 'rider') {
        // Send offline state to backend before session is cleared (FR-54)
        await setRiderStatus(isOnline: false).catchError((_) => <String, dynamic>{});
      }
    } catch (_) {
      // Ignore network errors so storage cleanup is never blocked
    } finally {
      await _storage.delete(key: _keyToken);
      await _storage.delete(key: _keyRole);
      await _storage.delete(key: _keyUserId);
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Returns auth headers. Throws ApiException(401) if token is null (BUG-4).
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    if (token == null) {
      throw const ApiException(401, {'message': 'Not authenticated. Please log in.'});
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Handles 401 responses globally: clears session (FR-4).
  static ApiException _handleError(int statusCode, Map<String, dynamic> body) {
    if (statusCode == 401) {
      // Fire-and-forget: clear session on 401
      logout();
    }
    return ApiException(statusCode, body);
  }

  /// Wraps an HTTP future with a timeout (BUG-13 / NFR §8).
  static Future<http.Response> _withTimeout(Future<http.Response> request) =>
      request.timeout(
        AppConfig.httpTimeout,
        onTimeout: () => throw const TimeoutApiException(),
      );

  // ── Auth API ──────────────────────────────────────────────────────────────

  /// POST /api/auth/register
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? vehicleType,
    String? vehicleNumber,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    };
    if (vehicleType != null) body['vehicle_type'] = vehicleType;
    if (vehicleNumber != null) body['vehicle_number'] = vehicleNumber;
    if (phone != null) body['phone'] = phone;

    final response = await _withTimeout(http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      await saveToken(data['token'] as String);
      await saveUserRole(data['user']['role'] as String);
      await saveUserId(data['user']['_id'] as String);
      return data;
    }
    throw _handleError(response.statusCode, data);
  }

  /// POST /api/auth/login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _withTimeout(http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      await saveToken(data['token'] as String);
      await saveUserRole(data['user']['role'] as String);
      await saveUserId(data['user']['_id'] as String);
      return data;
    }
    throw _handleError(response.statusCode, data);
  }

  /// GET /api/auth/me — validates token and returns current user
  static Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/auth/me'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  // ── Orders API ────────────────────────────────────────────────────────────

  /// GET /api/orders/restaurants — lists all restaurants (BUG-2 fix)
  static Future<Map<String, dynamic>> getRestaurants() async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/orders/restaurants'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// GET /api/restaurants/:id/menu — get menu for a specific restaurant (FR-57)
  static Future<Map<String, dynamic>> getRestaurantMenu(String restaurantId) async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/restaurants/$restaurantId/menu'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  // ── Restaurant Portal API (FR-62 to FR-66) ────────────────────────────────

  /// GET /api/restaurants/menu — get own restaurant menu items (FR-62)
  static Future<Map<String, dynamic>> getMyRestaurantMenu() async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/restaurants/menu'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// POST /api/restaurants/menu — add a new menu item (FR-63)
  static Future<Map<String, dynamic>> addMenuItem({
    required String name,
    required double price,
    required int prepTimeSeconds,
    bool isAvailable = true,
  }) async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.post(
      Uri.parse('$_baseUrl/api/restaurants/menu'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'price': price,
        'prep_time_seconds': prepTimeSeconds,
        'is_available': isAvailable,
      }),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return data;
    throw _handleError(response.statusCode, data);
  }

  /// PATCH /api/restaurants/menu/:item_id — update item or toggle availability (FR-63, FR-64)
  static Future<Map<String, dynamic>> updateMenuItem(
    String itemId, {
    String? name,
    double? price,
    int? prepTimeSeconds,
    bool? isAvailable,
  }) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (price != null) body['price'] = price;
    if (prepTimeSeconds != null) body['prep_time_seconds'] = prepTimeSeconds;
    if (isAvailable != null) body['is_available'] = isAvailable;

    final response = await _withTimeout(http.patch(
      Uri.parse('$_baseUrl/api/restaurants/menu/$itemId'),
      headers: headers,
      body: jsonEncode(body),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// GET /api/restaurants/orders — list incoming orders for restaurant with is_ready (FR-65, FR-69)
  static Future<Map<String, dynamic>> getRestaurantOrders() async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/restaurants/orders'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// POST /api/orders
  static Future<Map<String, dynamic>> placeOrder({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryAddress,
    required Map<String, dynamic> restaurantAddress,
    required double distanceKm,
  }) async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.post(
      Uri.parse('$_baseUrl/api/orders'),
      headers: headers,
      body: jsonEncode({
        'restaurant_id': restaurantId,
        'items': items,
        'delivery_address': deliveryAddress,
        'restaurant_address': restaurantAddress,
        'distance_km': distanceKm,
      }),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return data;
    throw _handleError(response.statusCode, data);
  }

  /// GET /api/orders/:id
  static Future<Map<String, dynamic>> getOrder(String orderId) async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/orders/$orderId'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// GET /api/orders/history
  static Future<Map<String, dynamic>> getOrderHistory() async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/orders/history'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// GET /api/orders/rider/active
  static Future<Map<String, dynamic>> getRiderActiveOrder() async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/orders/rider/active'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// PATCH /api/orders/:id/status
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String newStatus,
    int? restaurantWaitMins,
    Map<String, dynamic>? delayContext,
  }) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{'new_status': newStatus};
    if (restaurantWaitMins != null) body['restaurant_wait_mins'] = restaurantWaitMins;
    if (delayContext != null) body['delay_context'] = delayContext;

    final response = await _withTimeout(http.patch(
      Uri.parse('$_baseUrl/api/orders/$orderId/status'),
      headers: headers,
      body: jsonEncode(body),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// PATCH /api/orders/:id/accept — rider accepts allocated order (FR-15, FR-68)
  static Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.patch(
      Uri.parse('$_baseUrl/api/orders/$orderId/accept'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// PATCH /api/orders/:id/decline — rider declines allocated order without penalty (FR-15, D7)
  static Future<Map<String, dynamic>> declineOrder(String orderId) async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.patch(
      Uri.parse('$_baseUrl/api/orders/$orderId/decline'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// POST /api/orders/:id/retry-pay — retries pay calculation for delivered order (FR-24)
  static Future<Map<String, dynamic>> retryPay(String orderId) async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.post(
      Uri.parse('$_baseUrl/api/orders/$orderId/retry-pay'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  // ── Zones API ─────────────────────────────────────────────────────────────

  /// GET /api/zones/map — returns GeoJSON FeatureCollection
  static Future<Map<String, dynamic>> getZoneMap() async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/zones/map'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  // ── Online/Offline Status ─────────────────────────────────────────────────

  /// POST /api/rider/status — set rider online/offline (FR-7)
  /// Note: This endpoint may need to be added to core-service if not present.
  static Future<Map<String, dynamic>> setRiderStatus({
    required bool isOnline,
  }) async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.post(
      Uri.parse('$_baseUrl/api/rider/status'),
      headers: headers,
      body: jsonEncode({'is_online': isOnline}),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  /// GET /api/rider/stats/today — today's earnings and hours (FR-9)
  static Future<Map<String, dynamic>> getTodayStats() async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/rider/stats/today'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  // ── Onboarding & Safety Checklist (FR-46) ─────────────────────────────────

  /// POST /api/rider/checklist — acknowledges safety and Fairwork checklist on server (FR-46)
  static Future<Map<String, dynamic>> acknowledgeChecklist() async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.post(
      Uri.parse('$_baseUrl/api/rider/checklist'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }

  // ── Grievance & Feedback (FR-50) ──────────────────────────────────────────

  /// POST /api/grievances — submits grievance/feedback item (FR-50)
  static Future<Map<String, dynamic>> submitGrievance({
    required String category,
    String? orderId,
    required String subject,
    required String description,
  }) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{
      'category': category,
      'subject': subject,
      'description': description,
    };
    if (orderId != null && orderId.trim().isNotEmpty) {
      body['order_id'] = orderId.trim();
    }

    final response = await _withTimeout(http.post(
      Uri.parse('$_baseUrl/api/grievances'),
      headers: headers,
      body: jsonEncode(body),
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) return data;
    throw _handleError(response.statusCode, data);
  }

  /// GET /api/grievances — fetches user's submitted grievances
  static Future<Map<String, dynamic>> getGrievances() async {
    final headers = await _authHeaders();
    final response = await _withTimeout(http.get(
      Uri.parse('$_baseUrl/api/grievances'),
      headers: headers,
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw _handleError(response.statusCode, data);
  }
}
