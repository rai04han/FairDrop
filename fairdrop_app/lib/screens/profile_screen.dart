// ============================================================================
// FairDrop — Profile Screen
// ============================================================================
// Owner: Hari (25MCA025)
// PRD FR-47, FR-48 (P1)
//
// FR-47: Profile shows name, zone, vehicle type, link to policy summary
// FR-48: "Upcoming pay change" notice if a scheduled config exists
// ============================================================================

import 'package:flutter/material.dart';
import '../services/core_api_service.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _upcomingConfig;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Load user profile from core-service
      final meData = await CoreApiService.getMe();
      final user = meData['user'] as Map<String, dynamic>? ?? meData;

      // Load upcoming config from pay-service (FR-48)
      Map<String, dynamic>? upcoming;
      try {
        final historyData = await ApiService.getConfigHistory();
        final configs = historyData['configs'] as List<dynamic>? ?? [];
        // Find scheduled (future) config
        final now = DateTime.now();
        for (final c in configs) {
          final effDate = DateTime.tryParse(c['effective_from']?.toString() ?? '');
          if (effDate != null && effDate.isAfter(now)) {
            upcoming = c as Map<String, dynamic>;
            break;
          }
        }
      } catch (_) {
        // Non-critical — upcoming config notice is optional
      }

      setState(() {
        _user = user;
        _upcomingConfig = upcoming;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load profile.';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await CoreApiService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: cs.error),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Upcoming pay change notice (FR-48) ─────────────
                      if (_upcomingConfig != null) ...[
                        _buildUpcomingNotice(theme, cs),
                        const SizedBox(height: 16),
                      ],

                      // ── Avatar + name ───────────────────────────────────
                      _buildAvatarSection(theme, cs),
                      const SizedBox(height: 16),

                      // ── Profile details ─────────────────────────────────
                      _buildProfileCard(theme, cs),
                      const SizedBox(height: 16),

                      // ── Pay policy link ─────────────────────────────────
                      _buildPolicySection(theme, cs),
                      const SizedBox(height: 16),

                      // ── Quick links ─────────────────────────────────────
                      _buildQuickLinks(theme, cs),
                      const SizedBox(height: 24),

                      // ── Logout ──────────────────────────────────────────
                      OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ── Upcoming pay change notice (FR-48) ─────────────────────────────────────
  Widget _buildUpcomingNotice(ThemeData theme, ColorScheme cs) {
    final effDate = _upcomingConfig!['effective_from']?.toString() ?? '';
    final reason = _upcomingConfig!['change_reason']?.toString() ?? 'See admin for details';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        border: Border.all(color: Colors.amber.shade600),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming Pay Change',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Effective from: $effDate\nReason: $reason',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────
  Widget _buildAvatarSection(ThemeData theme, ColorScheme cs) {
    final name = _user?['name'] as String? ?? 'Rider';
    final email = _user?['email'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'R';

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: cs.primaryContainer,
          child: Text(
            initial,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(name,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text(email,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  // ── Profile details card ───────────────────────────────────────────────────
  Widget _buildProfileCard(ThemeData theme, ColorScheme cs) {
    final profile = _user?['rider_profile'] as Map<String, dynamic>? ?? {};
    final zone = profile['current_zone'] as String? ?? 'Not assigned';
    final vehicle = profile['vehicle_type'] as String? ?? 'Not specified';
    final activeHours =
        (profile['active_hours_today'] as num?)?.toStringAsFixed(1) ?? '0.0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _profileRow(theme, Icons.badge, 'Role',
                (_user?['role'] as String? ?? 'rider').toUpperCase()),
            _profileRow(theme, Icons.location_on, 'Current Zone', zone),
            _profileRow(theme, Icons.two_wheeler, 'Vehicle', vehicle),
            _profileRow(theme, Icons.schedule, 'Active Today', '$activeHours hrs'),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(ThemeData t, IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: t.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  Text(value,
                      style: t.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Pay policy section ─────────────────────────────────────────────────────
  Widget _buildPolicySection(ThemeData theme, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.policy, color: cs.primary),
                const SizedBox(width: 8),
                Text('Pay Policy Summary',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            ...[
              ('Base Rate', '₹15 per delivery'),
              ('Per Km Rate', '₹6 per km'),
              ('Surge Bonus', '₹20 flat (peak hours)'),
              ('Wait Compensation', '₹10 flat (if wait > 10 min)'),
              ('Earnings Floor', '₹70/hr minimum wage protection'),
              ('Notice Period', '7 days advance notice for changes'),
            ].map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.$1,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      Text(item.$2,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ── Quick links ────────────────────────────────────────────────────────────
  Widget _buildQuickLinks(ThemeData theme, ColorScheme cs) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.bar_chart, color: cs.primary),
          title: const Text('My Dashboard'),
          trailing: const Icon(Icons.chevron_right),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: cs.surfaceContainerLow,
          onTap: () => Navigator.pushNamed(context, '/rider-dashboard'),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.map_outlined, color: cs.primary),
          title: const Text('Zone Map'),
          trailing: const Icon(Icons.chevron_right),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: cs.surfaceContainerLow,
          onTap: () => Navigator.pushNamed(context, '/zone-map'),
        ),
      ],
    );
  }
}
