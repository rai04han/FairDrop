// ============================================================================
// FairDrop — Active Delivery Screen Widget Tests (FR-16 to FR-20, FR-69)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/active_delivery_screen.dart';
import 'package:fairdrop_app/models/order.dart';

void main() {
  group('ActiveDeliveryScreen Widget Tests', () {
    testWidgets('renders 4 delivery steps and order ready indicator (FR-16, FR-69)', (tester) async {
      final readyOrder = Order(
        id: 'active-order-1',
        orderId: 'ORD-20261019-0101',
        customerId: 'cust-1',
        restaurantId: 'rest-1',
        deliveryAddress: OrderAddress(label: 'Pin A, Kollam', latitude: 8.8932, longitude: 76.5950),
        restaurantAddress: OrderAddress(label: 'Hotel Arun, Kollam', latitude: 8.8870, longitude: 76.5900),
        distanceKm: 3.2,
        status: 'assigned',
        isReady: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveDeliveryScreen(
            order: readyOrder,
            autoStartTimer: false,
          ),
        ),
      );

      await tester.pump();

      // Verify Header & Order ID
      expect(find.text('Active Delivery'), findsOneWidget);
      expect(find.text('Order #ORD-20261019-0101'), findsOneWidget);

      // Verify 4 Step Labels
      expect(find.text('1. Heading'), findsOneWidget);
      expect(find.text('2. At Kitchen'), findsOneWidget);
      expect(find.text('3. Out for Delivery'), findsOneWidget);
      expect(find.text('4. Delivered'), findsOneWidget);

      // Verify Order Ready indicator is GREEN and indicates ready (FR-69)
      expect(find.byKey(const Key('order_ready_indicator')), findsOneWidget);
      expect(find.text('ORDER READY FOR PICKUP'), findsOneWidget);

      // Verify Advance Action Button
      expect(find.byKey(const Key('advance_step_button')), findsOneWidget);
      expect(find.text('Confirm Arrived at Restaurant'), findsOneWidget);
    });

    testWidgets('renders cooking indicator when order is not yet ready (FR-69)', (tester) async {
      final cookingOrder = Order(
        id: 'active-order-2',
        orderId: 'ORD-20261019-0102',
        customerId: 'cust-1',
        restaurantId: 'rest-1',
        deliveryAddress: OrderAddress(label: 'Pin A, Kollam', latitude: 8.8932, longitude: 76.5950),
        restaurantAddress: OrderAddress(label: 'Hotel Arun, Kollam', latitude: 8.8870, longitude: 76.5900),
        distanceKm: 2.0,
        status: 'assigned',
        isReady: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveDeliveryScreen(
            order: cookingOrder,
            autoStartTimer: false,
          ),
        ),
      );

      await tester.pump();

      expect(find.byKey(const Key('order_ready_indicator')), findsOneWidget);
      expect(find.text('FOOD PREPARING IN KITCHEN'), findsOneWidget);
    });

    testWidgets('advances to At Kitchen and renders wait timer (FR-18)', (tester) async {
      final order = Order(
        id: 'active-order-3',
        orderId: 'ORD-20261019-0103',
        customerId: 'cust-1',
        restaurantId: 'rest-1',
        deliveryAddress: OrderAddress(label: 'Pin A, Kollam', latitude: 8.8932, longitude: 76.5950),
        restaurantAddress: OrderAddress(label: 'Hotel Arun, Kollam', latitude: 8.8870, longitude: 76.5900),
        distanceKm: 2.5,
        status: 'assigned',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveDeliveryScreen(
            order: order,
            autoStartTimer: false,
          ),
        ),
      );

      await tester.pump();

      // Tap Confirm Arrived at Restaurant
      await tester.ensureVisible(find.byKey(const Key('advance_step_button')));
      await tester.tap(find.byKey(const Key('advance_step_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 300));

      // Now at step 1: At Kitchen
      expect(find.text('Confirm Food Picked Up'), findsOneWidget);
      expect(find.byKey(const Key('wait_timer_card')), findsOneWidget);
      expect(find.textContaining('Restaurant Wait Time'), findsOneWidget);
    });

    testWidgets('supports delay reporting and logs delay context (FR-19)', (tester) async {
      final order = Order(
        id: 'active-order-4',
        orderId: 'ORD-20261019-0104',
        customerId: 'cust-1',
        restaurantId: 'rest-1',
        deliveryAddress: OrderAddress(label: 'Pin A, Kollam', latitude: 8.8932, longitude: 76.5950),
        restaurantAddress: OrderAddress(label: 'Hotel Arun, Kollam', latitude: 8.8870, longitude: 76.5900),
        distanceKm: 3.5,
        status: 'assigned',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveDeliveryScreen(
            order: order,
            autoStartTimer: false,
          ),
        ),
      );

      await tester.pump();

      // Tap Report Delay
      await tester.ensureVisible(find.byKey(const Key('report_delay_button')));
      await tester.tap(find.byKey(const Key('report_delay_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify delay options appear
      expect(find.text('Reason for delay'), findsOneWidget);
      expect(find.byKey(const Key('submit_delay_button')), findsOneWidget);

      // Submit delay
      await tester.ensureVisible(find.byKey(const Key('submit_delay_button')));
      await tester.tap(find.byKey(const Key('submit_delay_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify confirmation
      expect(find.text('Delay Reported (Verified)'), findsOneWidget);
    });

    testWidgets('advancing from Picked Up to Delivered routes to /delivery-summary (FR-20)', (tester) async {
      final deliveredOrder = Order(
        id: 'active-order-5',
        orderId: 'ORD-20261019-0105',
        customerId: 'cust-1',
        restaurantId: 'rest-1',
        deliveryAddress: OrderAddress(label: 'Pin A, Kollam', latitude: 8.8932, longitude: 76.5950),
        restaurantAddress: OrderAddress(label: 'Hotel Arun, Kollam', latitude: 8.8870, longitude: 76.5900),
        distanceKm: 2.0,
        status: 'picked_up',
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/delivery-summary': (context) => const Scaffold(body: Text('Delivery Summary Screen Route')),
          },
          home: ActiveDeliveryScreen(
            order: deliveredOrder,
            autoStartTimer: false,
          ),
        ),
      );

      await tester.pump();

      // Current step is 2: Out for delivery
      expect(find.text('Confirm Delivery to Customer'), findsOneWidget);

      // Tap Confirm Delivery to Customer
      await tester.ensureVisible(find.byKey(const Key('advance_step_button')));
      await tester.tap(find.byKey(const Key('advance_step_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 300));

      // Successfully transitioned to /delivery-summary
      expect(find.text('Delivery Summary Screen Route'), findsOneWidget);
    });
  });
}
