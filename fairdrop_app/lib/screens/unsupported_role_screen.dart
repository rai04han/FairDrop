// ============================================================================
// FairDrop — Unsupported Role Screen
// ============================================================================
// FR-6: Customer or restaurant accounts that log in see this screen.
// BUG-9 fix: Previously, customer/restaurant logins navigated to '/'
//            (the generic HomeScreen) instead of this error screen.
//
// Shows a clear message explaining the mobile app is for riders and admins
// only, with a logout button.
// ============================================================================

import 'package:flutter/material.dart';
import '../services/core_api_service.dart';

class UnsupportedRoleScreen extends StatelessWidget {
  const UnsupportedRoleScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await CoreApiService.logout();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon ─────────────────────────────────────────────────
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.phonelink_off,
                    size: 52,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Heading ───────────────────────────────────────────────
                Text(
                  'This role isn\'t supported',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // ── Explanation ───────────────────────────────────────────
                Text(
                  'The FairDrop mobile app is designed for delivery riders and administrators only.\n\n'
                  'Customer and restaurant accounts can interact with FairDrop via the web dashboard or Postman API.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // ── Logout button ─────────────────────────────────────────
                FilledButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Footer ────────────────────────────────────────────────
                Text(
                  'FairDrop v1.0.0 — MCA Mini Project 23MCAM307',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
