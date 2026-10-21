// ============================================================================
// FairDrop — Order Acceptance Screen Widget Tests (FR-11 to FR-15)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/order_acceptance_screen.dart';
import 'package:fairdrop_app/models/order.dart';

void main() {
  group('OrderAcceptanceScreen Widget Tests', () {
    const testPayConfig = {
      'base_rate': '30.00',
      'per_km_rate': '10.00',
      'surge_bonus': '15.00',
      'wait_threshold_mins': 1,
      'wait_compensation': '2.00',
      'min_wage_per_hour': '75.00',
    };

    testWidgets('renders upfront transparent formula and guaranteed payout (FR-11, FR-12, FR-13)', (tester) async {
      final mockOrder = Order(
        id: 'mock-order-1',
        orderId: 'ORD-20261019-0001',
        customerId: 'cust-1',
        restaurantId: 'rest-1',
        deliveryAddress: OrderAddress(label: 'Pin A, Kollam', latitude: 8.8932, longitude: 76.5950),
        restaurantAddress: OrderAddress(label: 'Hotel Arun, Kollam', latitude: 8.8870, longitude: 76.5900),
        distanceKm: 2.5,
        isSurgeActive: false,
        isOutOfZone: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrderAcceptanceScreen(
            order: mockOrder,
            payConfig: testPayConfig,
            autoStartTimer: false,
          ),
        ),
      );

      await tester.pump();

      // Verify screen title and route summary
      expect(find.text('Order Acceptance'), findsOneWidget);
      expect(find.text('Your pay for this order'), findsOneWidget);
      expect(find.text('Base rate'), findsOneWidget);
      expect(find.text('ESTIMATED PAYOUT'), findsOneWidget);
      expect(find.text('Wage Protection Active'), findsOneWidget);

      // Verify action buttons exist
      expect(find.byKey(const Key('accept_order_button')), findsOneWidget);
      expect(find.byKey(const Key('decline_order_button')), findsOneWidget);

      // In-zone delivery must not show out-of-zone banner or checkbox
      expect(find.text('OUT-OF-ZONE DELIVERY'), findsNothing);
      expect(find.byKey(const Key('out_of_zone_consent_checkbox')), findsNothing);
    });

    testWidgets('displays out-of-zone warning banner and enforces consent checkbox (FR-14)', (tester) async {
      final outOfZoneOrder = Order(
        id: 'mock-order-2',
        orderId: 'ORD-20261019-0002',
        customerId: 'cust-1',
        restaurantId: 'rest-1',
        deliveryAddress: OrderAddress(label: 'Pin B (Polayathode), Kollam', latitude: 8.8750, longitude: 76.6050),
        restaurantAddress: OrderAddress(label: 'Hotel Arun, Kollam', latitude: 8.8870, longitude: 76.5900),
        distanceKm: 4.8,
        isSurgeActive: true,
        isOutOfZone: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrderAcceptanceScreen(
            order: outOfZoneOrder,
            payConfig: testPayConfig,
            autoStartTimer: false,
          ),
        ),
      );

      await tester.pump();

      // Verify out-of-zone warning banner is displayed (FR-14)
      expect(find.text('OUT-OF-ZONE DELIVERY'), findsOneWidget);
      expect(find.text('CONSENT REQ.'), findsOneWidget);

      // Scroll down to action section
      await tester.ensureVisible(find.byKey(const Key('accept_order_button')));
      await tester.pump();

      // Checkbox must be present
      final checkboxFinder = find.byKey(const Key('out_of_zone_consent_checkbox'));
      expect(checkboxFinder, findsOneWidget);

      // Accept button should be disabled before consent is checked
      final acceptButtonFinder = find.byKey(const Key('accept_order_button'));
      var filledButton = tester.widget<FilledButton>(acceptButtonFinder);
      expect(filledButton.onPressed, isNull);

      // Tap consent checkbox
      await tester.tap(checkboxFinder);
      await tester.pump();

      // Accept button should now be enabled
      filledButton = tester.widget<FilledButton>(acceptButtonFinder);
      expect(filledButton.onPressed, isNotNull);
    });

    testWidgets('decline action executes without penalty (FR-15)', (tester) async {
      final mockOrder = Order(
        id: 'mock-order-3',
        orderId: 'ORD-20261019-0003',
        customerId: 'cust-1',
        restaurantId: 'rest-1',
        deliveryAddress: OrderAddress(label: 'Pin A, Kollam', latitude: 8.8932, longitude: 76.5950),
        restaurantAddress: OrderAddress(label: 'Hotel Arun, Kollam', latitude: 8.8870, longitude: 76.5900),
        distanceKm: 1.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/rider-home': (context) => const Scaffold(body: Text('Rider Home Screen')),
          },
          home: OrderAcceptanceScreen(
            order: mockOrder,
            payConfig: testPayConfig,
            autoStartTimer: false,
          ),
        ),
      );

      await tester.pump();

      // Verify Order Acceptance opened
      expect(find.byType(OrderAcceptanceScreen), findsOneWidget);

      // Tap Decline button
      await tester.ensureVisible(find.byKey(const Key('decline_order_button')));
      await tester.tap(find.byKey(const Key('decline_order_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 300));

      // Returned to rider home
      expect(find.text('Rider Home Screen'), findsOneWidget);
    });
  });
}
