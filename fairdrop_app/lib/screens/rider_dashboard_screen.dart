// ============================================================================
// FairDrop — Rider Dashboard Screen
// ============================================================================
// Owner: Raihan
// PRD Features: F-DASH-02 (FairDrop vs Cliff-Bonus Comparison Chart)
//
// PURPOSE:
//   This screen shows a rider's earnings history and the KEY academic
//   contribution — a visual comparison between FairDrop's linear pay
//   model and the traditional cliff-bonus system.
//
//   The chart makes it immediately obvious WHY FairDrop is fairer:
//   - Cliff: ₹0 bonus for deliveries 1-9, ₹500 bonus at delivery 10
//   - FairDrop: Fair pay from delivery #1
//
// DATA FLOW:
//   Screen loads → GET /api/pay/history/rider-001 → displays table + chart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Import our API service to fetch earnings history
import '../services/api_service.dart';

// ============================================================================
// RiderDashboardScreen — StatefulWidget
// ============================================================================
// StatefulWidget because:
//   - Earnings data loads from API on screen open
//   - Chart data is computed from API response
//   - Loading/error states change
class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  // ── State Variables ─────────────────────────────────────────────────────

  bool _isLoading = true;
  String? _errorMessage;

  // Raw earnings data from the API
  List<dynamic> _earnings = [];

  // Computed summary statistics
  double _totalEarned = 0;
  double _avgHourlyRate = 0;
  int _totalDeliveries = 0;
  double _totalFloorTopup = 0;

  // ── Cliff-Bonus Simulation Constants ──────────────────────────────────
  // These simulate what a typical Indian gig platform would pay:
  //
  // Real example (based on Fairwork India 2024 data):
  //   - Base per delivery: ₹20 (lower than FairDrop's transparent rate)
  //   - Cliff bonus: ₹0 for 1-9 deliveries, ₹500 at exactly 10
  //   - No distance pay, no wait compensation, no minimum wage floor
  //
  // This is the "incentive trap" — riders are pressured to hit 10
  // deliveries even in unsafe conditions (rain, late night, etc.)
  static const double _cliffBasePerDelivery = 20;
  static const int _cliffThreshold = 10;
  static const double _cliffBonus = 500;

  // ── Lifecycle: initState() ────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  // ── API Call: _loadEarnings() ─────────────────────────────────────────
  // Fetches earnings history for rider-001 from the server.
  Future<void> _loadEarnings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // GET /api/pay/history/rider-001
      final response = await ApiService.getPayHistory('rider-001');
      final earnings = response['earnings'] as List<dynamic>;

      // ── Compute summary statistics ──────────────────────────────────
      double totalEarned = 0;
      double totalFloorTopup = 0;
      double totalHourlyRate = 0;

      for (final e in earnings) {
        // Each earning record has fields like 'total_delivery_pay',
        // 'floor_topup', 'hourly_earnings_so_far' as strings from MySQL.
        final deliveryPay =
            double.tryParse(e['total_delivery_pay'].toString()) ?? 0;
        final topup = double.tryParse(e['floor_topup'].toString()) ?? 0;
        final hourly =
            double.tryParse(e['hourly_earnings_so_far'].toString()) ?? 0;

        totalEarned += deliveryPay + topup;
        totalFloorTopup += topup;
        totalHourlyRate += hourly;
      }

      setState(() {
        _earnings = earnings;
        _totalEarned = totalEarned;
        _totalDeliveries = earnings.length;
        _totalFloorTopup = totalFloorTopup;
        _avgHourlyRate =
            earnings.isNotEmpty ? totalHourlyRate / earnings.length : 0;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.body['message'] ?? 'Failed to load earnings';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed. Is the server running?\n\n'
            'Start it with: cd pay-service && npm start\n\nError: $e';
        _isLoading = false;
      });
    }
  }

  // ── Cliff-Bonus Calculator ────────────────────────────────────────────
  // Simulates what a traditional platform would pay for N deliveries.
  //
  // Cliff model: ₹20 per delivery, ₹500 bonus ONLY at 10 deliveries.
  // If rider does 9 deliveries: 9 × ₹20 = ₹180 (no bonus)
  // If rider does 10 deliveries: 10 × ₹20 + ₹500 = ₹700 (bonus!)
  //
  // This creates a "cliff" — massive incentive to push for delivery #10
  // even in unsafe conditions.
  double _calculateCliffTotal(int deliveryCount) {
    final basePay = deliveryCount * _cliffBasePerDelivery;
    final bonus = deliveryCount >= _cliffThreshold ? _cliffBonus : 0;
    return basePay + bonus;
  }

  // ── Build the UI ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadEarnings,
            tooltip: 'Reload earnings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView(theme)
              : _earnings.isEmpty
                  ? _buildEmptyView(theme)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Summary Cards ───────────────────────────
                          _buildSummaryCards(theme),
                          const SizedBox(height: 20),

                          // ── Comparison Chart ────────────────────────
                          _buildComparisonChart(theme),
                          const SizedBox(height: 20),

                          // ── Earnings History Table ──────────────────
                          _buildEarningsTable(theme),
                        ],
                      ),
                    ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ERROR VIEW — Shown when API call fails
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadEarnings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // EMPTY VIEW — Shown when no deliveries exist yet
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildEmptyView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No deliveries yet',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete some deliveries in the Pay Breakdown screen first, '
              'then come back to see your earnings chart.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // SUMMARY CARDS — Key statistics at the top
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildSummaryCards(ThemeData theme) {
    return Column(
      children: [
        // ── Row 1: Total Earned + Deliveries ──────────────────────────
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                icon: Icons.account_balance_wallet,
                label: 'Total Earned',
                value: '₹${_totalEarned.toStringAsFixed(0)}',
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                icon: Icons.delivery_dining,
                label: 'Deliveries',
                value: '$_totalDeliveries',
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Row 2: Avg Hourly Rate + Floor Top-ups ────────────────────
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                icon: Icons.speed,
                label: 'Avg Hourly Rate',
                value: '₹${_avgHourlyRate.toStringAsFixed(1)}/hr',
                color: _avgHourlyRate >= 70
                    ? Colors.green
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                icon: Icons.shield,
                label: 'Floor Top-ups',
                value: '₹${_totalFloorTopup.toStringAsFixed(0)}',
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helper: _buildStatCard ────────────────────────────────────────────
  Widget _buildStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // COMPARISON CHART — FairDrop vs Cliff-Bonus
  // ══════════════════════════════════════════════════════════════════════
  //
  // This is the CORE VISUAL for the demo.
  // It shows a bar chart comparing cumulative earnings under:
  //   - FairDrop model (green bars — actual earnings from DB)
  //   - Cliff-bonus model (red bars — simulated cliff earnings)
  //
  // The chart makes the "cliff" visually obvious:
  //   Deliveries 1-9: Cliff bars are flat, FairDrop bars grow steadily
  //   Delivery 10: Cliff bar jumps (₹500 bonus), but FairDrop was
  //                already earning fairly from delivery #1
  Widget _buildComparisonChart(ThemeData theme) {
    // ── Prepare chart data ──────────────────────────────────────────────
    // For each delivery (1 to N), compute cumulative totals for both models.

    // FairDrop cumulative: sum actual earnings from DB
    List<double> fairDropCumulative = [];
    double runningFairDrop = 0;
    for (final e in _earnings) {
      final pay = double.tryParse(e['total_delivery_pay'].toString()) ?? 0;
      final topup = double.tryParse(e['floor_topup'].toString()) ?? 0;
      runningFairDrop += pay + topup;
      fairDropCumulative.add(runningFairDrop);
    }

    // Cliff cumulative: simulate for same number of deliveries
    List<double> cliffCumulative = [];
    for (int i = 1; i <= _earnings.length; i++) {
      cliffCumulative.add(_calculateCliffTotal(i));
    }

    // Find the max value for chart Y-axis scaling
    double maxY = 0;
    for (final v in fairDropCumulative) {
      if (v > maxY) maxY = v;
    }
    for (final v in cliffCumulative) {
      if (v > maxY) maxY = v;
    }
    // Add 20% padding to top of chart
    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 100; // Prevent zero-height chart

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Chart Header ──────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.bar_chart, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FairDrop vs Cliff-Bonus',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cumulative earnings comparison across deliveries',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),

            // ── Chart Legend ──────────────────────────────────────────
            Row(
              children: [
                _buildLegendDot(Colors.green, 'FairDrop'),
                const SizedBox(width: 20),
                _buildLegendDot(Colors.red.shade300, 'Cliff-Bonus'),
              ],
            ),
            const SizedBox(height: 16),

            // ── Bar Chart ────────────────────────────────────────────
            // SizedBox constrains the chart height (fl_chart needs fixed height)
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  // ── Axis configuration ──────────────────────────────
                  maxY: maxY,

                  // Grid lines — horizontal dashed lines
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                  ),

                  // Border around the chart
                  borderData: FlBorderData(show: false),

                  // X-axis labels (delivery numbers)
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(
                        'Delivery #',
                        style: theme.textTheme.bodySmall,
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt() + 1}',
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        '₹',
                        style: theme.textTheme.bodySmall,
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '₹${value.toInt()}',
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Bar groups (one per delivery) ───────────────────
                  // Each group has 2 bars: FairDrop (green) + Cliff (red)
                  barGroups: List.generate(
                    _earnings.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        // FairDrop bar (green)
                        BarChartRodData(
                          toY: fairDropCumulative[index],
                          color: Colors.green,
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                        // Cliff-bonus bar (red)
                        BarChartRodData(
                          toY: cliffCumulative[index],
                          color: Colors.red.shade300,
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Insight Text ─────────────────────────────────────────
            // Dynamic text that explains what the chart shows
            if (_earnings.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _earnings.length < _cliffThreshold
                            ? 'After ${_earnings.length} deliveries: FairDrop paid '
                                '₹${_totalEarned.toStringAsFixed(0)} vs Cliff-Bonus '
                                '₹${_calculateCliffTotal(_earnings.length).toStringAsFixed(0)}. '
                                'Under cliff model, the rider gets NO bonus until delivery #$_cliffThreshold.'
                            : 'After ${_earnings.length} deliveries: FairDrop paid '
                                '₹${_totalEarned.toStringAsFixed(0)} vs Cliff-Bonus '
                                '₹${_calculateCliffTotal(_earnings.length).toStringAsFixed(0)}. '
                                'FairDrop provided fair pay from delivery #1.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Helper: _buildLegendDot ───────────────────────────────────────────
  Widget _buildLegendDot(Color color, String label) {
    return Row(
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
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // EARNINGS TABLE — Recent delivery history
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildEarningsTable(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Recent Deliveries',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Table of deliveries ───────────────────────────────────
            // Each row shows one delivery with key metrics
            ..._earnings.map((e) {
              final orderId = e['order_id'] ?? 'N/A';
              final distance = e['distance_km'] ?? '0';
              final deliveryPay =
                  double.tryParse(e['total_delivery_pay'].toString()) ?? 0;
              final topup =
                  double.tryParse(e['floor_topup'].toString()) ?? 0;
              final total = deliveryPay + topup;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Order info
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orderId,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${distance} km',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Delivery pay
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${deliveryPay.toStringAsFixed(0)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (topup > 0)
                            Text(
                              '+₹${topup.toStringAsFixed(0)} top-up',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Total
                    SizedBox(
                      width: 80,
                      child: Text(
                        '₹${total.toStringAsFixed(0)}',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
