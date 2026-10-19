// ============================================================================
// FairDrop — Pay Result & Line Item Models (FR-21, FR-22, FR-74)
// ============================================================================
// Represents the pay calculation breakdown returned by the Pay Engine
// (Port 3001 POST /api/pay/calculate) and embedded on completed orders.
// ============================================================================

class PayLineItem {
  final String label;
  final double amount;
  final String? subtitle;
  final bool isHighlight;

  PayLineItem({
    required this.label,
    required this.amount,
    this.subtitle,
    this.isHighlight = false,
  });
}

class PayResult {
  final String orderId;
  final double baseRate;
  final double distancePay;
  final double surgeBonus;
  final double waitCompensation;
  final double totalDeliveryPay;
  final double floorTopup;
  final double hourlyEarningsSoFar;
  final bool isCached;

  PayResult({
    required this.orderId,
    required this.baseRate,
    required this.distancePay,
    this.surgeBonus = 0.0,
    this.waitCompensation = 0.0,
    required this.totalDeliveryPay,
    this.floorTopup = 0.0,
    this.hourlyEarningsSoFar = 0.0,
    this.isCached = false,
  });

  /// Total pay including any minimum earnings floor top-up
  double get totalWithTopup => (totalDeliveryPay + floorTopup);

  factory PayResult.fromJson(Map<String, dynamic> json) {
    return PayResult(
      orderId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      baseRate: (json['base_rate'] as num?)?.toDouble() ?? 0.0,
      distancePay: (json['distance_pay'] as num?)?.toDouble() ?? 0.0,
      surgeBonus: (json['surge_bonus'] as num?)?.toDouble() ?? 0.0,
      waitCompensation: (json['wait_compensation'] as num?)?.toDouble() ?? 0.0,
      totalDeliveryPay: (json['total_delivery_pay'] as num?)?.toDouble() ?? 0.0,
      floorTopup: (json['floor_topup'] as num?)?.toDouble() ?? 0.0,
      hourlyEarningsSoFar: (json['hourly_earnings_so_far'] as num?)?.toDouble() ?? 0.0,
      isCached: json['is_cached'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'base_rate': baseRate,
      'distance_pay': distancePay,
      'surge_bonus': surgeBonus,
      'wait_compensation': waitCompensation,
      'total_delivery_pay': totalDeliveryPay,
      'floor_topup': floorTopup,
      'hourly_earnings_so_far': hourlyEarningsSoFar,
      'is_cached': isCached,
    };
  }

  /// Generates the line-item breakdown for the rider delivery receipt (FR-21).
  List<PayLineItem> get breakdownLineItems {
    final list = <PayLineItem>[
      PayLineItem(label: 'Base Rate', amount: baseRate),
      PayLineItem(label: 'Distance Pay', amount: distancePay),
    ];

    if (surgeBonus > 0) {
      list.add(PayLineItem(label: 'Surge Bonus', amount: surgeBonus));
    }
    if (waitCompensation > 0) {
      list.add(PayLineItem(label: 'Wait Compensation', amount: waitCompensation));
    }
    if (floorTopup > 0) {
      list.add(
        PayLineItem(
          label: 'Floor Top-Up',
          amount: floorTopup,
          subtitle: 'Guarantees statutory minimum hourly rate',
        ),
      );
    }

    list.add(
      PayLineItem(
        label: 'Total Payout',
        amount: totalWithTopup,
        isHighlight: true,
      ),
    );

    return list;
  }
}
