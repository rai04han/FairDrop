// ============================================================================
// FairDrop — Delivery Location Screen (Screen 11, FR-55)
// ============================================================================
// Allows customer to choose delivery destination in Kollam with one-tap
// selection for verified demo pins: Pin A (In-Zone) and Pin B (Out-of-Zone).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/cart_service.dart';

class DeliveryLocationScreen extends StatefulWidget {
  const DeliveryLocationScreen({super.key});

  @override
  State<DeliveryLocationScreen> createState() => _DeliveryLocationScreenState();
}

class _DeliveryLocationScreenState extends State<DeliveryLocationScreen> {
  // Pre-configured official demo pins from PRD §10.1 & seed.js
  static const pinA = {
    'label': 'Pin A — Chinnakada',
    'address': 'Chinnakada Market Road, Near Clock Tower, Kollam',
    'latitude': 8.8932,
    'longitude': 76.5950,
    'zone_id': 'KLM-CHK',
    'is_out_of_zone': false,
  };

  static const pinB = {
    'label': 'Pin B — Polayathode',
    'address': 'Polayathode Junction, SN College Road, Kollam',
    'latitude': 8.8750,
    'longitude': 76.6050,
    'zone_id': 'KLM-PLY',
    'is_out_of_zone': true,
  };

  Map<String, dynamic> _selectedLocation = pinA;

  void _selectLocation(Map<String, dynamic> loc) {
    setState(() {
      _selectedLocation = loc;
    });
  }

  void _confirmLocation() {
    CartService.instance.setDeliveryLocation(_selectedLocation);
    Navigator.pushNamed(context, '/customer/restaurants');
  }

  @override
  Widget build(BuildContext context) {
    final isPinA = _selectedLocation['zone_id'] == 'KLM-CHK';

    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Choose Delivery Location',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: FairDropColors.brandNavy,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: FairDropColors.brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Map Banner & Header ────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F2B1D), FairDropColors.brandGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: FairDropColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Kollam Delivery Zones',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Select your delivery address pin. FairDrop delivers across Chinnakada, Polayathode, and Asramam with transparent straight-line distance pay.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'VERIFIED DEMO DESTINATIONS (PRD §10.1)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.slateMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Option 1: Pin A (In-Zone: KLM-CHK) ──────────────────
                    _buildPinCard(
                      keyName: 'select_pin_a_button',
                      title: 'Pin A — Chinnakada (In-Zone)',
                      subtitle: 'Clock Tower / Market Rd • Zone KLM-CHK',
                      coords: '8.8932° N, 76.5950° E',
                      zoneBadge: 'KLM-CHK (HOME ZONE)',
                      zoneBadgeColor: FairDropColors.brandGreen,
                      isSelected: isPinA,
                      onTap: () => _selectLocation(pinA),
                    ),
                    const SizedBox(height: 12),

                    // ── Option 2: Pin B (Out-of-Zone: KLM-PLY) ──────────────
                    _buildPinCard(
                      keyName: 'select_pin_b_button',
                      title: 'Pin B — Polayathode (Out-of-Zone)',
                      subtitle: 'Polayathode Jn / SN College • Zone KLM-PLY',
                      coords: '8.8750° N, 76.6050° E',
                      zoneBadge: 'KLM-PLY (OUT-OF-ZONE)',
                      zoneBadgeColor: FairDropColors.brandOrange,
                      isSelected: !isPinA,
                      onTap: () => _selectLocation(pinB),
                    ),
                    const SizedBox(height: 24),

                    // ── Selected Location Summary ───────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: FairDropColors.mintBorder),
                        boxShadow: FairDropColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: FairDropColors.brandGreen, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'ACTIVE SELECTION',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: FairDropColors.slateMuted,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (_selectedLocation['is_out_of_zone'] == true)
                                      ? FairDropColors.brandOrange.withValues(alpha: 0.15)
                                      : FairDropColors.brandGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _selectedLocation['zone_id'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: (_selectedLocation['is_out_of_zone'] == true)
                                        ? FairDropColors.brandOrange
                                        : FairDropColors.brandGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedLocation['label'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: FairDropColors.brandNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedLocation['address'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: FairDropColors.slateMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Coordinates: ${_selectedLocation['latitude']}, ${_selectedLocation['longitude']}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: FairDropColors.brandNavy.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom Action Button ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: FilledButton(
                key: const Key('confirm_location_button'),
                onPressed: _confirmLocation,
                style: FilledButton.styleFrom(
                  backgroundColor: FairDropColors.brandGreen,
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  elevation: 2,
                ),
                child: Text(
                  'CONFIRM LOCATION & BROWSE RESTAURANTS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinCard({
    required String keyName,
    required String title,
    required String subtitle,
    required String coords,
    required String zoneBadge,
    required Color zoneBadgeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: Key(keyName),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? FairDropColors.brandGreen : FairDropColors.mintBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: FairDropColors.brandGreen.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : FairDropColors.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? FairDropColors.brandGreen : FairDropColors.slateMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: FairDropColors.brandNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: FairDropColors.slateMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: zoneBadgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          zoneBadge,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: zoneBadgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        coords,
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
            ),
          ],
        ),
      ),
    );
  }
}
