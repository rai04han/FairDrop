// ============================================================================
// FairDrop — Restaurant List Screen (Screen 12, FR-56)
// ============================================================================
// Displays restaurants in Kollam with live distance from selected delivery pin,
// cuisine tags, ratings, and operating hours.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/cart_service.dart';
import '../../services/core_api_service.dart';
import '../../utils/geo_utils.dart';

class RestaurantListScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialRestaurants;

  const RestaurantListScreen({super.key, this.initialRestaurants});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  List<Map<String, dynamic>> _restaurants = [];
  bool _isLoading = true;
  String? _errorMessage;


  @override
  void initState() {
    super.initState();
    if (widget.initialRestaurants != null) {
      _restaurants = widget.initialRestaurants!;
      _isLoading = false;
    } else {
      _loadRestaurants();
    }
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await CoreApiService.getRestaurants().timeout(
        const Duration(seconds: 8),
      );
      final list = res['restaurants'] as List<dynamic>?;
      if (list != null && list.isNotEmpty && mounted) {
        setState(() {
          _restaurants = list.map((r) => r as Map<String, dynamic>).toList();
          _isLoading = false;
        });
        return;
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'No restaurants available at this time.';
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load restaurants. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  double _computeDistanceTo(Map<String, dynamic> rest) {
    final dest = CartService.instance.deliveryLocation;
    if (dest == null) return 2.5;

    final destLat = (dest['latitude'] ?? dest['lat'] as num?)?.toDouble() ?? 8.8932;
    final destLng = (dest['longitude'] ?? dest['lng'] as num?)?.toDouble() ?? 76.5950;

    final restAddr = rest['address'] as Map<String, dynamic>?;
    final restLat = (restAddr?['latitude'] ?? restAddr?['lat'] as num?)?.toDouble() ?? 8.8870;
    final restLng = (restAddr?['longitude'] ?? restAddr?['lng'] as num?)?.toDouble() ?? 76.5900;

    return GeoUtils.haversineDistanceKm(restLat, restLng, destLat, destLng);
  }

  void _onSelectRestaurant(Map<String, dynamic> rest) {
    CartService.instance.setRestaurant(rest);
    Navigator.pushNamed(
      context,
      '/customer/menu',
      arguments: rest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = CartService.instance.deliveryLocation;
    final locLabel = loc?['label'] as String? ?? 'Pin A — Chinnakada';

    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Restaurant',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: FairDropColors.brandNavy,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 12, color: FairDropColors.brandGreen),
                const SizedBox(width: 4),
                Text(
                  locLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FairDropColors.slateMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: FairDropColors.brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: FairDropColors.brandGreen))
            : _errorMessage != null
                ? _buildErrorView()
                : RefreshIndicator(
                onRefresh: _loadRestaurants,
                color: FairDropColors.brandGreen,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _restaurants.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final rest = _restaurants[index];
                    final name = rest['name'] as String? ?? 'Restaurant';
                    final cuisine = rest['cuisine'] as String? ?? 'South Indian & Kerala Specials';
                    final rating = (rest['rating'] as num?)?.toDouble() ?? 4.8;
                    final distKm = _computeDistanceTo(rest);
                    final estTime = rest['est_time'] as String? ?? '${(distKm * 5 + 15).round()} mins';
                    final cleanKey = 'restaurant_card_${name.toLowerCase().replaceAll(' ', '_')}';

                    return InkWell(
                      key: Key(cleanKey),
                      onTap: () => _onSelectRestaurant(rest),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: FairDropColors.mintBorder),
                          boxShadow: FairDropColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: FairDropColors.brandGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.restaurant_rounded,
                                    color: FairDropColors.brandGreen,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: FairDropColors.brandNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        cuisine,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: FairDropColors.slateMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: FairDropColors.brandGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                                      const SizedBox(width: 2),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1, color: FairDropColors.mintBorder),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.navigation_rounded, size: 14, color: FairDropColors.brandNavy),
                                const SizedBox(width: 4),
                                Text(
                                  '${distKm.toStringAsFixed(1)} km straight-line',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: FairDropColors.brandNavy,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.access_time_rounded, size: 14, color: FairDropColors.brandNavy),
                                const SizedBox(width: 4),
                                Text(
                                  estTime,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: FairDropColors.slateMuted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'View Menu →',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: FairDropColors.brandGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      key: const Key('restaurant_list_error_banner'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: FairDropColors.errorRed),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load restaurants',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FairDropColors.brandNavy,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('retry_restaurant_list_button'),
              onPressed: _loadRestaurants,
              style: FilledButton.styleFrom(
                minimumSize: Size.zero,
                backgroundColor: FairDropColors.brandGreen,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
