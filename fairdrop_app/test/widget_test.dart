// ============================================================================
// FairDrop — Widget Test
// ============================================================================
// This test verifies that the app starts without crashing.
// Run with: flutter test

import 'package:flutter_test/flutter_test.dart';

// Import our app (FairDropApp, not the old MyApp)
import 'package:fairdrop_app/main.dart';

void main() {
  testWidgets('App starts and shows splash screen', (WidgetTester tester) async {
    // Build the app and trigger a frame (renders the first screen)
    await tester.pumpWidget(const FairDropApp());

    // Verify the splash screen title is visible (FR-1)
    expect(find.text('FairDrop'), findsOneWidget);
  });
}
