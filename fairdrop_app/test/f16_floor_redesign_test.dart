// ============================================================================
// FairDrop — AUDIT-F16 Widget Tests: Floor Top-Up Redesign & Engaged Hours
// Tested at 393px width (iPhone 16 / Pixel 7 mobile baseline)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/pay_breakdown_screen.dart';
import 'package:fairdrop_app/screens/rider_dashboard_screen.dart';
import 'package:fairdrop_app/screens/rider_home_screen.dart';
import 'package:fairdrop_app/models/pay_result.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AUDIT-F16 393px Width Layout & Ledger Tests', () {
    testWidgets('PayBreakdownScreen renders 6 lines and "Floor evaluated after 60 min on orders" at 393px', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockPayResult = PayResult(
        orderId: 'ORD-20261020-0033',
        baseRate: 15.00,
        distancePay: 4.80,
        surgeBonus: 0.00,
        waitCompensation: 10.00,
        totalDeliveryPay: 29.80,
        floorTopup: 0.00,
        hourlyEarningsSoFar: 29.80,
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: RouteSettings(
                arguments: {
                  'order_id': 'ORD-20261020-0033',
                  'distance_km': 0.8,
                  'restaurant_wait_mins': 2,
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

      // Verify no overflow
      expect(tester.takeException(), isNull);

      // Verify 6 ledger lines exist
      expect(find.text('Base Rate'), findsOneWidget);
      expect(find.text('Distance Pay'), findsOneWidget);
      expect(find.text('Surge Bonus'), findsOneWidget);
      expect(find.text('Wait Compensation'), findsOneWidget);
      expect(find.text('Total Delivery Pay'), findsOneWidget);
      expect(find.text('Effective Hourly Rate So Far'), findsOneWidget);

      // Verify floor top-up line is NOT in the delivery ledger
      expect(find.text('Floor Top-Up'), findsNothing);

      // Verify oracle amounts for ORD-20261020-0033
      expect(find.text('₹15.00'), findsOneWidget);
      expect(find.text('₹4.80'), findsOneWidget);
      expect(find.text('₹10.00'), findsOneWidget);
      expect(find.text('₹29.80'), findsWidgets); // Hero card + Total Delivery Pay

      // Verify floor evaluated label
      expect(find.text('Floor evaluated after 60 min on orders'), findsOneWidget);
    });

    testWidgets('RiderDashboardScreen renders 6-line delivery breakdown and "—" when 0 engaged hours at 393px', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sampleEarnings = [
        {
          'order_id': 'ORD-20261020-0033',
          'base_rate': 15.00,
          'distance_pay': 4.80,
          'surge_bonus': 0.00,
          'wait_compensation': 10.00,
          'total_delivery_pay': 29.80,
          'floor_topup': 0.00,
          'hourly_earnings_so_far': 29.80,
          'distance_km': 0.8,
          'is_surge_active': 0,
          'restaurant_wait_mins': 2,
          'created_at': '2026-10-20T10:00:00Z',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: RiderDashboardScreen(
            initialEarnings: sampleEarnings,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no overflow
      expect(tester.takeException(), isNull);

      // Verify 6 itemized rows in expanded tile
      const orderId = 'ORD-20261020-0033';
      expect(find.byKey(const Key('breakdown_base_rate_$orderId')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_distance_pay_$orderId')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_surge_bonus_$orderId')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_wait_compensation_$orderId')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_total_pay_$orderId')), findsOneWidget);
      expect(find.byKey(const Key('breakdown_hourly_rate_$orderId')), findsOneWidget);

      // Floor top-up row must NOT exist in delivery history
      expect(find.byKey(const Key('breakdown_floor_topup_$orderId')), findsNothing);

      // Verify no stray 4.3 hrs
      expect(find.textContaining('4.3 hrs'), findsNothing);
      expect(find.textContaining('4.3h'), findsNothing);
    });

    testWidgets('RiderHomeScreen renders shift card with "—" and floor rule at 393px without overflow', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: RiderHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no overflow
      expect(tester.takeException(), isNull);

      // Verify shift card displays "—" for 0 engaged hours
      expect(find.textContaining("Today's Shift • — active in Kollam"), findsOneWidget);

      // Verify floor evaluation notice
      expect(find.text('Floor evaluated after 60 min on orders'), findsOneWidget);
    });
  });
}
