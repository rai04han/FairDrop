// ============================================================================
// FairDrop — Customer Order History Screen Widget Tests (Screen 22, FR-61)
// ============================================================================
// PRD Feature: FR-61 (Order History with pull-to-refresh)
// Demo Step 12: Customer verifies order history shows past orders & deliveries.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/customer/customer_order_history_screen.dart';
import 'package:fairdrop_app/screens/customer_shell_screen.dart';

void main() {
  group('CustomerOrderHistoryScreen Widget Tests (Screen 22, FR-61)', () {
    final mockOrders = [
      {
        'order_id': 'ORD-KL02-9901',
        'status': 'delivered',
        'created_at': '2026-10-20T08:30:00Z',
        'restaurant_name': 'Grand Malabar Kitchen',
        'delivery_address': {'label': 'Chinnakkada Round, Kollam'},
        'distance_km': 3.4,
        'items': [
          {'name': 'Malabar Chicken Biryani', 'quantity': 2, 'price': 180.0},
          {'name': 'Lime Mint Juice', 'quantity': 1, 'price': 40.0},
        ],
        'delivery_fee': 42.0,
        'total_amount': 442.0,
      },
      {
        'order_id': 'ORD-KL02-9902',
        'status': 'placed',
        'created_at': '2026-10-20T09:15:00Z',
        'restaurant_name': 'Supreme Bakers',
        'delivery_address': {'label': 'Asramam Ground, Kollam'},
        'distance_km': 1.8,
        'items': [
          {'name': 'Plum Cake 500g', 'quantity': 1, 'price': 220.0},
        ],
        'delivery_fee': 28.0,
        'total_amount': 248.0,
      },
    ];

    // ── Test 1: Empty state rendering ───────────────────────────────────────
    testWidgets('Renders empty state when customer has no previous orders', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerOrderHistoryScreen(
            initialOrders: [],
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Orders'), findsOneWidget);
      expect(find.text('No orders placed yet'), findsOneWidget);
      expect(find.text('Discover local Kollam partners and order with transparent pay.'), findsOneWidget);
      expect(find.byKey(const Key('customer_order_history_refresh_indicator')), findsOneWidget);
    });

    // ── Test 2: Order cards rendering ───────────────────────────────────────
    testWidgets('Renders past orders with status badges, items and transparent totals (FR-61)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOrderHistoryScreen(
            initialOrders: mockOrders,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Order 1 details
      expect(find.text('ORD-KL02-9901'), findsOneWidget);
      expect(find.text('DELIVERED'), findsOneWidget);
      expect(find.text('Grand Malabar Kitchen'), findsOneWidget);
      expect(find.text('Chinnakkada Round, Kollam'), findsOneWidget);
      expect(find.text('(3.4 km)'), findsOneWidget);
      expect(find.text('Malabar Chicken Biryani'), findsOneWidget);
      expect(find.text('2x '), findsOneWidget);
      expect(find.text('Delivery Fee: ₹42.00'), findsOneWidget);
      expect(find.text('Total: ₹442.00'), findsOneWidget);

      // Check Order 2 details
      expect(find.text('ORD-KL02-9902'), findsOneWidget);
      expect(find.text('PLACED'), findsOneWidget);
      expect(find.text('Supreme Bakers'), findsOneWidget);
      expect(find.text('Asramam Ground, Kollam'), findsOneWidget);
      expect(find.text('(1.8 km)'), findsOneWidget);
      expect(find.text('Total: ₹248.00'), findsOneWidget);
    });

    // ── Test 3: Fetch callback and Refresh action ───────────────────────────
    testWidgets('Triggers fetch callback and re-renders list on refresh', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int fetchCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOrderHistoryScreen(
            autoFetch: true,
            onFetchOrders: () async {
              fetchCount++;
              return mockOrders;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fetchCount, 1);
      expect(find.text('ORD-KL02-9901'), findsOneWidget);

      // Tap appbar refresh button
      await tester.tap(find.byKey(const Key('customer_order_history_refresh_button')));
      await tester.pumpAndSettle();

      expect(fetchCount, 2);
    });

    // ── Test 4: Error handling and retry ────────────────────────────────────
    testWidgets('Displays error banner on fetch failure and retries successfully', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool shouldFail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOrderHistoryScreen(
            autoFetch: true,
            onFetchOrders: () async {
              if (shouldFail) {
                throw Exception('Network unreachable');
              }
              return mockOrders;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load order history: Exception: Network unreachable'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Retry
      shouldFail = false;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('ORD-KL02-9901'), findsOneWidget);
    });

    // ── Test 5: Navigation from CustomerShellScreen ─────────────────────────
    testWidgets('Customer shell navigates to /customer/history on order history card tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool navigatedToHistory = false;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => const CustomerShellScreen(),
            '/customer/history': (context) {
              navigatedToHistory = true;
              return const Scaffold(body: Text('Customer Order History Screen Mock'));
            },
          },
        ),
      );
      await tester.pumpAndSettle();

      final historyCardFinder = find.byKey(const Key('customer_order_history_button'));
      expect(historyCardFinder, findsOneWidget);

      await tester.ensureVisible(historyCardFinder);
      await tester.tap(historyCardFinder);
      await tester.pumpAndSettle();

      expect(navigatedToHistory, isTrue);
      expect(find.text('Customer Order History Screen Mock'), findsOneWidget);
    });
  });
}
