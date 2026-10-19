// ============================================================================
// FairDrop — Widget Test
// ============================================================================
// Verifies that the application boots and renders the splash screen (FR-1).
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/main.dart';
import 'package:fairdrop_app/screens/splash_screen.dart';
import 'package:fairdrop_app/config/theme.dart';

void main() {
  testWidgets('App starts and renders splash screen with brand logo', (WidgetTester tester) async {
    // Build the app and trigger a frame
    await tester.pumpWidget(const FairDropApp());

    // Allow animations to initiate
    await tester.pump();

    // Verify SplashScreen is rendered
    expect(find.byType(SplashScreen), findsOneWidget);

    // Verify FairDrop logo is displayed
    expect(find.byType(FairDropLogo), findsOneWidget);

    // Verify subtitle or brand message is displayed
    expect(find.textContaining('Transparent Algorithmic Pay'), findsOneWidget);
  });
}
