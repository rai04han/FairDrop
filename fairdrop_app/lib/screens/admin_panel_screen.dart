// ============================================================================
// FairDrop — Admin Panel Screen (Placeholder)
// ============================================================================
// Owner: Raihan
// Branch: flutter/admin-panel (Week 12 — full implementation)
//
// PURPOSE:
//   Placeholder screen. The real implementation will show:
//   - Current pay config display (from GET /api/admin/pay-config)
//   - Form to update pay constants (calls PUT /api/admin/pay-config)
//   - 7-day advance notice confirmation before submitting
//   - Change reason input (mandatory audit field)
//
// PRD FEATURES:
//   - F-ADMIN-01: Pay Config Management
//   - F-PAY-04: 7-day advance notice before pay structure change
// ============================================================================

import 'package:flutter/material.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Admin Panel',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Full implementation coming in Week 12',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
