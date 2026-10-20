// ============================================================================
// FairDrop — Cart Service & Models (FR-57, FR-58)
// ============================================================================
// Singleton cart managing in-memory customer cart state with single-restaurant
// enforcement, live quantity manipulation, and straight-line delivery fee calculation.
// ============================================================================

import '../models/menu_item.dart';
import '../utils/geo_utils.dart';

class CartItem {
  final MenuItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});

  double get totalPrice => item.price * quantity;
}

class CartService {
  CartService._internal();
  static final CartService instance = CartService._internal();

  Map<String, dynamic>? _deliveryLocation;
  Map<String, dynamic>? _restaurant;
  final List<CartItem> _items = [];

  Map<String, dynamic>? get deliveryLocation => _deliveryLocation;
  Map<String, dynamic>? get restaurant => _restaurant;
  List<CartItem> get items => List.unmodifiable(_items);

  void setDeliveryLocation(Map<String, dynamic> location) {
    _deliveryLocation = location;
  }

  void setRestaurant(Map<String, dynamic> restaurant) {
    if (_restaurant != null && (_restaurant!['id'] ?? _restaurant!['_id']) != (restaurant['id'] ?? restaurant['_id'])) {
      // Restaurant changed: clear cart to enforce single-restaurant rule (FR-58)
      _items.clear();
    }
    _restaurant = restaurant;
  }

  /// Adds a menu item to the cart. Rejects if unavailable (FR-57) or different restaurant.
  bool addItem(MenuItem menuItem) {
    if (!menuItem.isAvailable) {
      return false;
    }

    if (_restaurant != null) {
      final currentRestId = (_restaurant!['id'] ?? _restaurant!['_id'])?.toString();
      if (currentRestId != null && currentRestId.isNotEmpty && currentRestId != menuItem.restaurantId) {
        return false;
      }
    }

    final index = _items.indexWhere((i) => i.item.id == menuItem.id);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(item: menuItem, quantity: 1));
    }
    return true;
  }

  /// Decrements item quantity, removing if reaches 0.
  void removeItem(String itemId) {
    final index = _items.indexWhere((i) => i.item.id == itemId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
    }
  }

  /// Removes an item completely from the cart.
  void deleteItem(String itemId) {
    _items.removeWhere((i) => i.item.id == itemId);
  }

  /// Resets the cart.
  void clear() {
    _items.clear();
    _restaurant = null;
    _deliveryLocation = null;
  }

  int get totalItemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => _items.fold(0.0, (sum, i) => sum + i.totalPrice);

  double get distanceKm {
    if (_deliveryLocation == null || _restaurant == null) return 2.5;

    final destLat = (_deliveryLocation!['latitude'] ?? _deliveryLocation!['lat'] as num?)?.toDouble();
    final destLng = (_deliveryLocation!['longitude'] ?? _deliveryLocation!['lng'] as num?)?.toDouble();

    final restAddr = _restaurant!['address'] as Map<String, dynamic>?;
    final restLat = (restAddr?['latitude'] ?? restAddr?['lat'] as num?)?.toDouble() ?? 8.8870;
    final restLng = (restAddr?['longitude'] ?? restAddr?['lng'] as num?)?.toDouble() ?? 76.5900;

    if (destLat != null && destLng != null) {
      final d = GeoUtils.haversineDistanceKm(restLat, restLng, destLat, destLng);
      return double.parse(d.toStringAsFixed(2));
    }
    return 2.5;
  }

  /// FR-59 / D4: Total is sum of item prices only (no delivery fee, platform fee, GST).
  double get grandTotal => subtotal;

  List<Map<String, dynamic>> toOrderItems() {
    return _items.map((i) => {
      'item_id': i.item.id,
      'name': i.item.name,
      'quantity': i.quantity,
    }).toList();
  }
}
