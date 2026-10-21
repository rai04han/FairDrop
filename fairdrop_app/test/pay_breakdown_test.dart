// ============================================================================
// FairDrop — Delivery Summary & Pay Breakdown Widget Tests (FR-21 to FR-25)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/pay_breakdown_screen.dart';
import 'package:fairdrop_app/models/pay_result.dart';

void main() {
  group('PayBreakdownScreen Widget Tests', () {
    testWidgets('renders all 7 itemized lines and zero-line explanations (FR-21, FR-22)', (tester) async {
      final mockPayResult = PayResult(
        orderId: 'ORD-20261019-0001',
        baseRate: 15.00,
        distancePay: 7.50,
        surgeBonus: 0.00,
        waitCompensation: 10.00,
        totalDeliveryPay: 32.50,
        floorTopup: 0.00,
        hourlyEarningsSoFar: 65.00,
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: RouteSettings(
                arguments: {
                  'order_id': 'ORD-20261019-0001',
                  'distance_km': 1.25,
                  'restaurant_wait_mins': 3,
                  'is_surge_active': false,
                  'pay_result': mockPayResult.toJson(),
                },
              ),
              builder: (context) => const PayBreakdownScreen(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Verify Screen renders
      expect(find.byType(PayBreakdownScreen), findsOneWidget);

      // Verify 6 Line Items (AUDIT-F16)
      expect(find.text('Base Rate'), findsOneWidget);
      expect(find.text('Distance Pay'), findsOneWidget);
      expect(find.text('Surge Bonus'), findsOneWidget);
      expect(find.text('Wait Compensation'), findsOneWidget);
      expect(find.text('Total Delivery Pay'), findsOneWidget);
      expect(find.text('Effective Hourly Rate So Far'), findsOneWidget);
      expect(find.text('Floor Top-Up'), findsNothing);

      // Verify amounts and zero lines with reasons (FR-22 / AUDIT-F16)
      expect(find.text('₹15.00'), findsOneWidget);
      expect(find.text('₹7.50'), findsOneWidget);
      expect(find.text('No surge active in zone'), findsOneWidget);
      expect(find.text('Floor evaluated after 60 min on orders'), findsOneWidget);
      expect(find.text('₹32.50'), findsWidgets);
      expect(find.text('₹65.00/hr'), findsOneWidget);
    });

    testWidgets('renders delay verification badge (FR-25)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: const RouteSettings(
                arguments: {
                  'order_id': 'ORD-20261019-0002',
                  'distance_km': 2.0,
                  'restaurant_wait_mins': 4,
                  'delay_context': {
                    'type': 'restaurant',
                    'verified': true,
                    'source': 'system_log',
                  },
                },
              ),
              builder: (context) => const PayBreakdownScreen(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Restaurant delay verified by system log'), findsOneWidget);
    });

    testWidgets('renders pending state and retry button when payStatus is pending (FR-24)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: const RouteSettings(
                arguments: {
                  'order_id': 'ORD-20261019-0003',
                  'pay_status': 'pending',
                },
              ),
              builder: (context) => const PayBreakdownScreen(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pay Calculation Pending'), findsOneWidget);
      expect(find.text('Retry Pay Calculation (FR-24)'), findsOneWidget);
    });

    testWidgets('renders out-of-zone banner when order is out-of-zone (FR-73)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: const RouteSettings(
                arguments: {
                  'order_id': 'ORD-20261019-0004',
                  'is_out_of_zone': true,
                },
              ),
              builder: (context) => const PayBreakdownScreen(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Out-of-Zone Delivery Transition (FR-73)'), findsOneWidget);
    });

    testWidgets('renders empty state "No completed deliveries yet" when launched without arguments (F26 / R21)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PayBreakdownScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No completed deliveries yet'), findsOneWidget);
      expect(find.text('ORD-20261019-0001'), findsNothing);
      expect(find.text('CACHED'), findsNothing);
    });
  });
}
