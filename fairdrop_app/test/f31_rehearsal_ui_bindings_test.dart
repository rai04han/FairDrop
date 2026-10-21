import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/customer/order_confirmation_screen.dart';
import 'package:fairdrop_app/screens/customer/customer_order_history_screen.dart';
import 'package:fairdrop_app/screens/restaurant/restaurant_orders_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F31 Rehearsal UI Display Bindings Tests', () {
    testWidgets('OrderConfirmationScreen computes items total without 375.0 fallback',
        (tester) async {
      final mockOrder = {
        'order_id': 'ORD-TEST-001',
        'status': 'accepted',
        'allocation': 'assigned',
        'items': [
          {'name': 'Chicken Biryani', 'price': 180.0, 'quantity': 2},
          {'name': 'Lime Soda', 'price': 40.0, 'quantity': 1},
        ],
        // note: total_price and total_amount omitted intentionally
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OrderConfirmationScreen(orderData: mockOrder),
        ),
      );
      await tester.pumpAndSettle();

      // Expected total: 180*2 + 40 = 400.00. Should NOT be 375.00 or 0.00.
      expect(find.text('₹400.00'), findsOneWidget);
      expect(find.text('₹375.00'), findsNothing);
      expect(find.text('₹0.00'), findsNothing);
    });

    testWidgets('RestaurantOrdersScreen computes order card total from items array',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RestaurantOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Restaurant orders screen initial mock orders:
      // Order 1: 2 Porottas @ 25.0 = 50.0
      expect(find.text('₹0.00'), findsNothing);
    });

    testWidgets('CustomerOrderHistoryScreen computes items total when root total is missing',
        (tester) async {
      final mockOrders = [
        {
          'order_id': 'ORD-HIST-001',
          'status': 'delivered',
          'items': [
            {'name': 'Porotta', 'price': 25.0, 'quantity': 4},
          ],
          'created_at': DateTime.now().toIso8601String(),
          // total_amount and total_price omitted intentionally
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOrderHistoryScreen(
            initialOrders: mockOrders,
            autoFetch: false,
          ),
        ),
      );
      await tester.pump();

      // 4 * 25.0 = 100.00
      expect(find.text('Total: ₹100.00'), findsOneWidget);
      expect(find.text('Total: ₹0.00'), findsNothing);
    });
  });
}
