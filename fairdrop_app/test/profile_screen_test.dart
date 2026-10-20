// ============================================================================
// FairDrop — Profile Screen Widget Tests (Screen 23, FR-47, FR-48)
// ============================================================================
// PRD Feature: FR-47 (Rider Profile, verified badge, metrics, shift status)
// PRD Feature: FR-48 (Upcoming pay change notice, 7-day countdown, Fairwork P2)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/profile_screen.dart';

void main() {
  group('ProfileScreen Widget Tests (Screen 23, FR-47, FR-48)', () {
    final mockUser = {
      'name': 'Rahul Nair',
      'email': 'rahul.rider@fairdrop.in',
      'phone': '+91 94471 23456',
      'role': 'rider',
      'zone': 'Kollam Coastal (KL-02)',
      'vehicle': 'Ather 450X (KL-02-CB-5678)',
    };

    final mockUpcomingConfig = {
      'config_id': 105,
      'base_rate': 18.00,
      'per_km_rate': 8.50,
      'surge_bonus': 10.00,
      'wait_threshold_mins': 8,
      'wait_compensation': 2.50,
      'min_wage_per_hour': 95.00,
      'effective_from': '2026-10-27T00:00:00.000Z',
      'change_reason': 'Kerala festive seasonal adjustment & fuel parity revision',
    };

    // ── Test 1: Profile information & key metrics rendering (FR-47) ─────────
    testWidgets('Renders rider profile details, verified badge, and metrics card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            initialUser: mockUser,
            initialUpcomingConfig: null,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rider Profile'), findsOneWidget);
      expect(find.text('Rahul Nair'), findsNWidgets(2));
      expect(find.text('+91 94471 23456'), findsOneWidget);
      expect(find.text('Verified Partner'), findsOneWidget);

      // Key metrics
      expect(find.text('Deliveries'), findsOneWidget);
      expect(find.text('Avg earnings'), findsOneWidget);
      expect(find.text('Shift Status'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Menu items
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Wage Guarantees & Rate Card'), findsOneWidget);
      expect(find.text('Pay Policy & 7-Day Notices'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Upcoming banner should NOT be present when upcoming config is null
      expect(find.byKey(const Key('upcoming_pay_change_banner')), findsNothing);
    });

    // ── Test 2: Upcoming pay change banner displays when scheduled (FR-48) ───
    testWidgets('Displays Upcoming Pay Revision banner with rates & countdown (FR-48)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            initialUser: mockUser,
            initialUpcomingConfig: mockUpcomingConfig,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bannerFinder = find.byKey(const Key('upcoming_pay_change_banner'));
      expect(bannerFinder, findsOneWidget);

      // Banner text and badges
      expect(find.text('Upcoming Pay Revision'), findsOneWidget);
      expect(find.text('7-Day Notice'), findsOneWidget);
      expect(find.textContaining('Takes effect in 7 days'), findsOneWidget);

      // Rates breakdown
      expect(find.text('₹18.00'), findsOneWidget); // Base Fare
      expect(find.text('₹8.50/km'), findsOneWidget); // Per Km
      expect(find.text('₹2.50/m'), findsOneWidget); // Wait Comp
      expect(find.text('₹95/hr'), findsOneWidget); // Min Floor

      // Justification reason & Fairwork notice
      expect(find.text('Reason: "Kerala festive seasonal adjustment & fuel parity revision"'), findsOneWidget);
      expect(find.textContaining('Fairwork Principle 2: Statutory 7-day advance notice'), findsOneWidget);
    });

    // ── Test 3: Wage Policy Bottom Sheet Modal ──────────────────────────────
    testWidgets('Tapping Wage Guarantees opens Pay Policy bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            initialUser: mockUser,
            initialUpcomingConfig: null,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final guaranteeItem = find.text('Wage Guarantees & Rate Card');
      expect(guaranteeItem, findsOneWidget);

      await tester.ensureVisible(guaranteeItem);
      await tester.tap(guaranteeItem);
      await tester.pumpAndSettle();

      // Policy bottom sheet verifies statutory guarantees
      expect(find.text('FairDrop Pay Policy'), findsOneWidget);
      expect(find.textContaining('Base Fare: '), findsOneWidget);
      expect(find.textContaining('Metered Distance: '), findsOneWidget);
      expect(find.textContaining('Kerala Wage Floor: '), findsOneWidget);
      expect(find.text('Understood'), findsOneWidget);

      // Dismiss bottom sheet
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();

      expect(find.text('FairDrop Pay Policy'), findsNothing);
    });
  });
}
