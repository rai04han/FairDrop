// ============================================================================
// FairDrop — Admin Panel Screen
// ============================================================================
// Owner: Raihan
// PRD Features: F-ADMIN-01 (Pay Config Management)
//               F-PAY-04 (7-day advance notice before pay structure change)
//
// PURPOSE:
//   This screen lets an admin:
//   1. VIEW the current pay configuration (base rate, per km rate, etc.)
//   2. UPDATE the config with new values
//   3. See the 7-day advance notice applied automatically
//
//   Every config change requires a REASON (audit trail — Fairwork P6).
//
// DATA FLOW:
//   Screen loads → GET /api/admin/pay-config → displays current config
//   Admin edits form → taps "Update" → confirmation dialog
//   → PUT /api/admin/pay-config → server enforces 7-day notice
//   → new config saved → success message with effective_from date
// ============================================================================

import 'package:flutter/material.dart';

// Import our API service to make HTTP calls to the Pay Engine
import '../services/api_service.dart';

// ============================================================================
// AdminPanelScreen — StatefulWidget
// ============================================================================
// StatefulWidget because:
//   - Config data loads from API on screen open (state changes)
//   - Admin edits form values (state changes)
//   - Loading spinner shows during API calls (state changes)
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  // ── State Variables ─────────────────────────────────────────────────────

  // Loading states — separate for initial load vs update
  bool _isLoadingConfig = true; // true on first load
  bool _isUpdating = false; // true while saving new config

  // Stores the current config from the server
  Map<String, dynamic>? _currentConfig;

  // Error and success messages
  String? _errorMessage;
  String? _successMessage;

  // ── Form Controllers ──────────────────────────────────────────────────
  // Each controller holds the value of one form field.
  // Initialized empty — filled with current values after API loads.

  final _baseRateController = TextEditingController();
  final _perKmRateController = TextEditingController();
  final _surgeBonusController = TextEditingController();
  final _waitThresholdController = TextEditingController();
  final _waitCompController = TextEditingController();
  final _minWageController = TextEditingController();
  final _changeReasonController = TextEditingController();

  // ── Lifecycle: initState() ────────────────────────────────────────────
  // initState() is called ONCE when this screen is first created.
  // We use it to load the current config from the server immediately.
  //
  // Think of it as: "do this setup work as soon as the screen appears."
  @override
  void initState() {
    super.initState(); // Always call super.initState() first
    _loadConfig(); // Fetch current config from server
  }

  // ── Lifecycle: dispose() ──────────────────────────────────────────────
  // Clean up all controllers to prevent memory leaks.
  @override
  void dispose() {
    _baseRateController.dispose();
    _perKmRateController.dispose();
    _surgeBonusController.dispose();
    _waitThresholdController.dispose();
    _waitCompController.dispose();
    _minWageController.dispose();
    _changeReasonController.dispose();
    super.dispose();
  }

  // ── API Call: _loadConfig() ───────────────────────────────────────────
  // Fetches the current active pay configuration from the server.
  // Called on screen load (initState) and after a successful update.
  Future<void> _loadConfig() async {
    setState(() {
      _isLoadingConfig = true;
      _errorMessage = null;
    });

    try {
      // GET /api/admin/pay-config
      final response = await ApiService.getPayConfig();
      final config = response['config'];

      // Fill form fields with current values from the server.
      // The server returns decimal strings like "15.00" — we display them as-is.
      _baseRateController.text = _formatValue(config['base_rate']);
      _perKmRateController.text = _formatValue(config['per_km_rate']);
      _surgeBonusController.text = _formatValue(config['surge_bonus']);
      _waitThresholdController.text = config['wait_threshold_mins'].toString();
      _waitCompController.text = _formatValue(config['wait_compensation']);
      _minWageController.text = _formatValue(config['min_wage_per_hour']);

      setState(() {
        _currentConfig = config;
        _isLoadingConfig = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.body['message'] ?? 'Failed to load config';
        _isLoadingConfig = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed. Is the server running?\n\n'
            'Start it with: cd pay-service && npm start\n\nError: $e';
        _isLoadingConfig = false;
      });
    }
  }

  // ── Helper: _formatValue() ────────────────────────────────────────────
  // MySQL returns decimals as strings ("15.00"). This helper removes
  // trailing zeros for cleaner display ("15.00" → "15", "6.50" → "6.5").
  String _formatValue(dynamic value) {
    if (value == null) return '0';
    final doubleVal = double.tryParse(value.toString()) ?? 0;
    // If it's a whole number, show without decimals
    if (doubleVal == doubleVal.toInt().toDouble()) {
      return doubleVal.toInt().toString();
    }
    return doubleVal.toString();
  }

  // ── API Call: _updateConfig() ─────────────────────────────────────────
  // Sends the new config values to the server.
  // Called after the user confirms the 7-day notice dialog.
  Future<void> _updateConfig() async {
    // Validate change reason is not empty
    if (_changeReasonController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Change reason is required (audit trail requirement)';
      });
      return;
    }

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // PUT /api/admin/pay-config
      final response = await ApiService.updatePayConfig(
        baseRate: double.tryParse(_baseRateController.text) ?? 0,
        perKmRate: double.tryParse(_perKmRateController.text) ?? 0,
        surgeBonus: double.tryParse(_surgeBonusController.text) ?? 0,
        waitThresholdMins:
            int.tryParse(_waitThresholdController.text) ?? 0,
        waitCompensation: double.tryParse(_waitCompController.text) ?? 0,
        minWagePerHour: double.tryParse(_minWageController.text) ?? 0,
        changeReason: _changeReasonController.text.trim(),
      );

      setState(() {
        _successMessage = '${response['message']}\n\n'
            'Effective from: ${response['effective_from']}\n'
            '${response['notice']}';
        _isUpdating = false;
      });

      // Clear the change reason field after successful update
      _changeReasonController.clear();

      // Reload config to show the updated values
      await _loadConfig();
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.body['message'] ?? 'Failed to update config';
        _isUpdating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed: $e';
        _isUpdating = false;
      });
    }
  }

  // ── Confirmation Dialog ───────────────────────────────────────────────
  // Shows a dialog confirming the 7-day advance notice policy
  // BEFORE sending the update to the server.
  //
  // This is Fairwork P6 (Fair Contracts): workers must receive advance
  // notice before pay structure changes take effect.
  void _showConfirmationDialog() {
    // Validate change reason first
    if (_changeReasonController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a change reason before updating';
      });
      return;
    }

    // showDialog() creates a modal popup that blocks interaction
    // with the screen behind it until dismissed.
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // Dialog icon
          icon: Icon(
            Icons.policy,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),

          // Dialog title
          title: const Text('7-Day Advance Notice'),

          // Dialog content — explains the policy
          content: Column(
            mainAxisSize: MainAxisSize.min, // Don't expand to full height
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Per Fairwork P6 (Fair Contracts), pay structure changes '
                'require 7 days advance notice to workers.',
              ),
              const SizedBox(height: 16),
              Text(
                'Change reason:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _changeReasonController.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New config will take effect 7 days from today',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Dialog buttons
          actions: [
            // Cancel button — closes dialog without doing anything
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),

            // Confirm button — closes dialog AND calls _updateConfig()
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close the dialog first
                _updateConfig(); // Then send the update
              },
              child: const Text('Confirm Update'),
            ),
          ],
        );
      },
    );
  }

  // ── Build the UI ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          // Refresh button in the app bar — reloads config from server
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingConfig ? null : _loadConfig,
            tooltip: 'Reload config',
          ),
        ],
      ),
      body: _isLoadingConfig
          // Show loading spinner while fetching config
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Success Message ──────────────────────────────────
                  if (_successMessage != null)
                    Card(
                      color: Colors.green.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style:
                                    const TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_successMessage != null) const SizedBox(height: 16),

                  // ── Error Message ────────────────────────────────────
                  if (_errorMessage != null)
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline,
                                color:
                                    theme.colorScheme.onErrorContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                    color: theme
                                        .colorScheme.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_errorMessage != null) const SizedBox(height: 16),

                  // ── Current Config Info ──────────────────────────────
                  if (_currentConfig != null) _buildConfigInfo(theme),

                  const SizedBox(height: 16),

                  // ── Config Edit Form ─────────────────────────────────
                  _buildConfigForm(theme),

                  const SizedBox(height: 16),

                  // ── Update Button ────────────────────────────────────
                  FilledButton.icon(
                    onPressed:
                        _isUpdating ? null : _showConfirmationDialog,
                    icon: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isUpdating
                        ? 'Updating...'
                        : 'Update Pay Config'),
                    style: FilledButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Policy Notice ────────────────────────────────────
                  Card(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.policy,
                              color:
                                  theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Fairwork P6: All pay config changes require '
                              '7-day advance notice and a documented reason.',
                              style:
                                  theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // CURRENT CONFIG INFO — Shows metadata about the active config
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildConfigInfo(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Active Configuration',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Config ID and creation info
            _buildInfoRow(
                theme, 'Config ID', '#${_currentConfig!['config_id']}'),
            _buildInfoRow(
                theme, 'Created by', _currentConfig!['created_by'] ?? 'system'),
            _buildInfoRow(theme, 'Change reason',
                _currentConfig!['change_reason'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  // ── Helper: _buildInfoRow ─────────────────────────────────────────────
  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONFIG EDIT FORM — Text fields for each pay constant
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildConfigForm(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pay Constants',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Base Rate ─────────────────────────────────────────────
            _buildConfigField(
              controller: _baseRateController,
              label: 'Base Rate (₹/delivery)',
              hint: 'Fixed amount per delivery',
              icon: Icons.attach_money,
            ),
            const SizedBox(height: 12),

            // ── Per Km Rate ───────────────────────────────────────────
            _buildConfigField(
              controller: _perKmRateController,
              label: 'Per Km Rate (₹/km)',
              hint: 'Distance-based pay',
              icon: Icons.route,
            ),
            const SizedBox(height: 12),

            // ── Surge Bonus ───────────────────────────────────────────
            _buildConfigField(
              controller: _surgeBonusController,
              label: 'Surge Bonus (₹ flat)',
              hint: 'Peak hour bonus',
              icon: Icons.flash_on,
            ),
            const SizedBox(height: 12),

            // ── Wait Threshold ────────────────────────────────────────
            _buildConfigField(
              controller: _waitThresholdController,
              label: 'Wait Threshold (minutes)',
              hint: 'Minutes before compensation kicks in',
              icon: Icons.timer,
            ),
            const SizedBox(height: 12),

            // ── Wait Compensation ─────────────────────────────────────
            _buildConfigField(
              controller: _waitCompController,
              label: 'Wait Compensation (₹ flat)',
              hint: 'Paid when wait exceeds threshold',
              icon: Icons.hourglass_bottom,
            ),
            const SizedBox(height: 12),

            // ── Minimum Wage ──────────────────────────────────────────
            _buildConfigField(
              controller: _minWageController,
              label: 'Minimum Wage Floor (₹/hr)',
              hint: 'Kerala minimum wage baseline',
              icon: Icons.shield,
            ),

            const Divider(height: 32),

            // ── Change Reason (mandatory) ─────────────────────────────
            // This field is REQUIRED — the server rejects updates without it.
            // It's stored in the pay_configs table for audit trail.
            TextField(
              controller: _changeReasonController,
              maxLines: 3, // Multiline for detailed reasons
              decoration: InputDecoration(
                labelText: 'Change Reason *',
                hintText: 'e.g., "Adjusted base rate for Q4 2026 review"',
                prefixIcon: const Icon(Icons.edit_note),
                border: const OutlineInputBorder(),
                // Red asterisk hint that this field is required
                helperText: 'Required — stored as audit trail (Fairwork P6)',
                helperStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper: _buildConfigField ─────────────────────────────────────────
  // Creates a number input field for a pay constant.
  // Extracted to avoid repeating the same TextField code 6 times.
  Widget _buildConfigField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
