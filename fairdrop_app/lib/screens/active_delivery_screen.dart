// ============================================================================
// FairDrop — Active Delivery Screen
// ============================================================================
// Owner: Hari (25MCA025)
// PRD FR-17 to FR-20
//
// FR-17: Status steps: Assigned → Arrived at Restaurant → Picked Up → Delivered
// FR-18: Arrived + Picked Up send timestamps; wait = server-computed diff
// FR-19: Delay report (traffic/restaurant/railway) + shows verified state
// FR-20: "Delivered" → pay calculation loading → Delivery Summary screen
// ============================================================================

import 'package:flutter/material.dart';
import '../services/core_api_service.dart';
import '../services/exceptions.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  Map<String, dynamic>? _order;

  // Current workflow step (0=assigned, 1=arrived, 2=picked_up, 3=delivered)
  int _currentStep = 0;
  bool _isUpdating = false;
  String? _errorMessage;

  // Delay report state (FR-19)
  bool _hasDelay = false;
  String _delayType = 'traffic';
  final _delayController = TextEditingController();
  bool _delaySubmitted = false;

  // Timestamps for wait calculation (FR-18)
  DateTime? _arrivedAt;

  // Steps configuration
  static const _steps = [
    _DeliveryStep(
      status: 'assigned',
      label: 'Heading to Restaurant',
      icon: Icons.directions_bike,
      description: 'Make your way to the restaurant to pick up the order.',
    ),
    _DeliveryStep(
      status: 'arrived_at_restaurant',
      label: 'Arrived at Restaurant',
      icon: Icons.restaurant,
      description: 'Tap when you arrive at the restaurant to start the wait timer.',
    ),
    _DeliveryStep(
      status: 'picked_up',
      label: 'Order Picked Up',
      icon: Icons.takeout_dining,
      description: 'Tap when you have the order and are heading to the customer.',
    ),
    _DeliveryStep(
      status: 'delivered',
      label: 'Delivered',
      icon: Icons.check_circle,
      description: 'Tap to confirm delivery. Pay will be calculated automatically.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _order = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (_order != null) {
        _initStepFromOrder();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _delayController.dispose();
    super.dispose();
  }

  void _initStepFromOrder() {
    final status = _order?['status'] as String? ?? 'assigned';
    switch (status) {
      case 'assigned':
        _currentStep = 0;
      case 'arrived_at_restaurant':
        _currentStep = 1;
      case 'picked_up':
        _currentStep = 2;
      case 'delivered':
        _currentStep = 3;
    }
  }

  Future<void> _advanceStep() async {
    if (_currentStep >= _steps.length - 1) return;

    final nextStep = _steps[_currentStep + 1];
    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });

    try {
      final orderId = _order?['order_id'] as String?;
      if (orderId == null) throw Exception('Order ID missing');

      // FR-18: Track arrived_at_restaurant timestamp for wait calculation
      if (nextStep.status == 'arrived_at_restaurant') {
        _arrivedAt = DateTime.now();
      }

      // FR-18: When picking up, send restaurant wait time
      int? waitMins;
      if (nextStep.status == 'picked_up' && _arrivedAt != null) {
        waitMins = DateTime.now().difference(_arrivedAt!).inMinutes;
      }

      // FR-20: On delivery, show pay loading then navigate to summary
      if (nextStep.status == 'delivered') {
        await _completeDelivery(orderId, waitMins);
        return;
      }

      // For other transitions, just update status
      final delayCtx = _delaySubmitted
          ? {
              'type': _delayType,
              'verified': false,
              'source': 'rider_report',
            }
          : {'type': 'none', 'verified': false, 'source': 'none'};

      await CoreApiService.updateOrderStatus(
        orderId: orderId,
        newStatus: nextStep.status,
        restaurantWaitMins: waitMins,
        delayContext: delayCtx,
      );

      setState(() {
        _currentStep++;
        _isUpdating = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isUpdating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Update failed. Check your connection.';
        _isUpdating = false;
      });
    }
  }

  Future<void> _completeDelivery(String orderId, int? waitMins) async {
    // FR-20: Show loading state while pay is being calculated
    final delayCtx = _delaySubmitted
        ? {
            'type': _delayType,
            'verified': false,
            'source': 'rider_report',
          }
        : {'type': 'none', 'verified': false, 'source': 'none'};

    try {
      final result = await CoreApiService.updateOrderStatus(
        orderId: orderId,
        newStatus: 'delivered',
        restaurantWaitMins: waitMins,
        delayContext: delayCtx,
      );

      if (mounted) {
        // Navigate to Delivery Summary with pay result
        final payResult = result['order']?['pay_calculation_result'];
        Navigator.pushReplacementNamed(
          context,
          '/pay-breakdown',
          arguments: {
            'order': result['order'],
            'pay_result': payResult,
          },
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isUpdating = false;
      });
    }
  }

  Future<void> _submitDelayReport() async {
    final orderId = _order?['order_id'] as String?;
    if (orderId == null) return;

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });

    try {
      await CoreApiService.updateOrderStatus(
        orderId: orderId,
        newStatus: _order?['status'] as String? ?? 'assigned',
        delayContext: {
          'type': _delayType,
          'verified': false,
          'source': 'rider_report',
          'notes': _delayController.text.trim(),
        },
      );
      setState(() {
        _delaySubmitted = true;
        _hasDelay = false;
        _isUpdating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delay reported. It will be verified by the system.')),
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final order = _order;

    return Scaffold(
      appBar: AppBar(
        title: Text(order?['order_id'] as String? ?? 'Active Delivery'),
        automaticallyImplyLeading: false,
      ),
      body: order == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Progress stepper (FR-17) ─────────────────────────
                  _buildStepper(theme, cs),
                  const SizedBox(height: 20),

                  // ── Current step action card ─────────────────────────
                  _buildActionCard(theme, cs, order),
                  const SizedBox(height: 16),

                  // ── Delay report section (FR-19) ─────────────────────
                  _buildDelaySection(theme, cs),

                  // ── Error message ─────────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: cs.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Order details ─────────────────────────────────────
                  _buildOrderDetails(theme, cs, order),
                ],
              ),
            ),
    );
  }

  // ── Stepper widget (FR-17) ─────────────────────────────────────────────────
  Widget _buildStepper(ThemeData theme, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.route, color: cs.primary),
                const SizedBox(width: 8),
                Text('Delivery Progress',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(_steps.length, (i) {
                final isDone = i < _currentStep;
                final isCurrent = i == _currentStep;
                final stepColor = isDone
                    ? Colors.green
                    : isCurrent
                        ? cs.primary
                        : cs.surfaceContainerHighest;
                final iconColor = (isDone || isCurrent) ? Colors.white : cs.outline;

                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: stepColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDone ? Icons.check : _steps[i].icon,
                          color: iconColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _steps[i].label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: isCurrent ? FontWeight.bold : null,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Connector line (except last)
                      if (i < _steps.length - 1)
                        const SizedBox.shrink(),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action card for current step ───────────────────────────────────────────
  Widget _buildActionCard(ThemeData theme, ColorScheme cs,
      Map<String, dynamic> order) {
    final isDelivered = _currentStep >= _steps.length - 1;
    if (isDelivered) {
      return Card(
        color: Colors.green.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              Text('Delivered!',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Pay is being calculated…'),
            ],
          ),
        ),
      );
    }

    final step = _steps[_currentStep];
    final nextStep = _steps[_currentStep + 1];
    final isLastBeforeDelivery = _currentStep == _steps.length - 2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(step.icon, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current: ${step.label}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(step.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Wait timer display (when at restaurant)
            if (_currentStep == 1 && _arrivedAt != null) ...[
              _WaitTimer(arrivedAt: _arrivedAt!),
              const SizedBox(height: 12),
            ],

            FilledButton.icon(
              onPressed: _isUpdating ? null : _advanceStep,
              icon: _isUpdating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(nextStep.icon),
              label: Text(_isUpdating
                  ? (isLastBeforeDelivery ? 'Completing delivery…' : 'Updating…')
                  : isLastBeforeDelivery
                      ? 'Mark as Delivered'
                      : nextStep.label),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor:
                    isLastBeforeDelivery ? Colors.green : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delay report section (FR-19) ──────────────────────────────────────────
  Widget _buildDelaySection(ThemeData theme, ColorScheme cs) {
    if (_delaySubmitted) {
      return Card(
        color: Colors.amber.withValues(alpha: 0.1),
        child: ListTile(
          leading: Icon(Icons.warning_amber, color: Colors.amber.shade700),
          title: const Text('Delay reported'),
          subtitle: Text('Type: $_delayType — pending system verification'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.report_problem_outlined, color: cs.secondary),
                const SizedBox(width: 8),
                Text('Report a Delay',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: _hasDelay,
                  onChanged: (v) => setState(() => _hasDelay = v),
                ),
              ],
            ),
            if (_hasDelay) ...[
              const SizedBox(height: 12),
              Text('Delay type:', style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['traffic', 'restaurant', 'railway'].map((type) {
                  return ChoiceChip(
                    label: Text(type.capitalize()),
                    selected: _delayType == type,
                    onSelected: (s) {
                      if (s) setState(() => _delayType = type);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _delayController,
                decoration: const InputDecoration(
                  labelText: 'Additional notes (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isUpdating ? null : _submitDelayReport,
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Submit Delay Report'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Order details card ─────────────────────────────────────────────────────
  Widget _buildOrderDetails(ThemeData theme, ColorScheme cs,
      Map<String, dynamic> order) {
    final items = (order['items'] as List<dynamic>? ?? []);
    final restaurant = order['restaurant_address'] as Map<String, dynamic>? ?? {};
    final delivery = order['delivery_address'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: cs.primary),
                const SizedBox(width: 8),
                Text('Order Summary',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            _infoRow(theme, Icons.restaurant, restaurant['label']?.toString() ?? '—'),
            _infoRow(theme, Icons.location_on, delivery['label']?.toString() ?? '—'),
            _infoRow(theme, Icons.route,
                '${(order["distance_km"] as num? ?? 0).toStringAsFixed(1)} km'),
            const SizedBox(height: 8),
            Text('${items.length} items:',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            ...items.map((item) {
              final i = item as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• ${i["name"]} × ${i["quantity"]}',
                    style: theme.textTheme.bodySmall),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData t, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 16, color: t.colorScheme.outline),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: t.textTheme.bodySmall)),
          ],
        ),
      );
}

// ── Live wait timer widget ─────────────────────────────────────────────────────
class _WaitTimer extends StatefulWidget {
  final DateTime arrivedAt;
  const _WaitTimer({required this.arrivedAt});

  @override
  State<_WaitTimer> createState() => _WaitTimerState();
}

class _WaitTimerState extends State<_WaitTimer> {
  late final ticker = Stream.periodic(const Duration(seconds: 1));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: ticker,
      builder: (context, _) {
        final elapsed = DateTime.now().difference(widget.arrivedAt);
        final mins = elapsed.inMinutes;
        final secs = elapsed.inSeconds % 60;
        final overThreshold = mins >= 10;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: overThreshold
                ? Colors.orange.withValues(alpha: 0.12)
                : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.timer,
                  color: overThreshold ? Colors.orange : Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Wait time: ${mins}m ${secs.toString().padLeft(2, "0")}s',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: overThreshold ? Colors.orange.shade800 : null,
                ),
              ),
              if (overThreshold) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('COMP APPLIES',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Step data class ────────────────────────────────────────────────────────────
class _DeliveryStep {
  final String status;
  final String label;
  final IconData icon;
  final String description;

  const _DeliveryStep({
    required this.status,
    required this.label,
    required this.icon,
    required this.description,
  });
}

extension _StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
