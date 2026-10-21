// ============================================================================
// FairDrop — Zone Map Widget Tests (Screen 8, FR-26, FR-27, FR-28, FR-29, FR-73)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:fairdrop_app/screens/zone_map_screen.dart';
import 'package:fairdrop_app/screens/pay_breakdown_screen.dart';
import 'package:fairdrop_app/models/order.dart';
import 'package:fairdrop_app/models/pay_result.dart';

void main() {
  group('Zone Map Screen Widget Tests (Screen 8)', () {
    testWidgets('Screen 8: Renders 3 Kollam zones and highlights active hub (FR-26, FR-28)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ZoneMapScreen(enableTileLayer: false, autoFetch: false),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar elements
      expect(find.text('Kollam Zones'), findsOneWidget);
      expect(find.byKey(const Key('active_zone_pill')), findsOneWidget);
      expect(find.text('KLM-CHK'), findsWidgets);

      // Bottom floating sheet
      expect(find.text('3 Active Kollam Zones'), findsOneWidget);
      expect(find.text('₹70/hr Floor Protected'), findsOneWidget);

      // Verify the 3 zone cards are rendered
      expect(find.byKey(const Key('zone_card_KLM-CHK')), findsOneWidget);
      expect(find.byKey(const Key('zone_card_KLM-PLY')), findsOneWidget);
      expect(find.byKey(const Key('zone_card_KLM-KLK')), findsOneWidget);

      // Verify all 3 polygon centroid labels are rendered (F19)
      expect(find.byKey(const Key('polygon_marker_KLM-CHK')), findsOneWidget);
      expect(find.byKey(const Key('polygon_marker_KLM-PLY')), findsOneWidget);
      expect(find.byKey(const Key('polygon_marker_KLM-KLK')), findsOneWidget);

      // Verify Pilot hub zones legend is rendered (F19)
      expect(find.byKey(const Key('pilot_hub_zones_legend')), findsOneWidget);
      expect(find.text('Pilot hub zones'), findsOneWidget);

      // Active badge on home zone
      expect(find.text('ACTIVE HUB'), findsOneWidget);

      // Out-of-zone banner is NOT shown on normal home entry
      expect(find.byKey(const Key('zone_changed_banner')), findsNothing);
    });

    testWidgets('Screen 8: Displays out-of-zone transition banner and updates active hub to KLM-PLY (FR-27, FR-73, Demo Step 11)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const Key('open_zone_map'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(
                        name: '/zone-map',
                        arguments: {
                          'zoneChangedTo': 'KLM-PLY',
                          'previousZone': 'KLM-CHK',
                          'isOutOfZoneTransition': true,
                        },
                      ),
                      builder: (_) => const ZoneMapScreen(enableTileLayer: false, autoFetch: false),
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_zone_map')));
      await tester.pumpAndSettle();

      // Verify prominent transition banner
      expect(find.byKey(const Key('zone_changed_banner')), findsOneWidget);
      expect(find.text('OUT-OF-ZONE TRANSITION'), findsOneWidget);
      expect(find.textContaining('Zone Changed: Your active zone is now KLM-PLY'), findsOneWidget);
      expect(find.textContaining('updated from KLM-CHK'), findsOneWidget);

      // Verify top bar active pill updated to KLM-PLY
      final pillFinder = find.byKey(const Key('active_zone_pill'));
      expect(pillFinder, findsOneWidget);
      expect(find.descendant(of: pillFinder, matching: find.text('KLM-PLY')), findsOneWidget);

      // Dismiss banner
      await tester.tap(find.byKey(const Key('dismiss_zone_banner_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('zone_changed_banner')), findsNothing);
    });

    testWidgets('Screen 8: Renders last delivery endpoint marker (FR-29)', (tester) async {
      const pinB = LatLng(8.8750, 76.6050);
      await tester.pumpWidget(
        const MaterialApp(
          home: ZoneMapScreen(
            zoneChangedTo: 'KLM-PLY',
            previousZone: 'KLM-CHK',
            isOutOfZoneTransition: true,
            lastDeliveryPoint: pinB,
            enableTileLayer: false,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Marker for last delivery endpoint (Pin B)
      expect(find.byKey(const Key('last_delivery_marker')), findsOneWidget);
      expect(find.text('Last Delivery (Pin B)'), findsOneWidget);
    });

    testWidgets('Screen 8: Tapping zone card selects and focuses zone in bottom sheet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ZoneMapScreen(enableTileLayer: false, autoFetch: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Polayathode card
      await tester.tap(find.byKey(const Key('zone_card_KLM-PLY')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('zone_card_KLM-PLY')), findsOneWidget);
    });

    testWidgets('PayBreakdownScreen: Out-of-zone banner navigates to /zone-map with transition arguments', (tester) async {
      final outOfZoneOrder = Order(
        id: 'ord-out-of-zone',
        orderId: 'ORD-1002',
        customerId: 'cust-1',
        restaurantId: 'rest-arun',
        status: 'delivered',
        deliveryAddress: OrderAddress(
          label: 'Pin B - Polayathode Junction, Kollam',
          latitude: 8.8750,
          longitude: 76.6050,
        ),
        restaurantAddress: OrderAddress(
          label: 'Hotel Arun, Chinnakada',
          latitude: 8.8853,
          longitude: 76.5864,
        ),
        distanceKm: 4.8,
        restaurantWaitMins: 3,
        isOutOfZone: true,
        payCalculationResult: PayResult(
          orderId: 'ORD-1002',
          baseRate: 35.0,
          distancePay: 38.4,
          surgeBonus: 0.0,
          waitCompensation: 15.0,
          totalDeliveryPay: 88.4,
          floorTopup: 0.0,
          hourlyEarningsSoFar: 88.4,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/zone-map': (context) => const ZoneMapScreen(enableTileLayer: false, autoFetch: false),
          },
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: RouteSettings(
                          name: '/pay-breakdown',
                          arguments: {
                            'order': outOfZoneOrder,
                            'orderId': outOfZoneOrder.id,
                            'payResult': outOfZoneOrder.payCalculationResult,
                            'isOutOfZone': true,
                          },
                        ),
                        builder: (_) => const PayBreakdownScreen(),
                      ),
                    );
                  },
                  child: const Text('Go to Breakdown'),
                ),
              );
            },
          ),
        ),
      );

      // Open Breakdown
      await tester.tap(find.text('Go to Breakdown'));
      await tester.pumpAndSettle();

      // Out-of-zone notice should be visible
      expect(find.text('Out-of-Zone Delivery Transition (FR-73)'), findsOneWidget);
      expect(find.byKey(const Key('view_zone_map_button')), findsOneWidget);

      // Tap View Updated Zone Map
      await tester.tap(find.byKey(const Key('view_zone_map_button')));
      await tester.pumpAndSettle();

      // Should land on ZoneMapScreen with zone changed banner
      expect(find.byKey(const Key('zone_changed_banner')), findsOneWidget);
      expect(find.textContaining('Zone Changed: Your active zone is now KLM-PLY'), findsOneWidget);
    });
  });
}
