// ============================================================================
// FairDrop — Role Routing & Shells Unit & Widget Tests (FR-1, FR-4, FR-6)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/utils/role_router.dart';
import 'package:fairdrop_app/screens/customer_shell_screen.dart';
import 'package:fairdrop_app/screens/restaurant_shell_screen.dart';
import 'package:fairdrop_app/screens/unsupported_role_screen.dart';

void main() {
  group('RoleRouter Unit Tests', () {
    test('routes rider to /rider-home when onboarded', () {
      expect(RoleRouter.getRouteForRole('rider', isOnboarded: true), '/rider-home');
      expect(RoleRouter.getRouteForRole('RIDER', isOnboarded: true), '/rider-home');
    });

    test('routes rider to /onboarding when not onboarded', () {
      expect(RoleRouter.getRouteForRole('rider', isOnboarded: false), '/onboarding');
    });

    test('routes customer to /customer', () {
      expect(RoleRouter.getRouteForRole('customer'), '/customer');
      expect(RoleRouter.getRouteForRole('CUSTOMER'), '/customer');
    });

    test('routes restaurant to /restaurant', () {
      expect(RoleRouter.getRouteForRole('restaurant'), '/restaurant');
      expect(RoleRouter.getRouteForRole('RESTAURANT'), '/restaurant');
    });

    test('routes admin to /admin-panel', () {
      expect(RoleRouter.getRouteForRole('admin'), '/admin-panel');
      expect(RoleRouter.getRouteForRole('ADMIN'), '/admin-panel');
    });

    test('routes unknown roles to /unsupported-role', () {
      expect(RoleRouter.getRouteForRole('driver'), '/unsupported-role');
      expect(RoleRouter.getRouteForRole('manager'), '/unsupported-role');
      expect(RoleRouter.getRouteForRole('guest'), '/unsupported-role');
      expect(RoleRouter.getRouteForRole(''), '/unsupported-role');
    });

    test('routes null role to /login', () {
      expect(RoleRouter.getRouteForRole(null), '/login');
    });

    test('isSupportedRole validates 4 official roles', () {
      expect(RoleRouter.isSupportedRole('rider'), isTrue);
      expect(RoleRouter.isSupportedRole('customer'), isTrue);
      expect(RoleRouter.isSupportedRole('restaurant'), isTrue);
      expect(RoleRouter.isSupportedRole('admin'), isTrue);
      expect(RoleRouter.isSupportedRole('Rider'), isTrue);
      expect(RoleRouter.isSupportedRole('superadmin'), isFalse);
      expect(RoleRouter.isSupportedRole('unknown'), isFalse);
      expect(RoleRouter.isSupportedRole(null), isFalse);
    });
  });

  group('Role Shells Widget Tests', () {
    testWidgets('CustomerShellScreen renders greeting and order actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerShellScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(CustomerShellScreen), findsOneWidget);
      expect(find.textContaining('Start New Delivery Order'), findsOneWidget);
      expect(find.textContaining('Order History'), findsOneWidget);
    });

    testWidgets('RestaurantShellScreen renders menu management and orders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RestaurantShellScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(RestaurantShellScreen), findsOneWidget);
      expect(find.text('Menu Management'), findsOneWidget);
      expect(find.text('Incoming Orders'), findsOneWidget);
    });

    testWidgets('UnsupportedRoleScreen renders notice and logout button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnsupportedRoleScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(UnsupportedRoleScreen), findsOneWidget);
      expect(find.text("This role isn't supported"), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });
  });
}
