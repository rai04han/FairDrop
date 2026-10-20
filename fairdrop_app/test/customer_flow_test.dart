// ============================================================================
// FairDrop — Customer Flow Widget Tests (Screens 11 to 16, FR-55 to FR-60)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/customer/delivery_location_screen.dart';
import 'package:fairdrop_app/screens/customer/restaurant_list_screen.dart';
import 'package:fairdrop_app/screens/customer/restaurant_menu_screen.dart';
import 'package:fairdrop_app/screens/customer/cart_screen.dart';
import 'package:fairdrop_app/screens/customer/mock_payment_screen.dart';
import 'package:fairdrop_app/screens/customer/order_confirmation_screen.dart';
import 'package:fairdrop_app/services/cart_service.dart';
import 'package:fairdrop_app/models/menu_item.dart';

void main() {
  setUp(() {
    CartService.instance.clear();
  });

  tearDown(() {
    CartService.instance.clear();
  });

  group('Customer Flow Widget Tests (Screens 11 to 16)', () {
    // ── Screen 11 (FR-55): Delivery Location Screen ─────────────────────────
    testWidgets('Screen 11: DeliveryLocationScreen selects Pin A & Pin B and saves location (FR-55)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/customer/restaurants': (context) => const Scaffold(body: Text('Restaurants Route Target')),
          },
          home: const DeliveryLocationScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & demo pins
      expect(find.text('Choose Delivery Location'), findsOneWidget);
      expect(find.text('Pin A — Chinnakada (In-Zone)'), findsOneWidget);
      expect(find.text('Pin B — Polayathode (Out-of-Zone)'), findsOneWidget);
      expect(find.text('KLM-CHK'), findsWidgets);

      // Tap Pin B (Out-of-Zone)
      await tester.tap(find.byKey(const Key('select_pin_b_button')));
      await tester.pumpAndSettle();

      // Verify selected location updated to KLM-PLY
      expect(find.text('KLM-PLY'), findsWidgets);
      expect(find.text('Polayathode Junction, SN College Road, Kollam'), findsWidgets);

      // Confirm location
      await tester.tap(find.byKey(const Key('confirm_location_button')));
      await tester.pumpAndSettle();

      // Verify CartService received Pin B and route transitioned
      expect(CartService.instance.deliveryLocation?['zone_id'], 'KLM-PLY');
      expect(find.text('Restaurants Route Target'), findsOneWidget);
    });

    // ── Screen 12 (FR-56): Restaurant List Screen ───────────────────────────
    testWidgets('Screen 12: RestaurantListScreen displays restaurants with straight-line distance (FR-56)', (tester) async {
      CartService.instance.setDeliveryLocation({
        'label': 'Pin A — Chinnakada',
        'latitude': 8.8932,
        'longitude': 76.5950,
        'zone_id': 'KLM-CHK',
      });

      final testRestaurants = [
        {
          'id': 'rest-hotel-arun',
          'name': 'Hotel Arun',
          'cuisine': 'Kerala Specials • South Indian',
          'rating': 4.8,
          'est_time': '20 mins',
          'address': {
            'name': 'Hotel Arun',
            'latitude': 8.8870,
            'longitude': 76.5900,
            'zone_id': 'KLM-CHK',
          },
        },
        {
          'id': 'rest-marina-grill',
          'name': 'Marina Grill',
          'cuisine': 'Coastal Grills • Biryani',
          'rating': 4.7,
          'est_time': '25 mins',
          'address': {
            'name': 'Marina Grill',
            'latitude': 8.8780,
            'longitude': 76.5820,
            'zone_id': 'KLM-CHK',
          },
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/customer/menu': (context) => const Scaffold(body: Text('Menu Route Target')),
          },
          home: RestaurantListScreen(initialRestaurants: testRestaurants),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Restaurant'), findsOneWidget);
      expect(find.text('Hotel Arun'), findsOneWidget);
      expect(find.text('Marina Grill'), findsOneWidget);
      expect(find.text('Pin A — Chinnakada'), findsOneWidget);

      // Tap Hotel Arun card
      await tester.tap(find.byKey(const Key('restaurant_card_hotel_arun')));
      await tester.pumpAndSettle();

      // Verify CartService restaurant is set and navigated
      expect(CartService.instance.restaurant?['name'], 'Hotel Arun');
      expect(find.text('Menu Route Target'), findsOneWidget);
    });

    // ── Screen 13 (FR-57, Demo Step 3): Restaurant Menu Screen ──────────────
    testWidgets('Screen 13: RestaurantMenuScreen adds available items and prevents unavailable items (FR-57, Step 3)', (tester) async {
      final restaurant = {
        'id': 'rest-hotel-arun',
        'name': 'Hotel Arun',
        'cuisine': 'Kerala Specials • South Indian',
        'address': {'latitude': 8.8870, 'longitude': 76.5900},
      };
      CartService.instance.setRestaurant(restaurant);

      final menuItems = [
        MenuItem(
          id: 'item-1',
          restaurantId: 'rest-hotel-arun',
          name: 'Kerala Porotta',
          price: 25.0,
          isAvailable: true,
          prepTimeSeconds: 600,
        ),
        MenuItem(
          id: 'item-2',
          restaurantId: 'rest-hotel-arun',
          name: 'Nadan Chicken Curry',
          price: 180.0,
          isAvailable: true,
          prepTimeSeconds: 900,
        ),
        MenuItem(
          id: 'item-3',
          restaurantId: 'rest-hotel-arun',
          name: 'Seasonal Mango Fish Curry',
          price: 220.0,
          isAvailable: false, // UNAVAILABLE item for Demo Step 3
          prepTimeSeconds: 1200,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/customer/cart': (context) => const Scaffold(body: Text('Cart Route Target')),
          },
          home: RestaurantMenuScreen(
            restaurant: restaurant,
            initialItems: menuItems,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify available items have ADD buttons
      expect(find.byKey(const Key('add_item_button_kerala_porotta')), findsOneWidget);
      expect(find.byKey(const Key('add_item_button_nadan_chicken_curry')), findsOneWidget);

      // 2. Demo Step 3 defense: Unavailable item shows UNAVAILABLE badge and NO add button
      expect(find.byKey(const Key('unavailable_badge_seasonal_mango_fish_curry')), findsOneWidget);
      expect(find.byKey(const Key('add_item_button_seasonal_mango_fish_curry')), findsNothing);

      // 3. Add available item to cart
      await tester.tap(find.byKey(const Key('add_item_button_kerala_porotta')));
      await tester.pumpAndSettle();

      // Verify quantity indicator appears
      expect(find.byKey(const Key('item_qty_kerala_porotta')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Increment item
      await tester.tap(find.byKey(const Key('increment_button_kerala_porotta')));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(CartService.instance.totalItemCount, 2);

      // Verify sticky bottom cart button is visible
      expect(find.byKey(const Key('view_cart_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('view_cart_button')));
      await tester.pumpAndSettle();
      expect(find.text('Cart Route Target'), findsOneWidget);
    });

    // ── Screen 14 (FR-58): Cart Screen ──────────────────────────────────────
    testWidgets('Screen 14: CartScreen displays single restaurant items and itemized transparent bill (FR-58)', (tester) async {
      CartService.instance.setDeliveryLocation({
        'label': 'Pin A — Chinnakada',
        'latitude': 8.8932,
        'longitude': 76.5950,
        'is_out_of_zone': false,
      });

      final restaurant = {
        'id': 'rest-hotel-arun',
        'name': 'Hotel Arun',
        'address': {'latitude': 8.8870, 'longitude': 76.5900},
      };
      CartService.instance.setRestaurant(restaurant);

      CartService.instance.addItem(MenuItem(
        id: 'item-1',
        restaurantId: 'rest-hotel-arun',
        name: 'Kerala Porotta',
        price: 25.0,
        isAvailable: true,
        prepTimeSeconds: 600,
      ));
      CartService.instance.addItem(MenuItem(
        id: 'item-2',
        restaurantId: 'rest-hotel-arun',
        name: 'Nadan Chicken Curry',
        price: 180.0,
        isAvailable: true,
        prepTimeSeconds: 900,
      ));

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/customer/payment': (context) => const Scaffold(body: Text('Payment Route Target')),
          },
          home: const CartScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify restaurant name & location
      expect(find.text('Hotel Arun'), findsWidgets);
      expect(find.textContaining('Pin A — Chinnakada'), findsWidgets);

      // Verify items rendered
      expect(find.text('Kerala Porotta'), findsOneWidget);
      expect(find.text('Nadan Chicken Curry'), findsOneWidget);

      // Verify transparent bill breakdown items (sum of item prices only, no fees)
      expect(find.text('Item Subtotal'), findsOneWidget);
      expect(find.text('Delivery Partner Fair Pay Fee'), findsNothing);
      expect(find.text('FairDrop Platform Fee'), findsNothing);
      expect(find.text('Taxes & Packaging (5% GST)'), findsNothing);
      expect(find.text('TO PAY'), findsOneWidget);

      // Proceed to payment
      expect(find.byKey(const Key('proceed_to_payment_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('proceed_to_payment_button')));
      await tester.pumpAndSettle();
      expect(find.text('Payment Route Target'), findsOneWidget);
    });

    // ── Screen 15 (FR-59): Mock Payment Screen ──────────────────────────────
    testWidgets('Screen 15: MockPaymentScreen displays demo payment notice and executes checkout (FR-59)', (tester) async {
      CartService.instance.setDeliveryLocation({
        'label': 'Pin A — Chinnakada',
        'latitude': 8.8932,
        'longitude': 76.5950,
      });
      CartService.instance.setRestaurant({
        'id': 'rest-hotel-arun',
        'name': 'Hotel Arun',
        'address': {'latitude': 8.8870, 'longitude': 76.5900},
      });
      CartService.instance.addItem(MenuItem(
        id: 'item-1',
        restaurantId: 'rest-hotel-arun',
        name: 'Kerala Porotta',
        price: 25.0,
        isAvailable: true,
        prepTimeSeconds: 600,
      ));

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/customer/order-confirmation': (context) => const Scaffold(body: Text('Confirmation Route Target')),
          },
          home: const MockPaymentScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title, amount, and demo notice
      expect(find.text('Mock Payment'), findsOneWidget);
      expect(find.byKey(const Key('payment_total_amount')), findsOneWidget);
      expect(find.text('Demo payment. No money is charged.'), findsOneWidget);
      expect(find.text('Place Order (₹25)'), findsOneWidget);

      // Tap Place Order
      expect(find.byKey(const Key('pay_now_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pay_now_button')));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // Cart should be cleared and routed to confirmation
      expect(CartService.instance.items.isEmpty, isTrue);
      expect(find.text('Confirmation Route Target'), findsOneWidget);
    });

    // ── Screen 16 (FR-60, Demo Step 4): Order Confirmation Screen ───────────
    testWidgets('Screen 16: OrderConfirmationScreen displays auto-accepted status and allocation state (FR-60, Step 4)', (tester) async {
      final mockOrderAssigned = {
        'order_id': 'ORD-20261020-0042',
        'status': 'accepted',
        'allocation': 'assigned',
        'restaurant_name': 'Hotel Arun',
        'delivery_location': 'Pin A — Chinnakada',
        'distance_km': 0.85,
        'total_price': 243.0,
        'items': [
          {'name': 'Kerala Porotta', 'quantity': 2},
          {'name': 'Nadan Chicken Curry', 'quantity': 1},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/customer': (context) => const Scaffold(body: Text('Customer Home Target')),
          },
          home: OrderConfirmationScreen(orderData: mockOrderAssigned),
        ),
      );
      await tester.pumpAndSettle();

      // Verify order confirmation details
      expect(find.text('Order Placed Successfully!'), findsOneWidget);
      expect(find.text('Order #ORD-20261020-0042'), findsOneWidget);
      expect(find.text('STATUS: AUTO-ACCEPTED (FR-67)'), findsOneWidget);
      expect(find.text('Kitchen is preparing your order at Hotel Arun.'), findsOneWidget);
      expect(find.text('Rider Allocated (FR-68)'), findsOneWidget);
      expect(find.text('Pin A — Chinnakada'), findsOneWidget);

      // Verify Back to Home button navigates back
      expect(find.byKey(const Key('back_to_home_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('back_to_home_button')));
      await tester.pumpAndSettle();
      expect(find.text('Customer Home Target'), findsOneWidget);
    });

    testWidgets('Screen 16: OrderConfirmationScreen displays no_rider_available notice when no rider is available (D6)', (tester) async {
      final mockOrderNoRider = {
        'order_id': 'ORD-20261020-0099',
        'status': 'accepted',
        'allocation': 'no_rider_available',
        'restaurant_name': 'Hotel Arun',
        'delivery_location': 'Pin B — Polayathode',
        'distance_km': 3.2,
        'total_price': 310.0,
        'items': [
          {'name': 'Kerala Porotta', 'quantity': 2},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OrderConfirmationScreen(orderData: mockOrderNoRider),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no rider notice (D6, FR-60)
      expect(find.text('Searching for Available Riders...'), findsOneWidget);
      expect(
        find.text('All zone riders are currently active. Order is prioritized and will allocate as soon as a rider goes online or completes delivery (FR-60, D6).'),
        findsOneWidget,
      );
    });
  });
}
