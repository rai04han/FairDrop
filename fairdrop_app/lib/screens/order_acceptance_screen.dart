// ============================================================================
// FairDrop — Order Acceptance Screen
// Based on Stitch Design Project #1184075210986276795
// (FairDrop - Order Acceptance)
// ============================================================================
// PRD FR-11 to FR-16:
// - Upfront transparent pay formula before acceptance
// - Schematic route map preview with distance and time estimate
// - Itemized guaranteed payout with proportion stack visualizer
// - Explicit wait time conditional incentive explanation
// - Wage Protection active badge
// - Zero penalty decline action
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/core_api_service.dart';
import '../utils/format_utils.dart';

class OrderAcceptanceScreen extends StatefulWidget {
  final Order? order;
  final Map<String, dynamic>? payConfig;
  final bool autoStartTimer;

  const OrderAcceptanceScreen({
    super.key,
    this.order,
    this.payConfig,
    this.autoStartTimer = true,
  });

  @override
  State<OrderAcceptanceScreen> createState() => _OrderAcceptanceScreenState();
}

class _OrderAcceptanceScreenState extends State<OrderAcceptanceScreen> {
  Order? _orderModel;
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _payConfig = const {
    'base_rate': '30.00',
    'per_km_rate': '10.00',
    'surge_bonus': '15.00',
    'wait_threshold_mins': 1,
    'wait_compensation': '2.00',
    'min_wage_per_hour': '75.00',
  };
  bool _isActing = false;
  bool _outOfZoneConsent = false;
  Timer? _timer;
  int _secondsLeft = 42;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _orderModel = widget.order;
      _order = widget.order!.toJson();
    }
    if (widget.payConfig != null) {
      _payConfig = widget.payConfig;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_orderModel == null && _order == null) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Order) {
          _orderModel = args;
          _order = args.toJson();
        } else if (args is Map<String, dynamic>) {
          _order = args;
          try {
            _orderModel = Order.fromJson(args);
          } catch (_) {}
        }
        if (mounted) setState(() {});
      }
      if (widget.payConfig == null) {
        _loadPayConfig();
      }
    });
    if (widget.autoStartTimer) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _secondsLeft = 0;
          _timer?.cancel();
        }
      });
    });
  }

  Future<void> _loadPayConfig() async {
    try {
      final data = await ApiService.getPayConfig().timeout(
        const Duration(seconds: 1),
        onTimeout: () => {},
      );
      final active = data['active_config'] ?? data['active'] ?? data['config'];
      if (active is Map<String, dynamic> && mounted) {
        setState(() {
          _payConfig = active;
        });
      }
    } catch (_) {
      // Fallback already initialized
    }
  }

  double get _distanceKm {
    if (_orderModel != null) return _orderModel!.distanceKm;
    final dist = _order?['distance_km'] as num?;
    return dist?.toDouble() ?? 5.0;
  }

  bool get _isSurge => _orderModel?.isSurgeActive ?? (_order?['is_surge_active'] as bool?) ?? false;

  double get _baseRate {
    return double.tryParse(_payConfig?['base_rate']?.toString() ?? '30') ?? 30.0;
  }

  double get _perKmRate {
    return double.tryParse(_payConfig?['per_km_rate']?.toString() ?? '10') ?? 10.0;
  }

  double get _surgeBonus {
    if (!_isSurge) return 0.0;
    return double.tryParse(_payConfig?['surge_bonus']?.toString() ?? '15') ?? 15.0;
  }

  double get _waitCompensation {
    return double.tryParse(_payConfig?['wait_compensation']?.toString() ?? '2') ?? 2.0;
  }

  int get _waitThresholdMins {
    return int.tryParse(_payConfig?['wait_threshold_mins']?.toString() ?? '1') ?? 1;
  }

  double get _minWagePerHour {
    return double.tryParse(_payConfig?['min_wage_per_hour']?.toString() ?? '75') ?? 75.0;
  }

  double get _distancePay => _distanceKm * _perKmRate;

  double get _estimatedTotal => _baseRate + _distancePay + _surgeBonus;

  bool get _isOutOfZone => _orderModel?.isOutOfZone ?? (_order?['is_out_of_zone'] as bool?) ?? false;

  bool get _canAccept =>
      _secondsLeft > 0 &&
      (!_isOutOfZone || _outOfZoneConsent);

  Future<void> _acceptOrder() async {
    final orderId = _orderModel?.orderId ?? _order?['order_id'] as String? ?? 'ORD-20261019-0001';
    setState(() => _isActing = true);

    try {
      await CoreApiService.acceptOrder(orderId).timeout(
        const Duration(seconds: 1),
        onTimeout: () => {},
      );
    } catch (_) {
      // In offline / test environment, proceed
    }

    if (mounted) {
      Navigator.pushReplacementNamed(
        context,
        '/active-delivery',
        arguments: _orderModel ?? _order ?? {
          'order_id': orderId,
          'restaurant_name': 'Hotel Arun, Chinnakada',
          'delivery_location': 'Pin A (Near Chinnakada)',
          'distance_km': _distanceKm,
          'base_rate': _baseRate,
          'per_km_rate': _perKmRate,
          'surge_bonus': _surgeBonus,
          'is_out_of_zone': _isOutOfZone,
        },
      );
    }
  }

  Future<void> _declineOrder() async {
    final orderId = _orderModel?.orderId ?? _order?['order_id'] as String?;
    if (orderId != null) {
      try {
        await CoreApiService.declineOrder(orderId).timeout(
          const Duration(seconds: 1),
          onTimeout: () => {},
        );
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order declined without penalty. Returning to online status.'),
          backgroundColor: FairDropColors.brandNavy,
        ),
      );
      Navigator.pushReplacementNamed(context, '/rider-home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = _order?['restaurant_name'] as String? ??
        (_order?['restaurant_address'] as Map<String, dynamic>?)?['name'] as String? ??
        'Ashtamudi Bites';
    final deliveryName = _order?['delivery_location'] as String? ??
        (_order?['delivery_address'] as Map<String, dynamic>?)?['area'] as String? ??
        'Kadappakkada';

    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: FairDropColors.brandNavy),
                  ),
                  const FairDropLogo(fontSize: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Order Acceptance',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FairDropColors.brandNavy,
                    ),
                  ),
                  const Spacer(),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: FairDropColors.brandGreen.withValues(alpha: 0.12),
                    child: const Icon(Icons.person_rounded, size: 18, color: FairDropColors.brandGreen),
                  ),
                ],
              ),
            ),

            // ── Main Content ─────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Timer & Offer Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _secondsLeft > 0
                                ? FairDropColors.brandOrange.withValues(alpha: 0.15)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: _secondsLeft > 0
                                    ? FairDropColors.brandOrange
                                    : FairDropColors.slateMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _secondsLeft > 0 ? 'Accept in ${_secondsLeft}s' : 'Offer Expired',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _secondsLeft > 0
                                      ? FairDropColors.brandOrange
                                      : FairDropColors.slateMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                              'Direct Offer',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: FairDropColors.slateMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Out-of-zone prominent warning banner (FR-14)
                    if (_isOutOfZone) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: FairDropColors.brandOrange.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: FairDropColors.brandOrange.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.explore_off_rounded, size: 20, color: FairDropColors.brandOrange),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'OUT-OF-ZONE DELIVERY',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: FairDropColors.brandOrange,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: FairDropColors.brandOrange,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'CONSENT REQ.',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'This order drops off outside your home operating zone. Upon delivery completion, your active operating zone will be automatically reassigned to the destination zone (FR-73).',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: FairDropColors.brandNavy,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 1. Route Summary Card with Schematic Route Preview
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: FairDropColors.mintBorder),
                        boxShadow: FairDropColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.navigation_rounded, size: 14, color: FairDropColors.brandGreen),
                                        const SizedBox(width: 4),
                                        Text(
                                          'KOLLAM CENTRAL ROUTE',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: FairDropColors.slateMuted,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$restaurantName → $deliveryName',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: FairDropColors.brandNavy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_distanceKm.toStringAsFixed(1)} km · Est. 18 mins travel',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: FairDropColors.brandGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: FairDropColors.surfaceLow,
                                child: const Icon(Icons.two_wheeler_rounded, color: FairDropColors.brandNavy, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Schematic Vector Route Preview
                          Container(
                            height: 100,
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: FairDropColors.surfaceLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: FairDropColors.mintBorder.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                // Node 1: Ashtamudi
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: FairDropColors.brandGreen,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: CircleAvatar(radius: 4, backgroundColor: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pickup',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: FairDropColors.brandNavy,
                                      ),
                                    ),
                                  ],
                                ),

                                // Connecting Path with km badge
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        height: 3,
                                        color: FairDropColors.brandGreen.withValues(alpha: 0.5),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: FairDropColors.brandNavy,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_distanceKm.toStringAsFixed(1)} KM',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Node 2: Kadappakkada
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: FairDropColors.brandOrange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: CircleAvatar(radius: 4, backgroundColor: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Drop',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: FairDropColors.brandNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Transparent Pay Breakdown Card (Stitch Spec)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                                'Your pay for this order',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: FairDropColors.brandNavy,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: FairDropColors.brandGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'GUARANTEED',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: FairDropColors.brandGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Itemized upfront fare with zero hidden deductions.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: FairDropColors.slateMuted,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Line Item Breakdown
                          _buildPayLineItem(
                            label: 'Base rate',
                            desc: 'Fixed pickup baseline',
                            amount: formatCurrency(_baseRate),
                            color: FairDropColors.payBase,
                          ),
                          const SizedBox(height: 10),
                          _buildPayLineItem(
                            label: 'Distance (${_distanceKm.toStringAsFixed(1)} km × ₹${_perKmRate.toStringAsFixed(0)})',
                            desc: '₹${_perKmRate.toStringAsFixed(2)}/km standard rate',
                            amount: formatCurrency(_distancePay),
                            color: FairDropColors.payBase,
                          ),
                          const SizedBox(height: 10),
                          if (_isSurge) ...[
                            _buildPayLineItem(
                              label: 'Surge bonus',
                              desc: 'Peak demand incentive',
                              amount: formatCurrency(_surgeBonus),
                              color: FairDropColors.paySurge,
                              isSurge: true,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Proportion Bar Visualizer
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 8,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: (_baseRate * 10).round().clamp(1, 100),
                                    child: Container(color: FairDropColors.payBase),
                                  ),
                                  Expanded(
                                    flex: (_distancePay * 10).round().clamp(1, 100),
                                    child: Container(color: FairDropColors.payBase.withValues(alpha: 0.7)),
                                  ),
                                  if (_isSurge)
                                    Expanded(
                                      flex: (_surgeBonus * 10).round().clamp(1, 100),
                                      child: Container(color: FairDropColors.paySurge),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Highlighted Guaranteed Payout Block
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: FairDropColors.surfaceLow,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'GUARANTEED PAYOUT',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: FairDropColors.slateMuted,
                                      ),
                                    ),
                                    Text(
                                      "Minimum you'll earn",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: FairDropColors.brandNavy,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  formatCurrency(_estimatedTotal),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: FairDropColors.brandGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Wait Time Conditional Incentive (FR-18)
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 16, color: FairDropColors.payWait),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '+${formatCurrency(_waitCompensation)}/min if restaurant wait exceeds $_waitThresholdMins min (credited on delivery)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: FairDropColors.payWait,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Wage Protection Active Shield Banner (FR-34–36, FR-41)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: FairDropColors.brandGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: FairDropColors.brandGreen.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: FairDropColors.brandGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_rounded, size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Wage Protection Active',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: FairDropColors.brandGreen,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Statutory wage protection of ${formatCurrency(_minWagePerHour)}/hr is active. Final pay, wait compensation, and floor top-up are calculated upon delivery completion.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: FairDropColors.slateMuted,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Out-of-zone consent checkbox if applicable (FR-14)
                    if (_isOutOfZone) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _outOfZoneConsent
                                ? FairDropColors.brandGreen
                                : FairDropColors.brandOrange.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            key: const Key('out_of_zone_consent_checkbox'),
                            value: _outOfZoneConsent,
                            activeColor: FairDropColors.brandGreen,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'I consent to this delivery outside my home zone and understand my operating zone will transfer upon completion (FR-14).',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: FairDropColors.brandNavy,
                              ),
                            ),
                            onChanged: (val) => setState(() => _outOfZoneConsent = val ?? false),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Action Buttons (Stitch Spec)
                    FilledButton.icon(
                      key: const Key('accept_order_button'),
                      onPressed: _canAccept && !_isActing ? _acceptOrder : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: FairDropColors.brandGreen,
                        minimumSize: const Size.fromHeight(54),
                        shape: const StadiumBorder(),
                        elevation: 3,
                        shadowColor: FairDropColors.brandGreen.withValues(alpha: 0.35),
                      ),
                      icon: _isActing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 22),
                      label: Text(
                        _isActing ? 'Securing Route...' : 'ACCEPT ORDER',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextButton(
                      key: const Key('decline_order_button'),
                      onPressed: _declineOrder,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Decline',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: FairDropColors.errorRed,
                            ),
                          ),
                          Text(
                            '(Zero acceptance rate penalty)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: FairDropColors.slateMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayLineItem({
    required String label,
    required String desc,
    required String amount,
    required Color color,
    bool isSurge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSurge ? FairDropColors.brandOrange : FairDropColors.brandNavy,
                      ),
                    ),
                    if (isSurge) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.bolt_rounded, size: 14, color: FairDropColors.brandOrange),
                    ],
                  ],
                ),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: FairDropColors.slateMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        Text(
          amount,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isSurge ? FairDropColors.brandOrange : FairDropColors.brandNavy,
          ),
        ),
      ],
    );
  }
}
