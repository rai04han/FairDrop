// ============================================================================
// FairDrop — Splash Screen
// ============================================================================
// FR-1: Splash screen checks stored JWT → routes by role; expired → Login
// BUG-8 fix: App was always starting at /login regardless of stored token.
//
// Flow:
//   1. Show logo for at least 800ms
//   2. Check for stored JWT token
//   3. If token exists → call GET /api/auth/me to validate
//      - Valid token + role=rider  → /rider-home
//      - Valid token + role=admin  → /admin-panel
//      - Valid token + other role  → /unsupported-role
//      - Invalid/expired token    → /login (after clearing storage)
//   4. If no token → /login
// ============================================================================

import 'package:flutter/material.dart';
import '../services/core_api_service.dart';
import '../services/exceptions.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    // Subtle entrance animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    // Kick off auth check after animation
    Future.delayed(const Duration(milliseconds: 900), _checkAuth);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// FR-1: Read token → validate → route by role
  Future<void> _checkAuth() async {
    if (!mounted) return;

    try {
      final token = await CoreApiService.getToken();

      if (token == null) {
        // No token stored — must log in
        _navigate('/login');
        return;
      }

      // Token exists — validate it by calling /api/auth/me
      final me = await CoreApiService.getMe();
      final role = me['user']?['role'] as String? ??
          me['role'] as String? ?? 'unknown';

      _routeByRole(role);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Token expired or invalid — clear and go to login
        await CoreApiService.logout();
        _navigate('/login');
      } else {
        // Network or server error — still go to login
        _navigate('/login');
      }
    } catch (_) {
      // Any other error (network down, parse error) — go to login
      _navigate('/login');
    }
  }

  void _routeByRole(String role) {
    switch (role) {
      case 'rider':
        _navigate('/rider-home');
      case 'admin':
        _navigate('/admin-panel');
      case 'customer':
      case 'restaurant':
        _navigate('/unsupported-role');
      default:
        _navigate('/login');
    }
  }

  void _navigate(String route) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo icon ────────────────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    Icons.delivery_dining,
                    size: 60,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 24),

                // ── App name ─────────────────────────────────────────────
                Text(
                  'FairDrop',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fair pay for every delivery',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 48),

                // ── Loading indicator ─────────────────────────────────────
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 24),

                // ── MCA footer ───────────────────────────────────────────
                Text(
                  'MCA Mini Project — 23MCAM307',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
