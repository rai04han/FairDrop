// ============================================================================
// FairDrop — Pay Breakdown Screen (Placeholder)
// ============================================================================
// Owner: Raihan
// Branch: flutter/pay-breakdown (Week 9 — full implementation)
//
// PURPOSE:
//   This is a PLACEHOLDER screen. It shows a "Coming Soon" message.
//   The real implementation (with API call to POST /api/pay/calculate
//   and line-by-line pay breakdown display) will be built on the
//   flutter/pay-breakdown branch during Week 9.
//
// PRD FEATURES:
//   - F-PAY-04: Post-delivery line-by-line breakdown
//   - F-DASH-01: Earnings Breakdown Screen
// ============================================================================

import 'package:flutter/material.dart';

// StatelessWidget because this placeholder has no changing state.
// The real implementation will be a StatefulWidget (it will need to
// call the API and update the UI when the response arrives).
class PayBreakdownScreen extends StatelessWidget {
  // 'const' constructor — Flutter can optimize constant widgets.
  // 'super.key' passes the widget key to the parent class (required boilerplate).
  const PayBreakdownScreen({super.key});

  // build() is called by Flutter to create the visual UI.
  // It returns a Widget tree (nested widgets that describe the screen).
  @override
  Widget build(BuildContext context) {
    // Scaffold = basic screen layout (AppBar on top, body below).
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Breakdown'),
      ),

      // Center widget places its child in the exact center of the screen.
      body: Center(
        child: Column(
          // MainAxisAlignment.center vertically centers the column's children.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A large icon to make the placeholder visually clear
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Pay Breakdown',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Full implementation coming in Week 9',
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
