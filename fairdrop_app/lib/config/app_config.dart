// ============================================================================
// FairDrop — App Configuration
// ============================================================================
// Single source of truth for service URLs and other config constants.
// PRD §7: "Two base URLs in one config file."
//
// Android emulator uses 10.0.2.2 as alias for host machine (localhost).
// Change to your WiFi IP for physical device testing.
// ============================================================================

class AppConfig {
  AppConfig._(); // Prevent instantiation

  // ── Service URLs ─────────────────────────────────────────────────────────
  // Android emulator: 10.0.2.2 maps to host machine's localhost
  // Chrome web:       localhost
  // Physical device:  your machine's WiFi IP (e.g., 192.168.1.x)

  /// Hari's core-service: auth, orders, zones (Port 3003)
  static const String coreServiceUrl = 'http://10.0.2.2:3003';

  /// Raihan's pay-service: pay calculation, history, admin config (Port 3001)
  static const String payServiceUrl = 'http://10.0.2.2:3001';

  // ── Network ──────────────────────────────────────────────────────────────

  /// Default timeout for all HTTP calls (NFR §8)
  static const Duration httpTimeout = Duration(seconds: 10);

  // ── Polling ──────────────────────────────────────────────────────────────

  /// How often the Home screen polls for assigned orders (FR-8)
  static const Duration orderPollingInterval = Duration(seconds: 10);
}
