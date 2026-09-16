// ============================================================================
// FairDrop — Widget Test
// ============================================================================
// This test verifies that the app starts without crashing.
// Run with: flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import our app (FairDropApp, not the old MyApp)
import 'package:fairdrop_app/main.dart';

void main() {
  testWidgets('App starts and shows home screen', (WidgetTester tester) async {
    // Build the app and trigger a frame (renders the first screen)
    await tester.pumpWidget(const FairDropApp());

    // Verify the home screen title is visible
    expect(find.text('FairDrop'), findsOneWidget);

    // Verify navigation cards are visible
    expect(find.text('Pay Breakdown'), findsOneWidget);
    expect(find.text('Rider Dashboard'), findsOneWidget);
    expect(find.text('Admin Panel'), findsOneWidget);
  });
}
