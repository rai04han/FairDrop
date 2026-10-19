// ============================================================================
// FairDrop — Pay Configuration Models (FR-40, FR-41, FR-42, FR-75)
// ============================================================================
// Models for active and scheduled pay configurations.
// ============================================================================

class PayConfig {
  final int? configId;
  final double baseRate;
  final double perKmRate;
  final double surgeBonus;
  final int waitThresholdMins;
  final double waitCompensation;
  final double minWagePerHour;
  final DateTime? effectiveFrom;
  final bool isActive;
  final String? changeReason;
  final String? createdBy;
  final DateTime? createdAt;

  PayConfig({
    this.configId,
    required this.baseRate,
    required this.perKmRate,
    required this.surgeBonus,
    required this.waitThresholdMins,
    required this.waitCompensation,
    required this.minWagePerHour,
    this.effectiveFrom,
    this.isActive = true,
    this.changeReason,
    this.createdBy,
    this.createdAt,
  });

  factory PayConfig.fromJson(Map<String, dynamic> json) {
    return PayConfig(
      configId: json['config_id'] as int?,
      baseRate: (json['base_rate'] as num?)?.toDouble() ?? 0.0,
      perKmRate: (json['per_km_rate'] as num?)?.toDouble() ?? 0.0,
      surgeBonus: (json['surge_bonus'] as num?)?.toDouble() ?? 0.0,
      waitThresholdMins: (json['wait_threshold_mins'] as num?)?.toInt() ?? 1,
      waitCompensation: (json['wait_compensation'] as num?)?.toDouble() ?? 0.0,
      minWagePerHour: (json['min_wage_per_hour'] as num?)?.toDouble() ?? 0.0,
      effectiveFrom: json['effective_from'] != null
          ? DateTime.tryParse(json['effective_from'].toString())
          : null,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      changeReason: json['change_reason'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (configId != null) 'config_id': configId,
      'base_rate': baseRate,
      'per_km_rate': perKmRate,
      'surge_bonus': surgeBonus,
      'wait_threshold_mins': waitThresholdMins,
      'wait_compensation': waitCompensation,
      'min_wage_per_hour': minWagePerHour,
      if (effectiveFrom != null) 'effective_from': effectiveFrom!.toIso8601String().substring(0, 10),
      'is_active': isActive,
      if (changeReason != null) 'change_reason': changeReason,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

class PayConfigResponse {
  final PayConfig active;
  final PayConfig? scheduled;

  PayConfigResponse({
    required this.active,
    this.scheduled,
  });

  factory PayConfigResponse.fromJson(Map<String, dynamic> json) {
    final activeJson = json['active'] ?? json['config'] ?? json['active_config'];
    if (activeJson is! Map<String, dynamic>) {
      throw FormatException('Missing active config in response');
    }

    final rawScheduled = json['scheduled'] ?? json['scheduled_config'];
    final scheduledJson = rawScheduled is Map<String, dynamic> ? rawScheduled : null;

    return PayConfigResponse(
      active: PayConfig.fromJson(activeJson),
      scheduled: scheduledJson != null ? PayConfig.fromJson(scheduledJson) : null,
    );
  }
}
