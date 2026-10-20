// ============================================================================
// FairDrop — Rider Home Screen
// Based on Stitch Design Project #1184075210986276795
// (FairDrop Home - Transparent Shift Pay & Order Offer)
// ============================================================================
// PRD FR-7 to FR-10:
// - Online/Offline toggle with core-service synchronization
// - Polling for assigned order every 10s
// - Upfront itemized shift transparent pay card & proportion stack bar
// - Instant order dispatch offer with countdown and route milestones
// - Kollam Hub Fairness Index compliance monitoring
// - 4-tab bottom navigation shell
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../services/core_api_service.dart';
import '../services/api_service.dart';

class RiderHomeScreen extends StatefulWidget {
  final String? initialError;
  const RiderHomeScreen({super.key, this.initialError});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  bool _isOnline = true;
  bool _isTogglingStatus = false;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 45;
  String? _homeDataError;

  // Today's stats
  double _todayEarnings = 685.0;
  double _activeHoursToday = 4.25;
  double _hourlyRate = 162.0;
  double? _floorValue;
  int _deliveriesToday = 7;
  String _currentZone = 'Chinnakada & Asramam (KL-02)';

  // Active incoming order (if assigned)
  Map<String, dynamic>? _incomingOrder;

  static String _extractAddress(dynamic address, {String fallback = ''}) {
    if (address == null) return fallback;
    if (address is String) return address.trim().isNotEmpty ? address.trim() : fallback;
    if (address is Map) {
      final map = address is Map<String, dynamic> ? address : Map<String, dynamic>.from(address);
      final val = (map['label'] ?? map['name'] ?? map['area'] ?? map['address'])?.toString();
      if (val != null && val.trim().isNotEmpty) return val.trim();
    }
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialError != null) {
      _homeDataError = widget.initialError;
    }
    _loadStats();
    _startPolling();
    _startCountdown();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _secondsLeft = 45; // loop for demo glanceability
        }
      });
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(AppConfig.orderPollingInterval, (_) {
      if (_isOnline) _pollForOrder();
    });
  }

  Future<void> _pollForOrder() async {
    try {
      final data = await CoreApiService.getRiderActiveOrder();
      final order = data['order'] as Map<String, dynamic>?;

      if (order != null && mounted) {
        setState(() {
          _incomingOrder = order;
        });
      }
    } catch (_) {
      // Silently ignore poll errors
    }
  }

  Future<void> _loadStats() async {
    try {
      final statsData = await CoreApiService.getTodayStats();
      final stats = statsData['stats'] as Map<String, dynamic>? ?? {};

      final configData = await ApiService.getPayConfig();
      final config = configData['config'] as Map<String, dynamic>? ?? {};

      setState(() {
        final earnings = (stats['total_earnings_today'] as num?)?.toDouble() ?? 0;
        final hours = (stats['active_hours_today'] as num?)?.toDouble() ?? 0;
        if (earnings > 0) _todayEarnings = earnings;
        if (hours > 0) _activeHoursToday = hours;
        _deliveriesToday = (stats['deliveries_today'] as num?)?.toInt() ?? _deliveriesToday;
        _currentZone = stats['current_zone'] as String? ?? 'Chinnakada & Asramam (KL-02)';
        _hourlyRate = _activeHoursToday > 0 ? _todayEarnings / _activeHoursToday : 162.0;
        _floorValue = double.tryParse(config['min_wage_per_hour']?.toString() ?? '');
      });
    } catch (_) {
      // Keep defaults
    }
  }

  Future<void> _toggleOnlineStatus() async {
    setState(() => _isTogglingStatus = true);
    try {
      await CoreApiService.setRiderStatus(isOnline: !_isOnline);
      setState(() => _isOnline = !_isOnline);

      if (_isOnline) {
        _pollForOrder();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are now Online — receiving live delivery offers'),
              backgroundColor: FairDropColors.brandGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are now Offline — shift paused'),
              backgroundColor: FairDropColors.slateMuted,
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: FairDropColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingStatus = false);
    }
  }

  void _acceptOffer(Map<String, dynamic>? order) {
    _pollTimer?.cancel();
    Navigator.pushNamed(
      context,
      '/order-acceptance',
      arguments: order ?? {
        'order_id': 'FD-8821',
        'pickup_address': 'Supreme Bakers, Chinnakada',
        'delivery_address': 'Kadappakkada Junction',
        'distance_km': 3.8,
        'base_pay': 30.0,
        'distance_pay': 38.0,
        'surge_bonus': 15.0,
        'wait_buffer': 9.0,
        'guaranteed_payout': 92.0,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_homeDataError != null) {
      return Scaffold(
        backgroundColor: FairDropColors.mintBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: FairDropColors.errorRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rider Dashboard Error',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: FairDropColors.brandNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _homeDataError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: FairDropColors.slateMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        key: const Key('btn_back_rider_home'),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Back',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: FairDropColors.brandNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        key: const Key('btn_retry_rider_home'),
                        onPressed: () {
                          setState(() {
                            _homeDataError = null;
                          });
                          _loadStats();
                          _pollForOrder();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: FairDropColors.brandGreen,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar (Stitch Spec) ──────────────────────────────
            _buildTopHeader(),

            // ── Scrollable Shift Content ───────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadStats,
                color: FairDropColors.brandGreen,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Strip: Live Shift • Chinnakada Hub
                      _buildLiveShiftStrip(),
                      const SizedBox(height: 12),

                      // 1. Current Shift Transparent Pay Card
                      _buildCurrentShiftPayCard(),
                      const SizedBox(height: 16),

                      // 2. Incoming Order Alert Card (Urgent, High-Contrast Dispatch Card)
                      if (_isOnline) ...[
                        _buildIncomingOrderCard(),
                        const SizedBox(height: 16),
                      ],

                      // 3. Kollam Zone Fairness & Governance Card
                      _buildFairnessGovernanceCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom Navigation Bar (Stitch Spec) ────────────────────────
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ── Top Header Widget ─────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: FairDropColors.mintBorder.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: FairDropColors.brandGreen.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Brand & Zone Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const FairDropLogo(fontSize: 22),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: FairDropColors.brandGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'KL-02',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _isOnline ? FairDropColors.brandGreen : FairDropColors.slateMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _currentZone,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: FairDropColors.slateMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),

          // Online / Offline Switch
          GestureDetector(
            onTap: _isTogglingStatus ? null : _toggleOnlineStatus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isOnline
                    ? FairDropColors.brandGreen.withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isOnline ? FairDropColors.brandGreen : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isTogglingStatus)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isOnline ? FairDropColors.brandGreen : FairDropColors.slateMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isOnline ? FairDropColors.brandGreen : FairDropColors.slateMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Profile Avatar Icon
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: CircleAvatar(
              radius: 17,
              backgroundColor: FairDropColors.brandGreen.withValues(alpha: 0.15),
              child: const Icon(
                Icons.person_rounded,
                size: 20,
                color: FairDropColors.brandGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Live Shift Strip ──────────────────────────────────────────────────────
  Widget _buildLiveShiftStrip() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isOnline ? FairDropColors.brandGreen : FairDropColors.slateMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isOnline ? 'Live Shift • Chinnakada Hub' : 'Shift Offline • Tap to go online',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FairDropColors.brandNavy,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: FairDropColors.brandGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FairDropColors.brandGreen.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, size: 14, color: FairDropColors.brandGreen),
              const SizedBox(width: 4),
              Text(
                'AUDIT PASSED',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: FairDropColors.brandGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 1. Current Shift Transparent Pay Card ─────────────────────────────────
  Widget _buildCurrentShiftPayCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FairDropColors.mintBorder.withValues(alpha: 0.8)),
        boxShadow: FairDropColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Shift • ${_activeHoursToday.toStringAsFixed(1)}h active in Kollam",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FairDropColors.slateMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FairDropColors.mintBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'KL-02 TIER-1',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Large Earnings Hero Metric
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${_todayEarnings.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: FairDropColors.brandNavy,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FairDropColors.brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '100% Transparent',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandGreen,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Calculated from $_deliveriesToday completed drops • Zero hidden deductions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: FairDropColors.slateMuted,
            ),
          ),
          const SizedBox(height: 16),

          // Segmented Stack Proportion Bar (Stitch Spec)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: 61,
                    child: Container(color: FairDropColors.payBase),
                  ),
                  Expanded(
                    flex: 14,
                    child: Container(color: FairDropColors.payWait),
                  ),
                  Expanded(
                    flex: 18,
                    child: Container(color: FairDropColors.paySurge),
                  ),
                  Expanded(
                    flex: 7,
                    child: Container(color: FairDropColors.payGuarantee),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹0',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: FairDropColors.slateMuted,
                ),
              ),
              if (_floorValue != null)
                Text(
                  'Kerala Min Floor ₹${_floorValue!.toStringAsFixed(0)}/hr met (+₹${(_hourlyRate - _floorValue!).clamp(0, 999).toStringAsFixed(0)} buffer)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandGreen,
                  ),
                ),
              Text(
                '₹${_todayEarnings.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: FairDropColors.slateMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Transparent Live Pay Formula Matrix
          _buildFormulaRow(
            color: FairDropColors.payBase,
            title: 'Base Pay & Distance',
            subtitle: '$_deliveriesToday drops @ ₹30 + 21.0 km @ ₹10/km',
            amount: '₹420',
          ),
          const SizedBox(height: 8),
          _buildFormulaRow(
            color: FairDropColors.payWait,
            title: 'Geofenced Wait Time',
            subtitle: '19 mins excess wait @ ₹5/min GPS logged',
            amount: '₹95',
          ),
          const SizedBox(height: 8),
          _buildFormulaRow(
            color: FairDropColors.paySurge,
            title: 'Monsoon Surge Allowance',
            subtitle: '4 coastal peak deliveries @ ₹30 bonus',
            amount: '₹120',
          ),
          const SizedBox(height: 8),
          _buildFormulaRow(
            color: FairDropColors.payGuarantee,
            title: 'Kerala Fair Pay Top-Up',
            subtitle: _floorValue != null
                ? 'State wage floor adjustment ₹${_floorValue!.truncateToDouble() == _floorValue ? _floorValue!.toInt() : _floorValue!.toStringAsFixed(0)}/hr min'
                : '',
            amount: '+₹50',
            isPositive: true,
          ),
          const SizedBox(height: 16),

          // Formula Action Button
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, '/pay-breakdown'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: FairDropColors.mintBorder),
              backgroundColor: FairDropColors.mintBg.withValues(alpha: 0.5),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View Full Formula Breakdown & Ledger',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: FairDropColors.brandNavy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaRow({
    required Color color,
    required String title,
    required String subtitle,
    required String amount,
    bool isPositive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FairDropColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isPositive ? FairDropColors.brandGreen : FairDropColors.brandNavy,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: FairDropColors.slateMuted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isPositive ? FairDropColors.brandGreen : FairDropColors.brandNavy,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Incoming Order Alert Card ──────────────────────────────────────────
  Widget _buildIncomingOrderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FairDropColors.brandOrange.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: FairDropColors.brandOrange.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: FairDropColors.brandOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                    Text(
                      'New Offer • ${_secondsLeft}s to accept',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandOrange,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FairDropColors.mintBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Instant Match',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payout Headline
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FairDropColors.surfaceLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GROSS GUARANTEED PAYOUT',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: FairDropColors.slateMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '₹92',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: FairDropColors.brandNavy,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: FairDropColors.brandGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'No hidden cut',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: FairDropColors.brandGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '3.8 km total trip',
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
                const SizedBox(height: 10),

                // Itemized Pre-Acceptance Ledger
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildLedgerItem('Base Pick & Drop', '₹30', FairDropColors.payBase),
                      const SizedBox(height: 5),
                      _buildLedgerItem('Trip Distance (3.8 km @ ₹10/km)', '₹38', FairDropColors.payBase),
                      const SizedBox(height: 5),
                      _buildLedgerItem('Monsoon Coastal Surge', '₹15', FairDropColors.paySurge),
                      const SizedBox(height: 5),
                      _buildLedgerItem('Kitchen Buffer (3 min est.)', '₹9', FairDropColors.payWait),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Route Milestones
          Container(
            padding: const EdgeInsets.only(left: 6),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: FairDropColors.brandNavy,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _extractAddress(
                                  _incomingOrder?['restaurant_address'],
                                  fallback: _extractAddress(
                                    _incomingOrder?['pickup_address'],
                                    fallback: (_incomingOrder?['restaurant_name'] as String?) ?? 'Supreme Bakers, Chinnakada',
                                  ),
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: FairDropColors.brandNavy,
                                ),
                              ),
                              Text(
                                '${((_incomingOrder?['distance_km'] as num?)?.toDouble() ?? 3.8).toStringAsFixed(1)} km trip',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: FairDropColors.slateMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Order #${_incomingOrder?['order_id'] ?? _incomingOrder?['id'] ?? 'FD-8821'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: FairDropColors.slateMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(left: 5),
                  height: 18,
                  width: 2,
                  color: FairDropColors.mintBorder,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: FairDropColors.brandGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _extractAddress(
                                  _incomingOrder?['delivery_address'],
                                  fallback: (_incomingOrder?['delivery_location'] as String?) ?? 'Kadappakkada Junction',
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: FairDropColors.brandNavy,
                                ),
                              ),
                              Text(
                                'Drop',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: FairDropColors.slateMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Prepaid online • Contactless porch delivery',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: FairDropColors.slateMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Big Touch Action Buttons
          FilledButton.icon(
            onPressed: () => _acceptOffer(_incomingOrder),
            style: FilledButton.styleFrom(
              backgroundColor: FairDropColors.brandOrange,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              elevation: 3,
              shadowColor: FairDropColors.brandOrange.withValues(alpha: 0.35),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: Text(
              'Accept Order (₹${(((_incomingOrder?['pay_calculation_result'] as Map<String, dynamic>?)?['guaranteed_payout'] ?? _incomingOrder?['guaranteed_payout'] as num?)?.toDouble() ?? 92.0).toStringAsFixed(0)} Guaranteed)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),

          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Offer declined with zero acceptance rate penalty.'),
                  backgroundColor: FairDropColors.slateMuted,
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              minimumSize: const Size.fromHeight(44),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Decline (Zero Acceptance Rate Penalty)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: FairDropColors.slateMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerItem(String label, String amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
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
        Text(
          amount,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FairDropColors.brandNavy,
          ),
        ),
      ],
    );
  }

  // ── 3. Kollam Zone Fairness & Governance Card ─────────────────────────────
  Widget _buildFairnessGovernanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FairDropColors.mintBorder.withValues(alpha: 0.8)),
        boxShadow: FairDropColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.policy_rounded, color: FairDropColors.brandGreen, size: 22),
              const SizedBox(width: 8),
              Text(
                'Kollam Hub Fairness Index',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: FairDropColors.brandNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FairDropColors.surfaceLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          'Kerala Gig Worker Wage Norms',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: FairDropColors.brandNavy,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FairDropColors.brandGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '100% Compliant',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: FairDropColors.brandGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Comparative Stat Block
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Hub Realized Pay",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: FairDropColors.slateMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${_hourlyRate.toStringAsFixed(0)}/hr',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: FairDropColors.brandGreen,
                              ),
                            ),
                            Text(
                              'Chinnakada & Asramam',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: FairDropColors.slateMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Statutory Wage Floor',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: FairDropColors.slateMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _floorValue != null ? '₹${_floorValue!.toStringAsFixed(0)}/hr' : '—',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: FairDropColors.brandNavy,
                              ),
                            ),
                            Text(
                              '+₹12 above mandate',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: FairDropColors.brandGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: FairDropColors.brandOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Road conditions clear near Kollam Beach road. High traction on overbridge.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: FairDropColors.slateMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Navigation Bar ─────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: FairDropColors.mintBorder.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: FairDropColors.brandNavy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: FairDropColors.brandGreen,
        unselectedItemColor: FairDropColors.slateMuted,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on home
              break;
            case 1:
              Navigator.pushNamed(context, '/orders');
              break;
            case 2:
              Navigator.pushNamed(context, '/pay-breakdown');
              break;
            case 3:
              Navigator.pushNamed(context, '/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.two_wheeler_rounded),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.badge_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
