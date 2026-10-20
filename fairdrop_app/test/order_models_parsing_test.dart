import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/config/theme.dart';
import 'package:fairdrop_app/models/order.dart';
import 'package:fairdrop_app/screens/order_acceptance_screen.dart';
import 'package:fairdrop_app/screens/rider_home_screen.dart';

void main() {
  group('Order & OrderAddress Models Parsing Tests (F11 / R7)', () {
    test('OrderAddress.fromJson parses Map with label, latitude, longitude', () {
      final mapData = {
        'label': 'Pin A (Near Chinnakada)',
        'latitude': 8.8860,
        'longitude': 76.5920,
      };

      final addr = OrderAddress.fromJson(mapData);
      expect(addr.label, 'Pin A (Near Chinnakada)');
      expect(addr.latitude, 8.8860);
      expect(addr.longitude, 76.5920);
    });

    test('OrderAddress.fromJson safely parses String ("Kadappakkada Junction")', () {
      final addr = OrderAddress.fromJson('Kadappakkada Junction');
      expect(addr.label, 'Kadappakkada Junction');
      expect(addr.latitude, 0.0);
      expect(addr.longitude, 0.0);
    });

    test('OrderAddress.fromJson safely handles null and empty map', () {
      final addrNull = OrderAddress.fromJson(null);
      expect(addrNull.label, '');
      expect(addrNull.latitude, 0.0);

      final addrEmpty = OrderAddress.fromJson(<String, dynamic>{});
      expect(addrEmpty.label, '');
      expect(addrEmpty.latitude, 0.0);
    });

    test('Order.fromJson parses real core-service API order payload', () {
      // Full path trace: POST /api/orders output structure from core-service
      final apiOrderJson = {
        '_id': '67153a99e01123456789abcd',
        'order_id': 'ORD-20261020-0001',
        'customer_id': '67153a99e011234567890001',
        'restaurant_id': '67153a99e011234567890002',
        'rider_id': '67153a99e011234567890003',
        'status': 'accepted',
        'rider_ack': 'pending',
        'distance_km': 4.2,
        'items': [
          {
            'name': 'Chicken Dum Biryani',
            'price': 240.0,
            'quantity': 2,
            'prep_time_seconds': 600,
          }
        ],
        'restaurant_address': {
          'label': 'Hotel Arun, Chinnakada',
          'latitude': 8.8860,
          'longitude': 76.5920,
        },
        'delivery_address': {
          'label': 'Kadappakkada Junction',
          'latitude': 8.8920,
          'longitude': 76.6010,
        },
        'is_surge_active': false,
        'is_out_of_zone': false,
        'pay_calculation_result': {
          'base_pay': 30.0,
          'distance_pay': 42.0,
          'guaranteed_payout': 92.0,
        },
      };

      final order = Order.fromJson(apiOrderJson);
      expect(order.orderId, 'ORD-20261020-0001');
      expect(order.status, 'accepted');
      expect(order.riderAck, 'pending');
      expect(order.distanceKm, 4.2);
      expect(order.restaurantAddress.label, 'Hotel Arun, Chinnakada');
      expect(order.deliveryAddress.label, 'Kadappakkada Junction');
      expect(order.items.length, 1);
      expect(order.items.first.name, 'Chicken Dum Biryani');
    });

    test('Order.fromJson parses payload with string delivery_address without TypeError', () {
      final legacyJson = {
        'order_id': 'FD-8821',
        'pickup_address': 'Supreme Bakers, Chinnakada',
        'delivery_address': 'Kadappakkada Junction',
        'distance_km': 3.8,
        'status': 'accepted',
        'rider_ack': 'pending',
      };

      final order = Order.fromJson(legacyJson);
      expect(order.orderId, 'FD-8821');
      expect(order.deliveryAddress.label, 'Kadappakkada Junction');
      expect(order.restaurantAddress.label, 'Supreme Bakers, Chinnakada');
    });
  });

  group('Order Acceptance & Rider Home Screen Resilience (F11 / R7)', () {
    testWidgets('OrderAcceptanceScreen renders real API order without exceptions', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final realOrder = Order.fromJson({
        'order_id': 'ORD-20261020-9999',
        'restaurant_name': 'Hotel Arun, Chinnakada',
        'restaurant_address': {
          'label': 'Hotel Arun, Chinnakada',
          'latitude': 8.8860,
          'longitude': 76.5920,
        },
        'delivery_address': {
          'label': 'Kadappakkada Junction',
          'latitude': 8.8920,
          'longitude': 76.6010,
        },
        'distance_km': 4.2,
        'status': 'accepted',
        'rider_ack': 'pending',
      });

      final payConfig = {
        'base_rate': 30.0,
        'per_km_rate': 10.0,
        'surge_bonus': 0.0,
        'wait_compensation': 10.0,
        'wait_threshold_mins': 5,
        'min_wage_per_hour': 70.0,
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: FairDropTheme.lightTheme,
          home: OrderAcceptanceScreen(
            order: realOrder,
            payConfig: payConfig,
            autoStartTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Order Acceptance'), findsOneWidget);
      expect(find.textContaining('Hotel Arun, Chinnakada'), findsWidgets);
      expect(find.textContaining('Kadappakkada Junction'), findsWidgets);
    });

    testWidgets('OrderAcceptanceScreen renders String delivery_address without TypeError', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final payConfig = {
        'base_rate': 30.0,
        'per_km_rate': 10.0,
      };

      // Simulates passing the map containing String addresses
      await tester.pumpWidget(
        MaterialApp(
          theme: FairDropTheme.lightTheme,
          initialRoute: '/order-acceptance',
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: const RouteSettings(
                name: '/order-acceptance',
                arguments: {
                  'order_id': 'FD-8821',
                  'pickup_address': 'Supreme Bakers, Chinnakada',
                  'delivery_address': 'Kadappakkada Junction',
                  'distance_km': 3.8,
                },
              ),
              builder: (_) => OrderAcceptanceScreen(
                payConfig: payConfig,
                autoStartTimer: false,
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Order Acceptance'), findsOneWidget);
      expect(find.textContaining('Supreme Bakers, Chinnakada'), findsWidgets);
      expect(find.textContaining('Kadappakkada Junction'), findsWidgets);
    });

    testWidgets('OrderAcceptanceScreen renders error state with Retry and Back on data error', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: FairDropTheme.lightTheme,
          home: const OrderAcceptanceScreen(
            initialError: 'Corrupted order payload received',
            autoStartTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Order Acceptance Error'), findsOneWidget);
      expect(find.text('Corrupted order payload received'), findsOneWidget);
      expect(find.byKey(const Key('btn_retry_acceptance')), findsOneWidget);
      expect(find.byKey(const Key('btn_back_acceptance')), findsOneWidget);
    });

    testWidgets('RiderHomeScreen renders error state with Retry and Back on data error', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: FairDropTheme.lightTheme,
          home: const RiderHomeScreen(
            initialError: 'Failed to synchronize shift data with server',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Rider Dashboard Error'), findsOneWidget);
      expect(find.text('Failed to synchronize shift data with server'), findsOneWidget);
      expect(find.byKey(const Key('btn_retry_rider_home')), findsOneWidget);
      expect(find.byKey(const Key('btn_back_rider_home')), findsOneWidget);
    });
  });
}
