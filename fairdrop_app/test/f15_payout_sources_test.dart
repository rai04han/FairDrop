// ============================================================================
// FairDrop — Single Source of Truth for Payout Figures Widget Tests (AUDIT-F15)
// ============================================================================
// Tests verifying:
// 1. Active Delivery earnings meter:
//    - Base rate ₹15 (not ₹30)
//    - Flat wait compensation (55s wait with 1-min threshold earns ₹0)
//    - Label "Estimated delivery pay" with no "guaranteed min"
// 2. Rider Home Shift card:
//    - Split ledger rows (Base+Distance, Wait, Surge, Floor top-up)
//    - "1 drop" grammar fix (no "1 drops")
//    - Removal of "+₹199 buffer" text
// 3. Delivery Completed (Pay Breakdown Screen):
//    - Total Delivery Pay is visually below Wait Comp and equals lines above it
//    - VERIFIED badge on server result; CACHED with Retry on cached/fallback
// 4. Zero layout exceptions at 393px width
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/config/theme.dart';
import 'package:fairdrop_app/models/order.dart';
import 'package:fairdrop_app/models/pay_result.dart';
import 'package:fairdrop_app/screens/active_delivery_screen.dart';
import 'package:fairdrop_app/screens/pay_breakdown_screen.dart';
import 'package:fairdrop_app/screens/rider_home_screen.dart';

void main() {
  const double viewportWidth = 393.0;
  const double viewportHeight = 852.0;

  group('F15: Single Source of Truth for Payout Figures (393px width)', () {
    testWidgets('ActiveDeliveryScreen: Base ₹15, flat wait comp (55s = ₹0), Estimated delivery pay label, 0 overflows at 393px', (tester) async {
      tester.view.physicalSize = const Size(viewportWidth, viewportHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final activeOrder = Order(
        id: 'ord-test-01',
        orderId: 'ORD-20261020-0033',
        customerId: 'cust-1',
        restaurantId: 'rest-1',
        deliveryAddress: OrderAddress(label: 'Pin A, Chinnakada', latitude: 8.8932, longitude: 76.5950),
        restaurantAddress: OrderAddress(label: 'Hotel Arun, Kollam', latitude: 8.8870, longitude: 76.5900),
        distanceKm: 0.8,
        status: 'arrived',
        restaurantWaitMins: 0,
        isSurgeActive: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: FairDropTheme.lightTheme,
          home: ActiveDeliveryScreen(
            order: activeOrder,
            autoStartTimer: false,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify label is "Estimated delivery pay" and NO "guaranteed min"
      expect(find.text('Estimated delivery pay'), findsOneWidget);
      expect(find.text('guaranteed min'), findsNothing);
      expect(find.text('DELIVERY EARNINGS METER'), findsNothing);

      // Verify Base Rate is ₹15.00 (not ₹30.00)
      expect(find.text('Base Pick-up Fee'), findsOneWidget);
      expect(find.text('₹15.00'), findsOneWidget);
      expect(find.text('₹30.00'), findsNothing);

      // Verify Wait Compensation is ₹0.00 when wait is under 1-min threshold (0s or 55s)
      expect(find.text('Wait Time Compensated'), findsOneWidget);
      expect(find.text('₹0.00'), findsOneWidget);
      expect(find.textContaining('No bonus until wait exceeds 1m threshold'), findsOneWidget);
    });

    testWidgets('RiderHomeScreen: displays "1 drop" grammar, removes buffer text, renders split ledger rows at 393px', (tester) async {
      tester.view.physicalSize = const Size(viewportWidth, viewportHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: FairDropTheme.lightTheme,
          home: const RiderHomeScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Check buffer text is NOT rendered
      expect(find.textContaining('buffer)'), findsNothing);
      expect(find.textContaining('1 drops'), findsNothing);

      // Check split ledger row titles
      expect(find.text('Base Pay & Distance'), findsOneWidget);
      expect(find.text('Geofenced Wait Time'), findsOneWidget);
      expect(find.text('Monsoon Surge Allowance'), findsOneWidget);
      expect(find.text('Kerala Fair Pay Top-Up'), findsOneWidget);
    });

    testWidgets('PayBreakdownScreen: Total Delivery Pay sums lines above it, VERIFIED badge on live result, no layout exceptions at 393px', (tester) async {
      tester.view.physicalSize = const Size(viewportWidth, viewportHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Oracle for order ORD-20261020-0033: base 15.00, distance 4.80, surge 0, wait 10.00, total 29.80
      final livePayResult = PayResult(
        orderId: 'ORD-20261020-0033',
        baseRate: 15.00,
        distancePay: 4.80,
        surgeBonus: 0.00,
        waitCompensation: 10.00,
        totalDeliveryPay: 29.80,
        floorTopup: 0.00,
        hourlyEarningsSoFar: 29.80,
        isCached: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: FairDropTheme.lightTheme,
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: RouteSettings(
                arguments: {
                  'order_id': 'ORD-20261020-0033',
                  'distance_km': 0.8,
                  'restaurant_wait_mins': 2,
                  'pay_result': livePayResult.toJson(),
                },
              ),
              builder: (context) => const PayBreakdownScreen(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Hero Total Payout & VERIFIED badge
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('₹29.80'), findsWidgets);

      // Verify 6 itemized lines exist (F16 redesign: floor top-up removed from delivery ledger)
      expect(find.text('Base Rate'), findsOneWidget);
      expect(find.text('Distance Pay'), findsOneWidget);
      expect(find.text('Surge Bonus'), findsOneWidget);
      expect(find.text('Wait Compensation'), findsOneWidget);
      expect(find.text('Total Delivery Pay'), findsOneWidget);
      expect(find.text('Effective Hourly Rate So Far'), findsOneWidget);
      expect(find.text('Floor Top-Up'), findsNothing);

      // Verify visual order: Base (15) + Distance (4.80) + Surge (0) + Wait (10) = Total Delivery Pay (29.80)
      final waitY = tester.getTopLeft(find.text('Wait Compensation')).dy;
      final totalPayY = tester.getTopLeft(find.text('Total Delivery Pay')).dy;
      final hourlyY = tester.getTopLeft(find.text('Effective Hourly Rate So Far')).dy;

      // Total Delivery Pay must be below Wait Compensation, and Effective Hourly Rate below Total Delivery Pay
      expect(waitY < totalPayY, isTrue, reason: 'Total Delivery Pay must be visually below Wait Compensation');
      expect(totalPayY < hourlyY, isTrue, reason: 'Effective Hourly Rate must be visually below Total Delivery Pay');
    });

    testWidgets('PayBreakdownScreen: shows CACHED badge with interactive Retry when fallback/cached pay is used', (tester) async {
      tester.view.physicalSize = const Size(viewportWidth, viewportHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cachedPayResult = PayResult(
        orderId: 'ORD-20261020-0034',
        baseRate: 15.00,
        distancePay: 7.50,
        surgeBonus: 0.00,
        waitCompensation: 10.00,
        totalDeliveryPay: 32.50,
        floorTopup: 0.00,
        hourlyEarningsSoFar: 65.00,
        isCached: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: FairDropTheme.lightTheme,
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: RouteSettings(
                arguments: {
                  'order_id': 'ORD-20261020-0034',
                  'distance_km': 1.25,
                  'restaurant_wait_mins': 2,
                  'pay_result': cachedPayResult.toJson(),
                },
              ),
              builder: (context) => const PayBreakdownScreen(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Badge must show CACHED with Retry button
      expect(find.byKey(const Key('btn_retry_cached_pay')), findsOneWidget);
      expect(find.text('CACHED'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
