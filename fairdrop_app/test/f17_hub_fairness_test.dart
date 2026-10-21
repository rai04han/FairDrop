// ============================================================================
// FairDrop — AUDIT-F17 Widget Tests: Hub Fairness Index & Formula Modal
// Tested at 393px width (iPhone 16 / Pixel 7 mobile baseline)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/rider_home_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AUDIT-F17 Hub Fairness Index & Formula Modal Tests', () {
    testWidgets('RiderHomeScreen renders Hub Fairness Index subtitle and "Not enough completed hours today" at 393px', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: RiderHomeScreen(autoFetch: false),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no overflow/exceptions at 393px
      expect(tester.takeException(), isNull);

      // Verify Kollam Hub Fairness Index card heading and exact subtitle
      expect(find.text('Kollam Hub Fairness Index'), findsOneWidget);
      expect(
        find.text('Average pay per engaged hour for riders in this hub today vs the statutory floor.'),
        findsOneWidget,
      );

      // Verify Realized pay tile shows "Not enough completed hours today" when completed engaged hours = 0
      expect(find.text('Not enough completed hours today'), findsOneWidget);

      // Verify Statutory Wage Floor tile exists
      expect(find.text('Statutory Wage Floor'), findsOneWidget);

      // Verify "+₹12 above mandate" and road conditions line are deleted
      expect(find.text('+₹12 above mandate'), findsNothing);
      expect(find.textContaining('Road conditions clear'), findsNothing);
    });

    testWidgets('Tapping "View Full Formula Breakdown" opens modal rendering config rates at 393px without overflow', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/zone-map': (context) => const SizedBox(),
            '/pay-breakdown': (context) => const SizedBox(),
          },
          home: const RiderHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final formulaBtn = find.byKey(const Key('btn_view_full_formula'));
      expect(formulaBtn, findsOneWidget);
      await tester.ensureVisible(formulaBtn);
      await tester.pumpAndSettle();
      await tester.tap(formulaBtn);
      await tester.pumpAndSettle();

      // Verify modal opened
      expect(find.text('Full Pay Formula Breakdown'), findsOneWidget);
      expect(find.text('Active Policy Rate Card'), findsOneWidget);

      // Verify formula components rendered from pay config
      expect(find.text('Base Dispatch Fee'), findsOneWidget);
      expect(find.text('Distance Transit Rate'), findsOneWidget);
      expect(find.text('Geofenced Wait Compensation'), findsOneWidget);
      expect(find.text('Monsoon Severe Weather Surge'), findsOneWidget);
      expect(find.text('Kerala Statutory Minimum Floor'), findsOneWidget);

      // Verify zero overflow exceptions inside the modal at 393px
      expect(tester.takeException(), isNull);
    });
    testWidgets('Shift card and Hub Fairness Index dynamically bind hub name to current zone (F30 / R20-R25)', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. Test Polayathode (KLM-PLY)
      await tester.pumpWidget(
        const MaterialApp(
          home: RiderHomeScreen(
            key: ValueKey('KLM-PLY'),
            initialZone: 'KLM-PLY',
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('KLM-PLY'), findsOneWidget);
      expect(find.textContaining('KLM-PLY • View Map'), findsOneWidget);
      expect(find.text('Live Shift • Polayathode Hub'), findsOneWidget);
      expect(find.text('Polayathode Hub'), findsOneWidget);

      // 2. Test Kilikolloor (KLM-KLK)
      await tester.pumpWidget(
        const MaterialApp(
          home: RiderHomeScreen(
            key: ValueKey('KLM-KLK'),
            initialZone: 'KLM-KLK',
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('KLM-KLK'), findsOneWidget);
      expect(find.text('Live Shift • Kilikolloor Hub'), findsOneWidget);
      expect(find.text('Kilikolloor Hub'), findsOneWidget);

      // 3. Test Chinnakkada (KLM-CHK)
      await tester.pumpWidget(
        const MaterialApp(
          home: RiderHomeScreen(
            key: ValueKey('KLM-CHK'),
            initialZone: 'KLM-CHK',
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('KLM-CHK'), findsOneWidget);
      expect(find.text('Live Shift • Chinnakada Hub'), findsOneWidget);
      expect(find.text('Chinnakada Hub'), findsOneWidget);
    });
  });
}
