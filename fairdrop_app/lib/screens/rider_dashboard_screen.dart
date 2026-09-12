// ============================================================================
// FairDrop — Rider Dashboard Screen (Placeholder)
// ============================================================================
// Owner: Raihan
// Branch: flutter/rider-dashboard (Week 11 — full implementation)
//
// PURPOSE:
//   Placeholder screen. The real implementation will show:
//   - Earnings history table (from GET /api/pay/history/:rider_id)
//   - FairDrop vs cliff-bonus comparison chart (using fl_chart package)
//   - Hourly earnings vs minimum wage threshold visualization
//
// PRD FEATURES:
//   - F-DASH-02: FairDrop vs Cliff-Bonus Comparison Chart
// ============================================================================

import 'package:flutter/material.dart';

class RiderDashboardScreen extends StatelessWidget {
  const RiderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Rider Dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Full implementation coming in Week 11',
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
