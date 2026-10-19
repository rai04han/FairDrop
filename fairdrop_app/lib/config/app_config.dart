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
  // Switching between USB `adb reverse` (127.0.0.1) and hotspot (192.168.137.1)
  // is a one-line change below (PRD §7, §10.1).
  //
  // Primary (USB adb reverse on phone & emulator): '127.0.0.1'
  // Fallback (Laptop Mobile Hotspot):             '192.168.137.1'
  // Fallback (Emulator default alias):            '10.0.2.2'
  static const String _host = '127.0.0.1';

  /// Core-service: auth, orders, zones (Port 3003)
  static const String coreServiceUrl = 'http://$_host:3003';

  /// Pay-service: pay calculation, history, admin config (Port 3001)
  static const String payServiceUrl = 'http://$_host:3001';

  // ── Network ──────────────────────────────────────────────────────────────

  /// Default timeout for all HTTP calls (NFR §8)
  static const Duration httpTimeout = Duration(seconds: 10);

  // ── Polling ──────────────────────────────────────────────────────────────

  /// How often the Home screen polls for assigned orders (FR-8)
  static const Duration orderPollingInterval = Duration(seconds: 10);
}
