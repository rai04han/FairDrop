// ============================================================================
// FairDrop — Pay Analytics Screen (Screen 10)
// ============================================================================
// PRD Features: FR-34, FR-35, FR-36
//
// PURPOSE:
//   A dedicated analytics screen reachable from Rider Dashboard (/analytics).
//   Compares FairDrop linear incentive policy against illustrative target platform
//   incentive ladders (Zomato benchmark) over 0–30 orders using fl_chart.
//
// CRITICAL CRITERIA:
//   1. FR-34: Visualizes FairDrop (with/without peak) vs Zomato ladder curves (0–30 orders)
//             using fl_chart. Explicitly states that base, distance, monsoon, and return
//             pay are identical on both sides; the comparison focuses on daily incentives only.
//   2. FR-35: Transparently states all illustrative model parameters on screen
//             (Zomato ladder, FairDrop ₹17.04/order rate, ₹50 peak bonus) with an
//             interactive toggle for peak windows covered.
//   3. FR-36: Displays parity table showing orders needed to earn the same incentive
//             (With peak: 16, 20, 23, 27; Without peak: 18, 23, 26, 30), highlights
//             equal pay at 27 orders with peak, and includes all required notes.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/core_api_service.dart';
import '../utils/incentive_analytics.dart';

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

  // Toggle for interactive peak windows covered (+₹50)
  bool _includePeakBonus = true;

  // Actual completed deliveries today (for personal benchmark)
  int _actualDeliveriesToday = 0;
  double _fairDropTotal = 0.0;
  double _benchmarkTotal = 0.0;

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
      final actualComparison = (data['actual_comparison'] as Map<String, dynamic>?) ?? {};
      _actualDeliveriesToday = (actualComparison['total_deliveries'] as num?)?.toInt() ?? 0;
      _fairDropTotal = (actualComparison['fairdrop_total'] as num?)?.toDouble() ??
          IncentiveAnalytics.getFairDropIncentive(_actualDeliveriesToday, includePeak: _includePeakBonus);
      _benchmarkTotal = (actualComparison['cliff_total'] as num?)?.toDouble() ??
          IncentiveAnalytics.getZomatoIncentive(_actualDeliveriesToday);
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
        const Duration(seconds: 4),
      );
      if (mounted) {
        _applyAnalyticsData(res);
      }
    } catch (_) {
      try {
        final statsData = await CoreApiService.getTodayStats();
        final stats = statsData['stats'] as Map<String, dynamic>? ?? {};
        if (mounted) {
          final count = (stats['deliveries_today'] as num?)?.toInt() ?? 0;
          setState(() {
            _actualDeliveriesToday = count;
            _fairDropTotal = IncentiveAnalytics.getFairDropIncentive(count, includePeak: _includePeakBonus);
            _benchmarkTotal = IncentiveAnalytics.getZomatoIncentive(count);
            _isLoading = false;
            _errorMessage = null;
          });
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
                        const SizedBox(height: 14),

                        // ── Scope Notice Banner (FR-34) ───────────────────────
                        _buildScopeBanner(),
                        const SizedBox(height: 14),

                        // ── Equal Pay & Metric Highlight Cards ────────────────
                        _buildMetricCards(),
                        const SizedBox(height: 16),

                        // ── Interactive Peak Windows Toggle (FR-35) ───────────
                        _buildPeakToggleCard(),
                        const SizedBox(height: 16),

                        // ── Cumulative Incentive Chart 0–30 (FR-34, FR-36) ────
                        _buildChartCard(),
                        const SizedBox(height: 16),

                        // ── Parity Table Card (FR-36) ─────────────────────────
                        _buildParityTableCard(),
                        const SizedBox(height: 16),

                        // ── Stated Assumptions Card (FR-35) ───────────────────
                        _buildAssumptionsCard(),
                        const SizedBox(height: 16),

                        // ── Policy Explanatory Notes Card (FR-36) ─────────────
                        _buildPolicyNotesCard(),
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
                  'FairDrop Linear Incentive Policy vs Target Benchmark',
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

  // ── Scope Notice Banner (FR-34, FR-36) ────────────────────────────────────
  Widget _buildScopeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FairDropColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FairDropColors.mintBorder.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: FairDropColors.brandNavy,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              IncentiveAnalytics.noteScope,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FairDropColors.brandNavy,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Comparison Metric Cards ───────────────────────────────────────────────
  Widget _buildMetricCards() {
    final fairDropAt27 = IncentiveAnalytics.getFairDropIncentive(27, includePeak: true);
    final zomatoAt27 = IncentiveAnalytics.getZomatoIncentive(27);

    return Row(
      children: [
        // FairDrop Incentive Card
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
                    Flexible(
                      child: Text(
                        'FairDrop Incentive',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: FairDropColors.brandGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${_fairDropTotal.toStringAsFixed(0)}',
                  key: const Key('text_fairdrop_total'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                Text(
                  'Over $_actualDeliveriesToday deliveries',
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

        // Target Benchmark Card (Zomato Ladder)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FairDropColors.brandOrange, width: 1.5),
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
                        color: FairDropColors.brandOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Zomato Ladder',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: FairDropColors.brandOrange,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${_benchmarkTotal.toStringAsFixed(0)}',
                  key: const Key('text_cliff_total'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                Text(
                  'Equal pay at 27 orders (₹${zomatoAt27.toInt()} vs ₹${fairDropAt27.toInt()})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FairDropColors.brandNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Peak Windows Toggle Card (FR-35) ──────────────────────────────────────
  Widget _buildPeakToggleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FairDropColors.mintBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peak Windows Covered',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _includePeakBonus
                      ? '₹25 × 2 windows (12–2 PM, 7–9 PM) = +₹50 bonus active'
                      : 'Linear rate only (₹0 peak bonus applied)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: FairDropColors.slateMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('switch_peak_windows'),
            value: _includePeakBonus,
            activeThumbColor: FairDropColors.brandGreen,
            onChanged: (val) {
              setState(() {
                _includePeakBonus = val;
                _fairDropTotal = IncentiveAnalytics.getFairDropIncentive(
                  _actualDeliveriesToday,
                  includePeak: _includePeakBonus,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  // ── Chart Card (0–30 Orders) (FR-34, FR-36) ───────────────────────────────
  Widget _buildChartCard() {
    final List<FlSpot> zomatoSpots = [];
    final List<FlSpot> fairDropWithPeakSpots = [];
    final List<FlSpot> fairDropNoPeakSpots = [];

    for (int n = 0; n <= 30; n++) {
      zomatoSpots.add(FlSpot(n.toDouble(), IncentiveAnalytics.getZomatoIncentive(n)));
      fairDropWithPeakSpots.add(
        FlSpot(n.toDouble(), IncentiveAnalytics.getFairDropIncentive(n, includePeak: true)),
      );
      fairDropNoPeakSpots.add(
        FlSpot(n.toDouble(), IncentiveAnalytics.getFairDropIncentive(n, includePeak: false)),
      );
    }

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
              Expanded(
                child: Text(
                  'Cumulative Daily Incentive vs Orders (0–30)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandNavy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FairDropColors.mintBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Equal @ 27 Drops',
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
            'Compares linear FairDrop policy against illustrative Zomato ladder steps',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: FairDropColors.slateMuted,
            ),
          ),
          const Divider(height: 24),

          // Chart Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegendPill(FairDropColors.brandGreen, 'FairDrop (With Peak)'),
              _buildLegendPill(const Color(0xFF0D9488), 'FairDrop (Without Peak)'),
              _buildLegendPill(FairDropColors.brandOrange, 'Zomato Ladder (Illustrative Example)'),
            ],
          ),
          const SizedBox(height: 18),

          // Chart Canvas
          SizedBox(
            height: 270,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 30,
                minY: 0,
                maxY: 600,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 100,
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
                      'Completed Orders (0–30)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: FairDropColors.slateMuted,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 5,
                      getTitlesWidget: (val, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            val.toInt().toString(),
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
                      interval: 100,
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
                  // 1. Zomato step line
                  LineChartBarData(
                    spots: zomatoSpots,
                    isCurved: false,
                    isStepLineChart: true,
                    color: FairDropColors.brandOrange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                  // 2. FairDrop with Peak Line
                  LineChartBarData(
                    spots: fairDropWithPeakSpots,
                    isCurved: false,
                    color: FairDropColors.brandGreen,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: FairDropColors.brandGreen.withValues(alpha: 0.08),
                    ),
                  ),
                  // 3. FairDrop without Peak Line
                  LineChartBarData(
                    spots: fairDropNoPeakSpots,
                    isCurved: false,
                    color: const Color(0xFF0D9488),
                    barWidth: 2.5,
                    dashArray: [5, 5],
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
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
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: FairDropColors.brandNavy,
            ),
          ),
        ),
      ],
    );
  }

  // ── Parity Table Card (FR-36) ─────────────────────────────────────────────
  Widget _buildParityTableCard() {
    return Container(
      key: const Key('parity_table_card'),
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
              const Icon(Icons.table_chart_rounded, color: FairDropColors.brandNavy, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Incentive Parity: Orders Needed to Match Benchmark',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Demonstrates how FairDrop linear compensation delivers equal or higher incentive with fewer orders',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: FairDropColors.slateMuted,
            ),
          ),
          const Divider(height: 20),

          // Parity Table Rows
          Table(
            border: TableBorder(
              horizontalInside: BorderSide(
                color: FairDropColors.mintBorder.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            columnWidths: const {
              0: FlexColumnWidth(1.4),
              1: FlexColumnWidth(1.0),
              2: FlexColumnWidth(1.1),
              3: FlexColumnWidth(1.1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: FairDropColors.surfaceLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                children: [
                  _buildTableCell('Target Tier', isHeader: true),
                  _buildTableCell('Zomato', isHeader: true),
                  _buildTableCell('FairDrop (Peak)', isHeader: true),
                  _buildTableCell('FairDrop (No Peak)', isHeader: true),
                ],
              ),
              ...IncentiveAnalytics.parityTable.map((tier) {
                final isEqualPay = tier.zomatoOrders == 27;
                return TableRow(
                  decoration: isEqualPay
                      ? BoxDecoration(color: FairDropColors.mintBg.withValues(alpha: 0.4))
                      : null,
                  children: [
                    _buildTableCell('₹${tier.targetIncentive.toInt()} Incentive', isBold: isEqualPay),
                    _buildTableCell('${tier.zomatoOrders} orders', isBold: isEqualPay),
                    _buildTableCell(
                      '${tier.fairDropOrdersWithPeak} orders',
                      color: FairDropColors.brandGreen,
                      isBold: true,
                    ),
                    _buildTableCell(
                      '${tier.fairDropOrdersWithoutPeak} orders',
                      color: const Color(0xFF0D9488),
                      isBold: true,
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FairDropColors.mintBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle_rounded, color: FairDropColors.brandGreen, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Equal pay at 27 orders with peak bonus: ₹510 FairDrop = ₹510 Zomato.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FairDropColors.brandNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cost-neutral at the top Zomato tier (27 orders); extra platform cost below 27 orders, with per-order extra capped at 27 orders.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: FairDropColors.brandNavy.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: isHeader ? 11 : 12,
          fontWeight: isHeader || isBold ? FontWeight.w800 : FontWeight.w500,
          color: color ?? (isHeader ? FairDropColors.brandNavy : FairDropColors.brandNavy),
        ),
      ),
    );
  }

  // ── Stated Assumptions Card (FR-35) ───────────────────────────────────────
  Widget _buildAssumptionsCard() {
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
              Expanded(
                child: Text(
                  'Stated Model Parameters & Assumptions',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Transparent parameters governing comparative incentive calculations (FR-35)',
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
              _buildAssumptionChip('Benchmark Model', 'Zomato Ladder (28 Jun)'),
              _buildAssumptionChip('FairDrop Linear Rate', '₹17.04 / order'),
              _buildAssumptionChip('Peak Windows Bonus', '₹25 × 2 = ₹50'),
              _buildAssumptionChip('Equal Pay Benchmark', '27 orders (₹510)'),
              _buildAssumptionChip('Break-Even Policy', 'Spend ÷ Expected Orders'),
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
              'Illustrative example data (single source, 28 Jun screenshot): 19 orders = ₹306, 23 = ₹383, 25 = ₹434, 27 = ₹510. FairDrop incentive(n) = ₹17.04 × n + ₹50 peak bonus.',
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
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: FairDropColors.brandNavy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Policy Explanatory Notes Card (FR-36) ──────────────────────────────────
  Widget _buildPolicyNotesCard() {
    return Container(
      key: const Key('policy_notes_card'),
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
              Expanded(
                child: Text(
                  'Policy Notes & Transparency Criteria',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPolicyBullet(IncentiveAnalytics.notePeakAssumption),
          const SizedBox(height: 8),
          _buildPolicyBullet(IncentiveAnalytics.noteDailyVariation),
          const SizedBox(height: 8),
          _buildPolicyBullet(IncentiveAnalytics.noteBreakEven),
          const SizedBox(height: 8),
          _buildPolicyBullet(IncentiveAnalytics.noteCostNeutrality),
        ],
      ),
    );
  }

  Widget _buildPolicyBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: FairDropColors.brandGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
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
