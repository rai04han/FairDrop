// ============================================================================
// FairDrop — Profile Screen
// Based on Stitch Design Project #1184075210986276795
// (FairDrop Rider Profile)
// ============================================================================
// PRD FR-47, FR-48:
// - Profile shows rider name, verified status, active shift toggle
// - Floating key metrics: Deliveries, Avg earnings, Active status
// - Upcoming pay change notice with 7-day advance countdown
// - Account navigation list: Personal Info, Vehicle, Guarantees, Policy, Grievance
// - Secure logout
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
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
  final bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final meData = await CoreApiService.getMe();
      final user = meData['user'] as Map<String, dynamic>? ?? meData;

      Map<String, dynamic>? upcoming;
      try {
        final historyData = await ApiService.getConfigHistory();
        final configs = historyData['configs'] as List<dynamic>? ?? [];
        final now = DateTime.now();
        for (final c in configs) {
          final effDate = DateTime.tryParse(c['effective_from']?.toString() ?? '');
          if (effDate != null && effDate.isAfter(now)) {
            upcoming = c as Map<String, dynamic>;
            break;
          }
        }
      } catch (_) {
        // Optional
      }

      setState(() {
        _user = user;
        _upcomingConfig = upcoming;
        _isLoading = false;
      });
    } catch (_) {
      // Offline fallback
      setState(() {
        _user = {
          'name': 'John M.',
          'email': 'rider@fairdrop.in',
          'phone': '+91 98765 43210',
          'role': 'rider',
          'zone': 'Kollam Central (KL-02)',
          'vehicle': 'Electric Scooter (KL-02-AB-1234)',
        };
        _isLoading = false;
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
          'Are you sure you want to end your shift and log out of FairDrop?',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: FairDropColors.errorRed),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CoreApiService.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showPolicyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FairDrop Pay Policy',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),
            _policyItem('Base Fare', '₹15.00 fixed starting baseline for all orders in Kollam.'),
            _policyItem('Metered Distance', '₹6.00 to ₹10.00/km GPS-verified travel compensation.'),
            _policyItem('Excess Wait Pay', '₹1.00 to ₹5.00/min compensated after 10 mins restaurant wait.'),
            _policyItem('Monsoon Surge', '100% of collected client surge goes directly to the active rider.'),
            _policyItem('Kerala Wage Floor', 'Guaranteed minimum ₹70–₹150/hr statutory floor top-up.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: FairDropColors.brandGreen,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Understood'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _policyItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: FairDropColors.brandGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(color: FairDropColors.brandNavy, fontSize: 13),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['name'] as String? ?? 'John M.';
    final phone = _user?['phone'] as String? ?? '+91 98765 43210';

    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: FairDropColors.brandGreen))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Header Banner (Stitch Spec: Deep Emerald Green #16804B) ──
                    Container(
                      color: FairDropColors.brandGreen,
                      padding: const EdgeInsets.only(top: 12, bottom: 44, left: 20, right: 20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              ),
                              Text(
                                'Rider Profile',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                onPressed: _loadProfile,
                                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Driver Avatar & Name
                          Row(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 33,
                                      backgroundColor: FairDropColors.mintBg,
                                      child: const Icon(
                                        Icons.sports_motorsports_rounded,
                                        size: 40,
                                        color: FairDropColors.brandGreen,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: _isActive ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      phone,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Verified Partner',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
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

                    // ── Floating Key Metrics Card (Stitch Spec) ──────────────
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: FairDropColors.cardShadow,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildMetricItem('32', 'Deliveries'),
                              ),
                              Container(height: 36, width: 1, color: const Color(0xFFF1F5F9)),
                              Expanded(
                                child: _buildMetricItem('₹68/hr', 'Avg earnings'),
                              ),
                              Container(height: 36, width: 1, color: const Color(0xFFF1F5F9)),
                              Expanded(
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _isActive ? 'Active' : 'Offline',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: _isActive ? const Color(0xFF059669) : FairDropColors.slateMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Shift Status',
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
                        ),
                      ),
                    ),

                    // ── Upcoming 7-Day Notice Alert (FR-48) ──────────────────
                    if (_upcomingConfig != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: FairDropColors.brandOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: FairDropColors.brandOrange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.announcement_rounded, color: FairDropColors.brandOrange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Scheduled Rate Card Update',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: FairDropColors.brandOrange,
                                      ),
                                    ),
                                    Text(
                                      'Effective in 7 days. Kerala statutory floor guarantees intact.',
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
                        ),
                      ),

                    // ── Account Navigation Menu (Stitch Spec) ────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account & Guarantees',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: FairDropColors.brandNavy,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: FairDropColors.cardShadow,
                            ),
                            child: Column(
                              children: [
                                _buildMenuItem(
                                  icon: Icons.person_outline_rounded,
                                  title: 'Personal Information',
                                  subtitle: name,
                                  onTap: () {},
                                ),
                                const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                                _buildMenuItem(
                                  icon: Icons.two_wheeler_rounded,
                                  title: 'Vehicle Details',
                                  subtitle: 'EV Scooter (KL-02)',
                                  onTap: () {},
                                ),
                                const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                                _buildMenuItem(
                                  icon: Icons.verified_user_outlined,
                                  title: 'Wage Guarantees & Rate Card',
                                  subtitle: 'Kerala Fairwork Charter Rates',
                                  onTap: _showPolicyDialog,
                                ),
                                const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                                _buildMenuItem(
                                  icon: Icons.shield_outlined,
                                  title: 'Safety & Insurance',
                                  subtitle: 'Accident & Health Covered',
                                  onTap: () {},
                                ),
                                const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                                _buildMenuItem(
                                  icon: Icons.description_outlined,
                                  title: 'Pay Policy & 7-Day Notices',
                                  subtitle: 'Published Formulas',
                                  onTap: _showPolicyDialog,
                                ),
                                const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                                _buildMenuItem(
                                  icon: Icons.help_outline_rounded,
                                  title: 'Help & Grievance',
                                  subtitle: 'Direct Dispute Resolution',
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Log Out Button
                          OutlinedButton.icon(
                            onPressed: _logout,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              minimumSize: const Size.fromHeight(50),
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.logout_rounded, color: FairDropColors.errorRed, size: 18),
                            label: Text(
                              'Log Out',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: FairDropColors.errorRed,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMetricItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: FairDropColors.brandNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: FairDropColors.slateMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: FairDropColors.mintBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: FairDropColors.brandGreen, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: FairDropColors.brandNavy,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: FairDropColors.slateMuted,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
    );
  }
}
