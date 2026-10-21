// ============================================================================
// FairDrop — Customer Order History Screen (Screen 22, FR-61)
// ============================================================================
// PRD Feature: FR-61 (Order History with pull-to-refresh)
// Demo Step 12: Customer verifies order history shows past orders & deliveries.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/core_api_service.dart';

class CustomerOrderHistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialOrders;
  final bool autoFetch;
  final Future<List<Map<String, dynamic>>> Function()? onFetchOrders;

  const CustomerOrderHistoryScreen({
    super.key,
    this.initialOrders,
    this.autoFetch = true,
    this.onFetchOrders,
  });

  @override
  State<CustomerOrderHistoryScreen> createState() => _CustomerOrderHistoryScreenState();
}

class _CustomerOrderHistoryScreenState extends State<CustomerOrderHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialOrders != null) {
      _orders = List<Map<String, dynamic>>.from(widget.initialOrders!);
      _isLoading = false;
    } else if (widget.autoFetch) {
      _loadOrders();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.onFetchOrders != null) {
        final result = await widget.onFetchOrders!();
        if (mounted) {
          setState(() {
            _orders = result;
            _isLoading = false;
          });
        }
        return;
      }

      final response = await CoreApiService.getOrderHistory();
      final rawOrders = response['orders'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          _orders = rawOrders.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load order history: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return FairDropColors.brandGreen;
      case 'picked_up':
      case 'arrived':
      case 'assigned':
      case 'accepted':
        return FairDropColors.brandOrange;
      case 'placed':
        return Colors.indigo;
      case 'cancelled':
        return Colors.red;
      default:
        return FairDropColors.slateMuted;
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateVal.toString().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Your Orders',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: FairDropColors.brandNavy,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: FairDropColors.brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            key: const Key('customer_order_history_refresh_button'),
            icon: const Icon(Icons.refresh_rounded, color: FairDropColors.brandNavy),
            tooltip: 'Refresh orders',
            onPressed: _isLoading ? null : _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadOrders,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  key: const Key('customer_order_history_refresh_indicator'),
                  onRefresh: _loadOrders,
                  child: _orders.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No orders placed yet',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: FairDropColors.brandNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Discover local Kollam partners and order with transparent pay.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            final orderId = order['order_id'] ?? 'ORD-#$index';
                            final status = (order['status'] ?? 'placed').toString();
                            final statusColor = _getStatusColor(status);
                            final createdAt = _formatDate(order['created_at']);
                            final items = (order['items'] as List<dynamic>? ?? []);
                            double itemsTotal = 0.0;
                            for (final it in items) {
                              if (it is Map<String, dynamic>) {
                                final p = double.tryParse(it['price']?.toString() ?? '0') ?? 0.0;
                                final q = int.tryParse(it['quantity']?.toString() ?? '1') ?? 1;
                                itemsTotal += p * q;
                              }
                            }
                            final rawTotal = double.tryParse(order['total_amount']?.toString() ?? '') ??
                                double.tryParse(order['total_price']?.toString() ?? '');
                            final totalAmount = rawTotal ?? itemsTotal;
                            final deliveryFee = double.tryParse(order['delivery_fee']?.toString() ?? '0') ?? 0;
                            final distanceKm = double.tryParse(order['distance_km']?.toString() ?? '0') ?? 0;
                            final deliveryAddress = order['delivery_address']?['label'] ?? 'Delivery Address';
                            final restaurantName = order['restaurant_name'] ?? 'Restaurant Partner';

                            return Card(
                              key: Key('customer_order_card_$orderId'),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ── Header Row: Order ID & Status Badge ─
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            orderId,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: FairDropColors.brandNavy,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      createdAt,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                    const Divider(height: 20),

                                    // ── Restaurant & Drop-off Info ─────────
                                    Row(
                                      children: [
                                        const Icon(Icons.storefront_rounded, size: 16, color: FairDropColors.brandNavy),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            restaurantName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 16, color: FairDropColors.brandGreen),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            deliveryAddress,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (distanceKm > 0)
                                          Text(
                                            '(${distanceKm.toStringAsFixed(1)} km)',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // ── Items Summary ──────────────────────
                                    if (items.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: items.map((it) {
                                            final name = it['name'] ?? 'Item';
                                            final qty = it['quantity'] ?? 1;
                                            final price = double.tryParse(it['price']?.toString() ?? '0') ?? 0;
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    '${qty}x ',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                  ),
                                                  Text(
                                                    '₹${(price * qty).toStringAsFixed(2)}',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],

                                    // ── Total & Transparent Fee Row ────────
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Delivery Fee: ₹${deliveryFee.toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                        Text(
                                          'Total: ₹${totalAmount.toStringAsFixed(2)}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: FairDropColors.brandNavy,
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
    );
  }
}
