// ============================================================================
// FairDrop — Restaurant Menu Screen (Screen 13, FR-57)
// ============================================================================
// Displays restaurant menu items. Disables unavailable items with prominent
// badges, provides live cart counters, and sticky bottom checkout navigation.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/menu_item.dart';
import '../../services/cart_service.dart';
import '../../services/core_api_service.dart';
import '../../utils/format_utils.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final Map<String, dynamic>? restaurant;
  final List<MenuItem>? initialItems;

  const RestaurantMenuScreen({super.key, this.restaurant, this.initialItems});

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  Map<String, dynamic>? _restaurant;
  List<MenuItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;


  @override
  void initState() {
    super.initState();
    _restaurant = widget.restaurant ?? CartService.instance.restaurant;
    if (widget.initialItems != null) {
      _items = widget.initialItems!;
      _isLoading = false;
    } else {
      _loadMenu();
    }
  }

  Future<void> _loadMenu() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final restId = (_restaurant?['id'] ?? _restaurant?['_id'])?.toString();
    if (restId != null) {
      try {
        final res = await CoreApiService.getRestaurantMenu(restId).timeout(
          const Duration(seconds: 8),
        );
        final list = res['items'] as List<dynamic>?;
        if (list != null && list.isNotEmpty && mounted) {
          setState(() {
            _items = list.map((i) => MenuItem.fromJson(i as Map<String, dynamic>)).toList();
            _isLoading = false;
          });
          return;
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = 'No menu items available for this restaurant.';
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Unable to load restaurant menu. Please check your connection and try again.';
            _isLoading = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _errorMessage = 'Restaurant not found.';
        _isLoading = false;
      });
    }
  }

  void _addItem(MenuItem item) {
    final added = CartService.instance.addItem(item);
    if (!added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !item.isAvailable
                ? 'Item is currently unavailable.'
                : 'Cart contains items from another restaurant. Clear cart to switch.',
          ),
          backgroundColor: FairDropColors.errorRed,
        ),
      );
    }
    setState(() {});
  }

  void _removeItem(MenuItem item) {
    CartService.instance.removeItem(item.id);
    setState(() {});
  }

  int _getItemQuantity(String itemId) {
    final match = CartService.instance.items.where((i) => i.item.id == itemId);
    return match.isNotEmpty ? match.first.quantity : 0;
  }

  @override
  Widget build(BuildContext context) {
    final restName = _restaurant?['name'] as String? ?? 'Hotel Arun';
    final cuisine = _restaurant?['cuisine'] as String? ?? 'Kerala Specials • South Indian';
    final cart = CartService.instance;

    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          restName,
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
            // ── Restaurant Header Banner ───────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: FairDropColors.brandGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: FairDropColors.brandGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: FairDropColors.brandNavy,
                          ),
                        ),
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
                      color: FairDropColors.brandGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'OPEN NOW',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: FairDropColors.mintBorder),

            // ── Menu List ──────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: FairDropColors.brandGreen))
                  : _errorMessage != null
                      ? _buildErrorView()
                      : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final qty = _getItemQuantity(item.id);
                        final slug = item.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: item.isAvailable ? Colors.white : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.isAvailable ? FairDropColors.mintBorder : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: item.isAvailable ? FairDropColors.cardShadow : [],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.green, width: 2),
                                            shape: BoxShape.rectangle,
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.circle, size: 6, color: Colors.green),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: item.isAvailable
                                                  ? FairDropColors.brandNavy
                                                  : FairDropColors.slateMuted,
                                              decoration: item.isAvailable ? null : TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formatCurrency(item.price),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: item.isAvailable
                                            ? FairDropColors.brandNavy
                                            : FairDropColors.slateMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 12, color: FairDropColors.slateMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Prep: ${(item.prepTimeSeconds / 60).round()} mins',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: FairDropColors.slateMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Action Column: Add / Unavailable
                              if (!item.isAvailable)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'UNAVAILABLE',
                                    key: Key('unavailable_badge_$slug'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: FairDropColors.slateMuted,
                                    ),
                                  ),
                                )
                              else if (qty == 0)
                                OutlinedButton(
                                  key: Key('add_item_button_$slug'),
                                  onPressed: () => _addItem(item),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: Size.zero,
                                    side: const BorderSide(color: FairDropColors.brandGreen, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  ),
                                  child: Text(
                                    'ADD',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: FairDropColors.brandGreen,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    color: FairDropColors.brandGreen,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        key: Key('decrement_button_$slug'),
                                        icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                                        onPressed: () => _removeItem(item),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Text(
                                        '$qty',
                                        key: Key('item_qty_$slug'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        key: Key('increment_button_$slug'),
                                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                        onPressed: () => _addItem(item),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // ── Sticky Floating Cart Bar ───────────────────────────────────
            if (cart.totalItemCount > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cart.totalItemCount} ITEMS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: FairDropColors.slateMuted,
                          ),
                        ),
                        Text(
                          formatCurrency(cart.subtotal),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: FairDropColors.brandNavy,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      key: const Key('view_cart_button'),
                      onPressed: () => Navigator.pushNamed(context, '/customer/cart'),
                      style: FilledButton.styleFrom(
                        minimumSize: Size.zero,
                        backgroundColor: FairDropColors.brandGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: Text(
                        'VIEW CART',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      key: const Key('menu_error_banner'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: FairDropColors.errorRed),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load menu',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FairDropColors.brandNavy,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('retry_menu_button'),
              onPressed: _loadMenu,
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
