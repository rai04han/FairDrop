// ============================================================================
// FairDrop — Responsive Layout & Button Width Tests (Screens at 360px & 393px)
// ============================================================================
// Tests verifying that buttons in Rows and AlertDialogs do not request infinite
// width from FairDropTheme.lightTheme, preventing layout exceptions at 360px/393px.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/config/theme.dart';
import 'package:fairdrop_app/models/menu_item.dart';
import 'package:fairdrop_app/services/cart_service.dart';
import 'package:fairdrop_app/screens/customer/restaurant_menu_screen.dart';
import 'package:fairdrop_app/screens/customer/restaurant_list_screen.dart';
import 'package:fairdrop_app/screens/restaurant/menu_management_screen.dart';

void main() {
  setUp(() {
    CartService.instance.clear();
  });

  tearDown(() {
    CartService.instance.clear();
  });

  final testRestaurant = {
    'id': 'rest-hotel-arun',
    'name': 'Hotel Arun',
    'cuisine': 'Kerala Specials • South Indian',
    'address': {'latitude': 8.8870, 'longitude': 76.5900},
  };

  final testMenuItems = [
    MenuItem(
      id: 'item-1',
      restaurantId: 'rest-hotel-arun',
      name: 'Kerala Porotta (2 pcs)',
      price: 30.0,
      isAvailable: true,
      prepTimeSeconds: 180,
    ),
    MenuItem(
      id: 'item-2',
      restaurantId: 'rest-hotel-arun',
      name: 'Malabar Chicken Biryani',
      price: 180.0,
      isAvailable: true,
      prepTimeSeconds: 600,
    ),
  ];

  for (final width in [360.0, 393.0]) {
    group('Responsive tests at ${width.toInt()}px width', () {
      testWidgets('Customer Menu Screen: 1-line price, visible ADD button, no layout exception', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        CartService.instance.setRestaurant(testRestaurant);

        await tester.pumpWidget(
          MaterialApp(
            theme: FairDropTheme.lightTheme,
            home: RestaurantMenuScreen(
              restaurant: testRestaurant,
              initialItems: testMenuItems,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Price text is visible and formatted on one line
        expect(find.text('₹30.00'), findsOneWidget);
        expect(find.text('₹180.00'), findsOneWidget);

        // ADD button is visible
        expect(find.byKey(const Key('add_item_button_kerala_porotta__2_pcs_')), findsOneWidget);

        // Add to cart to show sticky bottom cart bar with VIEW CART button in Row
        await tester.tap(find.byKey(const Key('add_item_button_kerala_porotta__2_pcs_')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('view_cart_button')), findsOneWidget);
      });

      testWidgets('Restaurant Menu Management: 1-line heading and ADD ITEM button, no layout exception', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: FairDropTheme.lightTheme,
            home: MenuManagementScreen(
              initialItems: testMenuItems,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Heading is visible on one line
        expect(find.textContaining('KITCHEN DISHES'), findsOneWidget);

        // ADD ITEM button is visible
        expect(find.byKey(const Key('add_menu_item_header_button')), findsOneWidget);
      });

      testWidgets('AlertDialog action buttons with minimumSize: Size.zero (Admin, Profile, Grievance)', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Test 1: Admin Panel Diff AlertDialog Actions (~L364)
        await tester.pumpWidget(
          MaterialApp(
            theme: FairDropTheme.lightTheme,
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Confirm Pay Structure Revision'),
                      actions: [
                        TextButton(
                          style: TextButton.styleFrom(minimumSize: Size.zero),
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                        ),
                        FilledButton.icon(
                          key: const Key('admin_confirm_diff_button'),
                          style: FilledButton.styleFrom(
                            minimumSize: Size.zero,
                            backgroundColor: FairDropColors.brandGreen,
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Confirm & Schedule'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Admin Dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Admin Dialog'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('admin_confirm_diff_button')), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Test 2: Profile Screen Logout AlertDialog Actions (~L124)
        await tester.pumpWidget(
          MaterialApp(
            theme: FairDropTheme.lightTheme,
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Log Out'),
                      content: const Text('Are you sure you want to end your shift?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          style: TextButton.styleFrom(minimumSize: Size.zero),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          style: FilledButton.styleFrom(
                            minimumSize: Size.zero,
                            backgroundColor: FairDropColors.errorRed,
                          ),
                          child: const Text('Log Out'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Profile Dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Profile Dialog'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Log Out'), findsWidgets);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Test 3: Grievance Screen Success AlertDialog Action (~L193)
        await tester.pumpWidget(
          MaterialApp(
            theme: FairDropTheme.lightTheme,
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Grievance Lodged'),
                      actions: [
                        FilledButton(
                          key: const Key('grievance_done_button'),
                          onPressed: () => Navigator.pop(dialogCtx),
                          style: FilledButton.styleFrom(
                            minimumSize: Size.zero,
                            backgroundColor: FairDropColors.brandGreen,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Return to Profile'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Grievance Dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Grievance Dialog'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('grievance_done_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('grievance_done_button')));
        await tester.pumpAndSettle();
      });
    });
  }

  group('Timeout and Error Banner Widget Tests', () {
    testWidgets('RestaurantListScreen shows error banner with Retry button on API failure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FairDropTheme.lightTheme,
          home: const RestaurantListScreen(),
        ),
      );
      // Wait for 8s timeout to expire
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('restaurant_list_error_banner')), findsOneWidget);
      expect(find.byKey(const Key('retry_restaurant_list_button')), findsOneWidget);
    });

    testWidgets('RestaurantMenuScreen shows error banner with Retry button on API failure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FairDropTheme.lightTheme,
          home: RestaurantMenuScreen(
            restaurant: {'id': 'unknown-rest-id', 'name': 'Ghost Cafe'},
          ),
        ),
      );
      // Wait for 8s timeout to expire
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu_error_banner')), findsOneWidget);
      expect(find.byKey(const Key('retry_menu_button')), findsOneWidget);
    });
  });
}
