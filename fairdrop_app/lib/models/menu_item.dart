// ============================================================================
// FairDrop — Menu Item Model (FR-62, FR-63, FR-64, D5)
// ============================================================================
// Strict schema: name, price, prep_time_seconds, is_available.
// ============================================================================

class MenuItem {
  final String id;
  final String restaurantId;
  final String name;
  final double price;
  final int prepTimeSeconds;
  final bool isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.price,
    required this.prepTimeSeconds,
    this.isAvailable = true,
    this.createdAt,
    this.updatedAt,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: (json['_id'] ?? json['id'] ?? json['item_id'] ?? '').toString(),
      restaurantId: (json['restaurant_id'] ?? json['restaurantId'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      prepTimeSeconds: (json['prep_time_seconds'] as num?)?.toInt() ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id,
      'restaurant_id': restaurantId,
      'name': name,
      'price': price,
      'prep_time_seconds': prepTimeSeconds,
      'is_available': isAvailable,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  MenuItem copyWith({
    String? id,
    String? restaurantId,
    String? name,
    double? price,
    int? prepTimeSeconds,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      price: price ?? this.price,
      prepTimeSeconds: prepTimeSeconds ?? this.prepTimeSeconds,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
