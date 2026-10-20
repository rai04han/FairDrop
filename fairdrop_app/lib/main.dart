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
import 'package:google_fonts/google_fonts.dart';

// Import screen files (each screen is a separate file).
// These are placeholder screens for now — real implementations
// will be built on separate branches (Week 9–12).
import 'config/theme.dart';
import 'screens/pay_breakdown_screen.dart';
import 'screens/rider_dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/login_screen.dart';
import 'screens/zone_map_screen.dart';
import 'screens/order_screen.dart';
import 'screens/splash_screen.dart';            // FR-1
import 'screens/rider_home_screen.dart';        // FR-7
import 'screens/order_acceptance_screen.dart';  // FR-11
import 'screens/active_delivery_screen.dart';   // FR-17
import 'screens/onboarding_screen.dart';        // FR-46
import 'screens/profile_screen.dart';           // FR-47
import 'screens/unsupported_role_screen.dart';  // FR-6
import 'screens/customer_shell_screen.dart';     // FR-55
import 'screens/restaurant_shell_screen.dart';   // FR-62
import 'screens/rider_signup_screen.dart';       // FR-51
import 'screens/customer/delivery_location_screen.dart'; // Screen 11 (FR-55)
import 'screens/customer/restaurant_list_screen.dart';   // Screen 12 (FR-56)
import 'screens/customer/restaurant_menu_screen.dart';   // Screen 13 (FR-57)
import 'screens/customer/cart_screen.dart';              // Screen 14 (FR-58)
import 'screens/customer/mock_payment_screen.dart';      // Screen 15 (FR-59)
import 'screens/customer/order_confirmation_screen.dart';// Screen 16 (FR-60)
import 'screens/restaurant/menu_management_screen.dart'; // Screen 17 (FR-62, FR-64)
import 'screens/restaurant/add_edit_menu_item_screen.dart'; // Screen 18 (FR-63)
import 'screens/restaurant/restaurant_orders_screen.dart'; // Screen 19 (FR-65, FR-66, FR-69)
import 'screens/customer/customer_order_history_screen.dart'; // Screen 22 (FR-61)
import 'services/core_api_service.dart';

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
      // Tailored FairDrop design system from Stitch project #1184075210986276795
      theme: FairDropTheme.lightTheme,

      // ── Routes ────────────────────────────────────────────────────────
      // Routes map URL-like paths to screen widgets.
      // Navigator.pushNamed(context, '/pay-breakdown') → shows PayBreakdownScreen
      //
      // '/' is the home route — shown when the app first opens.
      initialRoute: '/splash',
      routes: {
        '/':                 (context) => const HomeScreen(),
        '/splash':           (context) => const SplashScreen(),
        '/login':            (context) => const LoginScreen(),
        '/rider-home':       (context) => const RiderHomeScreen(),
        '/order-acceptance': (context) => const OrderAcceptanceScreen(),
        '/active-delivery':  (context) => const ActiveDeliveryScreen(),
        '/onboarding':       (context) => const OnboardingScreen(),
        '/profile':          (context) => const ProfileScreen(),
        '/unsupported-role': (context) => const UnsupportedRoleScreen(),
        '/zone-map':         (context) => const ZoneMapScreen(),
        '/orders':           (context) => const OrderScreen(),
        '/pay-breakdown':    (context) => const PayBreakdownScreen(),
        '/delivery-summary': (context) => const PayBreakdownScreen(),
        '/rider-dashboard':  (context) => const RiderDashboardScreen(),
        '/analytics':        (context) => const AnalyticsScreen(),
        '/admin-panel':                  (context) => const AdminPanelScreen(),
        '/customer':                     (context) => const CustomerShellScreen(),
        '/customer/location':            (context) => const DeliveryLocationScreen(),
        '/customer/restaurants':         (context) => const RestaurantListScreen(),
        '/customer/menu':                (context) => const RestaurantMenuScreen(),
        '/customer/cart':                (context) => const CartScreen(),
        '/customer/payment':             (context) => const MockPaymentScreen(),
        '/customer/order-confirmation':  (context) => const OrderConfirmationScreen(),
        '/customer/history':             (context) => const CustomerOrderHistoryScreen(),
        '/restaurant':                   (context) => const RestaurantShellScreen(),
        '/restaurant/menu':              (context) => const MenuManagementScreen(),
        '/restaurant/menu/add':          (context) => const AddEditMenuItemScreen(),
        '/restaurant/orders':            (context) => const RestaurantOrdersScreen(),
        '/rider-signup':                 (context) => const RiderSignupScreen(),
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
    // Scaffold is the basic screen structure: AppBar (top) + Body (content).
    // Almost every screen in Flutter uses Scaffold.
    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      // ── App Bar ─────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const FairDropLogo(fontSize: 22),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await CoreApiService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),

      // ── Body ────────────────────────────────────────────────────────
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: FairDropColors.cardShadow,
                  border: Border.all(color: FairDropColors.mintBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      'Pay Transparency & Equity Engine',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandNavy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Algorithmically fair pay for gig delivery workers in Kollam, Kerala',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: FairDropColors.slateMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Navigation Cards ────────────────────────────────────
              _buildNavCard(
                context: context,
                icon: Icons.app_registration_rounded,
                title: 'Rider Registration',
                subtitle: 'New delivery worker signup with automatic zone assignment',
                route: '/rider-signup',
                color: FairDropColors.brandGreen,
              ),
              const SizedBox(height: 10),

              _buildNavCard(
                context: context,
                icon: Icons.two_wheeler_rounded,
                title: 'Rider Shift & Offers',
                subtitle: 'Live shift pay, proportion stack & instant dispatch acceptance',
                route: '/rider-home',
                color: FairDropColors.brandGreen,
              ),
              const SizedBox(height: 10),

              _buildNavCard(
                context: context,
                icon: Icons.receipt_long_rounded,
                title: 'Pay Breakdown & Simulator',
                subtitle: 'Line-by-line itemized transparency and formula calculation',
                route: '/pay-breakdown',
                color: FairDropColors.brandOrange,
              ),
              const SizedBox(height: 10),

              _buildNavCard(
                context: context,
                icon: Icons.person_rounded,
                title: 'Rider Profile & Rate Cards',
                subtitle: 'Worker details, active shift status & wage guarantees',
                route: '/profile',
                color: FairDropColors.payWait,
              ),
              const SizedBox(height: 10),

              _buildNavCard(
                context: context,
                icon: Icons.map_rounded,
                title: 'Zone Map',
                subtitle: 'Interactive map of Kollam delivery zones & wage floors',
                route: '/zone-map',
                color: FairDropColors.brandNavy,
              ),
              const SizedBox(height: 10),

              _buildNavCard(
                context: context,
                icon: Icons.shopping_bag_rounded,
                title: 'Orders',
                subtitle: 'Place an order and track delivery status',
                route: '/orders',
                color: FairDropColors.warningAmber,
              ),
              const SizedBox(height: 10),

              _buildNavCard(
                context: context,
                icon: Icons.bar_chart_rounded,
                title: 'Rider Dashboard',
                subtitle: 'Earnings history, minimum wage status & delivery ledger',
                route: '/rider-dashboard',
                color: FairDropColors.brandGreen,
              ),
              const SizedBox(height: 10),

              _buildNavCard(
                context: context,
                icon: Icons.analytics_rounded,
                title: 'Pay Analytics (Screen 10)',
                subtitle: 'FairDrop vs cliff-bonus comparison with cliff-wins scenario',
                route: '/analytics',
                color: FairDropColors.brandOrange,
              ),
              const SizedBox(height: 10),

              _buildNavCard(
                context: context,
                icon: Icons.admin_panel_settings_rounded,
                title: 'Admin Panel',
                subtitle: 'Configure pay constants with 7-day advance notice',
                route: '/admin-panel',
                color: FairDropColors.slateMuted,
              ),
              const SizedBox(height: 10),

              _buildNavCard(
                context: context,
                icon: Icons.person_pin_circle_rounded,
                title: 'Customer Portal',
                subtitle: 'Delivery location picker, restaurant menus & transparent cart',
                route: '/customer',
                color: FairDropColors.brandGreen,
              ),
              const SizedBox(height: 10),

              _buildNavCard(
                context: context,
                icon: Icons.storefront_rounded,
                title: 'Restaurant Portal',
                subtitle: 'Partner kitchen, menu items, prep timers & live orders',
                route: '/restaurant',
                color: FairDropColors.brandOrange,
              ),
              const SizedBox(height: 24),

              // ── Footer ─────────────────────────────────────────────
              Text(
                'FairDrop v1.0.0 — MCA Mini Project 23MCAM307',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: FairDropColors.slateMuted,
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
