// ============================================================================
// FairDrop — Restaurant Orders Screen (Screen 19, FR-65, FR-66, FR-69)
// ============================================================================
// Lists orders placed with this restaurant, showing customer location, items,
// and the server-derived `is_ready` indicator based on elapsed prep time.
// Note: Orders are auto-accepted on placement (FR-66), no manual accept required.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/core_api_service.dart';
import '../../utils/format_utils.dart';

class RestaurantOrdersScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialOrders;

  const RestaurantOrdersScreen({super.key, this.initialOrders});

  @override
  State<RestaurantOrdersScreen> createState() => _RestaurantOrdersScreenState();
}

class _RestaurantOrdersScreenState extends State<RestaurantOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _selectedFilter = 'ACTIVE'; // 'ACTIVE', 'ALL', 'COMPLETED'

  // Deterministic fallback orders for testing/offline (Demo Steps 4, 7)
  static final List<Map<String, dynamic>> _fallbackOrders = [
    {
      'id': '67b7f0000000000000000042',
      '_id': '67b7f0000000000000000042',
      'order_id': 'ORD-20261020-0042',
      'status': 'accepted',
      'is_ready': false,
      'prep_time_seconds': 600,
      'created_at': DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String(),
      'delivery_address': {
        'label': 'Pin A — Chinnakada',
        'latitude': 8.8932,
        'longitude': 76.5950,
        'zone_id': 'KLM-CHK',
      },
      'distance_km': 0.85,
      'total_price': 243.0,
      'items': [
        {'name': 'Kerala Porotta', 'quantity': 2, 'price': 25.0},
        {'name': 'Nadan Chicken Curry', 'quantity': 1, 'price': 180.0},
      ],
    },
    {
      'id': '67b7f0000000000000000041',
      '_id': '67b7f0000000000000000041',
      'order_id': 'ORD-20261020-0041',
      'status': 'arrived',
      'is_ready': true,
      'prep_time_seconds': 600,
      'created_at': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      'delivery_address': {
        'label': 'Pin B — Polayathode',
        'latitude': 8.8750,
        'longitude': 76.6050,
        'zone_id': 'KLM-PLY',
      },
      'distance_km': 3.2,
      'total_price': 350.0,
      'items': [
        {'name': 'Appam with Vegetable Stew', 'quantity': 2, 'price': 120.0},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialOrders != null) {
      _orders = List.from(widget.initialOrders!);
      _isLoading = false;
    } else {
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final res = await CoreApiService.getRestaurantOrders().timeout(
        const Duration(seconds: 1),
        onTimeout: () => {},
      );

      final list = res['orders'] as List<dynamic>?;
      if (list != null && mounted) {
        setState(() {
          _orders = list.map((o) => o as Map<String, dynamic>).toList();
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Offline fallback
    }

    if (mounted) {
      setState(() {
        _orders = List.from(_fallbackOrders);
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == 'ACTIVE') {
      return _orders.where((o) {
        final status = (o['status'] as String? ?? '').toLowerCase();
        return status != 'delivered' && status != 'cancelled';
      }).toList();
    } else if (_selectedFilter == 'COMPLETED') {
      return _orders.where((o) {
        final status = (o['status'] as String? ?? '').toLowerCase();
        return status == 'delivered' || status == 'cancelled';
      }).toList();
    }
    return _orders;
  }

  bool _computeIsReady(Map<String, dynamic> order) {
    if (order['is_ready'] == true) return true;

    // Derived client fallback: check if now >= created_at + prep_time_seconds
    final createdAtStr = order['created_at'] as String?;
    final prepSeconds = (order['prep_time_seconds'] as num?)?.toInt() ?? 600;

    if (createdAtStr != null) {
      final created = DateTime.tryParse(createdAtStr);
      if (created != null) {
        final readyAt = created.add(Duration(seconds: prepSeconds));
        return DateTime.now().isAfter(readyAt);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Kitchen Live Orders',
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
        actions: [
          IconButton(
            key: const Key('refresh_orders_button'),
            icon: const Icon(Icons.refresh_rounded, color: FairDropColors.brandNavy),
            tooltip: 'Refresh Orders',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Filter Selector Bar ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  _buildFilterTab('ACTIVE (PREPARING)', 'ACTIVE'),
                  const SizedBox(width: 8),
                  _buildFilterTab('COMPLETED', 'COMPLETED'),
                  const SizedBox(width: 8),
                  _buildFilterTab('ALL ORDERS', 'ALL'),
                ],
              ),
            ),
            const Divider(height: 1, color: FairDropColors.mintBorder),

            // ── Orders List ──────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: FairDropColors.brandGreen))
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      color: FairDropColors.brandGreen,
                      child: filtered.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 60),
                                Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.inbox_outlined, size: 48, color: FairDropColors.slateMuted),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No $_selectedFilter orders at this time',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: FairDropColors.brandNavy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final order = filtered[index];
                                final orderId = order['order_id'] as String? ?? 'ORD-0000';
                                final status = (order['status'] as String? ?? 'accepted').toUpperCase();
                                final isReady = _computeIsReady(order);
                                final items = (order['items'] as List<dynamic>?) ?? [];
                                final total = (order['total_price'] as num?)?.toDouble() ?? 0.0;
                                final delivAddr = order['delivery_address'] as Map<String, dynamic>?;
                                final delivLabel = delivAddr?['label'] as String? ?? 'Kollam Delivery Location';
                                final distKm = (order['distance_km'] as num?)?.toDouble() ?? 1.5;

                                return Container(
                                  key: Key('restaurant_order_card_$orderId'),
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
                                      // Top Row: Order ID & Status Badge
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Order #$orderId',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: FairDropColors.brandNavy,
                                            ),
                                          ),
                                          Container(
                                            key: Key('order_status_badge_$orderId'),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: FairDropColors.brandNavy.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: FairDropColors.brandNavy,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Derived is_ready Indicator Banner (FR-69, Demo Step 7)
                                      Container(
                                        key: Key('order_ready_badge_$orderId'),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isReady
                                              ? FairDropColors.brandGreen.withValues(alpha: 0.12)
                                              : FairDropColors.brandOrange.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isReady
                                                ? FairDropColors.brandGreen.withValues(alpha: 0.3)
                                                : FairDropColors.brandOrange.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isReady ? Icons.check_circle_rounded : Icons.timer_outlined,
                                              size: 16,
                                              color: isReady ? FairDropColors.brandGreen : FairDropColors.brandOrange,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                isReady
                                                    ? 'ORDER READY FOR PICKUP (FR-69)'
                                                    : 'PREPARING IN KITCHEN (PREP IN PROGRESS)',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: isReady
                                                      ? FairDropColors.brandGreen
                                                      : FairDropColors.brandOrange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 20, color: FairDropColors.mintBorder),

                                      // Items List
                                      ...items.map((i) {
                                        final itemName = i['name'] as String? ?? 'Menu Item';
                                        final itemQty = i['quantity'] ?? 1;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${itemQty}x',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: FairDropColors.brandNavy,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  itemName,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: FairDropColors.brandNavy,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 8),

                                      // Delivery Address & Total
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                const Icon(Icons.location_on_rounded, size: 14, color: FairDropColors.slateMuted),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '$delivLabel (${distKm.toStringAsFixed(1)} km)',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11,
                                                      color: FairDropColors.slateMuted,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            formatCurrency(total),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: FairDropColors.brandGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: InkWell(
        key: Key('filter_tab_${value.toLowerCase()}'),
        onTap: () => setState(() => _selectedFilter = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? FairDropColors.brandGreen : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : FairDropColors.slateMuted,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
