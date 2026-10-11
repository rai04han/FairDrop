// ============================================================================
// FairDrop — Rider Home Screen
// ============================================================================
// Owner: Hari (25MCA025)
// PRD FR-7 to FR-10
//
// FR-7:  Online/Offline toggle → core-service records timestamps
// FR-8:  Polls for assigned order every 10s; assigned order → Order Acceptance
// FR-9:  Shows current zone name, today's earnings, floor indicator
// FR-10: When polled order arrives, navigates to Order Acceptance screen
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/core_api_service.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _isOnline = false;
  bool _isTogglingStatus = false;
  Timer? _pollTimer;

  // Today's stats
  double _todayEarnings = 0;
  double _activeHoursToday = 0;
  double _hourlyRate = 0;
  double _floorValue = 70.0; // Kerala minimum wage floor
  int _deliveriesToday = 0;
  String _currentZone = '—';

  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer = Timer.periodic(AppConfig.orderPollingInterval, (_) {
      if (_isOnline) _pollForOrder();
    });
  }

  /// FR-8: Poll core-service for an assigned order
  Future<void> _pollForOrder() async {
    try {
      final data = await CoreApiService.getRiderActiveOrder();
      final order = data['order'] as Map<String, dynamic>?;

      if (order != null && mounted) {
        // Stop polling and navigate to Order Acceptance
        _pollTimer?.cancel();
        if (context.mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/order-acceptance',
            arguments: order,
          );
        }
      }
    } catch (_) {
      // Silently ignore poll errors — don't interrupt the UI
    }
  }

  // ── Stats loading ─────────────────────────────────────────────────────────
  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      // Load rider's today stats from core-service
      final statsData = await CoreApiService.getTodayStats();
      final stats = statsData['stats'] as Map<String, dynamic>? ?? {};

      // Load floor value from pay-service config
      final configData = await ApiService.getPayConfig();
      final config = configData['config'] as Map<String, dynamic>? ?? {};

      setState(() {
        _todayEarnings = (stats['total_earnings_today'] as num?)?.toDouble() ?? 0;
        _activeHoursToday = (stats['active_hours_today'] as num?)?.toDouble() ?? 0;
        _deliveriesToday = (stats['deliveries_today'] as num?)?.toInt() ?? 0;
        _currentZone = stats['current_zone'] as String? ?? 'No zone assigned';
        _hourlyRate = _activeHoursToday > 0 ? _todayEarnings / _activeHoursToday : 0;
        _floorValue = double.tryParse(config['min_wage_per_hour']?.toString() ?? '70') ?? 70.0;
        _isLoadingStats = false;
      });
    } on ApiException catch (_) {
      setState(() {
        _isLoadingStats = false;
      });
    } catch (_) {
      // Stats load failure is non-critical — show with empty data
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  // ── Online/Offline toggle ─────────────────────────────────────────────────
  Future<void> _toggleOnlineStatus() async {
    setState(() => _isTogglingStatus = true);

    try {
      await CoreApiService.setRiderStatus(isOnline: !_isOnline);
      setState(() => _isOnline = !_isOnline);

      if (_isOnline) {
        // Immediately poll when going online
        _pollForOrder();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are now Online — accepting orders')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are now Offline')),
          );
        }
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
      if (mounted) setState(() => _isTogglingStatus = false);
    }
  }

  Future<void> _logout() async {
    _pollTimer?.cancel();
    await CoreApiService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FairDrop'),
        centerTitle: true,
        actions: [
          // Zone map shortcut
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Zone Map',
            onPressed: () => Navigator.pushNamed(context, '/zone-map'),
          ),
          // Dashboard shortcut
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'My Dashboard',
            onPressed: () => Navigator.pushNamed(context, '/rider-dashboard'),
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Online/Offline toggle card (FR-7) ──────────────────────
              _buildOnlineToggle(theme, colorScheme),
              const SizedBox(height: 16),

              // ── Today's stats (FR-9) ───────────────────────────────────
              if (_isLoadingStats)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                _buildStatsRow(theme, colorScheme),
                const SizedBox(height: 16),
                _buildFloorIndicator(theme, colorScheme),
                const SizedBox(height: 16),
                _buildZoneCard(theme, colorScheme),
              ],

              const SizedBox(height: 16),

              // ── Navigation shortcuts ───────────────────────────────────
              _buildQuickNav(theme),

              const SizedBox(height: 24),
              Text(
                'FairDrop v1.0.0 — MCA Mini Project 23MCAM307\nPolling for orders every ${AppConfig.orderPollingInterval.inSeconds}s when online.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Online toggle card ─────────────────────────────────────────────────────
  Widget _buildOnlineToggle(ThemeData theme, ColorScheme cs) {
    final isOnline = _isOnline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [cs.surfaceContainerHighest, cs.surfaceContainerHigh],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green : Colors.grey).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Status icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(isOnline),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isOnline ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? Colors.white : cs.onSurfaceVariant,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'You are Online' : 'You are Offline',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isOnline ? Colors.white : cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline
                      ? 'Waiting for orders…'
                      : 'Go online to receive delivery orders',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isOnline
                        ? Colors.white70
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Toggle switch
          _isTogglingStatus
              ? const SizedBox(
                  width: 40,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Switch(
                  value: isOnline,
                  onChanged: (_) => _toggleOnlineStatus(),
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.green.shade700,
                  inactiveThumbColor: cs.outline,
                ),
        ],
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            theme,
            icon: Icons.account_balance_wallet,
            label: "Today's Earnings",
            value: '₹${_todayEarnings.toStringAsFixed(2)}',
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            theme,
            icon: Icons.delivery_dining,
            label: 'Deliveries',
            value: '$_deliveriesToday',
            color: cs.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            theme,
            icon: Icons.access_time,
            label: 'Active Hrs',
            value: '${_activeHoursToday.toStringAsFixed(1)}h',
            color: cs.secondary,
          ),
        ),
      ],
    );
  }

  Widget _statCard(ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Floor indicator (FR-9) ─────────────────────────────────────────────────
  Widget _buildFloorIndicator(ThemeData theme, ColorScheme cs) {
    final aboveFloor = _hourlyRate >= _floorValue;
    final progress = (_hourlyRate / _floorValue).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: aboveFloor ? Colors.green : cs.error),
                const SizedBox(width: 8),
                Text(
                  'Earnings Floor Status',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: aboveFloor
                        ? Colors.green.withValues(alpha: 0.12)
                        : cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    aboveFloor ? 'ABOVE FLOOR' : 'BELOW FLOOR',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: aboveFloor ? Colors.green : cs.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${_hourlyRate.toStringAsFixed(2)}/hr',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: aboveFloor ? Colors.green : cs.error,
                  ),
                ),
                Text(
                  'Floor: ₹${_floorValue.toStringAsFixed(0)}/hr',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  aboveFloor ? Colors.green : cs.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Zone card (FR-9) ───────────────────────────────────────────────────────
  Widget _buildZoneCard(ThemeData theme, ColorScheme cs) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.location_on, color: cs.primary),
        title: const Text('Current Zone'),
        subtitle: Text(
          _currentZone,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/zone-map'),
          icon: const Icon(Icons.map, size: 16),
          label: const Text('View Map'),
        ),
      ),
    );
  }

  // ── Quick navigation ───────────────────────────────────────────────────────
  Widget _buildQuickNav(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Access', style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _navButton(
                theme,
                icon: Icons.bar_chart,
                label: 'Dashboard',
                onTap: () => Navigator.pushNamed(context, '/rider-dashboard'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _navButton(
                theme,
                icon: Icons.map_outlined,
                label: 'Zone Map',
                onTap: () => Navigator.pushNamed(context, '/zone-map'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _navButton(
                theme,
                icon: Icons.person_outline,
                label: 'Profile',
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _navButton(ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
