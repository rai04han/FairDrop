// ============================================================================
// FairDrop — Incentive Analytics Model & Helper (FR-34, FR-35, FR-36)
// ============================================================================
// Provides pure Dart analytics calculation comparing FairDrop linear incentive
// policy against illustrative target platform incentive ladders (Zomato benchmark).
//
// NOTE: Pure client-side calculation; does not alter payEngine.js.
// ============================================================================

class IncentiveTier {
  final int zomatoOrders;
  final double targetIncentive;
  final int fairDropOrdersWithPeak;
  final int fairDropOrdersWithoutPeak;

  const IncentiveTier({
    required this.zomatoOrders,
    required this.targetIncentive,
    required this.fairDropOrdersWithPeak,
    required this.fairDropOrdersWithoutPeak,
  });
}

class IncentiveAnalytics {
  /// Default linear incentive rate: (510 - 50) / 27 ≈ ₹17.04 per order
  static const double defaultRatePerOrder = (510.0 - 50.0) / 27.0;

  /// Default peak window bonus: ₹25 × 2 windows (12–2 PM, 7–9 PM) = ₹50
  static const double defaultPeakBonus = 50.0;

  /// Target illustrative Zomato incentive ladder data points (28 Jun screenshot)
  static const Map<int, double> zomatoLadderSteps = {
    19: 306.0,
    23: 383.0,
    25: 434.0,
    27: 510.0,
  };

  /// Parity table of orders needed to earn the same incentive
  static const List<IncentiveTier> parityTable = [
    IncentiveTier(
      zomatoOrders: 19,
      targetIncentive: 306.0,
      fairDropOrdersWithPeak: 16,
      fairDropOrdersWithoutPeak: 18,
    ),
    IncentiveTier(
      zomatoOrders: 23,
      targetIncentive: 383.0,
      fairDropOrdersWithPeak: 20,
      fairDropOrdersWithoutPeak: 23,
    ),
    IncentiveTier(
      zomatoOrders: 25,
      targetIncentive: 434.0,
      fairDropOrdersWithPeak: 23,
      fairDropOrdersWithoutPeak: 26,
    ),
    IncentiveTier(
      zomatoOrders: 27,
      targetIncentive: 510.0,
      fairDropOrdersWithPeak: 27,
      fairDropOrdersWithoutPeak: 30,
    ),
  ];

  /// Computes step incentive for illustrative benchmark (Zomato ladder)
  static double getZomatoIncentive(int orders) {
    if (orders >= 27) return 510.0;
    if (orders >= 25) return 434.0;
    if (orders >= 23) return 383.0;
    if (orders >= 19) return 306.0;
    return 0.0;
  }

  /// Computes FairDrop linear incentive: rate * n + peak_bonus
  static double getFairDropIncentive(
    int orders, {
    double rate = defaultRatePerOrder,
    double peakBonus = defaultPeakBonus,
    bool includePeak = true,
  }) {
    if (orders <= 0) return 0.0;
    return (rate * orders) + (includePeak ? peakBonus : 0.0);
  }

  /// Explanatory notes mandated by PRD FR-36
  static const String noteScope =
      'Base, distance, monsoon, and return pay are identical on both platforms; this analysis compares daily incentives only.';

  static const String notePeakAssumption =
      'Peak bonus assumes the rider is online in both designated windows (12–2 PM and 7–9 PM).';

  static const String noteDailyVariation =
      'The incentive rate varies by day based on market conditions, similar to Zomato daily targets.';

  static const String noteBreakEven =
      "The platform's break-even rate = expected Zomato incentive spend ÷ expected orders per rider.";
}
