// ============================================================================
// FairDrop — Profile Screen Widget Tests (Screen 23, FR-47, FR-48, AUDIT-F18)
// ============================================================================
// PRD Feature: FR-47 (Rider Profile, verified badge, metrics, shift status)
// PRD Feature: FR-48 (Upcoming pay change notice, 7-day countdown, Fairwork P3)
// AUDIT-F18: Stats from backend/ledger, removed Verified Partner & unverified vehicle,
//            removed Accident & Health Covered, flat bonus label, Fair Contracts citation.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/profile_screen.dart';

void main() {
  group('ProfileScreen Widget Tests (Screen 23, FR-47, FR-48, AUDIT-F18)', () {
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
      'effective_from': DateTime.now().add(const Duration(days: 7, hours: 2)).toIso8601String(),
      'change_reason': 'Kerala festive seasonal adjustment & fuel parity revision',
    };

    // ── Test 1: Profile details, removed unverified claims, & metrics (FR-47, F18) ──
    testWidgets('Renders rider profile details, metrics card, and removes unverified badges', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            initialUser: mockUser,
            initialUpcomingConfig: null,
            initialDeliveriesToday: 0,
            initialEngagedHours: 0.0,
            initialHourlyRate: 0.0,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rider Profile'), findsOneWidget);
      expect(find.text('Rahul Nair'), findsNWidgets(2));
      expect(find.text('+91 94471 23456'), findsOneWidget);

      // Verified Partner badge removed per AUDIT-F18 / R19
      expect(find.text('Verified Partner'), findsNothing);

      // Key metrics with 0 engaged hours shows " — "
      expect(find.text('Deliveries'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Avg earnings'), findsOneWidget);
      expect(find.text(' — '), findsOneWidget);
      expect(find.text('Shift Status'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Menu items: Accident & Health Covered removed per AUDIT-F18 / R19
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Vehicle Details'), findsOneWidget);
      expect(find.text('EV Scooter (KL-02)'), findsNothing);
      expect(find.text('Wage Guarantees & Rate Card'), findsOneWidget);
      expect(find.text('Safety & Insurance'), findsOneWidget);
      expect(find.text('Accident & Health Covered'), findsNothing);
      expect(find.text('Pay Policy & 7-Day Notices'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Upcoming banner should NOT be present when upcoming config is null
      expect(find.byKey(const Key('upcoming_pay_change_banner')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // ── Test 2: Upcoming pay change banner displays when scheduled (FR-48, F18) ───
    testWidgets('Displays Upcoming Pay Revision banner with flat bonus label & Fair Contracts citation (FR-48, F18)', (tester) async {
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

      // Rates breakdown: wait comp labeled as flat bonus (not /m)
      expect(find.text('₹18.00'), findsOneWidget); // Base Fare
      expect(find.text('₹8.50/km'), findsOneWidget); // Per Km
      expect(find.text('Flat bonus'), findsOneWidget); // Wait Comp label
      expect(find.text('₹2.50'), findsOneWidget); // Wait Comp flat amount
      expect(find.text('₹2.50/m'), findsNothing); // Obsolete per-minute label gone
      expect(find.text('₹95/hr'), findsOneWidget); // Min Floor

      // Justification reason & Fairwork Principle 3 (Fair Contracts) notice
      expect(find.text('Reason: "Kerala festive seasonal adjustment & fuel parity revision"'), findsOneWidget);
      expect(find.textContaining('Fairwork Principle 3 (Fair Contracts)'), findsOneWidget);
      expect(find.textContaining('Fairwork Principle 2'), findsNothing);
      expect(tester.takeException(), isNull);
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
      expect(find.textContaining('Wait Compensation: '), findsOneWidget);
      expect(find.textContaining('Kerala Wage Floor: '), findsOneWidget);
      expect(find.text('Understood'), findsOneWidget);

      // Dismiss bottom sheet
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();

      expect(find.text('FairDrop Pay Policy'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // ── Test 4: Mobile Viewport (393px width) with Real Engaged Stats (AUDIT-F18) ───
    testWidgets('ProfileScreen renders at 393px mobile width with 0 layout exceptions', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);


      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            initialUser: mockUser,
            initialUpcomingConfig: mockUpcomingConfig,
            initialDeliveriesToday: 3,
            initialEngagedHours: 2.5,
            initialHourlyRate: 82.0,
            initialFloorTopup: 15.0,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify deliveries and average hourly with floor topup indicator
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Deliveries'), findsOneWidget);
      expect(find.text('₹82/hr'), findsOneWidget);
      expect(find.text('(incl. floor top-up)'), findsOneWidget);

      final exc = tester.takeException();
      expect(exc, isNull);
    });
  });
}
