// ============================================================================
// FairDrop — Order Models (Module 2: Orders & Lifecycle)
// ============================================================================
// Conforms to MongoDB Order schema, PRD v2.1 Section 5, and demo flow.
// ============================================================================

import 'package:latlong2/latlong.dart';
import 'pay_result.dart';

class OrderItem {
  final String? itemId;
  final String name;
  final int quantity;
  final double price;
  final int prepTimeSeconds;

  OrderItem({
    this.itemId,
    required this.name,
    required this.quantity,
    required this.price,
    this.prepTimeSeconds = 0,
  });

  double get totalPrice => price * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemId: (json['item_id'] ?? json['itemId'])?.toString(),
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      prepTimeSeconds: (json['prep_time_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (itemId != null) 'item_id': itemId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'prep_time_seconds': prepTimeSeconds,
    };
  }
}

class OrderAddress {
  final String label;
  final double latitude;
  final double longitude;

  OrderAddress({
    this.label = '',
    required this.latitude,
    required this.longitude,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      label: json['label'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class DelayContext {
  final String type; // 'traffic', 'restaurant', 'railway', 'none'
  final bool verified;
  final String source; // 'system_log', 'api_mock', 'rider_report', 'none'

  DelayContext({
    this.type = 'none',
    this.verified = false,
    this.source = 'none',
  });

  factory DelayContext.fromJson(Map<String, dynamic> json) {
    return DelayContext(
      type: json['type'] as String? ?? 'none',
      verified: json['verified'] as bool? ?? false,
      source: json['source'] as String? ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'verified': verified,
      'source': source,
    };
  }
}

class StatusHistoryEntry {
  final String status;
  final DateTime changedAt;
  final String? changedBy;

  StatusHistoryEntry({
    required this.status,
    required this.changedAt,
    this.changedBy,
  });

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StatusHistoryEntry(
      status: json['status'] as String? ?? '',
      changedAt: json['changed_at'] != null
          ? DateTime.tryParse(json['changed_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      changedBy: json['changed_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'changed_at': changedAt.toIso8601String(),
      if (changedBy != null) 'changed_by': changedBy,
    };
  }
}

class Order {
  final String id;
  final String orderId; // ORD-YYYYMMDD-NNNN
  final String customerId;
  final String restaurantId;
  final String? riderId;
  final List<OrderItem> items;
  final OrderAddress deliveryAddress;
  final OrderAddress restaurantAddress;
  final double distanceKm;
  final String? zoneId;
  final String riderAck; // 'pending', 'accepted', 'declined'
  final List<String> declinedBy;
  final String allocation; // 'allocated', 'no_rider_available'
  final bool isOutOfZone;
  final double outOfZoneDistanceKm;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String payStatus; // 'none', 'pending', 'calculated'
  final bool isSurgeActive;
  final int restaurantWaitMins;
  final DelayContext delayContext;
  final PayResult? payCalculationResult;
  final String status; // 'placed', 'accepted', 'assigned', 'arrived', 'picked_up', 'delivered', 'cancelled'
  final List<StatusHistoryEntry> statusHistory;
  final bool isReady;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.restaurantId,
    this.riderId,
    this.items = const [],
    required this.deliveryAddress,
    required this.restaurantAddress,
    required this.distanceKm,
    this.zoneId,
    this.riderAck = 'pending',
    this.declinedBy = const [],
    this.allocation = 'allocated',
    this.isOutOfZone = false,
    this.outOfZoneDistanceKm = 0.0,
    this.acceptedAt,
    this.arrivedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.payStatus = 'none',
    this.isSurgeActive = false,
    this.restaurantWaitMins = 0,
    DelayContext? delayContext,
    this.payCalculationResult,
    this.status = 'accepted',
    this.statusHistory = const [],
    this.isReady = false,
    this.createdAt,
    this.updatedAt,
  }) : delayContext = delayContext ?? DelayContext();

  double get subtotal =>
      items.fold<double>(0.0, (sum, it) => sum + (it.price * it.quantity));

  int get totalItems =>
      items.fold<int>(0, (sum, it) => sum + it.quantity);

  bool get isPlaced => status == 'placed';
  bool get isAccepted => status == 'accepted';
  bool get isAssigned => status == 'assigned';
  bool get isArrived => status == 'arrived';
  bool get isPickedUp => status == 'picked_up';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final rawHistory = json['status_history'] as List<dynamic>? ?? [];
    final rawDeclined = json['declined_by'] as List<dynamic>? ?? [];

    final deliveryAddr = json['delivery_address'] is Map<String, dynamic>
        ? OrderAddress.fromJson(json['delivery_address'] as Map<String, dynamic>)
        : OrderAddress(latitude: 0.0, longitude: 0.0);

    final restaurantAddr = json['restaurant_address'] is Map<String, dynamic>
        ? OrderAddress.fromJson(json['restaurant_address'] as Map<String, dynamic>)
        : OrderAddress(latitude: 0.0, longitude: 0.0);

    final payResult = json['pay_calculation_result'] is Map<String, dynamic>
        ? PayResult.fromJson(json['pay_calculation_result'] as Map<String, dynamic>)
        : null;

    return Order(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      orderId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      customerId: (json['customer_id'] ?? json['customerId'] ?? '').toString(),
      restaurantId: (json['restaurant_id'] ?? json['restaurantId'] ?? '').toString(),
      riderId: json['rider_id']?.toString(),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((it) => OrderItem.fromJson(it))
          .toList(),
      deliveryAddress: deliveryAddr,
      restaurantAddress: restaurantAddr,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      zoneId: json['zone_id']?.toString(),
      riderAck: json['rider_ack'] as String? ?? 'pending',
      declinedBy: rawDeclined.map((e) => e.toString()).toList(),
      allocation: json['allocation'] as String? ?? 'allocated',
      isOutOfZone: json['is_out_of_zone'] as bool? ?? false,
      outOfZoneDistanceKm: (json['out_of_zone_distance_km'] as num?)?.toDouble() ?? 0.0,
      acceptedAt: json['accepted_at'] != null ? DateTime.tryParse(json['accepted_at'].toString()) : null,
      arrivedAt: json['arrived_at'] != null ? DateTime.tryParse(json['arrived_at'].toString()) : null,
      pickedUpAt: json['picked_up_at'] != null ? DateTime.tryParse(json['picked_up_at'].toString()) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.tryParse(json['delivered_at'].toString()) : null,
      payStatus: json['pay_status'] as String? ?? 'none',
      isSurgeActive: json['is_surge_active'] as bool? ?? false,
      restaurantWaitMins: (json['restaurant_wait_mins'] as num?)?.toInt() ?? 0,
      delayContext: json['delay_context'] is Map<String, dynamic>
          ? DelayContext.fromJson(json['delay_context'] as Map<String, dynamic>)
          : DelayContext(),
      payCalculationResult: payResult,
      status: json['status'] as String? ?? 'accepted',
      statusHistory: rawHistory
          .whereType<Map<String, dynamic>>()
          .map((h) => StatusHistoryEntry.fromJson(h))
          .toList(),
      isReady: json['is_ready'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id,
      'order_id': orderId,
      'customer_id': customerId,
      'restaurant_id': restaurantId,
      'rider_id': riderId,
      'items': items.map((i) => i.toJson()).toList(),
      'delivery_address': deliveryAddress.toJson(),
      'restaurant_address': restaurantAddress.toJson(),
      'distance_km': distanceKm,
      'zone_id': zoneId,
      'rider_ack': riderAck,
      'declined_by': declinedBy,
      'allocation': allocation,
      'is_out_of_zone': isOutOfZone,
      'out_of_zone_distance_km': outOfZoneDistanceKm,
      'accepted_at': acceptedAt?.toIso8601String(),
      'arrived_at': arrivedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'pay_status': payStatus,
      'is_surge_active': isSurgeActive,
      'restaurant_wait_mins': restaurantWaitMins,
      'delay_context': delayContext.toJson(),
      if (payCalculationResult != null)
        'pay_calculation_result': payCalculationResult!.toJson(),
      'status': status,
      'status_history': statusHistory.map((s) => s.toJson()).toList(),
      'is_ready': isReady,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
