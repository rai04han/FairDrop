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

  final sampleAnalytics = {
    'success': true,
    'rider_id': 'rider-test',
    'assumptions': {
      'cliff_threshold_deliveries': 10,
      'cliff_base_per_delivery': 20.0,
      'cliff_bonus': 500.0,
      'description':
          'Industry standard cliff-bonus model: ₹20 base pay per delivery with a ₹500 flat bonus upon reaching exactly 10 deliveries. Zero bonus for deliveries 1–9. No distance pay, no wait compensation, no hourly floor.',
    },
    'actual_comparison': {
      'total_deliveries': 2,
      'fairdrop_total': 120.0,
      'cliff_total': 40.0,
      'fairdrop_advantage': 80.0,
      'data_points': [
        {
          'delivery_index': 1,
          'fairdrop_cumulative': 80.0,
          'cliff_cumulative': 20.0,
          'difference': 60.0,
        },
        {
          'delivery_index': 2,
          'fairdrop_cumulative': 120.0,
          'cliff_cumulative': 40.0,
          'difference': 80.0,
        },
      ],
    },
    'cliff_wins_scenario': {
      'scenario_name': 'High-Volume Target-Achieved Shift (10 Deliveries)',
      'description':
          'A rider completes 10 short deliveries (2 km each) within a 4-hour peak window, clearing the cliff threshold.',
      'winner': 'cliff',
      'deliveries_count': 10,
      'fairdrop_total': 280.0,
      'cliff_total': 700.0,
      'cliff_advantage': 420.0,
      'rationale':
          'When a rider clears the 10-delivery quota, the ₹500 bonus elevates cliff earnings to ₹700 vs FairDrop ₹280. However, Fairwork data shows over 80% of shifts fail to reach quota due to fatigue, weather, or order droughts, resulting in severe cliff penalties.',
      'data_points': [
        {'delivery_index': 1, 'fairdrop_cumulative': 27.0, 'cliff_cumulative': 20.0, 'difference': 7.0},
        {'delivery_index': 2, 'fairdrop_cumulative': 54.0, 'cliff_cumulative': 40.0, 'difference': 14.0},
        {'delivery_index': 3, 'fairdrop_cumulative': 81.0, 'cliff_cumulative': 60.0, 'difference': 21.0},
        {'delivery_index': 4, 'fairdrop_cumulative': 108.0, 'cliff_cumulative': 80.0, 'difference': 28.0},
        {'delivery_index': 5, 'fairdrop_cumulative': 135.0, 'cliff_cumulative': 100.0, 'difference': 35.0},
        {'delivery_index': 6, 'fairdrop_cumulative': 162.0, 'cliff_cumulative': 120.0, 'difference': 42.0},
        {'delivery_index': 7, 'fairdrop_cumulative': 189.0, 'cliff_cumulative': 140.0, 'difference': 49.0},
        {'delivery_index': 8, 'fairdrop_cumulative': 216.0, 'cliff_cumulative': 160.0, 'difference': 56.0},
        {'delivery_index': 9, 'fairdrop_cumulative': 243.0, 'cliff_cumulative': 180.0, 'difference': 63.0},
        {'delivery_index': 10, 'fairdrop_cumulative': 280.0, 'cliff_cumulative': 700.0, 'difference': -420.0},
      ],
    },
  };

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

  group('Screen 10: Pay Analytics Screen Widget Tests', () {
    testWidgets('Renders comparative chart and metrics (FR-34)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnalyticsScreen(
            initialAnalytics: sampleAnalytics,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App bar & Header
      expect(find.text('Pay Analytics'), findsOneWidget);
      expect(find.text('Comparative Model Analytics'), findsOneWidget);

      // Metric totals
      expect(find.byKey(const Key('text_fairdrop_total')), findsOneWidget);
      expect(find.text('₹120'), findsOneWidget);
      expect(find.byKey(const Key('text_cliff_total')), findsOneWidget);
      expect(find.text('₹40'), findsOneWidget);

      // Chart container
      expect(find.byKey(const Key('pay_analytics_chart_container')), findsOneWidget);
      expect(find.text('FairDrop (Linear + Floor)'), findsOneWidget);
      expect(find.text('Cliff Model (Quota Trap)'), findsOneWidget);
    });

    testWidgets('Renders stated cliff model assumptions on screen (FR-35)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnalyticsScreen(
            initialAnalytics: sampleAnalytics,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Stated assumptions card exists
      final assumptionsCard = find.byKey(const Key('cliff_assumptions_card'));
      expect(assumptionsCard, findsOneWidget);

      expect(find.text('Stated Cliff Model Assumptions'), findsOneWidget);
      expect(find.text('10 deliveries'), findsOneWidget);
      expect(find.text('₹20.0 / delivery'), findsOneWidget);
      expect(find.text('₹500.0 flat'), findsOneWidget);
      expect(find.text('₹0.00 / km'), findsOneWidget);
      expect(find.text('₹0.00 / min'), findsOneWidget);
      expect(find.text('None (₹0/hr)'), findsOneWidget);
      expect(find.textContaining('Industry standard cliff-bonus model: ₹20 base pay'), findsOneWidget);
    });

    testWidgets('Renders Cliff-Wins Scenario with balanced framing and chart toggle (FR-36)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnalyticsScreen(
            initialAnalytics: sampleAnalytics,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cliff-wins scenario card exists
      final cliffWinsCard = find.byKey(const Key('cliff_wins_card'));
      expect(cliffWinsCard, findsOneWidget);

      // Scenario title and outcome
      expect(find.textContaining('BALANCED FRAMING: CLIFF WINS (+₹420)'), findsOneWidget);
      expect(find.text('High-Volume Target-Achieved Shift (10 Deliveries)'), findsOneWidget);
      expect(find.text('₹700'), findsOneWidget); // Cliff total in scenario
      expect(find.text('₹280'), findsOneWidget); // FairDrop total in scenario
      expect(find.text('+₹420'), findsOneWidget); // Cliff advantage

      // Balanced framing rationale citing Fairwork Kerala data
      expect(find.textContaining('Fairwork data shows over 80% of shifts fail to reach quota'), findsOneWidget);

      // Toggle to Cliff-Wins Scenario on chart
      final visualizeBtn = find.byKey(const Key('btn_visualize_scenario'));
      expect(visualizeBtn, findsOneWidget);

      await tester.ensureVisible(visualizeBtn);
      await tester.pumpAndSettle();
      await tester.tap(visualizeBtn);
      await tester.pumpAndSettle();

      // Metric cards now reflect the scenario values (FairDrop ₹280 vs Cliff ₹700)
      expect(find.text('₹280'), findsWidgets);
      expect(find.text('₹700'), findsWidgets);
      expect(find.text('Scenario Model Trajectory'), findsOneWidget);
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
                'fairdrop_advantage': 0.0,
                'data_points': [],
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
      expect(find.text('No cumulative points available yet.'), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
    });
  });
}
