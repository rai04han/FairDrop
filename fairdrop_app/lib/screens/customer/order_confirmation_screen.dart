// ============================================================================
// FairDrop — Order Confirmation Screen (Screen 16, FR-60)
// ============================================================================
// Displays order confirmation with order ID, auto-accepted status, allocation
// state (assigned vs no_rider_available queue notice), and delivery recap.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../utils/format_utils.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic>? orderData;

  const OrderConfirmationScreen({super.key, this.orderData});

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    if (widget.orderData != null) {
      _order = widget.orderData;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_order == null) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Order) {
          _order = args.toJson();
        } else if (args is Map<String, dynamic>) {
          _order = args;
        }
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _order?['order_id'] as String? ?? 'ORD-20261020-0042';
    final status = _order?['status'] as String? ?? 'accepted';
    final allocation = _order?['allocation'] as String? ?? 'assigned';
    final restName = _order?['restaurant_name'] as String? ??
        (_order?['restaurant_address'] as Map<String, dynamic>?)?['name'] as String? ??
        'Hotel Arun';
    final deliveryLoc = _order?['delivery_location'] as String? ??
        (_order?['delivery_address'] as Map<String, dynamic>?)?['label'] as String? ??
        'Pin A — Chinnakada';
    final itemsList = (_order?['items'] as List<dynamic>?) ?? [];
    double computedTotal = 0.0;
    for (final item in itemsList) {
      if (item is Map<String, dynamic>) {
        final p = (item['price'] as num?)?.toDouble() ?? 0.0;
        final q = (item['quantity'] as num?)?.toInt() ?? 1;
        computedTotal += p * q;
      }
    }
    final total = (_order?['total_price'] as num?)?.toDouble() ??
        (_order?['total_amount'] as num?)?.toDouble() ??
        (computedTotal > 0 ? computedTotal : 0.0);
    final distKm = (_order?['distance_km'] as num?)?.toDouble() ?? 2.5;

    final isNoRider = allocation == 'no_rider_available';

    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // ── Success Icon Animation ──────────────────────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: FairDropColors.brandGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 54,
                          color: FairDropColors.brandGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Order Placed Successfully!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order #$orderId',
                      key: const Key('confirmation_order_id'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FairDropColors.brandGreen,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Status & Allocation Card (FR-60, FR-67, FR-68) ───────
                    Container(
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
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: FairDropColors.brandGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'STATUS: ${status == 'accepted' ? 'AUTO-ACCEPTED' : status.toUpperCase()} (FR-67)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: FairDropColors.brandGreen,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kitchen is preparing your order at $restName.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: FairDropColors.brandNavy,
                            ),
                          ),
                          const Divider(height: 20, color: FairDropColors.mintBorder),

                          // Allocation Status
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isNoRider ? Icons.hourglass_top_rounded : Icons.two_wheeler_rounded,
                                color: isNoRider ? FairDropColors.brandOrange : FairDropColors.brandNavy,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isNoRider
                                          ? 'Searching for Available Riders...'
                                          : 'Rider Allocated (FR-68)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isNoRider ? FairDropColors.brandOrange : FairDropColors.brandNavy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isNoRider
                                          ? 'All zone riders are currently active. Order is prioritized and will allocate as soon as a rider goes online or completes delivery (FR-60, D6).'
                                          : 'A FairDrop partner in your zone has accepted this delivery route.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: FairDropColors.slateMuted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Delivery Route Recap ────────────────────────────────
                    Container(
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
                          Text(
                            'DELIVERY DETAILS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: FairDropColors.slateMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded, size: 16, color: FairDropColors.brandNavy),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  restName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: FairDropColors.brandNavy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: FairDropColors.brandGreen),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  deliveryLoc,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: FairDropColors.brandNavy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.navigation_rounded, size: 14, color: FairDropColors.slateMuted),
                              const SizedBox(width: 8),
                              Text(
                                '${distKm.toStringAsFixed(1)} km straight-line distance',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: FairDropColors.slateMuted,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: FairDropColors.mintBorder),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL PAID',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: FairDropColors.brandNavy,
                                ),
                              ),
                              Text(
                                formatCurrency(total),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: FairDropColors.brandGreen,
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
            ),

            // ── Return Home Button ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: FilledButton(
                key: const Key('back_to_home_button'),
                onPressed: () => Navigator.pushReplacementNamed(context, '/customer'),
                style: FilledButton.styleFrom(
                  backgroundColor: FairDropColors.brandGreen,
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  elevation: 2,
                ),
                child: Text(
                  'BACK TO CUSTOMER HOME',
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
}
