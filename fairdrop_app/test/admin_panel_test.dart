// ============================================================================
// FairDrop — Admin Panel Screen Widget Tests (Screen 20, FR-38 to FR-45)
// ============================================================================
// PRD Features:
//   - FR-38: Active Config Read & Display
//   - FR-39: Config History Table & Audit Trail (ACTIVE, SCHEDULED, SUPERSEDED)
//   - FR-40 to FR-42: Pay Revision & 7-Day Advance Notice Rule
//   - FR-43: Client-side Numeric Validation
//   - FR-44: Old → New Diff Comparison Confirmation Dialog
//   - FR-45: Audit Trail & Status Refresh
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/admin_panel_screen.dart';

void main() {
  final sampleActiveConfig = {
    'config_id': 1,
    'base_rate': 20.00,
    'per_km_rate': 10.00,
    'surge_bonus': 15.00,
    'wait_threshold_mins': 5,
    'wait_compensation': 2.00,
    'min_wage_per_hour': 70.00,
    'incentive_per_order': 17.04,
    'effective_from': '2026-01-01T00:00:00Z',
    'is_active': 1,
    'created_by': 'admin_seeder',
    'change_reason': 'Baseline Kerala Gig Workers Living Wage 2026',
  };

  final sampleHistory = [
    {
      'config_id': 2,
      'base_rate': 25.00,
      'per_km_rate': 12.00,
      'surge_bonus': 20.00,
      'wait_threshold_mins': 4,
      'wait_compensation': 3.00,
      'min_wage_per_hour': 80.00,
      'effective_from': '2026-12-01T00:00:00Z',
      'is_active': 0,
      'created_by': 'admin_raihan',
      'change_reason': 'Scheduled Q4 Festive Wage Hike',
    },
    {
      'config_id': 1,
      'base_rate': 20.00,
      'per_km_rate': 10.00,
      'surge_bonus': 15.00,
      'wait_threshold_mins': 5,
      'wait_compensation': 2.00,
      'min_wage_per_hour': 70.00,
      'effective_from': '2026-01-01T00:00:00Z',
      'is_active': 1,
      'created_by': 'admin_seeder',
      'change_reason': 'Baseline Kerala Gig Workers Living Wage 2026',
    },
    {
      'config_id': 0,
      'base_rate': 15.00,
      'per_km_rate': 8.00,
      'surge_bonus': 10.00,
      'wait_threshold_mins': 10,
      'wait_compensation': 1.50,
      'min_wage_per_hour': 60.00,
      'effective_from': '2025-06-01T00:00:00Z',
      'is_active': 0,
      'created_by': 'system_init',
      'change_reason': 'Legacy 2025 trial rates',
    },
  ];

  group('AdminPanelScreen Widget Tests (Screen 20)', () {
    // ── Test 1: Renders Active Config & History Table (FR-38, FR-39) ─────────
    testWidgets('Renders active configuration card and historical audit trail (FR-38, FR-39)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPanelScreen(
            initialConfig: sampleActiveConfig,
            initialHistory: sampleHistory,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top title
      expect(find.text('Admin Panel — Pay Governance'), findsOneWidget);

      // Active Configuration Card (FR-38)
      expect(find.text('Currently Active Configuration'), findsOneWidget);
      expect(find.text('Config #1'), findsWidgets);
      expect(find.text('₹20'), findsWidgets); // Base Pay
      expect(find.text('₹10/km'), findsWidgets); // Distance
      expect(find.text('₹15'), findsWidgets); // Surge
      expect(find.text('5 min'), findsWidgets); // Wait Threshold
      expect(find.text('₹2'), findsWidgets); // Wait Comp
      expect(find.text('₹17.04'), findsWidgets); // FairDrop Incentive
      expect(find.text('₹70/hr'), findsWidgets); // Floor
      expect(find.textContaining('Baseline Kerala Gig Workers Living Wage 2026'), findsWidgets);

      // Config History & Audit Trail (FR-39)
      expect(find.byKey(const Key('admin_config_history_section')), findsOneWidget);
      expect(find.text('3 records'), findsOneWidget);

      // Lifecycle status chips in history
      expect(find.text('SCHEDULED'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('SUPERSEDED'), findsOneWidget);
      expect(find.textContaining('Scheduled Q4 Festive Wage Hike'), findsOneWidget);
      expect(find.textContaining('Legacy 2025 trial rates'), findsOneWidget);
    });

    // ── Test 2: Client-side Numeric & Mandatory Validation (FR-43) ───────────
    testWidgets('Client-side validation rejects invalid numbers, non-integers, empty reasons (FR-43)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPanelScreen(
            initialConfig: sampleActiveConfig,
            initialHistory: sampleHistory,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter invalid inputs:
      // Base rate = -5
      await tester.enterText(find.byKey(const Key('admin_base_rate_field')), '-5');
      // Wait threshold = 3.5 (must be whole integer)
      await tester.enterText(find.byKey(const Key('admin_wait_threshold_field')), '3.5');
      // Surge bonus = -2
      await tester.enterText(find.byKey(const Key('admin_surge_bonus_field')), '-2');
      // Change reason = empty
      await tester.enterText(find.byKey(const Key('admin_change_reason_field')), '');

      // Ensure button is visible & tap
      final updateBtn = find.byKey(const Key('admin_update_button'));
      await tester.ensureVisible(updateBtn);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      // Verify validation error messages are displayed
      expect(find.text('Must be > 0'), findsOneWidget);
      expect(find.text('Must be whole integer'), findsOneWidget);
      expect(find.text('Must be ≥ 0'), findsOneWidget);
      expect(find.text('Change reason is mandatory for audit trail compliance.'), findsOneWidget);

      // Modal should NOT open
      expect(find.byKey(const Key('admin_diff_dialog')), findsNothing);
    });

    // ── Test 3: Effective Date 7-Day Rule (FR-41) ────────────────────────────
    testWidgets('Rejects submission if effective date notice is missing or under 7 days (FR-41)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPanelScreen(
            initialConfig: sampleActiveConfig,
            initialHistory: sampleHistory,
            autoFetch: false,
            // Only 3 days in the future
            initialEffectiveDate: DateTime.now().add(const Duration(days: 3)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid numbers and reason
      await tester.enterText(find.byKey(const Key('admin_change_reason_field')), 'Valid fuel subsidy correction');

      // Attempt submit
      final updateBtn = find.byKey(const Key('admin_update_button'));
      await tester.ensureVisible(updateBtn);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      // Verify 7-day rule error banner appears
      expect(find.textContaining('Effective date must be at least 7 full days from today'), findsOneWidget);
      expect(find.byKey(const Key('admin_diff_dialog')), findsNothing);
    });

    // ── Test 4: Old → New Diff Confirmation Dialog (FR-44) ───────────────────
    testWidgets('Displays Old → New Diff comparison modal with Fairwork Principle 3 notice (FR-44)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final validFutureDate = DateTime.now().add(const Duration(days: 10));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPanelScreen(
            initialConfig: sampleActiveConfig,
            initialHistory: sampleHistory,
            autoFetch: false,
            initialEffectiveDate: validFutureDate,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Modify Base Rate to 30 and Wait Threshold to 8
      await tester.enterText(find.byKey(const Key('admin_base_rate_field')), '30.00');
      await tester.enterText(find.byKey(const Key('admin_wait_threshold_field')), '8');
      await tester.enterText(find.byKey(const Key('admin_change_reason_field')), 'Monsoon seasonal risk adjustment');

      // Open diff modal
      final updateBtn = find.byKey(const Key('admin_update_button'));
      await tester.ensureVisible(updateBtn);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      // Verify diff dialog opens
      expect(find.byKey(const Key('admin_diff_dialog')), findsOneWidget);
      expect(find.text('Confirm Pay Structure Revision'), findsOneWidget);
      expect(find.textContaining('Fairwork Principle 3 Compliant'), findsOneWidget);

      // Verify changed items have 'CHANGED' chips and unchanged have 'Same' chips
      expect(find.text('CHANGED'), findsNWidgets(2)); // Base Rate & Wait Threshold changed
      expect(find.text('Same'), findsNWidgets(5)); // Per-km, surge, incentive, wait comp, floor unchanged

      // Verify old values and new values within the dialog
      final dialogFinder = find.byKey(const Key('admin_diff_dialog'));
      expect(find.descendant(of: dialogFinder, matching: find.text('₹20.00')), findsOneWidget);
      expect(find.descendant(of: dialogFinder, matching: find.text('₹30.00')), findsOneWidget);
      expect(find.descendant(of: dialogFinder, matching: find.text('5 min')), findsOneWidget);
      expect(find.descendant(of: dialogFinder, matching: find.text('8 min')), findsOneWidget);

      // Verify reason is shown within dialog
      expect(find.descendant(of: dialogFinder, matching: find.textContaining('Monsoon seasonal risk adjustment')), findsOneWidget);

      // Verify action buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byKey(const Key('admin_confirm_diff_button')), findsOneWidget);
    });

    // ── Test 5: Confirm & Schedule Pay Revision (FR-44, FR-45) ────────────────
    testWidgets('Confirming diff invokes update callback and displays success notice (FR-45)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final validFutureDate = DateTime.now().add(const Duration(days: 14));
      Map<String, dynamic>? submittedParams;

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPanelScreen(
            initialConfig: sampleActiveConfig,
            initialHistory: sampleHistory,
            autoFetch: false,
            initialEffectiveDate: validFutureDate,
            onUpdateConfig: (params) async {
              submittedParams = params;
              return {
                'success': true,
                'notice': 'Revision scheduled for ${params['effective_from']} with statutory 14-day worker notice.',
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Update values
      await tester.enterText(find.byKey(const Key('admin_base_rate_field')), '28.00');
      await tester.enterText(find.byKey(const Key('admin_per_km_rate_field')), '14.00');
      await tester.enterText(find.byKey(const Key('admin_change_reason_field')), 'Kerala minimum wage revision 2026');

      // Open diff dialog
      final updateBtn = find.byKey(const Key('admin_update_button'));
      await tester.ensureVisible(updateBtn);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      // Tap Confirm & Schedule
      final confirmBtn = find.byKey(const Key('admin_confirm_diff_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify callback received properly parsed types
      expect(submittedParams, isNotNull);
      expect(submittedParams!['base_rate'], 28.00);
      expect(submittedParams!['per_km_rate'], 14.00);
      expect(submittedParams!['wait_threshold_mins'], 5); // int
      expect(submittedParams!['incentive_per_order'], 17.04);
      expect(submittedParams!['change_reason'], 'Kerala minimum wage revision 2026');

      // Dialog is dismissed
      expect(find.byKey(const Key('admin_diff_dialog')), findsNothing);

      // Success message is displayed
      expect(find.textContaining('Pay configuration revision successfully scheduled!'), findsOneWidget);
      expect(find.textContaining('Kerala minimum wage revision 2026'), findsNothing); // field was cleared
    });

    testWidgets('AppBar shows visible title, reload button, and logout button with confirm dialog (F28 / R22)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/login': (context) => const Scaffold(body: Text('Login Screen')),
          },
          home: AdminPanelScreen(
            initialConfig: sampleActiveConfig,
            initialHistory: sampleHistory,
            autoFetch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title is rendered with white text style
      final titleWidget = tester.widget<Text>(find.text('Admin Panel — Pay Governance'));
      expect(titleWidget.style?.color, Colors.white);

      // Verify buttons exist
      expect(find.byKey(const Key('btn_reload_admin_config')), findsOneWidget);
      expect(find.byKey(const Key('btn_admin_logout')), findsOneWidget);

      // Tap logout button to open confirmation dialog
      await tester.tap(find.byKey(const Key('btn_admin_logout')));
      await tester.pumpAndSettle();

      expect(find.text('Log Out'), findsWidgets);
      expect(find.text('Are you sure you want to log out of Admin Panel?'), findsOneWidget);
      expect(find.byKey(const Key('btn_cancel_admin_logout')), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_admin_logout')), findsOneWidget);

      // Tap Cancel dismisses dialog
      await tester.tap(find.byKey(const Key('btn_cancel_admin_logout')));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to log out of Admin Panel?'), findsNothing);
    });
  });
}

