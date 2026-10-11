// ============================================================================
// FairDrop — Shared Exception Classes
// ============================================================================
// BUG-1 fix: Both api_service.dart and core_api_service.dart previously
// defined their own ApiException, causing a compile error when both are
// imported in the same file. This file is the single source of truth.
//
// USAGE:
//   import '../services/exceptions.dart';
//   try { ... } on ApiException catch (e) {
//     print(e.statusCode); // 404
//     print(e.message);    // "Not found"
//   }
// ============================================================================

/// Custom exception for API failures (non-2xx HTTP responses).
///
/// Thrown by both CoreApiService (core-service) and ApiService (pay-service).
/// Screens catch this to show user-friendly inline error messages (FR-5).
class ApiException implements Exception {
  /// The HTTP status code from the server (400, 401, 404, 500, etc.)
  final int statusCode;

  /// The parsed error body from the server.
  /// Typically contains 'message' and optionally 'error' keys.
  final Map<String, dynamic> body;

  const ApiException(this.statusCode, this.body);

  /// Human-readable error message extracted from the response body.
  String get message => body['message']?.toString() ?? 'An error occurred';

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when a request is cancelled due to a network timeout.
/// Used to show "Request timed out" instead of an infinite spinner (NFR §8).
class TimeoutApiException extends ApiException {
  const TimeoutApiException()
      : super(408, const {'message': 'Request timed out. Check your connection.'});
}
