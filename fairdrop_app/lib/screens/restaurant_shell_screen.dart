// ============================================================================
// FairDrop — Restaurant Shell Screen (FR-6, FR-62, FR-65)
// ============================================================================
// Primary portal entry point for authenticated Restaurant partners.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/core_api_service.dart';

class RestaurantShellScreen extends StatefulWidget {
  const RestaurantShellScreen({super.key});

  @override
  State<RestaurantShellScreen> createState() => _RestaurantShellScreenState();
}

class _RestaurantShellScreenState extends State<RestaurantShellScreen> {
  String _restaurantName = 'Restaurant Partner';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRestaurantInfo();
  }

  Future<void> _loadRestaurantInfo() async {
    try {
      final me = await CoreApiService.getMe();
      if (mounted) {
        setState(() {
          _restaurantName = me['user']?['name'] as String? ?? 'Restaurant Partner';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await CoreApiService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const FairDropLogo(fontSize: 22),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: FairDropColors.brandNavy),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Restaurant Profile Banner ────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: FairDropColors.cardShadow,
                        border: Border.all(color: FairDropColors.mintBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: FairDropColors.brandOrange.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.restaurant_rounded,
                              color: FairDropColors.brandOrange,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _restaurantName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: FairDropColors.brandNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Partner Kitchen • Menu & Orders Portal',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: FairDropColors.slateMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Card 1: Menu Management (FR-62, FR-63, FR-64) ────────
                    InkWell(
                      key: const Key('restaurant_menu_management_card'),
                      onTap: () => Navigator.pushNamed(context, '/restaurant/menu'),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: FairDropColors.cardShadow,
                          border: Border.all(color: FairDropColors.mintBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: FairDropColors.brandGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: FairDropColors.brandGreen,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Menu Management',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: FairDropColors.brandNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add items, set prep seconds, and toggle availability.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: FairDropColors.slateMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: FairDropColors.slateMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Card 2: Kitchen Orders (FR-65, FR-66) ────────────────
                    InkWell(
                      key: const Key('restaurant_incoming_orders_card'),
                      onTap: () => Navigator.pushNamed(context, '/restaurant/orders'),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: FairDropColors.cardShadow,
                          border: Border.all(color: FairDropColors.mintBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: FairDropColors.brandNavy.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: FairDropColors.brandNavy,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Incoming Orders',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: FairDropColors.brandNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'View accepted orders with automatic prep timers.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: FairDropColors.slateMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: FairDropColors.slateMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
