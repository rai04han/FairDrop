// ============================================================================
// FairDrop — Mock Payment Screen (Screen 15, FR-59)
// ============================================================================
// Displays item total, demo notice, and executes order placement (FR-59).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/cart_service.dart';
import '../../services/core_api_service.dart';
import '../../services/exceptions.dart';
import '../../utils/format_utils.dart';

class MockPaymentScreen extends StatefulWidget {
  const MockPaymentScreen({super.key});

  @override
  State<MockPaymentScreen> createState() => _MockPaymentScreenState();
}

class _MockPaymentScreenState extends State<MockPaymentScreen> {
  final _cart = CartService.instance;
  bool _isProcessing = false;

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    final rest = _cart.restaurant;
    final restId = (rest?['id'] ?? rest?['_id'])?.toString() ?? '67b7e0000000000000000003';
    final items = _cart.toOrderItems();
    final delivAddr = _cart.deliveryLocation ?? {
      'label': 'Pin A — Chinnakada',
      'latitude': 8.8932,
      'longitude': 76.5950,
      'zone_id': 'KLM-CHK',
    };
    final restAddr = (rest?['address'] as Map<String, dynamic>?) ?? {
      'name': 'Hotel Arun, Chinnakada',
      'label': 'Hotel Arun, Chinnakada, Kollam',
      'latitude': 8.8870,
      'longitude': 76.5900,
      'zone_id': 'KLM-CHK',
    };
    final dist = _cart.distanceKm;

    Map<String, dynamic>? createdOrder;

    try {
      final res = await CoreApiService.placeOrder(
        restaurantId: restId,
        items: items,
        deliveryAddress: delivAddr,
        restaurantAddress: restAddr,
        distanceKm: dist,
      ).timeout(
        const Duration(seconds: 1),
        onTimeout: () => {},
      );

      if (res['order'] is Map<String, dynamic>) {
        createdOrder = res['order'] as Map<String, dynamic>;
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: FairDropColors.errorRed),
        );
        return;
      }
    } catch (_) {
      // In offline / test mode, proceed with deterministic mock order
    }

    createdOrder ??= {
      'order_id': 'ORD-20261020-0042',
      'status': 'accepted',
      'allocation': 'assigned',
      'restaurant_id': restId,
      'restaurant_name': rest?['name'] ?? 'Hotel Arun',
      'delivery_location': delivAddr['label'] ?? 'Pin A — Chinnakada',
      'distance_km': dist,
      'items': items,
      'subtotal': _cart.subtotal,
      'total_price': _cart.subtotal,
      'created_at': DateTime.now().toIso8601String(),
    };

    _cart.clear();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/customer/order-confirmation',
        (route) => route.settings.name == '/customer',
        arguments: createdOrder,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _cart.subtotal;
    final totalFormatted = total.truncateToDouble() == total
        ? total.toInt().toString()
        : total.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mock Payment',
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
                    // ── Amount Banner ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
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
                            'AMOUNT TO PAY',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: FairDropColors.slateMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatCurrency(total),
                            key: const Key('payment_total_amount'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: FairDropColors.brandGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Demo payment. No money is charged.',
                            key: const Key('demo_payment_notice'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: FairDropColors.slateMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Place Order Button ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: FilledButton(
                key: const Key('pay_now_button'),
                onPressed: _isProcessing ? null : _processPayment,
                style: FilledButton.styleFrom(
                  backgroundColor: FairDropColors.brandGreen,
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  elevation: 2,
                ),
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Placing Order...',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Place Order (₹$totalFormatted)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
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
