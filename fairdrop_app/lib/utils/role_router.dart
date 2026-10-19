// ============================================================================
// FairDrop — Role-Based Routing Utility (FR-1, FR-4, FR-6)
// ============================================================================
// Single source of truth for role-to-route mappings.
// Supported roles: rider, customer, restaurant, admin.
// Any other role routes to /unsupported-role.
// ============================================================================

class RoleRouter {
  static const String routeSplash = '/splash';
  static const String routeLogin = '/login';
  static const String routeRiderHome = '/rider-home';
  static const String routeCustomer = '/customer';
  static const String routeRestaurant = '/restaurant';
  static const String routeAdmin = '/admin-panel';
  static const String routeOnboarding = '/onboarding';
  static const String routeUnsupported = '/unsupported-role';

  /// Returns the target route for a given user role.
  static String getRouteForRole(String? role, {bool isOnboarded = true}) {
    if (role == null) return routeLogin;

    switch (role.toLowerCase().trim()) {
      case 'rider':
        return isOnboarded ? routeRiderHome : routeOnboarding;
      case 'customer':
        return routeCustomer;
      case 'restaurant':
        return routeRestaurant;
      case 'admin':
        return routeAdmin;
      default:
        return routeUnsupported;
    }
  }

  /// Checks if a given role is one of the four official FairDrop roles.
  static bool isSupportedRole(String? role) {
    if (role == null) return false;
    const supported = {'rider', 'customer', 'restaurant', 'admin'};
    return supported.contains(role.toLowerCase().trim());
  }
}
