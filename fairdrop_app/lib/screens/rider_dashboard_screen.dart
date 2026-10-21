// ============================================================================
// FairDrop — Rider Dashboard Screen (Screen 9)
// ============================================================================
// Owner: Raihan & Hari
// PRD Features: FR-30, FR-31, FR-32, FR-33, FR-34
//
// PURPOSE:
//   Displays the rider's earnings history, today's summary statistics, statutory
//   wage floor compliance, expandable per-delivery itemized ledgers, and a
//   direct bridge to the dedicated comparative Pay Analytics screen (/analytics).
//
// REQUIREMENTS:
//   - FR-30: Today's summary: deliveries, total earned, active hours, hourly rate.
//   - FR-31: Per-delivery expandable rows showing the 7-itemized ledger breakdown.
//   - FR-32: Minimum wage floor status: hourly rate against statutory ₹70/hr floor,
//            and cumulative floor top-ups.
//   - FR-33: Pull-to-refresh (RefreshIndicator) and auto-refresh on return from
//            Delivery Summary or sub-screens.
//   - FR-34: Navigation bridge to dedicated AnalyticsScreen (/analytics).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/core_api_service.dart';

class RiderDashboardScreen extends StatefulWidget {
  final List<dynamic>? initialEarnings;
  final bool autoFetch;
  final String? initialErrorMessage;

  const RiderDashboardScreen({
    super.key,
    this.initialEarnings,
    this.autoFetch = true,
    this.initialErrorMessage,
  });

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _earnings = [];

  // Summary statistics (FR-30, FR-32)
  double _totalEarned = 0.0;
  double _avgHourlyRate = 0.0;
  int _totalDeliveries = 0;
  double _totalFloorTopup = 0.0;
  double _engagedHours = 0.0;

  // Track expanded delivery items
  final Set<String> _expandedOrderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.initialErrorMessage != null) {
      _errorMessage = widget.initialErrorMessage;
      _isLoading = false;
    } else if (widget.initialEarnings != null) {
      _applyEarnings(widget.initialEarnings!);
    } else if (widget.autoFetch) {
      _loadEarnings();
    } else {
      _applyDefaultMockEarnings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-refresh when app resumes
    if (state == AppLifecycleState.resumed && widget.autoFetch) {
      _loadEarnings();
    }
  }

  void _applyDefaultMockEarnings() {
    _applyEarnings([]);
  }

  void _applyEarnings(
    List<dynamic> earnings, {
    double? totalFloorTopup,
    double? engagedHours,
  }) {
    double totalEarned = 0;
    double parsedTopup = totalFloorTopup ?? 0;
    double totalHourlyRate = 0;

    for (final e in earnings) {
      final deliveryPay = double.tryParse(e['total_delivery_pay'].toString()) ?? 0;
      final topup = double.tryParse(e['floor_topup'].toString()) ?? 0;
      final hourly = double.tryParse(e['hourly_earnings_so_far'].toString()) ?? 0;

      totalEarned += deliveryPay;
      parsedTopup += topup;
      totalHourlyRate += hourly;
    }

    setState(() {
      _earnings = earnings;
      _totalDeliveries = earnings.length;
      _totalFloorTopup = parsedTopup;
      _totalEarned = totalEarned + _totalFloorTopup;
      _engagedHours = engagedHours ?? (_totalDeliveries > 0 ? (totalHourlyRate > 0 ? totalEarned / (totalHourlyRate / earnings.length) : 0.0) : 0.0);
      _avgHourlyRate = _engagedHours > 0 ? _totalEarned / _engagedHours : 0.0;
      _isLoading = false;
      _errorMessage = null;

      // Expand the first delivery by default for glanceability
      if (earnings.isNotEmpty) {
        final firstId = earnings.first['order_id']?.toString() ?? '';
        if (firstId.isNotEmpty) {
          _expandedOrderIds.add(firstId);
        }
      }
    });
  }

  // ── API Call: _loadEarnings() (FR-33) ──────────────────────────────────────
  Future<void> _loadEarnings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final riderId = await CoreApiService.getUserId() ?? 'rider-001';
      final response = await ApiService.getPayHistory(riderId).timeout(
        const Duration(seconds: 2),
      );
      final rawList = response['earnings'] as List<dynamic>? ?? [];
      final topup = double.tryParse(response['total_floor_topup']?.toString() ?? '') ?? 0.0;
      final engagedHrs = double.tryParse(response['engaged_hours']?.toString() ?? '') ?? 0.0;

      if (mounted) {
        _applyEarnings(rawList, totalFloorTopup: topup, engagedHours: engagedHrs);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load dashboard earnings. Please check your connection and try again.';
        });
      }
    }
  }


  void _toggleExpanded(String orderId) {
    setState(() {
      if (_expandedOrderIds.contains(orderId)) {
        _expandedOrderIds.remove(orderId);
      } else {
        _expandedOrderIds.add(orderId);
      }
    });
  }

  // ── Auto-refresh helper on navigation return (FR-33) ──────────────────────
  Future<void> _navigateTo(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) {
      _loadEarnings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Rider Dashboard',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: FairDropColors.brandNavy,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('btn_refresh_dashboard'),
            icon: const Icon(Icons.refresh_rounded, color: FairDropColors.brandGreen),
            tooltip: 'Reload earnings',
            onPressed: _isLoading ? null : _loadEarnings,
          ),
        ],
      ),
      // ── FR-33: Pull-to-refresh with RefreshIndicator ─────────────────────
      body: RefreshIndicator(
        key: const Key('rider_dashboard_refresh_indicator'),
        color: FairDropColors.brandGreen,
        onRefresh: _loadEarnings,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: FairDropColors.brandGreen),
              )
            : _errorMessage != null
                ? _buildErrorView()
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── 1. Summary Cards (FR-30, FR-32) ─────────────────
                        _buildSummaryCards(),
                        const SizedBox(height: 16),

                        // ── 2. Statutory Floor Status Banner (FR-32) ────────
                        _buildFloorStatusBanner(),
                        const SizedBox(height: 16),

                        // ── 3. Pay Analytics Navigation Bridge (FR-34) ──────
                        _buildAnalyticsBridgeCard(),
                        const SizedBox(height: 16),

                        // ── 4. Expandable Delivery History (FR-31) ──────────
                        _buildDeliveryHistorySection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ── 1. Summary Cards (FR-30) ──────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Total Earned',
                value: '₹${_totalEarned.toStringAsFixed(2)}',
                color: FairDropColors.brandGreen,
                valueKey: 'summary_total_earned',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.two_wheeler_rounded,
                label: 'Deliveries Today',
                value: '$_totalDeliveries',
                color: FairDropColors.brandNavy,
                valueKey: 'summary_deliveries_count',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.speed_rounded,
                label: 'Avg Hourly Rate',
                value: _engagedHours > 0
                    ? '₹${_avgHourlyRate.toStringAsFixed(1)}/hr'
                    : '—',
                color: _avgHourlyRate >= 70.0
                    ? FairDropColors.brandGreen
                    : FairDropColors.warningAmber,
                valueKey: 'summary_avg_hourly_rate',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.shield_rounded,
                label: 'Floor Top-ups',
                value: '₹${_totalFloorTopup.toStringAsFixed(2)}',
                color: FairDropColors.brandOrange,
                valueKey: 'summary_floor_topups',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String valueKey,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FairDropColors.mintBorder),
        boxShadow: FairDropColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            key: Key(valueKey),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: FairDropColors.brandNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: FairDropColors.slateMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Statutory Floor Status Banner (FR-32) ──────────────────────────────
  Widget _buildFloorStatusBanner() {
    const double statutoryFloor = 70.0;
    final bool isProtected = _totalDeliveries > 0 && _avgHourlyRate >= statutoryFloor;
    final bool isCompliant = _totalDeliveries == 0 || isProtected;

    return Container(
      key: const Key('statutory_floor_status_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompliant ? FairDropColors.brandGreen : FairDropColors.warningAmber,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompliant ? Icons.verified_rounded : Icons.info_rounded,
            color: isCompliant ? FairDropColors.brandGreen : FairDropColors.warningAmber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _totalDeliveries == 0
                      ? 'Statutory Floor Guarantee: Protected'
                      : _engagedHours < 1.0
                          ? 'Floor evaluated after 60 min on orders'
                          : isProtected
                              ? 'Statutory Floor Guarantee: Protected'
                              : 'Statutory Floor: Auto-Topup Active',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                Text(
                  _engagedHours > 0
                      ? 'Minimum guaranteed wage: ₹${statutoryFloor.toStringAsFixed(0)}/hr • ${_engagedHours.toStringAsFixed(1)} hrs active'
                      : 'Minimum guaranteed wage: ₹${statutoryFloor.toStringAsFixed(0)}/hr • —',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: FairDropColors.slateMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCompliant
                  ? FairDropColors.mintBg
                  : FairDropColors.warningAmber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _totalDeliveries == 0
                  ? 'COMPLIANT'
                  : isProtected
                      ? 'COMPLIANT'
                      : 'TOP-UP APPLIED',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isCompliant
                    ? FairDropColors.brandGreen
                    : FairDropColors.warningAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Pay Analytics Bridge Card (FR-34) ──────────────────────────────────
  Widget _buildAnalyticsBridgeCard() {
    return Container(
      key: const Key('card_pay_analytics'),
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FairDropColors.brandOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: FairDropColors.brandOrange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay Analytics & Quota Comparison',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandNavy,
                      ),
                    ),
                    Text(
                      'FairDrop linear pay vs industry tiered incentive ladders',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: FairDropColors.slateMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Explore cumulative earnings trajectories, stated model parameters (FR-35), and benchmark parity conditions (FR-36).',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              height: 1.4,
              color: FairDropColors.slateMuted,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            key: const Key('btn_open_analytics'),
            onPressed: () => _navigateTo('/analytics'),
            icon: const Icon(Icons.insights_rounded, size: 18),
            label: const Text('Open Analytics & Incentive Comparison →'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FairDropColors.brandNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Expandable Delivery History (FR-31) ────────────────────────────────
  Widget _buildDeliveryHistorySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FairDropColors.mintBorder),
        boxShadow: FairDropColors.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: FairDropColors.brandGreen, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Itemized Delivery History',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: FairDropColors.brandNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_earnings.length} Orders',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FairDropColors.brandGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap any delivery to expand the full 7-itemized ledger breakdown (FR-31)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: FairDropColors.slateMuted,
            ),
          ),
          const Divider(height: 20),

          if (_earnings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No completed deliveries yet today.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: FairDropColors.slateMuted,
                  ),
                ),
              ),
            )
          else
            ..._earnings.map((e) => _buildExpandableDeliveryTile(e)),
        ],
      ),
    );
  }

  Widget _buildExpandableDeliveryTile(dynamic item) {
    final orderId = item['order_id']?.toString() ?? 'N/A';
    final distanceKm = double.tryParse(item['distance_km']?.toString() ?? '0') ?? 0.0;
    final isSurge = (item['is_surge_active'] == 1 || item['is_surge_active'] == true);
    final waitMins = int.tryParse(item['restaurant_wait_mins']?.toString() ?? '0') ?? 0;

    final baseRate = double.tryParse(item['base_rate']?.toString() ?? '0') ?? 0.0;
    final distancePay = double.tryParse(item['distance_pay']?.toString() ?? '0') ?? 0.0;
    final surgeBonus = double.tryParse(item['surge_bonus']?.toString() ?? '0') ?? 0.0;
    final waitComp = double.tryParse(item['wait_compensation']?.toString() ?? '0') ?? 0.0;
    final fairdropIncentive = double.tryParse(item['fairdrop_incentive']?.toString() ?? '17.04') ?? 17.04;
    final deliveryPay = double.tryParse(item['total_delivery_pay']?.toString() ?? '0') ?? 0.0;
    final hourlySoFar = double.tryParse(item['hourly_earnings_so_far']?.toString() ?? '0') ?? 0.0;
    final totalPay = deliveryPay;

    final isExpanded = _expandedOrderIds.contains(orderId);

    return Container(
      key: Key('delivery_tile_$orderId'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isExpanded ? FairDropColors.surfaceLow : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? FairDropColors.brandGreen : FairDropColors.mintBorder,
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header Row (Tap to expand/collapse)
          InkWell(
            key: Key('delivery_header_$orderId'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleExpanded(orderId),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FairDropColors.mintBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: FairDropColors.brandGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderId,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: FairDropColors.brandNavy,
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text(
                                '${distanceKm.toStringAsFixed(1)} km',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: FairDropColors.slateMuted,
                                ),
                              ),
                              if (isSurge) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: FairDropColors.paySurge.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'SURGE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: FairDropColors.paySurge,
                                    ),
                                  ),
                                ),
                              ],
                              if (waitMins > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• ${waitMins}m wait',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: FairDropColors.slateMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${totalPay.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: FairDropColors.brandNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: FairDropColors.slateMuted,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded 7-Itemized Ledger Breakdown (FR-31) ─────────────────
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 16),
                  Text(
                    'ITEMIZED LEDGER BREAKDOWN (FR-21 / FR-31)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: FairDropColors.slateMuted,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 1. Base Rate
                  _buildBreakdownRow(
                    key: Key('breakdown_base_rate_$orderId'),
                    label: '1. Base Pickup & Dispatch Pay',
                    value: '₹${baseRate.toStringAsFixed(2)}',
                    color: FairDropColors.payBase,
                  ),

                  // 2. Distance Pay
                  _buildBreakdownRow(
                    key: Key('breakdown_distance_pay_$orderId'),
                    label: '2. Distance Compensation (${distanceKm.toStringAsFixed(1)} km)',
                    value: '₹${distancePay.toStringAsFixed(2)}',
                    color: FairDropColors.payBase,
                  ),

                  // 3. Surge Bonus
                  _buildBreakdownRow(
                    key: Key('breakdown_surge_bonus_$orderId'),
                    label: '3. Real-Time Surge Bonus (${isSurge ? "Active" : "None"})',
                    value: '₹${surgeBonus.toStringAsFixed(2)}',
                    color: FairDropColors.paySurge,
                  ),

                  // 4. Wait Compensation
                  _buildBreakdownRow(
                    key: Key('breakdown_wait_compensation_$orderId'),
                    label: '4. Restaurant Wait Pay ($waitMins mins)',
                    value: '₹${waitComp.toStringAsFixed(2)}',
                    color: FairDropColors.payWait,
                  ),

                  // 5. FairDrop Incentive
                  _buildBreakdownRow(
                    key: Key('breakdown_fairdrop_incentive_$orderId'),
                    label: '5. FairDrop Per-Order Incentive',
                    value: '₹${fairdropIncentive.toStringAsFixed(2)}',
                    color: FairDropColors.brandGreen,
                  ),

                  // 6. Total Delivery Pay
                  _buildBreakdownRow(
                    key: Key('breakdown_total_pay_$orderId'),
                    label: '6. Net Total Delivery Payout',
                    value: '₹${totalPay.toStringAsFixed(2)}',
                    color: FairDropColors.brandNavy,
                    isBold: true,
                  ),

                  // 7. Hourly Rate So Far
                  _buildBreakdownRow(
                    key: Key('breakdown_hourly_rate_$orderId'),
                    label: '7. Cumulative Hourly Rate So Far',
                    value: hourlySoFar > 0 ? '₹${hourlySoFar.toStringAsFixed(1)}/hr' : '—',
                    color: FairDropColors.brandGreen,
                    isBold: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow({
    required Key key,
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: FairDropColors.brandNavy,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error View ────────────────────────────────────────────────────────────
  Widget _buildErrorView() {
    return Center(
      key: const Key('dashboard_error_view'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: FairDropColors.errorRed),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unable to load dashboard earnings',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: FairDropColors.brandNavy,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('btn_retry_dashboard'),
              onPressed: _loadEarnings,
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
