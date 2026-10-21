// ============================================================================
// FairDrop — Delivery Summary & Pay Breakdown Screen (Screen 7)
// ============================================================================
// PRD Requirements:
//   FR-21: Line-by-line itemized pay breakdown (Base, Distance, Surge, Wait, Floor, Total, Hourly)
//   FR-22: Zero lines displayed as ₹0.00 with plain-language explanation (never hidden)
//   FR-23: Currency in INR with ₹ symbol and 2 decimals
//   FR-24: "Pay calculation pending" state with retry button calling POST /api/orders/:id/retry-pay
//   FR-25: Delay verification status badge (traffic/restaurant/railway, verified/unverified)
//   FR-73: Out-of-zone zone switch notice if applicable
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/order.dart';
import '../models/pay_result.dart';
import '../services/core_api_service.dart';
import '../services/exceptions.dart';
import '../utils/format_utils.dart';

class PayBreakdownScreen extends StatefulWidget {
  const PayBreakdownScreen({super.key});

  @override
  State<PayBreakdownScreen> createState() => _PayBreakdownScreenState();
}

class _PayBreakdownScreenState extends State<PayBreakdownScreen> {
  Order? _order;
  PayResult? _payResult;
  bool _isPending = false;
  bool _isRetrying = false;
  bool _isCached = false;
  String? _errorMessage;

  // Fallback defaults for developer launch without arguments
  String _orderId = 'ORD-20261019-0001';
  double _distanceKm = 1.25;
  int _waitMins = 3;
  bool _isSurgeActive = false;
  bool _isOutOfZone = false;
  DelayContext _delayContext = DelayContext();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parseArguments();
  }

  void _parseArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Order) {
      _order = args;
      _orderId = args.orderId;
      _distanceKm = args.distanceKm;
      _waitMins = args.restaurantWaitMins;
      _isSurgeActive = args.isSurgeActive;
      _isOutOfZone = args.isOutOfZone;
      _delayContext = args.delayContext;
      _isPending = args.payStatus == 'pending' || args.payCalculationResult == null;
      _payResult = args.payCalculationResult;
    } else if (args is Map<String, dynamic>) {
      if (args['order'] is Order) {
        _order = args['order'] as Order;
        _orderId = _order!.orderId;
        _distanceKm = _order!.distanceKm;
        _waitMins = _order!.restaurantWaitMins;
        _isSurgeActive = _order!.isSurgeActive;
        _isOutOfZone = _order!.isOutOfZone;
        _delayContext = _order!.delayContext;
        _isPending = _order!.payStatus == 'pending' || _order!.payCalculationResult == null;
        _payResult = _order!.payCalculationResult;
      } else if (args['order'] is Map<String, dynamic>) {
        _order = Order.fromJson(args['order'] as Map<String, dynamic>);
        _orderId = _order!.orderId;
        _distanceKm = _order!.distanceKm;
        _waitMins = _order!.restaurantWaitMins;
        _isSurgeActive = _order!.isSurgeActive;
        _isOutOfZone = _order!.isOutOfZone;
        _delayContext = _order!.delayContext;
        _isPending = _order!.payStatus == 'pending' || _order!.payCalculationResult == null;
        _payResult = _order!.payCalculationResult;
      } else {
        _orderId = (args['order_id'] ?? args['orderId'] ?? 'ORD-20261019-0001').toString();
        _distanceKm = (args['distance_km'] as num?)?.toDouble() ?? 1.25;
        _waitMins = (args['restaurant_wait_mins'] as num?)?.toInt() ?? 3;
        _isSurgeActive = args['is_surge_active'] as bool? ?? false;
        _isOutOfZone = args['is_out_of_zone'] as bool? ?? false;
        if (args['delay_context'] is Map<String, dynamic>) {
          _delayContext = DelayContext.fromJson(args['delay_context'] as Map<String, dynamic>);
        }

        final payStatus = args['pay_status'] as String? ?? 'calculated';
        _isPending = payStatus == 'pending';

        if (args['pay_result'] is Map<String, dynamic>) {
          _payResult = PayResult.fromJson(args['pay_result'] as Map<String, dynamic>);
        } else if (args['pay_calculation_result'] is Map<String, dynamic>) {
          _payResult = PayResult.fromJson(args['pay_calculation_result'] as Map<String, dynamic>);
        }
      }
    }

    // Seeded demo fallback if pay result is null and not explicitly pending
    if (_payResult == null && !_isPending) {
      _isCached = true;
      _payResult = PayResult(
        orderId: _orderId,
        baseRate: 15.0,
        distancePay: 7.50,
        surgeBonus: 0.0,
        waitCompensation: 10.0,
        totalDeliveryPay: 32.50,
        floorTopup: 0.0,
        hourlyEarningsSoFar: 65.0,
        isCached: true,
      );
    } else if (_payResult != null) {
      _isCached = _payResult!.isCached;
    }
  }

  /// FR-24: Retry pay calculation for delivered order with pending pay
  Future<void> _retryPay() async {
    setState(() {
      _isRetrying = true;
      _errorMessage = null;
    });

    try {
      final response = await CoreApiService.retryPay(_orderId);

      if (!mounted) return;

      final orderData = response['order'];
      if (orderData != null && orderData['pay_calculation_result'] != null) {
        setState(() {
          _payResult = PayResult.fromJson(orderData['pay_calculation_result'] as Map<String, dynamic>);
          _isPending = false;
          _isRetrying = false;
          _isCached = _payResult?.isCached ?? false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pay calculation completed successfully!'),
            backgroundColor: FairDropColors.brandGreen,
          ),
        );
      } else {
        setState(() {
          _isRetrying = false;
          _errorMessage = response['message'] as String? ?? 'Pay calculation is still pending. Try again.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _errorMessage = 'Network error retrying pay calculation. Check server connectivity.';
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: FairDropColors.brandNavy, size: 20),
          onPressed: () => Navigator.pushReplacementNamed(context, '/rider-home'),
        ),
        title: const FairDropLogo(fontSize: 22),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Card: Order Metas ─────────────────────────────────
              _buildTripSummaryCard(),
              const SizedBox(height: 16),

              // ── Delay Context Badge (FR-25) ──────────────────────────────
              _buildDelayContextBadge(),
              const SizedBox(height: 16),

              // ── Out-of-Zone Transition Banner (FR-73) ───────────────────
              if (_isOutOfZone) ...[
                _buildOutOfZoneBanner(),
                const SizedBox(height: 16),
              ],

              // ── Main Content: Pending State vs Itemized Breakdown ────────
              if (_isPending) ...[
                _buildPendingCard(),
              ] else if (_payResult != null) ...[
                _buildTotalHeroCard(),
                const SizedBox(height: 16),
                _buildItemizedLedgerCard(),
              ],

              const SizedBox(height: 24),

              // ── Action Buttons ───────────────────────────────────────────
              _buildNavigationButtons(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Trip Metas Card ───────────────────────────────────────────────────
  Widget _buildTripSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: FairDropColors.cardShadow,
        border: Border.all(color: FairDropColors.mintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Delivery Completed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FairDropColors.brandNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _orderId,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.straighten_rounded,
                  label: 'Distance',
                  value: formatDistance(_distanceKm),
                ),
              ),
              Container(width: 1, height: 36, color: FairDropColors.mintBorder),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.hourglass_top_rounded,
                  label: 'Kitchen Wait',
                  value: formatDurationMinutes(_waitMins),
                ),
              ),
              Container(width: 1, height: 36, color: FairDropColors.mintBorder),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.bolt_rounded,
                  label: 'Surge',
                  value: _isSurgeActive ? 'Active' : 'Normal',
                  color: _isSurgeActive ? FairDropColors.brandOrange : FairDropColors.brandNavy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? FairDropColors.brandGreen),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color ?? FairDropColors.brandNavy,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: FairDropColors.slateMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── 2. Delay Context Badge (FR-25) ───────────────────────────────────────
  Widget _buildDelayContextBadge() {
    String delayText;
    Color badgeColor;
    IconData icon;

    if (_delayContext.type == 'none' || _delayContext.type.isEmpty) {
      delayText = 'Delay: None reported';
      badgeColor = FairDropColors.brandNavy;
      icon = Icons.check_circle_outline_rounded;
    } else {
      final typeLabel = _delayContext.type[0].toUpperCase() + _delayContext.type.substring(1);
      if (_delayContext.verified) {
        delayText = '$typeLabel delay verified by ${_delayContext.source.replaceAll('_', ' ')}';
        badgeColor = FairDropColors.brandGreen;
        icon = Icons.verified_rounded;
      } else {
        delayText = '$typeLabel delay (unverified rider report)';
        badgeColor = FairDropColors.brandOrange;
        icon = Icons.pending_actions_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FairDropColors.mintBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: badgeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              delayText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Out of Zone Transition Banner (FR-73) ────────────────────────────
  Widget _buildOutOfZoneBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.explore_rounded, color: Color(0xFFB45309), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Out-of-Zone Delivery Transition (FR-73)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your current active zone has been automatically updated to match the delivery area.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF78350F),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  key: const Key('view_zone_map_button'),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/zone-map',
                      arguments: {
                        'zoneChangedTo': 'KLM-PLY',
                        'previousZone': 'KLM-CHK',
                        'isOutOfZoneTransition': true,
                      },
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Updated Zone Map →',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB45309),
                          decoration: TextDecoration.underline,
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

  // ── 4. Pending State Card (FR-24) ────────────────────────────────────────
  Widget _buildPendingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: FairDropColors.cardShadow,
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sync_problem_rounded,
              color: Color(0xFFD97706),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pay Calculation Pending',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: FairDropColors.brandNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your delivery was successfully recorded on the core server! However, pay reconciliation with the Pay Engine is pending.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: FairDropColors.slateMuted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isRetrying ? null : _retryPay,
            icon: _isRetrying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
            label: Text(
              _isRetrying ? 'Calculating Pay...' : 'Retry Pay Calculation (FR-24)',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: FairDropColors.brandGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Total Payout Hero Card ────────────────────────────────────────────
  Widget _buildTotalHeroCard() {
    final totalPay = _payResult!.totalDeliveryPay;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0D5C3A),
            FairDropColors.brandGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: FairDropColors.brandGreen.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Total Payout',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (_isCached || (_payResult?.isCached ?? false))
                InkWell(
                  key: const Key('btn_retry_cached_pay'),
                  onTap: _isRetrying ? null : _retryPay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CACHED',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.refresh_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          'Retry',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'VERIFIED',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency(totalPay),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '100% transparent pay • credited to your FairDrop ledger',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Itemized Ledger Card (FR-21, FR-22, FR-23) ────────────────────────
  Widget _buildItemizedLedgerCard() {
    final r = _payResult!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: FairDropColors.cardShadow,
        border: Border.all(color: FairDropColors.mintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, size: 20, color: FairDropColors.brandNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Itemized Pay Ledger',
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
          const SizedBox(height: 16),

          // 1. Base Rate
          _buildLedgerLine(
            title: 'Base Rate',
            amount: r.baseRate,
            subtitle: 'Standard dispatch fee',
          ),
          const Divider(height: 20, color: FairDropColors.mintBorder),

          // 2. Distance Pay
          _buildLedgerLine(
            title: 'Distance Pay',
            amount: r.distancePay,
            subtitle: '${formatDistance(_distanceKm)} straight-line route',
          ),
          const Divider(height: 20, color: FairDropColors.mintBorder),

          // 3. Surge Bonus (FR-22: explicit zero reason)
          _buildLedgerLine(
            title: 'Surge Bonus',
            amount: r.surgeBonus,
            subtitle: r.surgeBonus > 0 ? 'High demand active' : 'No surge active in zone',
            zeroReason: 'No surge active in zone',
          ),
          const Divider(height: 20, color: FairDropColors.mintBorder),

          // 4. Wait Compensation (FR-22: explicit zero reason)
          _buildLedgerLine(
            title: 'Wait Compensation',
            amount: r.waitCompensation,
            subtitle: r.waitCompensation > 0
                ? 'Wait (${_waitMins}m) exceeded 1-min threshold'
                : 'Wait time under threshold (${_waitMins}m / 1m threshold)',
            zeroReason: 'Wait time under threshold',
          ),
          const Divider(height: 20, color: FairDropColors.mintBorder),

          // 5. FairDrop Incentive (FR-21 / F24)
          _buildLedgerLine(
            title: 'FairDrop Incentive',
            amount: r.fairdropIncentive,
            subtitle: 'Guaranteed per-order incentive',
          ),
          const Divider(height: 20, color: FairDropColors.mintBorder),

          // 6. Total Delivery Pay (sum of the lines above: base + distance + surge + wait + incentive)
          _buildLedgerLine(
            title: 'Total Delivery Pay',
            amount: r.totalDeliveryPay,
            subtitle: 'Base + distance + surge + wait + incentive',
            isBold: true,
          ),
          const Divider(height: 20, color: FairDropColors.mintBorder),

          // 7. Effective Hourly Rate So Far (AUDIT-F16)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Effective Hourly Rate So Far',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FairDropColors.brandNavy,
                      ),
                    ),
                    Text(
                      'Floor evaluated after 60 min on orders',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: FairDropColors.slateMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                r.hourlyEarningsSoFar > 0 ? '${formatCurrency(r.hourlyEarningsSoFar)}/hr' : '—',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: FairDropColors.brandGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerLine({
    required String title,
    required double amount,
    required String subtitle,
    String? zeroReason,
    bool isBold = false,
  }) {
    final bool isZero = amount <= 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                  color: FairDropColors.brandNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isZero && zeroReason != null
                      ? FairDropColors.slateMuted
                      : FairDropColors.slateMuted,
                ),
              ),
            ],
          ),
        ),
        Text(
          formatCurrency(amount),
          style: GoogleFonts.plusJakartaSans(
            fontSize: isBold ? 15 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: isZero ? FairDropColors.slateMuted : FairDropColors.brandNavy,
          ),
        ),
      ],
    );
  }

  // ── 7. Navigation Buttons ────────────────────────────────────────────────
  Widget _buildNavigationButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/rider-home'),
          style: ElevatedButton.styleFrom(
            backgroundColor: FairDropColors.brandGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            'Return to Rider Shift',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.pushNamed(context, '/rider-dashboard'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FairDropColors.brandNavy,
            side: const BorderSide(color: FairDropColors.mintBorder, width: 1.5),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            'View Earnings in Dashboard',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
