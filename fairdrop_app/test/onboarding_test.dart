// ============================================================================
// FairDrop — Onboarding Screen Widget Tests (Screen 21, FR-46)
// ============================================================================
// PRD Feature: FR-46 (4-slide onboarding, safety/fairwork checklist, server sync)
// Fairwork Principles: Fair Contracts P6, Fair Conditions P3, Fair Pay P1
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairdrop_app/screens/onboarding_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingScreen Widget Tests (Screen 21, FR-46)', () {
    // ── Test 1: Slide 1 Initial Render and Navigation ───────────────────────
    testWidgets('Renders Slide 1 and advances to Slide 2 on Next tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Slide 1 contents
      expect(find.text('Transparent\nEarnings'), findsOneWidget);
      expect(find.text('100% Upfront Breakdown'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_skip_button')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_next_button')), findsOneWidget);

      // Tap Next button to advance to Slide 2
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Verify Slide 2 contents
      expect(find.text('Kerala Minimum\nWage Guarantee'), findsOneWidget);
      expect(find.text('Guaranteed Safety Net'), findsOneWidget);
    });

    // ── Test 2: Skip Button Jumps to Final Checklist Slide ───────────────────
    testWidgets('Skip button jumps directly to mandatory checklist slide (FR-46)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Skip
      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pumpAndSettle();

      // Verify we arrived at Checklist slide
      expect(find.text('Safety & Fairwork Checklist'), findsOneWidget);
      expect(find.text('MANDATORY STEP (FR-46)'), findsOneWidget);
      expect(find.text('Please verify all 6 requirements before accepting your first delivery.'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_skip_button')), findsNothing); // Skip hidden on final page
      expect(find.byKey(const Key('onboarding_complete_button')), findsOneWidget);
    });

    // ── Test 3: Checklist Validation & Button Enablement ────────────────────
    testWidgets('Completion button remains disabled until all 6 checklist items are checked', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(initialPage: 3),
        ),
      );
      await tester.pumpAndSettle();

      final completeBtnFinder = find.byKey(const Key('onboarding_complete_button'));
      expect(completeBtnFinder, findsOneWidget);

      // Initially disabled
      FilledButton buttonWidget = tester.widget<FilledButton>(completeBtnFinder);
      expect(buttonWidget.onPressed, isNull);

      // Check the first 5 items
      for (int i = 0; i < 5; i++) {
        final itemFinder = find.byKey(Key('checklist_item_$i'));
        await tester.ensureVisible(itemFinder);
        await tester.tap(itemFinder);
        await tester.pumpAndSettle();
      }

      // Still disabled with 5/6 items
      buttonWidget = tester.widget<FilledButton>(completeBtnFinder);
      expect(buttonWidget.onPressed, isNull);

      // Check the final 6th item
      final lastItemFinder = find.byKey(const Key('checklist_item_5'));
      await tester.ensureVisible(lastItemFinder);
      await tester.tap(lastItemFinder);
      await tester.pumpAndSettle();

      // Now enabled
      buttonWidget = tester.widget<FilledButton>(completeBtnFinder);
      expect(buttonWidget.onPressed, isNotNull);
    });

    // ── Test 4: Server Synchronization & Local Persistence (FR-46) ───────────
    testWidgets('Tapping completion synchronizes with server and saves SharedPreferences flag', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool serverSyncInvoked = false;
      bool completionCallbackInvoked = false;

      // Pre-fill all 6 checklist items as true
      final allCheckedMap = {
        'I have read the FairDrop upfront pay formula policy': true,
        'I understand rate card changes require 7 days advance notice': true,
        'My vehicle is roadworthy, insured, and has valid PUC': true,
        'I hold a valid two-wheeler driving licence': true,
        'I will wear my helmet and obey traffic rules at all times': true,
        'I understand I can decline any order with zero penalty': true,
      };

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/rider-home': (context) => const Scaffold(body: Text('Rider Home Route Target')),
          },
          home: OnboardingScreen(
            initialPage: 3,
            initialChecklist: allCheckedMap,
            onAcknowledge: () async {
              serverSyncInvoked = true;
              return {
                'success': true,
                'message': 'Safety checklist acknowledged successfully.',
              };
            },
            onComplete: () {
              completionCallbackInvoked = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final completeBtn = find.byKey(const Key('onboarding_complete_button'));
      await tester.ensureVisible(completeBtn);
      await tester.tap(completeBtn);
      await tester.pumpAndSettle();

      // Assert server sync was invoked
      expect(serverSyncInvoked, isTrue);
      expect(completionCallbackInvoked, isTrue);

      // Assert local SharedPreferences was updated
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_complete'), isTrue);
    });

    // ── Test 5: Graceful Error Handling on Server Failure ───────────────────
    testWidgets('Gracefully completes and caches locally even if server sync fails', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool completionCallbackInvoked = false;

      final allCheckedMap = {
        'I have read the FairDrop upfront pay formula policy': true,
        'I understand rate card changes require 7 days advance notice': true,
        'My vehicle is roadworthy, insured, and has valid PUC': true,
        'I hold a valid two-wheeler driving licence': true,
        'I will wear my helmet and obey traffic rules at all times': true,
        'I understand I can decline any order with zero penalty': true,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            initialPage: 3,
            initialChecklist: allCheckedMap,
            onAcknowledge: () async {
              throw Exception('Simulated 500 Core-Service Offline');
            },
            onComplete: () {
              completionCallbackInvoked = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final completeBtn = find.byKey(const Key('onboarding_complete_button'));
      await tester.ensureVisible(completeBtn);
      await tester.tap(completeBtn);
      await tester.pumpAndSettle();

      // Non-blocking completion succeeded despite server exception
      expect(completionCallbackInvoked, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_complete'), isTrue);
    });
  });
}
