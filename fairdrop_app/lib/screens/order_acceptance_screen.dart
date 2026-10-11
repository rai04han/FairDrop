// ============================================================================
// FairDrop — Order Acceptance Screen
// ============================================================================
// Owner: Hari (25MCA025)
// PRD FR-11 to FR-16
//
// FR-11: Shows restaurant name, drop-off area, distance in km
// FR-12: Shows live pay formula using current constants from pay-service
// FR-13: Shows estimated pay (base + distance + surge only).
//        Notes that wait/floor are calculated after delivery.
// FR-14: Out-of-zone badge + consent rule if applicable
// FR-15: Accept / Decline buttons (no penalty language)
// FR-16: If constants can't load, Accept is disabled
//
// Receives the order data as a route argument (Map<String, dynamic>).
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/core_api_service.dart';

class OrderAcceptanceScreen extends StatefulWidget {
  const OrderAcceptanceScreen({super.key});

  @override
  State<OrderAcceptanceScreen> createState() => _OrderAcceptanceScreenState();
}

class _OrderAcceptanceScreenState extends State<OrderAcceptanceScreen> {
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _payConfig;
  bool _isLoadingConfig = true;
  bool _isActing = false;
  String? _configError;
  bool _outOfZoneConsent = false;

  @override
  void initState() {
    super.initState();
    // Delay to allow arguments to be injected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _order = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _loadPayConfig();
    });
  }

  Future<void> _loadPayConfig() async {
    setState(() {
      _isLoadingConfig = true;
      _configError = null;
    });
    try {
      final data = await ApiService.getPayConfig();
      setState(() {
        _payConfig = data['config'] as Map<String, dynamic>?;
        _isLoadingConfig = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _configError = e.message;
        _isLoadingConfig = false;
      });
    } catch (e) {
      setState(() {
        _configError = 'Could not load pay rates. Accept is disabled.';
        _isLoadingConfig = false;
      });
    }
  }

  double get _distanceKm =>
      ((_order?['distance_km'] as num?)?.toDouble()) ?? 0.0;

  bool get _isSurge => (_order?['is_surge_active'] as bool?) ?? false;

  // FR-13: Estimated pay = base + distance + surge (no wait/floor at acceptance)
  double get _estimatedPay {
    if (_payConfig == null) return 0;
    final base = double.tryParse(_payConfig!['base_rate']?.toString() ?? '15') ?? 15.0;
    final perKm = double.tryParse(_payConfig!['per_km_rate']?.toString() ?? '6') ?? 6.0;
    final surge = _isSurge
        ? double.tryParse(_payConfig!['surge_bonus']?.toString() ?? '20') ?? 20.0
        : 0.0;
    return base + (_distanceKm * perKm) + surge;
  }

  bool get _isOutOfZone {
    // Out-of-zone if order indicates it (server sets this field)
    return (_order?['is_out_of_zone'] as bool?) ?? false;
  }

  bool get _canAccept =>
      !_isLoadingConfig &&
      _configError == null &&
      (!_isOutOfZone || _outOfZoneConsent);

  Future<void> _acceptOrder() async {
    final orderId = _order?['order_id'] as String?;
    if (orderId == null) return;

    setState(() => _isActing = true);
    try {
      await CoreApiService.updateOrderStatus(
        orderId: orderId,
        newStatus: 'assigned',
      );
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/active-delivery',
          arguments: _order,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _declineOrder() async {
    // No penalty — simply navigate back to home (FR-15)
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/rider-home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_order == null && !_isLoadingConfig) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Order')),
        body: const Center(child: Text('No order data received.')),
      );
    }

    final restaurant = _order?['restaurant_address'] as Map<String, dynamic>? ?? {};
    final delivery = _order?['delivery_address'] as Map<String, dynamic>? ?? {};
    final orderId = _order?['order_id'] as String? ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Order'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── New order badge ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'New delivery request — $orderId',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Out-of-zone badge (FR-14) ─────────────────────────────────
            if (_isOutOfZone) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade600),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This order is outside your assigned zone. '
                        'You may accept it, but your zone assignment will update after delivery.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _outOfZoneConsent,
                onChanged: (v) => setState(() => _outOfZoneConsent = v ?? false),
                title: const Text('I understand and consent to the out-of-zone delivery'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
            ],

            // ── Surge badge ───────────────────────────────────────────────
            if (_isSurge) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'SURGE PRICING ACTIVE',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Order details card (FR-11) ─────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(theme, Icons.info_outline, 'Order Details'),
                    const Divider(height: 20),
                    _detailRow(theme, Icons.restaurant, 'Restaurant',
                        restaurant['label']?.toString() ?? 'Unknown'),
                    const SizedBox(height: 8),
                    _detailRow(theme, Icons.location_on, 'Delivery to',
                        delivery['label']?.toString() ?? 'Unknown'),
                    const SizedBox(height: 8),
                    _detailRow(theme, Icons.route, 'Distance',
                        '${_distanceKm.toStringAsFixed(1)} km'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Pay formula card (FR-12) ──────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(theme, Icons.calculate, 'Pay Formula'),
                    const Divider(height: 20),
                    if (_isLoadingConfig)
                      const Center(child: CircularProgressIndicator())
                    else if (_configError != null)
                      _errorBox(theme, _configError!)
                    else if (_payConfig != null) ...[
                      _formulaLine(theme, 'Base Rate',
                          '₹${_dbl(_payConfig!["base_rate"])} per delivery'),
                      _formulaLine(theme, 'Distance Pay',
                          '${_distanceKm.toStringAsFixed(1)} km × ₹${_dbl(_payConfig!["per_km_rate"])}/km = ₹${(_distanceKm * (_payConfig!["per_km_rate"] as num? ?? 6)).toStringAsFixed(2)}'),
                      if (_isSurge)
                        _formulaLine(theme, 'Surge Bonus',
                            '₹${_dbl(_payConfig!["surge_bonus"])} flat (peak hour)'),
                      _formulaLine(theme, 'Wait Compensation',
                          'If wait > ${_payConfig!["wait_threshold_mins"]} min → ₹${_dbl(_payConfig!["wait_compensation"])} flat',
                          note: true),
                      _formulaLine(theme, 'Earnings Floor',
                          '₹${_dbl(_payConfig!["min_wage_per_hour"])}/hr — top-up computed after delivery',
                          note: true),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Estimated pay card (FR-13) ────────────────────────────────
            if (!_isLoadingConfig && _configError == null)
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: cs.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Text(
                            'Estimated Pay (minimum)',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${_estimatedPay.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Final pay may be higher if you wait > ${_payConfig?["wait_threshold_mins"] ?? 10} min at restaurant, or if earnings floor top-up applies.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ── Accept / Decline buttons (FR-15) ──────────────────────────
            Row(
              children: [
                // Decline — no penalty language per FR-15
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isActing ? null : _declineOrder,
                    icon: const Icon(Icons.close),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Accept — disabled if config failed (FR-16) or out-of-zone no consent
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: (_canAccept && !_isActing) ? _acceptOrder : null,
                    icon: _isActing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isLoadingConfig
                        ? 'Loading rates…'
                        : _configError != null
                            ? 'Pay rates unavailable'
                            : 'Accept Order'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            // FR-16: Explain why Accept is disabled
            if (_configError != null) ...[
              const SizedBox(height: 8),
              _errorBox(theme,
                  'Accept is disabled because pay rates could not be loaded. '
                  'You may retry below, or contact your admin.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loadPayConfig,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry loading rates'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _dbl(dynamic v) =>
      (double.tryParse(v?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);

  Widget _sectionHeader(ThemeData t, IconData icon, String label) => Row(
        children: [
          Icon(icon, color: t.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: t.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      );

  Widget _detailRow(ThemeData t, IconData icon, String label, String value) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: t.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              Text(value,
                  style:
                      t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      );

  Widget _formulaLine(ThemeData t, String label, String desc,
      {bool note = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(note ? Icons.info_outline : Icons.check_circle_outline,
                size: 16,
                color:
                    note ? t.colorScheme.onSurfaceVariant : t.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: t.textTheme.bodySmall,
                  children: [
                    TextSpan(
                        text: '$label: ',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: desc),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _errorBox(ThemeData t, String msg) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: t.colorScheme.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: t.colorScheme.onErrorContainer)),
            ),
          ],
        ),
      );
}
