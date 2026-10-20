// ============================================================================
// FairDrop — Analytics & Dashboard Widget Tests (Screens 9 & 10)
// ============================================================================
// PRD Features: FR-30, FR-31, FR-32, FR-33, FR-34, FR-35, FR-36
// Demo Step 10: Rider opens dashboard & analytics, checks floor, 7-line ledger,
//               cliff model assumptions, and balanced cliff-wins scenario.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/rider_dashboard_screen.dart';
import 'package:fairdrop_app/screens/analytics_screen.dart';

void main() {
  final sampleEarnings = [
    {
      'order_id': 'ORD-KLM-TEST-1',
      'base_rate': 20.00,
      'distance_pay': 30.00,
      'surge_bonus': 10.00,
      'wait_compensation': 15.00,
      'total_delivery_pay': 75.00,
      'floor_topup': 5.00,
      'hourly_earnings_so_far': 80.00,
      'distance_km': 3.0,
      'is_surge_active': 1,
      'restaurant_wait_mins': 10,
      'created_at': '2026-10-20T10:00:00Z',
    },
    {
      'order_id': 'ORD-KLM-TEST-2',
      'base_rate': 20.00,
      'distance_pay': 20.00,
      'surge_bonus': 0.00,
      'wait_compensation': 0.00,
      'total_delivery_pay': 40.00,
      'floor_topup': 0.00,
      'hourly_earnings_so_far': 75.00,
      'distance_km': 2.0,
      'is_surge_active': 0,
      'restaurant_wait_mins': 2,
      'created_at': '2026-10-20T11:00:00Z',
    },
  ];

  group('Screen 9: Rider Dashboard Widget Tests', () {
    testWidgets('Renders summary statistics and statutory floor banner (FR-30, FR-32)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RiderDashboardScreen(
            initialEarnings: sampleEarnings,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title
      expect(find.text('Rider Dashboard'), findsOneWidget);

      // Summary Cards (Total Earned = 80 + 40 = 120.00)
      expect(find.byKey(const Key('summary_total_earned')), findsOneWidget);
      expect(find.text('₹120.00'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Deliveries Today
      expect(find.byKey(const Key('summary_floor_topups')), findsOneWidget);

      // Statutory floor banner (FR-32)
      expect(find.byKey(const Key('statutory_floor_status_banner')), findsOneWidget);
      expect(find.text('Statutory Floor Guarantee: Protected'), findsOneWidget);
      expect(find.text('COMPLIANT'), findsOneWidget);

      // Pull to refresh indicator (FR-33)
      expect(find.byKey(const Key('rider_dashboard_refresh_indicator')), findsOneWidget);
    });

    testWidgets('Expandable per-delivery row reveals full 7-itemized ledger breakdown (FR-31)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RiderDashboardScreen(
            initialEarnings: sampleEarnings,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      const order1 = 'ORD-KLM-TEST-1';
      final order1Tile = find.byKey(const Key('delivery_tile_$order1'));
      expect(order1Tile, findsOneWidget);

      // Order 1 is expanded by default (or tap header to ensure expanded)
      // Verify all 7 itemized breakdown rows exist for Order 1:
      expect(find.byKey(const Key('breakdown_base_rate_$order1')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_distance_pay_$order1')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_surge_bonus_$order1')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_wait_compensation_$order1')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_floor_topup_$order1')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_total_pay_$order1')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_hourly_rate_$order1')), findsOneWidget);

      // Verify values for order 1
      expect(find.text('₹20.00'), findsWidgets); // Base pay
      expect(find.text('₹30.00'), findsOneWidget); // Distance pay
      expect(find.text('₹10.00'), findsOneWidget); // Surge bonus
      expect(find.text('₹15.00'), findsOneWidget); // Wait pay
      expect(find.text('₹5.00'), findsWidgets);   // Floor topup
      expect(find.text('₹80.00'), findsWidgets);  // Total payout & hourly

      // Order 2 is initially collapsed; ensure visible and tap to expand it
      const order2 = 'ORD-KLM-TEST-2';
      expect(find.byKey(const Key('breakdown_base_rate_$order2')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('delivery_header_$order2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delivery_header_$order2')));
      await tester.pumpAndSettle();

      // Now Order 2's 7 breakdown rows should be visible
      expect(find.byKey(const Key('breakdown_base_rate_$order2')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_distance_pay_$order2')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_total_pay_$order2')), findsOneWidget);
    });

    testWidgets('Dashboard provides direct navigation bridge to AnalyticsScreen (FR-34)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/analytics': (context) => const Scaffold(body: Text('Analytics Screen Target')),
          },
          home: RiderDashboardScreen(
            initialEarnings: sampleEarnings,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check card and button exist
      expect(find.byKey(const Key('card_pay_analytics')), findsOneWidget);
      final openAnalyticsBtn = find.byKey(const Key('btn_open_analytics'));
      expect(openAnalyticsBtn, findsOneWidget);

      // Tap button and verify navigation
      await tester.tap(openAnalyticsBtn);
      await tester.pumpAndSettle();

      expect(find.text('Analytics Screen Target'), findsOneWidget);
    });

    testWidgets('Error state renders Retry button and NO mock numbers on network failure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RiderDashboardScreen(
            initialErrorMessage: 'Unable to load dashboard earnings. Please check your connection and try again.',
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify error view and Retry button
      expect(find.byKey(const Key('dashboard_error_view')), findsOneWidget);
      expect(find.byKey(const Key('btn_retry_dashboard')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Verify NO fabricated mock numbers
      expect(find.text('ORD-KLM-9021'), findsNothing);
      expect(find.text('₹120.00'), findsNothing);
      expect(find.text('₹82.00'), findsNothing);
    });

    testWidgets('Empty state with 0 deliveries renders clean zeros without NaN or Infinity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RiderDashboardScreen(
            initialEarnings: [],
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify clean zeros
      expect(find.byKey(const Key('summary_total_earned')), findsOneWidget);
      expect(find.text('₹0.00'), findsWidgets);
      expect(find.text('0'), findsWidgets);
      expect(find.text('₹0.0/hr'), findsOneWidget);
      expect(find.text('No completed deliveries yet today.'), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
    });
  });

  group('Screen 10: Pay Analytics Screen Widget Tests (F13 / R6)', () {
    testWidgets('Renders scope notice, comparative chart, and benchmark metrics (FR-34)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App bar & Header
      expect(find.text('Pay Analytics'), findsOneWidget);
      expect(find.text('Comparative Model Analytics'), findsOneWidget);

      // Scope Notice Banner (FR-34)
      expect(
        find.textContaining(
          'Base, distance, monsoon, and return pay are identical on both platforms; this analysis compares daily incentives only.',
        ),
        findsOneWidget,
      );

      // Metric totals and equal pay indicator
      expect(find.byKey(const Key('text_fairdrop_total')), findsOneWidget);
      expect(find.byKey(const Key('text_cliff_total')), findsOneWidget);
      expect(find.textContaining('Equal pay at 27 orders'), findsWidgets);

      // Chart container and legend pills (FR-34, FR-36)
      expect(find.byKey(const Key('pay_analytics_chart_container')), findsOneWidget);
      expect(find.text('FairDrop (With Peak)'), findsOneWidget);
      expect(find.text('FairDrop (Without Peak)'), findsOneWidget);
      expect(find.text('Zomato Ladder (Illustrative Example)'), findsOneWidget);
    });

    testWidgets('Renders stated model parameters, peak toggle, and parity table (FR-35, FR-36)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Peak toggle card and interactive toggle
      final peakToggle = find.byKey(const Key('switch_peak_windows'));
      expect(peakToggle, findsOneWidget);
      expect(find.text('Peak Windows Covered'), findsOneWidget);

      // Stated assumptions card exists (FR-35)
      final assumptionsCard = find.byKey(const Key('cliff_assumptions_card'));
      expect(assumptionsCard, findsOneWidget);
      expect(find.text('Stated Model Parameters & Assumptions'), findsOneWidget);
      expect(find.text('₹17.04 / order'), findsOneWidget);
      expect(find.text('₹25 × 2 = ₹50'), findsOneWidget);
      expect(find.text('27 orders (₹510)'), findsOneWidget);

      // Parity table exists with exact tiers: With peak (16, 20, 23, 27), Without peak (18, 23, 26, 30) (FR-36)
      final parityTable = find.byKey(const Key('parity_table_card'));
      expect(parityTable, findsOneWidget);
      expect(find.text('16 orders'), findsOneWidget);
      expect(find.text('20 orders'), findsOneWidget);
      expect(find.text('23 orders'), findsWidgets); // Appears in Zomato and FairDrop columns
      expect(find.text('27 orders'), findsWidgets); // Appears in Zomato and FairDrop columns
      expect(find.text('18 orders'), findsOneWidget);
      expect(find.text('26 orders'), findsOneWidget);
      expect(find.text('30 orders'), findsOneWidget);

      // Toggle peak windows off and verify bonus description updates
      await tester.tap(peakToggle);
      await tester.pumpAndSettle();
      expect(find.text('Linear rate only (₹0 peak bonus applied)'), findsOneWidget);
    });

    testWidgets('Renders policy notes and transparency criteria (FR-36)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Policy notes card (FR-36)
      final policyCard = find.byKey(const Key('policy_notes_card'));
      expect(policyCard, findsOneWidget);
      expect(find.text('Policy Notes & Transparency Criteria'), findsOneWidget);
      expect(
        find.textContaining('Peak bonus assumes the rider is online in both designated windows'),
        findsOneWidget,
      );
      expect(
        find.textContaining('The incentive rate varies by day based on market conditions'),
        findsOneWidget,
      );
      expect(
        find.textContaining("The platform's break-even rate = expected Zomato incentive spend ÷ expected orders per rider"),
        findsOneWidget,
      );

      // No unsourced cliff wins claim or quota trap wording
      expect(find.textContaining('over 80% of shifts fail quota'), findsNothing);
      expect(find.textContaining('CLIFF WINS'), findsNothing);
    });

    testWidgets('Error state renders Retry button and NO mock numbers on network failure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(
            initialErrorMessage: 'Unable to load analytics. Please check your connection and try again.',
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify error view and Retry button
      expect(find.byKey(const Key('analytics_error_view')), findsOneWidget);
      expect(find.byKey(const Key('btn_retry_analytics')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Verify NO fabricated mock numbers
      expect(find.text('rider-demo'), findsNothing);
      expect(find.text('₹545'), findsNothing);
      expect(find.text('₹140'), findsNothing);
    });

    testWidgets('Empty state with 0 deliveries renders clean zeros without NaN or Infinity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(
            initialAnalytics: {
              'success': true,
              'actual_comparison': {
                'total_deliveries': 0,
                'fairdrop_total': 0.0,
                'cliff_total': 0.0,
              },
            },
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify zero metrics
      expect(find.byKey(const Key('text_fairdrop_total')), findsOneWidget);
      expect(find.text('₹0'), findsWidgets);
      expect(find.text('Over 0 deliveries'), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
    });
  });
}
