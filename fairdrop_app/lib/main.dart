// ============================================================================
// FairDrop Flutter App — Main Entry Point
// ============================================================================
// Owner: Shared (Raihan + Harikrishnan)
//
// PURPOSE:
//   This is the FIRST file that runs when the app starts.
//   It sets up:
//     1. The app's visual theme (colors, fonts, dark mode)
//     2. The navigation routes (which screen to show for each URL path)
//     3. The home screen (landing page with buttons to each feature)
//
// HOW FLUTTER APPS START:
//   main() → runApp() → MaterialApp → HomeScreen
//   That's it. Every Flutter app follows this exact startup sequence.
// ============================================================================

// 'package:flutter/material.dart' gives us ALL the UI widgets:
// Text, Button, Scaffold, AppBar, Colors, Icons, etc.
// Almost every Dart file in a Flutter app imports this.
import 'package:flutter/material.dart';

// Import screen files (each screen is a separate file).
// These are placeholder screens for now — real implementations
// will be built on separate branches (Week 9–12).
import 'screens/pay_breakdown_screen.dart';
import 'screens/rider_dashboard_screen.dart';
import 'screens/admin_panel_screen.dart';

// ============================================================================
// main() — The very first function that runs
// ============================================================================
// Every Dart program starts here, just like main() in C or Java.
// runApp() takes a Widget and makes it the root of the entire app.
void main() {
  runApp(const FairDropApp());
}

// ============================================================================
// FairDropApp — The root widget of the application
// ============================================================================
// StatelessWidget = a widget that never changes after it's built.
// The app configuration (theme, routes) is fixed, so StatelessWidget is correct.
//
// 'const' means this widget is compile-time constant — Flutter can
// optimize it by creating it only once and reusing it.
class FairDropApp extends StatelessWidget {
  const FairDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp is Flutter's top-level widget for Material Design apps.
    // It provides: theme, navigation, routing, and app-wide settings.
    return MaterialApp(
      // ── App metadata ──────────────────────────────────────────────────
      title: 'FairDrop',

      // Hide the red "DEBUG" banner in the top-right corner
      debugShowCheckedModeBanner: false,

      // ── Theme ─────────────────────────────────────────────────────────
      // This defines the visual style for the ENTIRE app.
      // Every screen inherits these colors, fonts, and styles.
      theme: ThemeData(
        // colorSchemeSeed picks a base color and generates a harmonious
        // palette (primary, secondary, surface, background, error, etc.)
        colorSchemeSeed: const Color(0xFF00897B), // Teal 600 — worker equity theme
        brightness: Brightness.light,

        // useMaterial3 enables Material Design 3 (Google's latest design system)
        // Gives you rounded corners, updated buttons, and modern elevation
        useMaterial3: true,

        // AppBar theme — the top bar on every screen
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),

        // Card theme — for the info cards on dashboard and breakdown screens
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ── Dark theme ────────────────────────────────────────────────────
      // Automatically used when the device is in dark mode.
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF00897B),
        brightness: Brightness.dark,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Use system setting (light/dark) — respects user's device preference
      themeMode: ThemeMode.system,

      // ── Routes ────────────────────────────────────────────────────────
      // Routes map URL-like paths to screen widgets.
      // Navigator.pushNamed(context, '/pay-breakdown') → shows PayBreakdownScreen
      //
      // '/' is the home route — shown when the app first opens.
      initialRoute: '/',
      routes: {
        '/':                (context) => const HomeScreen(),
        '/pay-breakdown':   (context) => const PayBreakdownScreen(),
        '/rider-dashboard': (context) => const RiderDashboardScreen(),
        '/admin-panel':     (context) => const AdminPanelScreen(),
        // Hari's screens will be added here during integration (Week 10):
        // '/login':         (context) => const LoginScreen(),
        // '/order-accept':  (context) => const OrderAcceptanceScreen(),
        // '/zone-map':      (context) => const ZoneMapScreen(),
      },
    );
  }
}

// ============================================================================
// HomeScreen — Landing page with navigation to all features
// ============================================================================
// This is a temporary home screen for development.
// In the final app, the Login screen (Hari's) will be the first screen,
// and this becomes the rider's main menu after login.
//
// StatelessWidget because this screen has no changing state — it's just
// a list of navigation buttons.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 'Theme.of(context)' reads the theme we defined in MaterialApp above.
    // This way, if we change colors in the theme, all screens update automatically.
    final theme = Theme.of(context);

    // Scaffold is the basic screen structure: AppBar (top) + Body (content).
    // Almost every screen in Flutter uses Scaffold.
    return Scaffold(
      // ── App Bar ─────────────────────────────────────────────────────
      appBar: AppBar(
        title: const Text('FairDrop'),
      ),

      // ── Body ────────────────────────────────────────────────────────
      // SafeArea prevents content from being hidden behind the status bar
      // or phone notch.
      body: SafeArea(
        child: Padding(
          // EdgeInsets.all(16) adds 16 pixels of space on all four sides.
          padding: const EdgeInsets.all(16),
          child: Column(
            // Column stacks children vertically (top to bottom).
            // CrossAxisAlignment.stretch makes children fill the full width.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Text(
                'Pay Transparency Engine',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Algorithmically fair pay for gig delivery workers',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── Navigation Cards ────────────────────────────────────
              // Each card navigates to a different screen when tapped.

              _buildNavCard(
                context: context,
                icon: Icons.receipt_long,
                title: 'Pay Breakdown',
                subtitle: 'Calculate and view delivery pay with line-by-line transparency',
                route: '/pay-breakdown',
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),

              _buildNavCard(
                context: context,
                icon: Icons.bar_chart,
                title: 'Rider Dashboard',
                subtitle: 'Earnings history and FairDrop vs cliff-bonus comparison',
                route: '/rider-dashboard',
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(height: 12),

              _buildNavCard(
                context: context,
                icon: Icons.admin_panel_settings,
                title: 'Admin Panel',
                subtitle: 'Configure pay constants with 7-day advance notice',
                route: '/admin-panel',
                color: theme.colorScheme.secondary,
              ),

              // Spacer pushes the version text to the bottom of the screen.
              const Spacer(),

              // ── Footer ─────────────────────────────────────────────
              Text(
                'FairDrop v1.0.0 — MCA Mini Project 23MCAM307',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper method to build a navigation card ──────────────────────────────
  //
  // This is a private method (starts with '_') that creates a tappable card.
  // We extracted it to avoid repeating the same Card + ListTile code 3 times.
  //
  // 'Widget' is the return type — everything visible in Flutter is a Widget.
  Widget _buildNavCard({
    required BuildContext context, // needed for navigation
    required IconData icon,       // the icon to show (e.g., Icons.receipt_long)
    required String title,        // card title
    required String subtitle,     // card description
    required String route,        // route to navigate to (e.g., '/pay-breakdown')
    required Color color,         // icon and accent color
  }) {
    return Card(
      // InkWell adds a tap ripple effect AND an onTap handler.
      child: InkWell(
        // borderRadius makes the ripple effect follow the card's rounded corners.
        borderRadius: BorderRadius.circular(12),

        // onTap fires when the user taps this card.
        // Navigator.pushNamed() navigates to the route we specified.
        // Think of it as: "push a new screen onto the navigation stack."
        // The user can press the back button to return here.
        onTap: () => Navigator.pushNamed(context, route),

        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            // Row stacks children horizontally (left to right).
            children: [
              // Icon in a colored circle
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),

              // Expanded makes this child take up all remaining horizontal space.
              // Without Expanded, long text would overflow off the screen.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon on the right — visual hint that this is tappable
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
