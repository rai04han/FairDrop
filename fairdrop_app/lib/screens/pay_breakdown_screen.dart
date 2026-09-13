// ============================================================================
// FairDrop — Pay Breakdown Screen
// ============================================================================
// Owner: Raihan
// PRD Features: F-PAY-04 (post-delivery line-by-line breakdown)
//               F-DASH-01 (earnings breakdown display)
//
// PURPOSE:
//   This screen lets the user simulate a delivery and see the EXACT
//   pay breakdown — base rate, distance pay, surge bonus, wait compensation,
//   floor top-up — with full transparency.
//
//   It calls POST /api/pay/calculate (via ApiService) and displays
//   the result in a visual, easy-to-understand card layout.
//
// WHY THIS MATTERS (Fairwork P5 — Fair Pay):
//   Gig platforms hide how pay is calculated. FairDrop shows every
//   component openly — the rider knows exactly WHY they earned ₹X.
//
// DATA FLOW:
//   User fills form → taps "Calculate" → ApiService.calculatePay()
//   → POST request to server (Port 3001) → server runs payEngine.js
//   → MySQL persistence → JSON response → displayed on screen
// ============================================================================

import 'package:flutter/material.dart';

// Import our API service to make HTTP calls to the Pay Engine
import '../services/api_service.dart';

// ============================================================================
// PayBreakdownScreen — StatefulWidget
// ============================================================================
//
// WHY StatefulWidget (not StatelessWidget)?
//   This screen has CHANGING STATE:
//   - The user types in the form fields (input state changes)
//   - After tapping "Calculate", the API result arrives (output state changes)
//   - Loading spinner shows while waiting (loading state changes)
//
//   StatelessWidget can't handle any of this — it builds once and never updates.
//   StatefulWidget rebuilds whenever we call setState(() { ... }).
//
// HOW StatefulWidget WORKS:
//   It's split into TWO classes:
//   1. PayBreakdownScreen — the widget itself (immutable, never changes)
//   2. _PayBreakdownScreenState — holds the mutable state (form data, API result)
//
//   The underscore '_' prefix makes the State class PRIVATE to this file.
// ============================================================================
class PayBreakdownScreen extends StatefulWidget {
  const PayBreakdownScreen({super.key});

  // createState() links the widget to its State class.
  // Flutter calls this once when the widget is first inserted into the tree.
  @override
  State<PayBreakdownScreen> createState() => _PayBreakdownScreenState();
}

class _PayBreakdownScreenState extends State<PayBreakdownScreen> {
  // ── State Variables ─────────────────────────────────────────────────────
  // These variables hold data that CHANGES during the screen's lifetime.
  // When we call setState(() { variable = newValue; }), Flutter rebuilds
  // the UI with the new value.

  // Controls whether the loading spinner is shown
  bool _isLoading = false;

  // Stores the API response after calculation (null = no result yet)
  Map<String, dynamic>? _result;

  // Stores error messages if the API call fails
  String? _errorMessage;

  // ── Form Controllers ──────────────────────────────────────────────────
  // TextEditingController manages the text inside a TextField.
  // We can read the user's input with: _distanceController.text
  // We initialize them with default values for quick testing.

  // Rider ID — which rider is making this delivery
  final _riderIdController = TextEditingController(text: 'rider-001');

  // Order ID — unique identifier for this delivery
  final _orderIdController = TextEditingController(text: 'ORD-20260913-0001');

  // Distance — how far the delivery destination is (in km)
  final _distanceController = TextEditingController(text: '5');

  // Wait time — how long the rider waited at the restaurant (in minutes)
  final _waitMinsController = TextEditingController(text: '0');

  // Active hours — how many hours the rider has worked today
  final _activeHoursController = TextEditingController(text: '4');

  // Toggle switches for boolean fields
  bool _isSurgeActive = false;

  // Counter for auto-generating unique order IDs.
  // Each time "Calculate" is pressed, this increments so the order_id
  // is always unique (prevents "order already processed" error).
  int _orderCounter = 1;

  // ── Lifecycle: dispose() ──────────────────────────────────────────────
  // dispose() is called when this screen is removed from the widget tree
  // (e.g., user navigates back). We MUST dispose TextEditingControllers
  // to free memory. Forgetting this causes memory leaks.
  @override
  void dispose() {
    _riderIdController.dispose();
    _orderIdController.dispose();
    _distanceController.dispose();
    _waitMinsController.dispose();
    _activeHoursController.dispose();
    super.dispose();
  }

  // ── API Call: _calculatePay() ─────────────────────────────────────────
  // This method is called when the user taps the "Calculate Pay" button.
  // It reads form values, calls the API, and updates the screen with results.
  Future<void> _calculatePay() async {
    // Step 1: Show loading spinner, clear previous results/errors
    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = null;
    });

    try {
      // Step 2: Read values from the text fields
      // double.parse() converts String → double ("5" → 5.0)
      // int.parse() converts String → int ("0" → 0)
      final distance = double.tryParse(_distanceController.text) ?? 0;
      final waitMins = int.tryParse(_waitMinsController.text) ?? 0;
      final activeHours = double.tryParse(_activeHoursController.text) ?? 0;

      // Step 2b: Auto-generate a unique order ID using timestamp + counter.
      // This prevents the "order already processed" error when testing
      // multiple calculations without manually changing the order ID.
      final now = DateTime.now();
      final orderId = 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-'
          '${_orderCounter.toString().padLeft(4, '0')}';
      _orderCounter++;

      // Update the order ID field so the user can see what was sent
      _orderIdController.text = orderId;

      // Step 3: Call the API via our service layer
      // 'await' pauses here until the server responds
      final result = await ApiService.calculatePay(
        riderId: _riderIdController.text,
        orderId: orderId,
        distanceKm: distance,
        isSurgeActive: _isSurgeActive,
        restaurantWaitMins: waitMins,
        activeHoursToday: activeHours,
        delayType: 'none',
        delayVerified: false,
        delaySource: 'none',
      );

      // Step 4: Update the screen with the result
      // setState() tells Flutter: "data changed, please rebuild the UI"
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      // Step 5a: Handle API errors (400, 404, 500 from server)
      setState(() {
        _errorMessage = e.body['message'] ?? 'Server error: ${e.statusCode}';
        _isLoading = false;
      });
    } catch (e) {
      // Step 5b: Handle network errors (server not running, timeout, etc.)
      setState(() {
        _errorMessage = 'Connection failed. Is the server running?\n\n'
            'Start it with: cd pay-service && npm start\n\n'
            'Error: $e';
        _isLoading = false;
      });
    }
  }

  // ── Build the UI ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Breakdown'),
      ),

      // SingleChildScrollView makes the entire screen scrollable.
      // Without this, if the content is taller than the screen,
      // Flutter throws a "RenderFlex overflowed" error.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Section 1: Delivery Input Form ────────────────────────
            _buildInputSection(theme),

            const SizedBox(height: 16),

            // ── Calculate Button ──────────────────────────────────────
            FilledButton.icon(
              // onPressed: null disables the button while loading
              onPressed: _isLoading ? null : _calculatePay,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate),
              label: Text(_isLoading ? 'Calculating...' : 'Calculate Pay'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 24),

            // ── Section 2: Error Message ──────────────────────────────
            if (_errorMessage != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Section 3: Pay Breakdown Result ───────────────────────
            if (_result != null) _buildResultSection(theme),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // INPUT SECTION — Form fields for delivery details
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildInputSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Icon(Icons.edit_note, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Delivery Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Rider ID field ────────────────────────────────────────
            // TextField is Flutter's text input widget.
            // 'decoration' controls the label, hint, and icon.
            // 'controller' links this field to our TextEditingController.
            TextField(
              controller: _riderIdController,
              decoration: const InputDecoration(
                labelText: 'Rider ID',
                hintText: 'e.g., rider-001',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Order ID field ────────────────────────────────────────
            TextField(
              controller: _orderIdController,
              decoration: const InputDecoration(
                labelText: 'Order ID',
                hintText: 'e.g., ORD-20260913-0001',
                prefixIcon: Icon(Icons.receipt),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Distance field ────────────────────────────────────────
            // keyboardType: TextInputType.number shows the number keyboard
            // on mobile devices (on Chrome/web it still shows regular keyboard)
            TextField(
              controller: _distanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Distance (km)',
                hintText: 'e.g., 5',
                prefixIcon: Icon(Icons.route),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Wait time field ───────────────────────────────────────
            TextField(
              controller: _waitMinsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Restaurant Wait (minutes)',
                hintText: 'e.g., 15',
                prefixIcon: Icon(Icons.timer),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Active hours field ────────────────────────────────────
            TextField(
              controller: _activeHoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Active Hours Today',
                hintText: 'e.g., 4',
                prefixIcon: Icon(Icons.access_time),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Surge toggle ──────────────────────────────────────────
            // SwitchListTile is a ListTile with a toggle switch.
            // When toggled, onChanged fires and we update the state.
            SwitchListTile(
              title: const Text('Surge Pricing Active'),
              subtitle: const Text('Peak hour bonus applied'),
              value: _isSurgeActive,
              onChanged: (value) {
                // setState rebuilds the UI with the new toggle value
                setState(() => _isSurgeActive = value);
              },
              secondary: Icon(
                Icons.flash_on,
                color: _isSurgeActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // RESULT SECTION — Line-by-line pay breakdown display
  // ══════════════════════════════════════════════════════════════════════
  //
  // This is the core of Fairwork P5 (Fair Pay Transparency).
  // Every pay component is shown individually so the rider knows
  // exactly how their total was calculated.
  Widget _buildResultSection(ThemeData theme) {
    // Read values from the API response.
    // 'as num' handles both int and double from JSON.
    // '.toDouble()' ensures we always work with doubles.
    final baseRate = (_result!['base_rate'] as num).toDouble();
    final distancePay = (_result!['distance_pay'] as num).toDouble();
    final surgeBonus = (_result!['surge_bonus'] as num).toDouble();
    final waitComp = (_result!['wait_compensation'] as num).toDouble();
    final totalPay = (_result!['total_delivery_pay'] as num).toDouble();
    final floorTopup = (_result!['floor_topup'] as num).toDouble();
    final hourlyEarnings =
        (_result!['hourly_earnings_so_far'] as num).toDouble();

    // Grand total = delivery pay + floor top-up
    final grandTotal = totalPay + floorTopup;

    // Minimum wage for comparison (Kerala baseline)
    const minWage = 70.0;

    return Column(
      children: [
        // ── Pay Breakdown Card ────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Row(
                  children: [
                    Icon(Icons.receipt_long,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Pay Breakdown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // ── Individual pay components ─────────────────────────
                // Each line shows one component of the pay calculation.
                _buildPayLine(
                  theme,
                  icon: Icons.attach_money,
                  label: 'Base Rate',
                  value: baseRate,
                  description: 'Fixed amount per delivery',
                ),
                _buildPayLine(
                  theme,
                  icon: Icons.route,
                  label: 'Distance Pay',
                  value: distancePay,
                  description:
                      '${_distanceController.text} km × ₹6/km',
                ),
                if (surgeBonus > 0)
                  _buildPayLine(
                    theme,
                    icon: Icons.flash_on,
                    label: 'Surge Bonus',
                    value: surgeBonus,
                    description: 'Peak hour flat bonus',
                    highlight: true,
                  ),
                if (waitComp > 0)
                  _buildPayLine(
                    theme,
                    icon: Icons.timer,
                    label: 'Wait Compensation',
                    value: waitComp,
                    description:
                        'Restaurant wait > threshold',
                    highlight: true,
                  ),

                const Divider(height: 24),

                // ── Subtotal ──────────────────────────────────────────
                _buildPayLine(
                  theme,
                  icon: Icons.summarize,
                  label: 'Delivery Pay',
                  value: totalPay,
                  description: 'Sum of all components above',
                  isBold: true,
                ),

                // ── Floor top-up (if applicable) ──────────────────────
                if (floorTopup > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield,
                            color: theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Floor Top-Up: ₹${floorTopup.toStringAsFixed(2)}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              Text(
                                'Minimum wage protection (₹${minWage.toInt()}/hr floor)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Grand Total ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL EARNINGS',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '₹${grandTotal.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Hourly Earnings Card ──────────────────────────────────────
        // Shows how the rider's effective hourly rate compares to the
        // minimum wage threshold (₹70/hr Kerala baseline).
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 8),
                    Text(
                      'Hourly Rate',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // ── Hourly earnings vs minimum wage bar ───────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your hourly rate'),
                    Text(
                      '₹${hourlyEarnings.toStringAsFixed(2)}/hr',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hourlyEarnings >= minWage
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Visual progress bar showing earnings vs minimum wage
                // ClipRRect clips the child to rounded corners.
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    // value must be between 0.0 and 1.0
                    // clamp() ensures we don't exceed 1.0
                    value: (hourlyEarnings / minWage).clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      hourlyEarnings >= minWage
                          ? Colors.green
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Minimum wage label
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Minimum wage floor',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '₹${minWage.toInt()}/hr',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Status badge ──────────────────────────────────────
                // Shows whether the rider is above or below minimum wage
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: hourlyEarnings >= minWage
                        ? Colors.green.withValues(alpha: 0.1)
                        : theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hourlyEarnings >= minWage
                            ? Icons.check_circle
                            : Icons.warning,
                        size: 16,
                        color: hourlyEarnings >= minWage
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hourlyEarnings >= minWage
                            ? 'Above minimum wage — no top-up needed'
                            : 'Below minimum wage — floor top-up applied',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hourlyEarnings >= minWage
                              ? Colors.green
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Transparency Notice ───────────────────────────────────────
        // Fairwork P5 compliance: inform the rider that pay is transparent
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.visibility,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'FairDrop shows every pay component openly. '
                    'No hidden deductions, no opaque algorithms.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // HELPER: _buildPayLine — A single row in the pay breakdown
  // ══════════════════════════════════════════════════════════════════════
  //
  // Extracted as a helper because we repeat this pattern 4+ times.
  // Each call creates one row: [icon] [label + description] [₹ value]
  Widget _buildPayLine(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required double value,
    required String description,
    bool highlight = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Icon on the left
          Icon(
            icon,
            size: 20,
            color: highlight
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 12),

          // Label and description in the middle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // ₹ value on the right
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: highlight ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
