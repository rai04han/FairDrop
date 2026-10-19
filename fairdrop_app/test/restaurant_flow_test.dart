// ============================================================================
// FairDrop — Restaurant Flow Widget Tests (Screens 17 to 19, FR-62 to FR-66)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/restaurant_shell_screen.dart';
import 'package:fairdrop_app/screens/restaurant/menu_management_screen.dart';
import 'package:fairdrop_app/screens/restaurant/add_edit_menu_item_screen.dart';
import 'package:fairdrop_app/screens/restaurant/restaurant_orders_screen.dart';
import 'package:fairdrop_app/models/menu_item.dart';

void main() {
  group('Restaurant Portal Widget Tests (Screens 17 to 19)', () {
    // ── Restaurant Shell Navigation ─────────────────────────────────────────
    testWidgets('RestaurantShellScreen renders partner cards and routes correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/restaurant/menu': (context) => const Scaffold(body: Text('Menu Route Target')),
            '/restaurant/orders': (context) => const Scaffold(body: Text('Orders Route Target')),
          },
          home: const RestaurantShellScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Partner Kitchen • Menu & Orders Portal'), findsOneWidget);
      expect(find.byKey(const Key('restaurant_menu_management_card')), findsOneWidget);
      expect(find.byKey(const Key('restaurant_incoming_orders_card')), findsOneWidget);

      // Tap Menu Management Card
      await tester.tap(find.byKey(const Key('restaurant_menu_management_card')));
      await tester.pumpAndSettle();
      expect(find.text('Menu Route Target'), findsOneWidget);
    });

    // ── Screen 17: Menu Management (FR-62, FR-64, Demo Step 2) ──────────────
    testWidgets('Screen 17: MenuManagementScreen lists items and toggles availability (FR-62, FR-64, Step 2)', (tester) async {
      final testItems = [
        MenuItem(
          id: 'item-1',
          restaurantId: 'rest-arun',
          name: 'Kerala Porotta',
          price: 25.0,
          prepTimeSeconds: 600,
          isAvailable: true,
        ),
        MenuItem(
          id: 'item-2',
          restaurantId: 'rest-arun',
          name: 'Nadan Chicken Curry',
          price: 180.0,
          prepTimeSeconds: 900,
          isAvailable: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MenuManagementScreen(initialItems: testItems),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & item list
      expect(find.text('Menu Management'), findsOneWidget);
      expect(find.text('Kerala Porotta'), findsOneWidget);
      expect(find.text('Nadan Chicken Curry'), findsOneWidget);
      expect(find.text('₹25.00'), findsOneWidget);
      expect(find.text('₹180.00'), findsOneWidget);

      // Verify availability switch exists for Kerala Porotta
      final switchFinder = find.byKey(const Key('availability_switch_kerala_porotta'));
      expect(switchFinder, findsOneWidget);

      // Toggle Kerala Porotta availability off (Demo Step 2: "switches availability off")
      await tester.tap(switchFinder);
      await tester.pump();

      // SnackBar feedback appears
      expect(find.textContaining('is now UNAVAILABLE'), findsOneWidget);

      // Settle network timeout and SnackBar timers
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    // ── Screen 18: Add / Edit Menu Item (FR-63, Demo Step 2) ────────────────
    testWidgets('Screen 18: AddEditMenuItemScreen validates inputs and creates item (FR-63)', (tester) async {
      MenuItem? returnedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open_add_screen'),
                onPressed: () async {
                  returnedItem = await Navigator.push<MenuItem>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEditMenuItemScreen()),
                  );
                },
                child: const Text('Open Add Screen'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open screen
      await tester.tap(find.byKey(const Key('open_add_screen')));
      await tester.pumpAndSettle();

      expect(find.text('Add New Menu Item'), findsOneWidget);

      // 1. Submit empty form to verify validation
      await tester.ensureVisible(find.byKey(const Key('save_menu_item_button')));
      await tester.tap(find.byKey(const Key('save_menu_item_button')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter the dish name'), findsOneWidget);
      expect(find.text('Please enter the item price'), findsOneWidget);

      // 2. Fill in valid data
      await tester.enterText(find.byKey(const Key('item_name_field')), 'Appam with Stew');
      await tester.enterText(find.byKey(const Key('item_price_field')), '120.00');
      await tester.enterText(find.byKey(const Key('item_prep_time_field')), '720');
      await tester.pumpAndSettle();

      // 3. Submit valid form
      await tester.ensureVisible(find.byKey(const Key('save_menu_item_button')));
      await tester.tap(find.byKey(const Key('save_menu_item_button')));
      await tester.pumpAndSettle();

      // Verify screen popped and returned created MenuItem
      expect(returnedItem, isNotNull);
      expect(returnedItem!.name, 'Appam with Stew');
      expect(returnedItem!.price, 120.0);
      expect(returnedItem!.prepTimeSeconds, 720);
      expect(returnedItem!.isAvailable, isTrue);
    });

    // ── Screen 19: Restaurant Orders Screen (FR-65, FR-66, FR-69, Step 7) ────
    testWidgets('Screen 19: RestaurantOrdersScreen displays orders and derived is_ready flag (FR-65, FR-69, Step 7)', (tester) async {
      final testOrders = [
        {
          'id': 'ord-101',
          'order_id': 'ORD-20261020-0042',
          'status': 'accepted',
          'is_ready': false,
          'prep_time_seconds': 600,
          'created_at': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
          'delivery_address': {'label': 'Pin A — Chinnakada'},
          'distance_km': 0.85,
          'total_price': 243.0,
          'items': [
            {'name': 'Kerala Porotta', 'quantity': 2},
          ],
        },
        {
          'id': 'ord-102',
          'order_id': 'ORD-20261020-0041',
          'status': 'arrived',
          'is_ready': true,
          'prep_time_seconds': 600,
          'created_at': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
          'delivery_address': {'label': 'Pin B — Polayathode'},
          'distance_km': 3.2,
          'total_price': 350.0,
          'items': [
            {'name': 'Appam with Stew', 'quantity': 2},
          ],
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: RestaurantOrdersScreen(initialOrders: testOrders),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & both order cards
      expect(find.text('Kitchen Live Orders'), findsOneWidget);
      expect(find.text('Order #ORD-20261020-0042'), findsOneWidget);
      expect(find.text('Order #ORD-20261020-0041'), findsOneWidget);

      // Verify derived is_ready indicators (FR-69, Demo Step 7)
      expect(find.text('PREPARING IN KITCHEN (PREP IN PROGRESS)'), findsOneWidget);
      expect(find.text('ORDER READY FOR PICKUP (FR-69)'), findsOneWidget);

      // Verify items and customer pins rendered
      expect(find.text('Kerala Porotta'), findsOneWidget);
      expect(find.text('Appam with Stew'), findsOneWidget);
      expect(find.textContaining('Pin A — Chinnakada'), findsOneWidget);
      expect(find.textContaining('Pin B — Polayathode'), findsOneWidget);

      // Test filter tabs
      expect(find.byKey(const Key('filter_tab_active')), findsOneWidget);
      expect(find.byKey(const Key('filter_tab_completed')), findsOneWidget);
      expect(find.byKey(const Key('filter_tab_all')), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter_tab_completed')));
      await tester.pumpAndSettle();

      // No orders are completed yet ('delivered'), so empty placeholder shows
      expect(find.text('No COMPLETED orders at this time'), findsOneWidget);
    });
  });
}
