// ============================================================================
// FairDrop — Order Placement & Tracking Screen
// ============================================================================
// Owner: Hari (25MCA025)
//
// Two tabs:
//   1. Place Order — customer fills items, selects restaurant, places order
//   2. My Orders  — shows order history with status tracking

import 'package:flutter/material.dart';
import '../services/core_api_service.dart';
import '../services/exceptions.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_shopping_cart), text: 'Place Order'),
            Tab(icon: Icon(Icons.history), text: 'My Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlaceOrderTab(onOrderPlaced: () {
            // Switch to "My Orders" tab after placing
            _tabController.animateTo(1);
          }),
          const _OrderHistoryTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 1 — Place Order
// ============================================================================

class _PlaceOrderTab extends StatefulWidget {
  final VoidCallback onOrderPlaced;
  const _PlaceOrderTab({required this.onOrderPlaced});

  @override
  State<_PlaceOrderTab> createState() => _PlaceOrderTabState();
}

class _PlaceOrderTabState extends State<_PlaceOrderTab> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  // ── Seeded restaurants (populated from GET /api/orders/restaurants) ──────
  List<Map<String, dynamic>> _restaurants = [];
  bool _isLoadingRestaurants = false;

  // Legacy static addresses for known restaurant emails (fallback for demo)
  final _restaurantAddresses = {
    'arun@fairdrop.in': {'label': 'Hotel Arun, Chinnakkada', 'lat': 8.8855, 'lng': 76.5950},
    'marina@fairdrop.in': {'label': 'Cafe Marina, Kollam Beach', 'lat': 8.8875, 'lng': 76.6100},
  };

  int _selectedRestaurant = 0;

  // ── Menu items ────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _cartItems = [];
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();
  int _itemQuantity = 1;

  // ── Delivery address ──────────────────────────────────────────────────
  final _deliveryLabelController =
      TextEditingController(text: 'TKM College, Kollam');
  final double _deliveryLat = 8.8932;
  final double _deliveryLng = 76.6141;

  // ── Quick menu (common items) ─────────────────────────────────────────
  final _quickMenu = [
    {'name': 'Chicken Biryani', 'price': 180},
    {'name': 'Meals (Veg)', 'price': 90},
    {'name': 'Porotta + Beef', 'price': 120},
    {'name': 'Lime Soda', 'price': 40},
    {'name': 'Chai', 'price': 20},
    {'name': 'Fried Rice', 'price': 150},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
  }

  Future<void> _fetchRestaurants() async {
    setState(() => _isLoadingRestaurants = true);
    try {
      final data = await CoreApiService.getRestaurants();
      final list = (data['restaurants'] as List<dynamic>? ?? []);
      setState(() {
        _restaurants = list
            .map((r) {
              final rest = r as Map<String, dynamic>;
              final email = rest['email'] as String? ?? '';
              final addr = _restaurantAddresses[email];
              return {
                '_id': rest['_id'] as String? ?? '',
                'name': rest['name'] as String? ?? 'Restaurant',
                'email': email,
                'label': addr?['label'] ?? rest['name'] ?? 'Unknown',
                'lat': addr?['lat'] ?? 8.8855,
                'lng': addr?['lng'] ?? 76.5950,
              };
            })
            .toList();
        _isLoadingRestaurants = false;
      });
    } catch (_) {
      // Non-critical — fall through to show empty restaurant list
      setState(() => _isLoadingRestaurants = false);
    }
  }

  void _addQuickItem(Map<String, dynamic> item) {
    setState(() {
      // Check if item already in cart — increment quantity
      final existing = _cartItems.indexWhere((c) => c['name'] == item['name']);
      if (existing != -1) {
        _cartItems[existing]['quantity'] += 1;
      } else {
        _cartItems.add({
          'name': item['name'],
          'price': item['price'],
          'quantity': 1,
        });
      }
      _successMessage = null;
      _errorMessage = null;
    });
  }

  void _addCustomItem() {
    if (_itemNameController.text.isEmpty || _itemPriceController.text.isEmpty) {
      return;
    }
    setState(() {
      _cartItems.add({
        'name': _itemNameController.text.trim(),
        'price': int.tryParse(_itemPriceController.text) ?? 0,
        'quantity': _itemQuantity,
      });
      _itemNameController.clear();
      _itemPriceController.clear();
      _itemQuantity = 1;
    });
  }

  void _removeItem(int index) {
    setState(() => _cartItems.removeAt(index));
  }

  double get _totalAmount {
    return _cartItems.fold(0.0, (sum, item) {
      return sum + (item['price'] as int) * (item['quantity'] as int);
    });
  }

  Future<void> _placeOrder() async {
    if (_cartItems.isEmpty) {
      setState(() => _errorMessage = 'Add at least one item to your order.');
      return;
    }
    if (_restaurants.isEmpty) {
      setState(() => _errorMessage = 'No restaurants available. Check your connection.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // BUG-2 fix: use pre-fetched restaurant _id, no login impersonation needed
      final restaurant = _restaurants[_selectedRestaurant];
      final restaurantId = restaurant['_id'] as String;

      if (restaurantId.isEmpty) {
        throw Exception('Restaurant ID not available. Try refreshing.');
      }

      final result = await CoreApiService.placeOrder(
        restaurantId: restaurantId,
        items: _cartItems.map((item) => {
              'name': item['name'],
              'quantity': item['quantity'],
              'price': item['price'],
            }).toList(),
        deliveryAddress: {
          'label': _deliveryLabelController.text,
          'latitude': _deliveryLat,
          'longitude': _deliveryLng,
        },
        restaurantAddress: {
          'label': restaurant['label'],
          'latitude': restaurant['lat'],
          'longitude': restaurant['lng'],
        },
        distanceKm: 3.5,
      );

      setState(() {
        _successMessage =
            'Order ${result['order']['order_id']} placed successfully!';
        _cartItems.clear();
      });

      // Switch to history tab
      widget.onOrderPlaced();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _deliveryLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Restaurant selector ──────────────────────────────────
            Text('Restaurant',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isLoadingRestaurants)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_restaurants.isEmpty)
              const Text('No restaurants available. Check connection.')
            else
              SegmentedButton<int>(
                segments: _restaurants.asMap().entries.map((e) {
                  return ButtonSegment(
                    value: e.key,
                    label: Text(e.value['name'] as String),
                    icon: const Icon(Icons.restaurant),
                  );
                }).toList(),
                selected: {_selectedRestaurant.clamp(0, _restaurants.length - 1)},
                onSelectionChanged: (s) =>
                    setState(() => _selectedRestaurant = s.first),
              ),
            const SizedBox(height: 20),

            // ── Quick Menu ──────────────────────────────────────────
            Text('Quick Menu',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickMenu.map((item) {
                return ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text('${item['name']} — ₹${item['price']}'),
                  onPressed: () => _addQuickItem(item),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Custom item entry ───────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _itemNameController,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _itemPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '₹',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addCustomItem,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Cart ────────────────────────────────────────────────
            if (_cartItems.isNotEmpty) ...[
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Icon(Icons.shopping_cart, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Cart (${_cartItems.length} items)',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '₹${_totalAmount.toStringAsFixed(0)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ..._cartItems.asMap().entries.map((e) {
                      final item = e.value;
                      return ListTile(
                        dense: true,
                        title: Text(item['name'] as String),
                        subtitle: Text(
                            '₹${item['price']} × ${item['quantity']} = ₹${(item['price'] as int) * (item['quantity'] as int)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: 20,
                              onPressed: () {
                                setState(() {
                                  if ((item['quantity'] as int) > 1) {
                                    item['quantity'] =
                                        (item['quantity'] as int) - 1;
                                  } else {
                                    _removeItem(e.key);
                                  }
                                });
                              },
                            ),
                            Text('${item['quantity']}'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              iconSize: 20,
                              onPressed: () {
                                setState(() {
                                  item['quantity'] =
                                      (item['quantity'] as int) + 1;
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Delivery address ────────────────────────────────────
            TextField(
              controller: _deliveryLabelController,
              decoration: const InputDecoration(
                labelText: 'Delivery Address',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
                helperText: 'Kollam area (demo uses fixed coordinates)',
              ),
            ),
            const SizedBox(height: 20),

            // ── Messages ────────────────────────────────────────────
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_errorMessage!,
                            style:
                                TextStyle(color: colorScheme.onErrorContainer))),
                  ],
                ),
              ),

            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_successMessage!,
                            style: TextStyle(
                                color: colorScheme.onPrimaryContainer))),
                  ],
                ),
              ),

            // ── Place order button ──────────────────────────────────
            FilledButton.icon(
              onPressed: _isLoading || _cartItems.isEmpty ? null : _placeOrder,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_isLoading
                  ? 'Placing...'
                  : 'Place Order — ₹${_totalAmount.toStringAsFixed(0)}'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Tab 2 — Order History
// ============================================================================

class _OrderHistoryTab extends StatefulWidget {
  const _OrderHistoryTab();

  @override
  State<_OrderHistoryTab> createState() => _OrderHistoryTabState();
}

class _OrderHistoryTabState extends State<_OrderHistoryTab> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await CoreApiService.getOrderHistory();
      setState(() {
        _orders = data['orders'] as List<dynamic>;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.body['message'] ?? 'Failed to load orders';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Cannot connect to server.';
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'placed':
        return Colors.blue;
      case 'assigned':
        return Colors.orange;
      case 'picked_up':
        return Colors.amber;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'placed':
        return Icons.receipt;
      case 'assigned':
        return Icons.person_pin;
      case 'picked_up':
        return Icons.takeout_dining;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No orders yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            Text('Place your first order!',
                style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index] as Map<String, dynamic>;
          final status = order['status'] as String;
          final items = order['items'] as List<dynamic>;
          final statusHistory = order['status_history'] as List<dynamic>?;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: _statusColor(status).withAlpha(30),
                child: Icon(_statusIcon(status), color: _statusColor(status)),
              ),
              title: Text(
                order['order_id'] as String,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${items.length} items',
                      style: theme.textTheme.bodySmall),
                ],
              ),
              children: [
                // Items list
                ...items.map((item) {
                  final i = item as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.fastfood, size: 18),
                    title: Text('${i['name']} × ${i['quantity']}'),
                    trailing: Text('₹${(i['price'] as num) * (i['quantity'] as num)}'),
                  );
                }),
                const Divider(),

                // Status history (audit trail)
                if (statusHistory != null && statusHistory.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Status History',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  ...statusHistory.map((h) {
                    final entry = h as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      leading: Icon(_statusIcon(entry['status'] as String),
                          size: 16, color: _statusColor(entry['status'] as String)),
                      title: Text((entry['status'] as String).toUpperCase()),
                      trailing: Text(
                        _formatDate(entry['changed_at']?.toString()),
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '—';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    final local = date.toLocal();
    return '${local.day}/${local.month} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
}
