// ============================================================================
// FairDrop — AUDIT-F19 Widget Tests: Active Delivery Title & Zone Map Layout
// Tested at 393px width (iPhone 16 / Pixel 7 mobile baseline)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/active_delivery_screen.dart';
import 'package:fairdrop_app/screens/zone_map_screen.dart';
import 'package:fairdrop_app/models/order.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AUDIT-F19 Layout Tests at 393px Mobile Width', () {
    testWidgets('ActiveDeliveryScreen renders title row at 393px with zero layout overflow exceptions (R15)', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = Order(
        id: 'ord-f19-active',
        orderId: 'ORD-20261021-0001',
        customerId: 'cust-1',
        restaurantId: 'rest-arun',
        deliveryAddress: OrderAddress(label: 'Kadappakkada, Kollam', latitude: 8.8932, longitude: 76.5950),
        restaurantAddress: OrderAddress(label: 'Hotel Arun, Kollam', latitude: 8.8870, longitude: 76.5900),
        distanceKm: 3.2,
        status: 'assigned',
        isReady: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveDeliveryScreen(
            order: order,
            autoStartTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no overflow or render exceptions at 393px width
      expect(tester.takeException(), isNull);

      // Verify header elements
      expect(find.text('Active Delivery'), findsOneWidget);
      expect(find.text('KL-02'), findsOneWidget);
      expect(find.text('Order #ORD-20261021-0001'), findsOneWidget);
    });

    testWidgets('ZoneMapScreen renders polygon markers and Pilot hub zones legend at 393px without overflow (R16)', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ZoneMapScreen(enableTileLayer: false, autoFetch: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify all 3 polygon labels are rendered at centroids
      expect(find.byKey(const Key('polygon_marker_KLM-CHK')), findsOneWidget);
      expect(find.byKey(const Key('polygon_marker_KLM-PLY')), findsOneWidget);
      expect(find.byKey(const Key('polygon_marker_KLM-KLK')), findsOneWidget);

      // Verify floating legend "Pilot hub zones"
      expect(find.byKey(const Key('pilot_hub_zones_legend')), findsOneWidget);
      expect(find.text('Pilot hub zones'), findsOneWidget);
      expect(find.textContaining('KLM-CHK (Chinnakkada)'), findsOneWidget);
      expect(find.textContaining('KLM-PLY (Polayathode)'), findsOneWidget);
      expect(find.textContaining('KLM-KLK (Kilikolloor)'), findsOneWidget);

      // Verify bottom zone cards (horizontal scroll on 393px width)
      expect(find.byKey(const Key('zone_card_KLM-CHK')), findsOneWidget);
      await tester.drag(find.byKey(const Key('zone_card_KLM-CHK')), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('zone_card_KLM-KLK')), findsOneWidget);
    });

    testWidgets('ZoneMapScreen renders out-of-zone transition at 393px without overflow', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ZoneMapScreen(
            zoneChangedTo: 'KLM-PLY',
            previousZone: 'KLM-CHK',
            isOutOfZoneTransition: true,
            enableTileLayer: false,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('zone_changed_banner')), findsOneWidget);
      expect(find.text('OUT-OF-ZONE TRANSITION'), findsOneWidget);
      expect(find.byKey(const Key('pilot_hub_zones_legend')), findsOneWidget);
    });
  });
}
