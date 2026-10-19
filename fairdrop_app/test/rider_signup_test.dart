// ============================================================================
// FairDrop — Rider Signup Screen Widget & Form Tests (FR-51, FR-52, FR-53)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/rider_signup_screen.dart';

void main() {
  group('RiderSignupScreen Widget Tests', () {
    testWidgets('renders all required signup fields and vehicle options without role selector', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RiderSignupScreen(),
        ),
      );

      await tester.pump();

      // Verify Screen title
      expect(find.text('Rider Registration'), findsOneWidget);

      // Verify form labels
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Vehicle Type'), findsOneWidget);

      // Verify vehicle choices
      expect(find.text('Motorcycle'), findsOneWidget);
      expect(find.text('Scooter'), findsOneWidget);
      expect(find.text('Electric Vehicle'), findsOneWidget);
      expect(find.text('Bicycle'), findsOneWidget);

      // Verify FR-52 automatic zone assignment banner is present
      expect(find.textContaining('Automatic Zone Assignment (FR-52)'), findsOneWidget);

      // Verify NO role selector is present (FR-51)
      expect(find.text('Select Your Role'), findsNothing);
      expect(find.text('customer'), findsNothing);
      expect(find.text('restaurant'), findsNothing);

      // Verify Submit button
      expect(find.text('Create Rider Account'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitted with empty fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RiderSignupScreen(),
        ),
      );

      await tester.pump();

      // Ensure submit button is scrolled into view and tap it
      final submitButton = find.text('Create Rider Account');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      // Validation errors should appear
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password must be at least 4 characters'), findsOneWidget);
    });

    testWidgets('allows selecting different vehicle types', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RiderSignupScreen(),
        ),
      );

      await tester.pump();

      // Ensure Scooter chip is visible and tap
      final scooterFinder = find.text('Scooter');
      await tester.ensureVisible(scooterFinder);
      await tester.tap(scooterFinder);
      await tester.pump();

      final scooterChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Scooter'),
      );
      expect(scooterChip.selected, isTrue);

      final motorcycleChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Motorcycle'),
      );
      expect(motorcycleChip.selected, isFalse);
    });
  });
}
