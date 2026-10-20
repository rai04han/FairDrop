// ============================================================================
// FairDrop — Pay Analytics Screen (Screen 10)
// ============================================================================
// PRD Features: FR-34, FR-35, FR-36
//
// PURPOSE:
//   A dedicated analytics screen reachable from Rider Dashboard (/analytics).
//   Compares FairDrop cumulative pay against a traditional industry cliff-bonus
//   system over the same deliveries using fl_chart.
//
// CRITICAL CRITERIA:
//   1. FR-34: Visualizes FairDrop vs Cliff-Bonus curves using fl_chart.
//             Numbers fetched directly from GET /api/pay/analytics/:rider_id.
//   2. FR-35: Explicitly states all cliff model assumptions on screen so
//             the comparison can be challenged and verified.
//   3. FR-36: Displays the backend-computed "Cliff-Wins Scenario" (balanced
//             framing: when a rider clears 10+ deliveries, cliff bonus pays more;
//             paired with empirical Fairwork data showing >80% miss quota).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/core_api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialAnalytics;
  final bool autoFetch;
  final String? initialErrorMessage;

  const AnalyticsScreen({
    super.key,
    this.initialAnalytics,
    this.autoFetch = true,
    this.initialErrorMessage,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  // 0 = Actual Deliveries, 1 = Cliff-Wins Scenario
  int _selectedViewIndex = 0;

  Map<String, dynamic> _assumptions = {};
  Map<String, dynamic> _actualComparison = {};
  Map<String, dynamic> _cliffWinsScenario = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialErrorMessage != null) {
      _errorMessage = widget.initialErrorMessage;
      _isLoading = false;
    } else if (widget.initialAnalytics != null) {
      _applyAnalyticsData(widget.initialAnalytics!);
    } else if (widget.autoFetch) {
      _fetchAnalytics();
    } else {
      _applyAnalyticsData({});
    }
  }

  void _applyAnalyticsData(Map<String, dynamic> data) {
    setState(() {
      _assumptions = (data['assumptions'] as Map<String, dynamic>?) ?? {};
      _actualComparison =
          (data['actual_comparison'] as Map<String, dynamic>?) ?? {};
      _cliffWinsScenario =
          (data['cliff_wins_scenario'] as Map<String, dynamic>?) ?? {};
      _isLoading = false;
      _errorMessage = null;
    });
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final riderId = await CoreApiService.getUserId() ?? 'rider-001';
      final res = await ApiService.getPayAnalytics(riderId).timeout(
        const Duration(seconds: 2),
      );
      if (mounted) {
        _applyAnalyticsData(res);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load analytics. Please check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('btn_back_analytics'),
          icon: const Icon(Icons.arrow_back_rounded, color: FairDropColors.brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pay Analytics',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: FairDropColors.brandNavy,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: FairDropColors.brandGreen),
            tooltip: 'Refresh analytics',
            onPressed: _fetchAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: FairDropColors.brandGreen))
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  color: FairDropColors.brandGreen,
                  onRefresh: _fetchAnalytics,
                  child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header Card ───────────────────────────────────────
                    _buildHeaderCard(),
                    const SizedBox(height: 16),

                    // ── Mode Switcher (Actual vs Scenario) ────────────────
                    _buildModeSelector(),
                    const SizedBox(height: 16),

                    // ── Comparison Metric Cards ───────────────────────────
                    _buildMetricCards(),
                    const SizedBox(height: 16),

                    // ── Interactive Chart (FR-34) ─────────────────────────
                    _buildChartCard(),
                    const SizedBox(height: 16),

                    // ── Cliff Model Assumptions Card (FR-35) ──────────────
                    _buildAssumptionsCard(),
                    const SizedBox(height: 16),

                    // ── Cliff-Wins Scenario Card (FR-36) ──────────────────
                    _buildCliffWinsCard(),
                    const SizedBox(height: 16),

                    // ── Policy & Fairwork Context Card ────────────────────
                    _buildFairworkContextCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Header Card ───────────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FairDropColors.mintBorder),
        boxShadow: FairDropColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FairDropColors.mintBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: FairDropColors.brandGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comparative Model Analytics',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'FairDrop Linear Compensation vs Industry Quota Cliffs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: FairDropColors.slateMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── View Mode Selector (Segmented) ────────────────────────────────────────
  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FairDropColors.mintBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              key: const Key('tab_actual_history'),
              onTap: () => setState(() => _selectedViewIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedViewIndex == 0
                      ? FairDropColors.brandNavy
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Actual Deliveries',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _selectedViewIndex == 0
                        ? Colors.white
                        : FairDropColors.slateMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              key: const Key('tab_cliff_wins'),
              onTap: () => setState(() => _selectedViewIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedViewIndex == 1
                      ? FairDropColors.brandOrange
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Cliff-Wins Scenario',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _selectedViewIndex == 1
                        ? Colors.white
                        : FairDropColors.slateMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Comparison Metric Cards ───────────────────────────────────────────────
  Widget _buildMetricCards() {
    final isActual = _selectedViewIndex == 0;
    final fairDropTotal = isActual
        ? (_actualComparison['fairdrop_total'] ?? 0.0)
        : (_cliffWinsScenario['fairdrop_total'] ?? 0.0);
    final cliffTotal = isActual
        ? (_actualComparison['cliff_total'] ?? 0.0)
        : (_cliffWinsScenario['cliff_total'] ?? 0.0);
    final count = isActual
        ? (_actualComparison['total_deliveries'] ?? 0)
        : (_cliffWinsScenario['deliveries_count'] ?? 10);
    final difference = (fairDropTotal - cliffTotal).abs();
    final fairDropLeads = fairDropTotal >= cliffTotal;

    return Row(
      children: [
        // FairDrop Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FairDropColors.brandGreen, width: 1.5),
              boxShadow: FairDropColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: FairDropColors.brandGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FairDrop Pay',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FairDropColors.brandGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${fairDropTotal.toStringAsFixed(0)}',
                  key: const Key('text_fairdrop_total'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                Text(
                  'Over $count deliveries',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: FairDropColors.slateMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Cliff Model Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActual ? Colors.red.shade200 : FairDropColors.brandOrange,
                width: 1.5,
              ),
              boxShadow: FairDropColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActual ? Colors.red.shade400 : FairDropColors.brandOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cliff Model',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActual ? Colors.red.shade700 : FairDropColors.brandOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${cliffTotal.toStringAsFixed(0)}',
                  key: const Key('text_cliff_total'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                Text(
                  fairDropLeads
                      ? 'FairDrop +₹${difference.toStringAsFixed(0)}'
                      : 'Cliff +₹${difference.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fairDropLeads
                        ? FairDropColors.brandGreen
                        : FairDropColors.brandOrange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Chart Card (FR-34) ────────────────────────────────────────────────────
  Widget _buildChartCard() {
    final isActual = _selectedViewIndex == 0;
    final List<dynamic> dataPoints = isActual
        ? (_actualComparison['data_points'] as List<dynamic>? ?? [])
        : (_cliffWinsScenario['data_points'] as List<dynamic>? ?? []);

    if (dataPoints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FairDropColors.mintBorder),
        ),
        child: Center(
          child: Text(
            'No cumulative points available yet.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: FairDropColors.slateMuted,
            ),
          ),
        ),
      );
    }

    // Build fl_chart spots
    final List<FlSpot> fairDropSpots = [];
    final List<FlSpot> cliffSpots = [];

    double maxY = 100;
    for (int i = 0; i < dataPoints.length; i++) {
      final dp = dataPoints[i];
      final x = (dp['delivery_index'] as num?)?.toDouble() ?? (i + 1).toDouble();
      final fdY = (dp['fairdrop_cumulative'] as num?)?.toDouble() ?? 0.0;
      final clY = (dp['cliff_cumulative'] as num?)?.toDouble() ?? 0.0;

      fairDropSpots.add(FlSpot(x, fdY));
      cliffSpots.add(FlSpot(x, clY));

      if (fdY > maxY) maxY = fdY;
      if (clY > maxY) maxY = clY;
    }
    maxY = maxY * 1.15; // 15% headroom

    return Container(
      key: const Key('pay_analytics_chart_container'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FairDropColors.mintBorder),
        boxShadow: FairDropColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isActual ? 'Cumulative Delivery Pay' : 'Scenario Model Trajectory',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: FairDropColors.brandNavy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FairDropColors.mintBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${dataPoints.length} Points',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isActual
                ? 'Shows your actual cumulative shift earnings vs quota-cliff model'
                : '10-delivery shift simulation: Cliff bonus hits sharply at delivery #10',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: FairDropColors.slateMuted,
            ),
          ),
          const Divider(height: 24),

          // Chart Legend
          Row(
            children: [
              _buildLegendPill(FairDropColors.brandGreen, 'FairDrop (Linear + Floor)'),
              const SizedBox(width: 12),
              _buildLegendPill(
                isActual ? Colors.red.shade400 : FairDropColors.brandOrange,
                'Cliff Model (Quota Trap)',
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Chart Canvas
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: dataPoints.length.toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 500 ? 150 : 50,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: FairDropColors.mintBorder.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(
                      'Delivery Number (Cumulative)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: FairDropColors.slateMuted,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '#${val.toInt()}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: FairDropColors.slateMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (val, meta) {
                        return Text(
                          '₹${val.toInt()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: FairDropColors.slateMuted,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  // FairDrop Line
                  LineChartBarData(
                    spots: fairDropSpots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: FairDropColors.brandGreen,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: FairDropColors.brandGreen,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: FairDropColors.brandGreen.withValues(alpha: 0.08),
                    ),
                  ),
                  // Cliff Line
                  LineChartBarData(
                    spots: cliffSpots,
                    isCurved: false,
                    color: isActual ? Colors.red.shade400 : FairDropColors.brandOrange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: isActual ? Colors.red.shade400 : FairDropColors.brandOrange,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (isActual ? Colors.red : FairDropColors.brandOrange)
                          .withValues(alpha: 0.06),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: FairDropColors.brandNavy,
          ),
        ),
      ],
    );
  }

  // ── Cliff Model Assumptions Card (FR-35) ──────────────────────────────────
  Widget _buildAssumptionsCard() {
    final threshold = _assumptions['cliff_threshold_deliveries'] ?? 10;
    final basePay = _assumptions['cliff_base_per_delivery'] ?? 20.0;
    final bonus = _assumptions['cliff_bonus'] ?? 500.0;
    final description = _assumptions['description'] ??
        'Industry standard cliff-bonus model: ₹20 base pay per delivery with a ₹500 flat bonus upon reaching exactly 10 deliveries. Zero bonus for deliveries 1–9. No distance pay, no wait compensation, no hourly floor.';

    return Container(
      key: const Key('cliff_assumptions_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FairDropColors.mintBorder),
        boxShadow: FairDropColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_rounded, color: FairDropColors.brandNavy, size: 20),
              const SizedBox(width: 8),
              Text(
                'Stated Cliff Model Assumptions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: FairDropColors.brandNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Transparent parameters governing industry quota calculations (FR-35)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: FairDropColors.slateMuted,
            ),
          ),
          const Divider(height: 20),

          // Assumption pills / metrics
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAssumptionChip('Quota Threshold', '$threshold deliveries'),
              _buildAssumptionChip('Base Rate', '₹$basePay / delivery'),
              _buildAssumptionChip('Cliff Bonus', '₹$bonus flat'),
              _buildAssumptionChip('Distance Pay', '₹0.00 / km'),
              _buildAssumptionChip('Wait Pay', '₹0.00 / min'),
              _buildAssumptionChip('Floor Guarantee', 'None (₹0/hr)'),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FairDropColors.surfaceLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              description.toString(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.45,
                color: FairDropColors.brandNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssumptionChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FairDropColors.mintBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FairDropColors.mintBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: FairDropColors.slateMuted,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: FairDropColors.brandNavy,
            ),
          ),
        ],
      ),
    );
  }

  // ── Cliff-Wins Scenario Card (FR-36) ──────────────────────────────────────
  Widget _buildCliffWinsCard() {
    final scenarioName = _cliffWinsScenario['scenario_name'] ??
        'High-Volume Target-Achieved Shift (10 Deliveries)';
    final description = _cliffWinsScenario['description'] ??
        'A rider completes 10 short deliveries (2 km each) within a 4-hour peak window, clearing the cliff threshold.';
    final cliffAdvantage = _cliffWinsScenario['cliff_advantage'] ?? 420.0;
    final cliffTotal = _cliffWinsScenario['cliff_total'] ?? 700.0;
    final fairDropTotal = _cliffWinsScenario['fairdrop_total'] ?? 280.0;
    final rationale = _cliffWinsScenario['rationale'] ??
        'When a rider clears the 10-delivery quota, the ₹500 bonus elevates cliff earnings to ₹700 vs FairDrop ₹280. However, Fairwork data shows over 80% of shifts fail to reach quota due to fatigue, weather, or order droughts, resulting in severe cliff penalties.';

    return Container(
      key: const Key('cliff_wins_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FairDropColors.brandOrange.withValues(alpha: 0.5), width: 1.5),
        boxShadow: FairDropColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FairDropColors.brandOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.balance_rounded,
                  color: FairDropColors.brandOrange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: FairDropColors.brandOrange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'BALANCED FRAMING: CLIFF WINS (+₹${cliffAdvantage.toStringAsFixed(0)})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      scenarioName.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description.toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: FairDropColors.slateMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Payout comparison row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FairDropColors.mintBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FairDropColors.mintBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'FairDrop Total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: FairDropColors.slateMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${fairDropTotal.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandGreen,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 28, color: FairDropColors.mintBorder),
                Column(
                  children: [
                    Text(
                      'Cliff Model Total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: FairDropColors.slateMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${cliffTotal.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandOrange,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 28, color: FairDropColors.mintBorder),
                Column(
                  children: [
                    Text(
                      'Cliff Advantage',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: FairDropColors.slateMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+₹${cliffAdvantage.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Rationale & academic justification
          Text(
            rationale.toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: FairDropColors.brandNavy,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedViewIndex != 1)
            OutlinedButton.icon(
              key: const Key('btn_visualize_scenario'),
              onPressed: () => setState(() => _selectedViewIndex = 1),
              icon: const Icon(Icons.show_chart_rounded, size: 18),
              label: const Text('Visualize Scenario on Chart'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FairDropColors.brandOrange,
                side: const BorderSide(color: FairDropColors.brandOrange),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Policy & Fairwork Context Card ────────────────────────────────────────
  Widget _buildFairworkContextCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FairDropColors.brandNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Fairwork Kerala Principle',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Traditional cliff bonuses incentivize aggressive driving and excessive hours to avoid losing the entire bonus on delivery #9. FairDrop decouples pay from arbitrary quotas, guaranteeing ₹70/hr statutory wage floors and fair compensation for every kilometre and wait minute.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      key: const Key('analytics_error_view'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: FairDropColors.errorRed),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unable to load analytics',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: FairDropColors.brandNavy,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('btn_retry_analytics'),
              onPressed: _fetchAnalytics,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: FairDropColors.brandGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
