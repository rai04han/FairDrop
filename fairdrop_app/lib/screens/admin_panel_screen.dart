// ============================================================================
// FairDrop — Admin Panel Screen (Screen 20)
// ============================================================================
// Owner: Raihan (25MCA044)
// PRD Features: FR-38 (Active Config Read), FR-39 (Config History & Audit Trail),
//               FR-40 to FR-42 (Pay Revision & 7-Day Rule),
//               FR-43 (Client-side Numeric Validation),
//               FR-44 (Old → New Diff Comparison Confirmation Dialog),
//               FR-45 (Audit Trail & Status Refresh)
// Fairwork Principles: Fair Contracts P3 (7-day advance notice & recorded reasons),
//                      Fair Pay P1 & P2 (Living wage floor & transparent rates)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/core_api_service.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class AdminPanelScreen extends StatefulWidget {
  final Map<String, dynamic>? initialConfig;
  final List<Map<String, dynamic>>? initialHistory;
  final DateTime? initialEffectiveDate;
  final bool autoFetch;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> params)? onUpdateConfig;

  const AdminPanelScreen({
    super.key,
    this.initialConfig,
    this.initialHistory,
    this.initialEffectiveDate,
    this.autoFetch = true,
    this.onUpdateConfig,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  // ── State Variables ─────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isUpdating = false;

  Map<String, dynamic>? _currentConfig;
  List<Map<String, dynamic>> _configHistory = [];

  String? _errorMessage;
  String? _successMessage;

  // Selected future effective date (must be ≥ today + 7 days)
  DateTime? _selectedEffectiveDate;

  final _formKey = GlobalKey<FormState>();

  // ── Form Controllers ────────────────────────────────────────────────────────
  final _baseRateController = TextEditingController();
  final _perKmRateController = TextEditingController();
  final _surgeBonusController = TextEditingController();
  final _waitThresholdController = TextEditingController();
  final _waitCompController = TextEditingController();
  final _minWageController = TextEditingController();
  final _changeReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialEffectiveDate != null) {
      _selectedEffectiveDate = widget.initialEffectiveDate;
    }
    if (widget.initialConfig != null || widget.initialHistory != null) {
      _applyLoadedData(widget.initialConfig, widget.initialHistory ?? []);
    } else if (widget.autoFetch) {
      _loadData();
    } else {
      _isLoading = false;
    }
  }

  void _applyLoadedData(Map<String, dynamic>? config, List<dynamic> rawHistory) {
    if (config != null) {
      _baseRateController.text = _formatValue(config['base_rate']);
      _perKmRateController.text = _formatValue(config['per_km_rate']);
      _surgeBonusController.text = _formatValue(config['surge_bonus']);
      _waitThresholdController.text = config['wait_threshold_mins'].toString();
      _waitCompController.text = _formatValue(config['wait_compensation']);
      _minWageController.text = _formatValue(config['min_wage_per_hour']);
    }

    setState(() {
      _currentConfig = config;
      _configHistory = rawHistory.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _isLoading = false;
    });
  }

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

  // ── Fetch Active Config & History Concurrently (FR-38, FR-39) ───────────────
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getPayConfig(),
        ApiService.getConfigHistory(),
      ]);

      final activeData = results[0];
      final historyData = results[1];

      final config = activeData['config'] as Map<String, dynamic>?;
      final rawHistory = historyData['history'] as List<dynamic>? ?? [];

      _applyLoadedData(config, rawHistory);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.body['message'] ?? 'Failed to load configuration';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed. Is the pay-service running on port 3001?\n$e';
        _isLoading = false;
      });
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return '0';
    final doubleVal = double.tryParse(value.toString()) ?? 0;
    if (doubleVal == doubleVal.toInt().toDouble()) {
      return doubleVal.toInt().toString();
    }
    return doubleVal.toStringAsFixed(2);
  }

  // ── Client-side Validation & Show Diff Modal (FR-43, FR-44) ─────────────────
  void _handleInitiateUpdate() {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Effective date validation (FR-41)
    if (_selectedEffectiveDate == null) {
      setState(() {
        _errorMessage = 'Please select an effective-from date (min 7 days notice required)';
      });
      return;
    }

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final selectedMidnight = DateTime(
      _selectedEffectiveDate!.year,
      _selectedEffectiveDate!.month,
      _selectedEffectiveDate!.day,
    );
    final daysDifference = selectedMidnight.difference(todayMidnight).inDays;

    if (daysDifference < 7) {
      setState(() {
        _errorMessage = 'Effective date must be at least 7 full days from today. '
            'Selected date is only $daysDifference days ahead.';
      });
      return;
    }

    _showDiffConfirmationDialog(daysDifference);
  }

  // ── Old → New Diff Confirmation Dialog (FR-44) ──────────────────────────────
  void _showDiffConfirmationDialog(int noticeDays) {
    final oldBase = double.tryParse(_currentConfig?['base_rate']?.toString() ?? '0') ?? 0;
    final newBase = double.tryParse(_baseRateController.text) ?? 0;

    final oldPerKm = double.tryParse(_currentConfig?['per_km_rate']?.toString() ?? '0') ?? 0;
    final newPerKm = double.tryParse(_perKmRateController.text) ?? 0;

    final oldSurge = double.tryParse(_currentConfig?['surge_bonus']?.toString() ?? '0') ?? 0;
    final newSurge = double.tryParse(_surgeBonusController.text) ?? 0;

    final oldWaitThreshold = int.tryParse(_currentConfig?['wait_threshold_mins']?.toString() ?? '0') ?? 0;
    final newWaitThreshold = int.tryParse(_waitThresholdController.text) ?? 0;

    final oldWaitComp = double.tryParse(_currentConfig?['wait_compensation']?.toString() ?? '0') ?? 0;
    final newWaitComp = double.tryParse(_waitCompController.text) ?? 0;

    final oldMinWage = double.tryParse(_currentConfig?['min_wage_per_hour']?.toString() ?? '0') ?? 0;
    final newMinWage = double.tryParse(_minWageController.text) ?? 0;

    final diffItems = [
      _DiffItem('Base Rate', '₹${oldBase.toStringAsFixed(2)}', '₹${newBase.toStringAsFixed(2)}', oldBase != newBase),
      _DiffItem('Per-Km Rate', '₹${oldPerKm.toStringAsFixed(2)}/km', '₹${newPerKm.toStringAsFixed(2)}/km', oldPerKm != newPerKm),
      _DiffItem('Surge Bonus', '₹${oldSurge.toStringAsFixed(2)}', '₹${newSurge.toStringAsFixed(2)}', oldSurge != newSurge),
      _DiffItem('Wait Threshold', '$oldWaitThreshold min', '$newWaitThreshold min', oldWaitThreshold != newWaitThreshold),
      _DiffItem('Wait Comp', '₹${oldWaitComp.toStringAsFixed(2)}', '₹${newWaitComp.toStringAsFixed(2)}', oldWaitComp != newWaitComp),
      _DiffItem('Min Wage Floor', '₹${oldMinWage.toStringAsFixed(2)}/hr', '₹${newMinWage.toStringAsFixed(2)}/hr', oldMinWage != newMinWage),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('admin_diff_dialog'),
        icon: const Icon(Icons.compare_arrows, color: FairDropColors.brandGreen, size: 32),
        title: const Text(
          'Confirm Pay Structure Revision',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statutory Notice Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FairDropColors.mintBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: FairDropColors.mintBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: FairDropColors.brandGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '7-Day Advance Notice: $noticeDays days scheduled (Fairwork Principle 3 Compliant)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: FairDropColors.brandGreenDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Comparison (Current vs. Proposed):',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),

                // Diff Table (FR-44)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: diffItems.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: item.isChanged ? Colors.amber.shade50 : Colors.transparent,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: item.isChanged ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.oldValue,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  decoration: item.isChanged ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.newValue,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: item.isChanged ? FairDropColors.brandGreen : FairDropColors.brandNavy,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isChanged ? Colors.amber.shade100 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.isChanged ? 'CHANGED' : 'Same',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: item.isChanged ? Colors.brown.shade800 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'Effective From: ${_selectedEffectiveDate!.day.toString().padLeft(2, '0')}/'
                  '${_selectedEffectiveDate!.month.toString().padLeft(2, '0')}/'
                  '${_selectedEffectiveDate!.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  'Reason: "${_changeReasonController.text.trim()}"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: Size.zero),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: const Key('admin_confirm_diff_button'),
            style: FilledButton.styleFrom(
              minimumSize: Size.zero,
              backgroundColor: FairDropColors.brandGreen,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _executeConfigUpdate();
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirm & Schedule'),
          ),
        ],
      ),
    );
  }

  // ── Execute Server PUT Request (FR-40–FR-42) ────────────────────────────────
  Future<void> _executeConfigUpdate() async {
    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final effectiveDateStr = '${_selectedEffectiveDate!.year}-'
          '${_selectedEffectiveDate!.month.toString().padLeft(2, "0")}-'
          '${_selectedEffectiveDate!.day.toString().padLeft(2, "0")}';

      final Map<String, dynamic> response;
      if (widget.onUpdateConfig != null) {
        response = await widget.onUpdateConfig!({
          'base_rate': double.parse(_baseRateController.text),
          'per_km_rate': double.parse(_perKmRateController.text),
          'surge_bonus': double.parse(_surgeBonusController.text),
          'wait_threshold_mins': int.parse(_waitThresholdController.text),
          'wait_compensation': double.parse(_waitCompController.text),
          'min_wage_per_hour': double.parse(_minWageController.text),
          'effective_from': effectiveDateStr,
          'change_reason': _changeReasonController.text.trim(),
        });
      } else {
        response = await ApiService.updatePayConfig(
          baseRate: double.parse(_baseRateController.text),
          perKmRate: double.parse(_perKmRateController.text),
          surgeBonus: double.parse(_surgeBonusController.text),
          waitThresholdMins: int.parse(_waitThresholdController.text),
          waitCompensation: double.parse(_waitCompController.text),
          minWagePerHour: double.parse(_minWageController.text),
          effectiveFrom: effectiveDateStr,
          changeReason: _changeReasonController.text.trim(),
        );
      }

      setState(() {
        _successMessage = 'Pay configuration revision successfully scheduled!\n'
            'Notice: ${response['notice'] ?? 'Effective from $effectiveDateStr.'}';
        _isUpdating = false;
        _changeReasonController.clear();
        _selectedEffectiveDate = null;
      });

      // Reload active config & history table (FR-45)
      if (widget.autoFetch) {
        await _loadData();
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.body['message'] ?? 'Failed to update configuration';
        _isUpdating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving pay revision: $e';
        _isUpdating = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Log Out',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to log out of Admin Panel?',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            key: const Key('btn_cancel_admin_logout'),
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: Size.zero),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('btn_confirm_admin_logout'),
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              minimumSize: Size.zero,
              backgroundColor: FairDropColors.errorRed,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CoreApiService.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  // ── Main Build Method ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Admin Panel — Pay Governance', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: FairDropColors.brandNavy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            key: const Key('btn_reload_admin_config'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload configs',
            onPressed: _isLoading ? null : _loadData,
          ),
          IconButton(
            key: const Key('btn_admin_logout'),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Status Banners ─────────────────────────────────────────
                    if (_successMessage != null)
                      _buildAlertBanner(
                        icon: Icons.check_circle,
                        color: Colors.green,
                        message: _successMessage!,
                      ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      _buildAlertBanner(
                        icon: Icons.error_outline,
                        color: Colors.red,
                        message: _errorMessage!,
                      ),
                    ],
                    const SizedBox(height: 12),

                    // ── Active Configuration Card (FR-38) ──────────────────────
                    if (_currentConfig != null) _buildActiveConfigCard(theme),
                    const SizedBox(height: 16),

                    // ── Edit & Revision Form (FR-40–FR-43) ─────────────────────
                    _buildRevisionFormCard(theme),
                    const SizedBox(height: 24),

                    // ── Configuration History & Audit Trail (FR-39) ────────────
                    _buildHistorySection(theme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAlertBanner({required IconData icon, required Color color, required String message}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Active Configuration Card (FR-38) ───────────────────────────────────────
  Widget _buildActiveConfigCard(ThemeData theme) {
    final effectiveStr = _currentConfig!['effective_from']?.toString().split('T').first ?? 'N/A';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: FairDropColors.brandGreen, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Currently Active Configuration',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FairDropColors.mintBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FairDropColors.mintBorder),
                  ),
                  child: Text(
                    'Config #${_currentConfig!['config_id']}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: FairDropColors.brandGreenDark,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildMetricChip('Base Pay', '₹${_formatValue(_currentConfig!['base_rate'])}'),
                _buildMetricChip('Distance', '₹${_formatValue(_currentConfig!['per_km_rate'])}/km'),
                _buildMetricChip('Surge', '₹${_formatValue(_currentConfig!['surge_bonus'])}'),
                _buildMetricChip('FairDrop Incentive', '₹${_formatValue(_currentConfig!['incentive_per_order'] ?? 17.04)}'),
                _buildMetricChip('Wait Threshold', '${_currentConfig!['wait_threshold_mins']} min'),
                _buildMetricChip('Wait Comp', '₹${_formatValue(_currentConfig!['wait_compensation'])}'),
                _buildMetricChip('Statutory Floor', '₹${_formatValue(_currentConfig!['min_wage_per_hour'])}/hr'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Effective Since: $effectiveStr  •  Created by: ${_currentConfig!['created_by'] ?? 'admin'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (_currentConfig!['change_reason'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Reason: "${_currentConfig!['change_reason']}"',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Revision Form (FR-40–FR-43) ─────────────────────────────────────────────
  Widget _buildRevisionFormCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_calendar, color: FairDropColors.brandOrange),
                  const SizedBox(width: 8),
                  Text(
                    'Propose Pay Structure Revision',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Per Fairwork Principle 3 (Fair Contracts), revisions require a documented reason and at least 7 days advance notice.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Divider(height: 24),

              // Form inputs with client-side numeric validation (FR-43)
              Row(
                children: [
                  Expanded(
                    child: _buildValidatedField(
                      key: const Key('admin_base_rate_field'),
                      controller: _baseRateController,
                      label: 'Base Rate (₹)',
                      icon: Icons.attach_money,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null) return 'Invalid number';
                        if (num <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildValidatedField(
                      key: const Key('admin_per_km_rate_field'),
                      controller: _perKmRateController,
                      label: 'Per-Km Rate (₹/km)',
                      icon: Icons.route,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null) return 'Invalid number';
                        if (num < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildValidatedField(
                      key: const Key('admin_surge_bonus_field'),
                      controller: _surgeBonusController,
                      label: 'Surge Bonus (₹ flat)',
                      icon: Icons.flash_on,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null) return 'Invalid number';
                        if (num < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildValidatedField(
                      key: const Key('admin_wait_threshold_field'),
                      controller: _waitThresholdController,
                      label: 'Wait Threshold (whole mins)',
                      icon: Icons.timer,
                      isInteger: true,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = int.tryParse(val);
                        if (num == null) return 'Must be whole integer';
                        if (num < 1) return 'Must be ≥ 1 min';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildValidatedField(
                      key: const Key('admin_wait_comp_field'),
                      controller: _waitCompController,
                      label: 'Wait Comp (₹ flat)',
                      icon: Icons.hourglass_bottom,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null) return 'Invalid number';
                        if (num < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildValidatedField(
                      key: const Key('admin_min_wage_field'),
                      controller: _minWageController,
                      label: 'Min Wage Floor (₹/hr)',
                      icon: Icons.shield,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null) return 'Invalid number';
                        if (num <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mandatory Change Reason (FR-42)
              TextFormField(
                key: const Key('admin_change_reason_field'),
                controller: _changeReasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mandatory Change Reason / Justification *',
                  hintText: 'e.g. Annual inflation wage adjustment under Kerala Gig Policy',
                  prefixIcon: Icon(Icons.rate_review),
                  border: OutlineInputBorder(),
                  helperText: 'Recorded in audit trail (Fairwork Principle 3)',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Change reason is mandatory for audit trail compliance.';
                  }
                  if (val.trim().length < 5) {
                    return 'Please provide a descriptive reason (at least 5 characters).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Effective Date Picker (FR-41)
              InkWell(
                key: const Key('admin_effective_date_picker'),
                onTap: () async {
                  final earliestAllowed = DateTime.now().add(const Duration(days: 7));
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedEffectiveDate ?? earliestAllowed,
                    firstDate: earliestAllowed,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    helpText: 'Select effective date (≥ 7 days notice)',
                  );
                  if (picked != null) {
                    setState(() => _selectedEffectiveDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Effective From Date (Min 7-Day Advance Notice) *',
                    prefixIcon: Icon(Icons.calendar_month),
                    border: OutlineInputBorder(),
                    helperText: 'Workers receive automatic notice once scheduled.',
                  ),
                  child: Text(
                    _selectedEffectiveDate != null
                        ? '${_selectedEffectiveDate!.day.toString().padLeft(2, '0')}/'
                          '${_selectedEffectiveDate!.month.toString().padLeft(2, '0')}/'
                          '${_selectedEffectiveDate!.year}'
                        : 'Tap to select date (minimum 7 days ahead)',
                    style: TextStyle(
                      fontWeight: _selectedEffectiveDate != null ? FontWeight.bold : FontWeight.normal,
                      color: _selectedEffectiveDate != null ? FairDropColors.brandNavy : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Submit Button
              FilledButton.icon(
                key: const Key('admin_update_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: FairDropColors.brandNavy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _isUpdating ? null : _handleInitiateUpdate,
                icon: _isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.preview),
                label: Text(
                  _isUpdating ? 'Scheduling Revision...' : 'Review & Confirm Pay Revision (Diff)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidatedField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool isInteger = false,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: isInteger
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: validator,
    );
  }

  // ── Configuration History & Audit Trail (FR-39) ─────────────────────────────
  Widget _buildHistorySection(ThemeData theme) {
    return Column(
      key: const Key('admin_config_history_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: FairDropColors.brandNavy),
            const SizedBox(width: 8),
            Text(
              'Configuration History & Audit Trail',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: FairDropColors.brandNavy,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_configHistory.length} records',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_configHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text('No configuration history available.'),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _configHistory.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (ctx, index) {
              final item = _configHistory[index];
              final configId = item['config_id'];
              final effectiveDate = item['effective_from']?.toString().split('T').first ?? '';
              final reason = item['change_reason'] ?? 'N/A';
              final author = item['created_by'] ?? 'admin';

              // Determine lifecycle state: SCHEDULED vs ACTIVE vs SUPERSEDED
              final now = DateTime.now();
              final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              final isScheduled = effectiveDate.compareTo(todayStr) > 0;
              final isActive = _currentConfig != null && _currentConfig!['config_id'] == configId;

              Color statusColor = Colors.grey;
              String statusText = 'SUPERSEDED';

              if (isScheduled) {
                statusColor = Colors.indigo;
                statusText = 'SCHEDULED';
              } else if (isActive) {
                statusColor = FairDropColors.brandGreen;
                statusText = 'ACTIVE';
              }

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Config #$configId',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Effective: $effectiveDate',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reason: "$reason"',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          Text('Base: ₹${_formatValue(item['base_rate'])}', style: const TextStyle(fontSize: 11)),
                          Text('•  Per-Km: ₹${_formatValue(item['per_km_rate'])}', style: const TextStyle(fontSize: 11)),
                          Text('•  Wait: ${item['wait_threshold_mins']}m/₹${_formatValue(item['wait_compensation'])}', style: const TextStyle(fontSize: 11)),
                          Text('•  Floor: ₹${_formatValue(item['min_wage_per_hour'])}/hr', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Logged by: $author',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _DiffItem {
  final String label;
  final String oldValue;
  final String newValue;
  final bool isChanged;

  _DiffItem(this.label, this.oldValue, this.newValue, this.isChanged);
}
