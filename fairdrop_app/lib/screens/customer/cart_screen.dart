// ============================================================================
// FairDrop — Cart Screen (Screen 14, FR-58)
// ============================================================================
// Single-restaurant cart with itemized quantities, transparent straight-line
// distance delivery fee calculation, and breakdown before checkout.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/cart_service.dart';
import '../../utils/format_utils.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = CartService.instance;

  void _increment(String itemId) {
    final item = _cart.items.firstWhere((i) => i.item.id == itemId).item;
    _cart.addItem(item);
    setState(() {});
  }

  void _decrement(String itemId) {
    _cart.removeItem(itemId);
    setState(() {});
  }

  void _proceedToPayment() {
    if (_cart.items.isEmpty) return;
    Navigator.pushNamed(context, '/customer/payment');
  }

  @override
  Widget build(BuildContext context) {
    final rest = _cart.restaurant;
    final restName = rest?['name'] as String? ?? 'Hotel Arun';
    final loc = _cart.deliveryLocation;
    final locLabel = loc?['label'] as String? ?? 'Pin A — Chinnakada';
    final isOutOfZone = loc?['is_out_of_zone'] == true;

    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Your Order Cart',
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
        child: _cart.items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shopping_cart_outlined, size: 48, color: FairDropColors.slateMuted),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your cart is empty',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add items from a restaurant menu to get started.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: FairDropColors.slateMuted),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: FairDropColors.brandGreen),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Browse Menu'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Route & Restaurant Header ─────────────────────
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
                                    const Icon(Icons.store_rounded, size: 18, color: FairDropColors.brandGreen),
                                    const SizedBox(width: 8),
                                    Text(
                                      restName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: FairDropColors.brandNavy,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.navigation_rounded, size: 14, color: FairDropColors.slateMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Delivering to: $locLabel (${_cart.distanceKm.toStringAsFixed(1)} km straight-line)',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: FairDropColors.slateMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isOutOfZone) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: FairDropColors.brandOrange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'OUT-OF-ZONE DESTINATION (KLM-PLY)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: FairDropColors.brandOrange,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Items List ────────────────────────────────────
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
                                Text(
                                  'ITEMS IN CART',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: FairDropColors.slateMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _cart.items.length,
                                  separatorBuilder: (context, index) => const Divider(height: 16, color: FairDropColors.mintBorder),
                                  itemBuilder: (context, idx) {
                                    final cartItem = _cart.items[idx];
                                    final slug = cartItem.item.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                cartItem.item.name,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: FairDropColors.brandNavy,
                                                ),
                                              ),
                                              Text(
                                                formatCurrency(cartItem.item.price),
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  color: FairDropColors.slateMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(color: FairDropColors.mintBorder),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                key: Key('cart_decrement_$slug'),
                                                icon: const Icon(Icons.remove, size: 14, color: FairDropColors.brandNavy),
                                                onPressed: () => _decrement(cartItem.item.id),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              Text(
                                                '${cartItem.quantity}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: FairDropColors.brandNavy,
                                                ),
                                              ),
                                              IconButton(
                                                key: Key('cart_increment_$slug'),
                                                icon: const Icon(Icons.add, size: 14, color: FairDropColors.brandNavy),
                                                onPressed: () => _increment(cartItem.item.id),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          formatCurrency(cartItem.totalPrice),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: FairDropColors.brandNavy,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Bill Details ───────────────────────────────────
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
                                Text(
                                  'BILL DETAILS',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: FairDropColors.slateMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildBillRow('Item Subtotal', formatCurrency(_cart.subtotal)),
                                const Divider(height: 20, color: FairDropColors.mintBorder),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TO PAY',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: FairDropColors.brandNavy,
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(_cart.grandTotal),
                                      key: const Key('cart_grand_total'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
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

                  // ── Bottom Checkout Button ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: FilledButton(
                      key: const Key('proceed_to_payment_button'),
                      onPressed: _proceedToPayment,
                      style: FilledButton.styleFrom(
                        backgroundColor: FairDropColors.brandGreen,
                        minimumSize: const Size.fromHeight(54),
                        shape: const StadiumBorder(),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'PROCEED TO PAYMENT • ${formatCurrency(_cart.grandTotal)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBillRow(String label, String amount, {String? subtitle, bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight ? FairDropColors.brandGreen : FairDropColors.brandNavy,
              ),
            ),
            Text(
              amount,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isHighlight ? FairDropColors.brandGreen : FairDropColors.brandNavy,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: FairDropColors.slateMuted,
            ),
          ),
        ],
      ],
    );
  }
}
