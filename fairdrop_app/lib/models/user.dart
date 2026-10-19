// ============================================================================
// FairDrop — User & Rider Profile Models
// ============================================================================

class ShiftSession {
  final DateTime startedAt;
  final DateTime? endedAt;

  ShiftSession({
    required this.startedAt,
    this.endedAt,
  });

  factory ShiftSession.fromJson(Map<String, dynamic> json) {
    return ShiftSession(
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
    };
  }
}

class RiderProfile {
  final String vehicleType;
  final String vehicleNumber;
  final String? zoneId;
  final String? currentZoneId;
  final String? assignedZoneCode;
  final String? currentZoneCode;
  final bool isAvailable;
  final bool isOnline;
  final double activeHoursToday;
  final DateTime? currentSessionStartedAt;
  final List<ShiftSession> shiftSessions;
  final bool safetyChecklistAcknowledged;

  RiderProfile({
    this.vehicleType = 'motorcycle',
    this.vehicleNumber = '',
    this.zoneId,
    this.currentZoneId,
    this.assignedZoneCode,
    this.currentZoneCode,
    this.isAvailable = true,
    this.isOnline = false,
    this.activeHoursToday = 0.0,
    this.currentSessionStartedAt,
    this.shiftSessions = const [],
    this.safetyChecklistAcknowledged = false,
  });

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    final sessionsRaw = json['shift_sessions'] as List<dynamic>? ?? [];
    return RiderProfile(
      vehicleType: json['vehicle_type'] as String? ?? 'motorcycle',
      vehicleNumber: json['vehicle_number'] as String? ?? '',
      zoneId: json['zone_id']?.toString(),
      currentZoneId: json['current_zone_id']?.toString(),
      assignedZoneCode: json['assigned_zone_code'] as String?,
      currentZoneCode: json['current_zone_code'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      isOnline: json['is_online'] as bool? ?? false,
      activeHoursToday: (json['active_hours_today'] as num?)?.toDouble() ?? 0.0,
      currentSessionStartedAt: json['current_session_started_at'] != null
          ? DateTime.tryParse(json['current_session_started_at'] as String)
          : null,
      shiftSessions: sessionsRaw
          .whereType<Map<String, dynamic>>()
          .map((s) => ShiftSession.fromJson(s))
          .toList(),
      safetyChecklistAcknowledged: json['safety_checklist_acknowledged'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'zone_id': zoneId,
      'current_zone_id': currentZoneId,
      'assigned_zone_code': assignedZoneCode,
      'current_zone_code': currentZoneCode,
      'is_available': isAvailable,
      'is_online': isOnline,
      'active_hours_today': activeHoursToday,
      'current_session_started_at': currentSessionStartedAt?.toIso8601String(),
      'shift_sessions': shiftSessions.map((s) => s.toJson()).toList(),
      'safety_checklist_acknowledged': safetyChecklistAcknowledged,
    };
  }
}

class UserAddress {
  final String label;
  final double latitude;
  final double longitude;

  UserAddress({
    this.label = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
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

class User {
  final String id;
  final String name;
  final String email;
  final String role; // 'rider', 'customer', 'restaurant', 'admin'
  final String phone;
  final UserAddress address;
  final RiderProfile? riderProfile;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    UserAddress? address,
    this.riderProfile,
  }) : address = address ?? UserAddress();

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'customer',
      phone: json['phone'] as String? ?? '',
      address: json['address'] is Map<String, dynamic>
          ? UserAddress.fromJson(json['address'] as Map<String, dynamic>)
          : UserAddress(),
      riderProfile: json['rider_profile'] is Map<String, dynamic>
          ? RiderProfile.fromJson(json['rider_profile'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'address': address.toJson(),
      if (riderProfile != null) 'rider_profile': riderProfile!.toJson(),
    };
  }
}
