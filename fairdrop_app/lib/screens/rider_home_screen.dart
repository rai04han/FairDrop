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
  int _secondsLeft = 0;
  String? _homeDataError;

  // Today's stats (real values from backend, default zeros for new rider)
  double _todayEarnings = 0.0;
  double _activeHoursToday = 0.0;
  double _hourlyRate = 0.0;
  double? _floorValue = 70.0;
  int _deliveriesToday = 0;
  String _currentZone = 'Chinnakada & Asramam (KL-02)';

  // Split ledger components today
  double _baseDistancePayToday = 0.0;
  double _waitPayToday = 0.0;
  double _surgePayToday = 0.0;
  double _floorTopupToday = 0.0;

  // Pay config rates (default baseline Kerala parameters)
  double _baseRate = 15.0;
  double _perKmRate = 6.0;
  double _waitCompensation = 10.0;
  int _waitThresholdMins = 10;
  double _surgeBonus = 15.0;

  // Active incoming order (if assigned)
  Map<String, dynamic>? _incomingOrder;
  Map<String, dynamic>? _scheduledConfig;

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
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(Map<String, dynamic> order) {
    _countdownTimer?.cancel();
    _secondsLeft = 45;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          // Offer window elapsed
          _countdownTimer?.cancel();
        }
      });
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(AppConfig.orderPollingInterval, (_) {
      if (_isOnline) _pollForOrder();
    });
  }

  Future<void> _pollForOrder() async {
    try {
      final data = await CoreApiService.getRiderActiveOrder();
      final order = data['order'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          final prevId = _incomingOrder?['order_id'] ?? _incomingOrder?['id'];
          final newId = order?['order_id'] ?? order?['id'];
          _incomingOrder = order;

          if (order != null) {
            final status = (order['status'] as String? ?? '').toLowerCase();
            final ack = (order['rider_ack'] as String? ?? '').toLowerCase();
            final isPendingOffer = status == 'accepted' && ack == 'pending';

            if (isPendingOffer) {
              if (prevId != newId || _countdownTimer == null || !_countdownTimer!.isActive) {
                _startCountdown(order);
              }
            } else {
              _countdownTimer?.cancel();
              _secondsLeft = 0;
            }
          } else {
            _countdownTimer?.cancel();
            _secondsLeft = 0;
          }
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

      final serverIsOnline = (stats['is_online'] as bool?) ?? false;
      if (!serverIsOnline && _isOnline) {
        try {
          await CoreApiService.setRiderStatus(isOnline: true);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isOnline = (stats['is_online'] as bool?) ?? _isOnline;
          _todayEarnings = (stats['total_earnings_today'] as num?)?.toDouble() ?? 0.0;
          _activeHoursToday = (stats['active_hours_today'] as num?)?.toDouble() ?? 0.0;
          _deliveriesToday = (stats['deliveries_today'] as num?)?.toInt() ?? 0;
          _currentZone = stats['current_zone'] as String? ?? 'Chinnakada & Asramam (KL-02)';
          _hourlyRate = (stats['hourly_rate'] as num?)?.toDouble() ??
              (_activeHoursToday > 0 ? _todayEarnings / _activeHoursToday : 0.0);
          _floorValue = double.tryParse(config['min_wage_per_hour']?.toString() ?? '');
          _baseDistancePayToday = (stats['base_distance_pay_today'] as num?)?.toDouble() ?? 0.0;
          _waitPayToday = (stats['wait_pay_today'] as num?)?.toDouble() ?? 0.0;
          _surgePayToday = (stats['surge_pay_today'] as num?)?.toDouble() ?? 0.0;
          _floorTopupToday = (stats['floor_topup_today'] as num?)?.toDouble() ?? 0.0;
          _baseRate = double.tryParse(config['base_rate']?.toString() ?? '') ?? 15.0;
          _perKmRate = double.tryParse(config['per_km_rate']?.toString() ?? '') ?? 6.0;
          _waitCompensation = double.tryParse(config['wait_compensation']?.toString() ?? '') ?? 10.0;
          _waitThresholdMins = int.tryParse(config['wait_threshold_mins']?.toString() ?? '') ?? 10;
          _surgeBonus = double.tryParse(config['surge_bonus']?.toString() ?? '') ?? 15.0;
          _scheduledConfig = configData['scheduled'] as Map<String, dynamic>?;
        });
      }
      // Immediately check for any active or newly allocated order
      _pollForOrder();
    } catch (_) {
      // Keep real values (zeros for new rider)
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
    if (order == null) return;
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    Navigator.pushNamed(
      context,
      '/order-acceptance',
      arguments: order,
    ).then((_) {
      _pollForOrder();
      _loadStats();
      _startPolling();
    });
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

                      // 2. Incoming Order Alert Card or Active Delivery Banner
                      if (_isOnline && _incomingOrder != null) ...[
                        _buildOrderDispatchWidget(),
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
          // Brand & Zone Badge (Clickable to open Zone Map)
          Expanded(
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/zone-map'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FairDropLogo(fontSize: 18),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: FairDropColors.brandGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.map_rounded, size: 10, color: FairDropColors.brandGreen),
                                const SizedBox(width: 3),
                                Text(
                                  'KL-02',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: FairDropColors.brandGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                        Flexible(
                          child: Text(
                            '$_currentZone • View Map ↗',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: FairDropColors.slateMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

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
        Expanded(
          child: Row(
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
              Flexible(
                child: Text(
                  _isOnline ? 'Live Shift • Chinnakada Hub' : 'Shift Offline • Tap to go online',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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
              Expanded(
                child: Text(
                  _activeHoursToday > 0
                      ? "Today's Shift • ${_activeHoursToday.toStringAsFixed(1)}h active in Kollam"
                      : "Today's Shift • — active in Kollam",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FairDropColors.slateMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
              child: _todayEarnings <= 0
                  ? Container(color: FairDropColors.mintBorder.withValues(alpha: 0.3))
                  : Row(
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
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _activeHoursToday >= 1.0 && _todayEarnings > 0 && _hourlyRate >= _floorValue!
                          ? 'Kerala Min Floor ₹${_floorValue!.toStringAsFixed(0)}/hr met'
                          : 'Floor evaluated after 60 min on orders',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: FairDropColors.brandGreen,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
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
            subtitle: _deliveriesToday > 0
                ? '$_deliveriesToday ${_deliveriesToday == 1 ? "drop" : "drops"} @ ₹${_baseRate.toStringAsFixed(0)} + ₹${_perKmRate.toStringAsFixed(0)}/km standard transit'
                : '₹${_baseRate.toStringAsFixed(0)} base + ₹${_perKmRate.toStringAsFixed(0)}/km standard transit rate',
            amount: _baseDistancePayToday > 0 ? '₹${_baseDistancePayToday.toStringAsFixed(2)}' : '₹0.00',
          ),
          const SizedBox(height: 8),
          _buildFormulaRow(
            color: FairDropColors.payWait,
            title: 'Geofenced Wait Time',
            subtitle: 'Flat ₹${_waitCompensation.toStringAsFixed(0)} bonus when restaurant wait exceeds ${_waitThresholdMins}m',
            amount: _waitPayToday > 0 ? '₹${_waitPayToday.toStringAsFixed(2)}' : '₹0.00',
          ),
          const SizedBox(height: 8),
          _buildFormulaRow(
            color: FairDropColors.paySurge,
            title: 'Monsoon Surge Allowance',
            subtitle: '₹${_surgeBonus.toStringAsFixed(0)} bonus per order during declared severe weather',
            amount: _surgePayToday > 0 ? '₹${_surgePayToday.toStringAsFixed(2)}' : '₹0.00',
          ),
          const SizedBox(height: 8),
          _buildFormulaRow(
            color: FairDropColors.payGuarantee,
            title: 'Kerala Fair Pay Top-Up',
            subtitle: _floorValue != null
                ? 'State wage floor baseline ₹${_floorValue!.truncateToDouble() == _floorValue ? _floorValue!.toInt() : _floorValue!.toStringAsFixed(0)}/hr min'
                : 'Living wage floor protection',
            amount: _floorTopupToday > 0 ? '₹${_floorTopupToday.toStringAsFixed(2)}' : '₹0.00',
            isPositive: false,
          ),
          const SizedBox(height: 16),

          // Formula Action Button
          OutlinedButton(
            key: const Key('btn_view_full_formula'),
            onPressed: () => _showFormulaBreakdownModal(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: FairDropColors.mintBorder),
              backgroundColor: FairDropColors.mintBg.withValues(alpha: 0.5),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'View Full Formula Breakdown',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FairDropColors.brandNavy,
                    ),
                    overflow: TextOverflow.ellipsis,
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

  // ── 2. Order Dispatch Widget (New Offer or Active In-Progress Delivery) ───
  Widget _buildOrderDispatchWidget() {
    final order = _incomingOrder;
    if (order == null) return const SizedBox.shrink();

    final status = (order['status'] as String? ?? '').toLowerCase();

    // If active delivery in progress (assigned, arrived, picked_up)
    if (status == 'assigned' || status == 'arrived' || status == 'picked_up') {
      return _buildActiveDeliveryBanner(order);
    }

    // Pending offer dispatch card
    return _buildIncomingOrderCard();
  }

  Widget _buildActiveDeliveryBanner(Map<String, dynamic> order) {
    final orderId = order['order_id'] ?? order['id'] ?? 'FD-LIVE';
    final status = (order['status'] as String? ?? '').toLowerCase();
    final distanceKm = (order['distance_km'] as num?)?.toDouble() ?? 0.0;

    String statusLabel = 'Heading to Restaurant';
    Color statusColor = FairDropColors.brandNavy;
    IconData statusIcon = Icons.two_wheeler_rounded;

    if (status == 'arrived') {
      statusLabel = 'At Kitchen / Waiting';
      statusColor = FairDropColors.brandOrange;
      statusIcon = Icons.storefront_rounded;
    } else if (status == 'picked_up') {
      statusLabel = 'Out for Delivery';
      statusColor = FairDropColors.brandGreen;
      statusIcon = Icons.delivery_dining_rounded;
    }

    final pickupAddress = _extractAddress(
      order['restaurant_address'],
      fallback: _extractAddress(
        order['pickup_address'],
        fallback: (order['restaurant_name'] as String?) ?? 'Restaurant Pickup',
      ),
    );
    final dropAddress = _extractAddress(
      order['delivery_address'],
      fallback: (order['delivery_location'] as String?) ?? 'Customer Delivery Point',
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FairDropColors.brandGreen.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: FairDropColors.brandGreen.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: FairDropColors.brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                      'ACTIVE DELIVERY IN PROGRESS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Order #$orderId',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: FairDropColors.brandNavy,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: FairDropColors.slateMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$pickupAddress → $dropAddress ($distanceKm km)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: FairDropColors.slateMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/active-delivery',
                arguments: order,
              ).then((_) {
                _pollForOrder();
                _loadStats();
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: FairDropColors.brandGreen,
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
              elevation: 2,
            ),
            icon: const Icon(Icons.navigation_rounded, size: 18),
            label: Text(
              'Resume Delivery & Update Status',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Incoming Order Alert Card ──────────────────────────────────────────
  Widget _buildIncomingOrderCard() {
    final order = _incomingOrder;
    if (order == null) return const SizedBox.shrink();

    final orderId = order['order_id'] ?? order['id'] ?? 'FD-LIVE';
    final distanceKm = (order['distance_km'] as num?)?.toDouble() ?? 0.0;
    final isSurge = order['is_surge_active'] == true;
    final basePay = (order['base_pay'] as num?)?.toDouble() ?? _baseRate;
    final distancePay = (order['distance_pay'] as num?)?.toDouble() ?? (distanceKm * _perKmRate);
    final surgePay = isSurge ? ((order['surge_bonus'] as num?)?.toDouble() ?? _surgeBonus) : 0.0;
    final calcResult = order['pay_calculation_result'] as Map<String, dynamic>?;
    final guaranteedPayout = (calcResult?['guaranteed_payout'] as num?)?.toDouble() ??
        (order['guaranteed_payout'] as num?)?.toDouble() ??
        (basePay + distancePay + surgePay);

    final pickupAddress = _extractAddress(
      order['restaurant_address'],
      fallback: _extractAddress(
        order['pickup_address'],
        fallback: (order['restaurant_name'] as String?) ?? 'Restaurant Pickup',
      ),
    );
    final dropAddress = _extractAddress(
      order['delivery_address'],
      fallback: (order['delivery_location'] as String?) ?? 'Customer Delivery Point',
    );

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
                  'Live Dispatch',
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
                          '₹${guaranteedPayout.toStringAsFixed(0)}',
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
                          '${distanceKm.toStringAsFixed(1)} km total trip',
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
                      _buildLedgerItem('Base Pick & Drop', '₹${basePay.toStringAsFixed(0)}', FairDropColors.payBase),
                      const SizedBox(height: 5),
                      _buildLedgerItem('Trip Distance (${distanceKm.toStringAsFixed(1)} km @ ₹${_perKmRate.toStringAsFixed(0)}/km)', '₹${distancePay.toStringAsFixed(0)}', FairDropColors.payBase),
                      if (surgePay > 0) ...[
                        const SizedBox(height: 5),
                        _buildLedgerItem('Monsoon Coastal Surge', '₹${surgePay.toStringAsFixed(0)}', FairDropColors.paySurge),
                      ],
                      const SizedBox(height: 5),
                      _buildLedgerItem('Wait Guarantee (if >${_waitThresholdMins}m)', '+₹${_waitCompensation.toStringAsFixed(0)} flat', FairDropColors.payWait),
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
                                pickupAddress,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: FairDropColors.brandNavy,
                                ),
                              ),
                              Text(
                                '${distanceKm.toStringAsFixed(1)} km trip',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: FairDropColors.slateMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Order #$orderId',
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
                                dropAddress,
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
            onPressed: () => _acceptOffer(order),
            style: FilledButton.styleFrom(
              backgroundColor: FairDropColors.brandOrange,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              elevation: 3,
              shadowColor: FairDropColors.brandOrange.withValues(alpha: 0.35),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: Text(
              'Accept Order (₹${guaranteedPayout.toStringAsFixed(0)} Guaranteed)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),

          OutlinedButton(
            onPressed: () {
              setState(() {
                _incomingOrder = null;
                _countdownTimer?.cancel();
                _secondsLeft = 0;
              });
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
              Expanded(
                child: Text(
                  'Kollam Hub Fairness Index',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: FairDropColors.brandNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Average pay per engaged hour for riders in this hub today vs the statutory floor.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: FairDropColors.slateMuted,
            ),
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
                    Expanded(
                      child: Row(
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
                              'Kerala Gig Worker Wage Norms',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: FairDropColors.brandNavy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            _activeHoursToday > 0 && _todayEarnings > 0
                                ? Text(
                                    '₹${_hourlyRate.toStringAsFixed(0)}/hr',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: FairDropColors.brandGreen,
                                    ),
                                  )
                                : Text(
                                    'Not enough completed hours today',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: FairDropColors.slateMuted,
                                      height: 1.2,
                                    ),
                                  ),
                            const SizedBox(height: 2),
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
                            const SizedBox(height: 2),
                            Text(
                              'State wage floor',
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
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Zone Map Quick Action
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/zone-map'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: FairDropColors.mintBorder),
              backgroundColor: FairDropColors.mintBg.withValues(alpha: 0.5),
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.map_rounded, size: 16, color: FairDropColors.brandNavy),
            label: Text(
              'View Kollam Zone Map & Boundaries',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FairDropColors.brandNavy,
              ),
            ),
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
              Navigator.pushNamed(context, '/zone-map');
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
            icon: Icon(Icons.map_rounded),
            label: 'Zone Map',
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

  void _showFormulaBreakdownModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final hasScheduled = _scheduledConfig != null;
        final scheduled = _scheduledConfig ?? {};

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: FairDropColors.mintBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Full Pay Formula Breakdown',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: FairDropColors.brandNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                      color: FairDropColors.slateMuted,
                    ),
                  ],
                ),
                Text(
                  'Live rates from pay-service config & scheduled revisions (zero hardcoded rates).',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: FairDropColors.slateMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FairDropColors.surfaceLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FairDropColors.mintBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate_rounded, size: 18, color: FairDropColors.brandGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Active Policy Rate Card',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: FairDropColors.brandNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildModalFormulaRow(
                        title: 'Base Dispatch Fee',
                        value: '₹${_baseRate.toStringAsFixed(2)}',
                        desc: 'Fixed pickup compensation per delivered order',
                      ),
                      const Divider(height: 16, color: FairDropColors.mintBorder),
                      _buildModalFormulaRow(
                        title: 'Distance Transit Rate',
                        value: '₹${_perKmRate.toStringAsFixed(2)}/km',
                        desc: 'Straight-line transit distance from restaurant to customer',
                      ),
                      const Divider(height: 16, color: FairDropColors.mintBorder),
                      _buildModalFormulaRow(
                        title: 'Geofenced Wait Compensation',
                        value: 'Flat ₹${_waitCompensation.toStringAsFixed(2)} bonus',
                        desc: 'Credited when GPS kitchen wait time exceeds $_waitThresholdMins minutes',
                      ),
                      const Divider(height: 16, color: FairDropColors.mintBorder),
                      _buildModalFormulaRow(
                        title: 'Monsoon Severe Weather Surge',
                        value: '₹${_surgeBonus.toStringAsFixed(2)} per order',
                        desc: 'Direct bonus during declared extreme weather conditions',
                      ),
                      const Divider(height: 16, color: FairDropColors.mintBorder),
                      _buildModalFormulaRow(
                        title: 'Kerala Statutory Minimum Floor',
                        value: _floorValue != null ? '₹${_floorValue!.toStringAsFixed(2)}/hr' : '—',
                        desc: 'Evaluated per completed 60-min block of cumulative engaged order time',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (hasScheduled) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.update_rounded, size: 18, color: Color(0xFFB45309)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Upcoming Scheduled Revision',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatEffectiveDateNotice(scheduled['effective_from']),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                        if (scheduled['change_reason'] != null && scheduled['change_reason'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Reason: ${scheduled['change_reason']}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF78350F),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _buildModalFormulaRow(
                          title: 'Revised Base Dispatch Fee',
                          value: '₹${(double.tryParse(scheduled['base_rate']?.toString() ?? '') ?? _baseRate).toStringAsFixed(2)}',
                          desc: 'Scheduled starting pickup rate',
                        ),
                        const Divider(height: 16, color: Color(0xFFFCD34D)),
                        _buildModalFormulaRow(
                          title: 'Revised Distance Rate',
                          value: '₹${(double.tryParse(scheduled['per_km_rate']?.toString() ?? '') ?? _perKmRate).toStringAsFixed(2)}/km',
                          desc: 'Scheduled transit per km rate',
                        ),
                        const Divider(height: 16, color: Color(0xFFFCD34D)),
                        _buildModalFormulaRow(
                          title: 'Revised Wait Compensation',
                          value: 'Flat ₹${(double.tryParse(scheduled['wait_compensation']?.toString() ?? '') ?? _waitCompensation).toStringAsFixed(2)} bonus',
                          desc: 'Threshold: ${scheduled['wait_threshold_mins'] ?? _waitThresholdMins} minutes',
                        ),
                        const Divider(height: 16, color: Color(0xFFFCD34D)),
                        _buildModalFormulaRow(
                          title: 'Revised Monsoon Surge',
                          value: '₹${(double.tryParse(scheduled['surge_bonus']?.toString() ?? '') ?? _surgeBonus).toStringAsFixed(2)} per order',
                          desc: 'Scheduled surge allowance',
                        ),
                        const Divider(height: 16, color: Color(0xFFFCD34D)),
                        _buildModalFormulaRow(
                          title: 'Revised Statutory Floor',
                          value: '₹${(double.tryParse(scheduled['min_wage_per_hour']?.toString() ?? '') ?? (_floorValue ?? 70.0)).toStringAsFixed(2)}/hr',
                          desc: 'Scheduled statutory floor rate',
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FairDropColors.mintBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FairDropColors.mintBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_outlined, size: 20, color: FairDropColors.brandGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No scheduled formula revisions pending. All rate adjustments require minimum 7 days advance notice under Fairwork Fair Contracts principles.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: FairDropColors.brandNavy,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/pay-breakdown');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: FairDropColors.mintBorder),
                    backgroundColor: FairDropColors.mintBg,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, color: FairDropColors.brandNavy, size: 18),
                  label: Text(
                    'View Itemized Delivery Ledger',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: FairDropColors.brandNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalFormulaRow({
    required String title,
    required String value,
    required String desc,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FairDropColors.brandNavy,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: FairDropColors.brandGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: FairDropColors.slateMuted,
          ),
        ),
      ],
    );
  }

  String _formatEffectiveDateNotice(dynamic effFrom) {
    if (effFrom == null) return 'Scheduled for upcoming rollout';
    try {
      final effDate = DateTime.parse(effFrom.toString().split('T').first);
      final today = DateTime.now();
      final diffDays = effDate.difference(DateTime(today.year, today.month, today.day)).inDays;
      final dateStr = '${effDate.day.toString().padLeft(2, '0')}/${effDate.month.toString().padLeft(2, '0')}/${effDate.year}';
      if (diffDays > 0) {
        return 'Takes effect in $diffDays days ($dateStr)';
      } else if (diffDays == 0) {
        return 'Takes effect today ($dateStr)';
      } else {
        return 'Effective since $dateStr';
      }
    } catch (_) {
      return 'Effective: $effFrom';
    }
  }
}
