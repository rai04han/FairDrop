// ============================================================================
// FairDrop — Rider Signup Screen (Screen 3, FR-51, FR-52, FR-53)
// ============================================================================
// Dedicated onboarding signup for delivery riders.
// Strictly collects name, email, password, and vehicle type.
// No role or zone selector — backend auto-assigns the zone with fewest riders.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/core_api_service.dart';
import '../services/exceptions.dart';
import '../utils/role_router.dart';

class RiderSignupScreen extends StatefulWidget {
  const RiderSignupScreen({super.key});

  @override
  State<RiderSignupScreen> createState() => _RiderSignupScreenState();
}

class _RiderSignupScreenState extends State<RiderSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedVehicle = 'motorcycle';
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _vehicleOptions = const [
    {
      'value': 'motorcycle',
      'label': 'Motorcycle',
      'icon': Icons.two_wheeler_rounded,
    },
    {
      'value': 'scooter',
      'label': 'Scooter',
      'icon': Icons.moped_rounded,
    },
    {
      'value': 'ev',
      'label': 'Electric Vehicle',
      'icon': Icons.electric_moped_rounded,
    },
    {
      'value': 'bicycle',
      'label': 'Bicycle',
      'icon': Icons.pedal_bike_rounded,
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await CoreApiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: 'rider', // FR-51: Always creates a rider account
        vehicleType: _selectedVehicle,
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;

      final assignedZone = result['user']?['rider_profile']?['assigned_zone_code'] ?? 'Kollam';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created! Welcome to FairDrop, ${_nameController.text.trim()}! Zone: $assignedZone'),
          backgroundColor: FairDropColors.brandGreen,
        ),
      );

      // FR-53: Navigate to Onboarding after successful signup
      final targetRoute = RoleRouter.getRouteForRole('rider', isOnboarded: false);
      Navigator.pushReplacementNamed(context, targetRoute);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Cannot connect to server. Is core-service running on port 3003?';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: FairDropColors.brandNavy, size: 20),
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
        title: const FairDropLogo(fontSize: 22),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ───────────────────────────────────────────────
                    Text(
                      'Rider Registration',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandNavy,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join FairDrop to earn with transparent, formula-based pay and zero cliff-bonus penalties.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: FairDropColors.slateMuted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // ── Error Banner ─────────────────────────────────────────
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Full Name Field ──────────────────────────────────────
                    Text(
                      'Full Name',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FairDropColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        color: FairDropColors.brandNavy,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Arun Kumar',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: FairDropColors.brandGreen),
                        fillColor: FairDropColors.mintBg.withValues(alpha: 0.3),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Email Field ──────────────────────────────────────────
                    Text(
                      'Email Address',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FairDropColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        color: FairDropColors.brandNavy,
                      ),
                      decoration: InputDecoration(
                        hintText: 'arun@fairdrop.in',
                        prefixIcon: const Icon(Icons.mail_outline_rounded, color: FairDropColors.brandGreen),
                        fillColor: FairDropColors.mintBg.withValues(alpha: 0.3),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Email is required';
                        if (!value.contains('@')) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Phone Number Field ───────────────────────────────────
                    Text(
                      'Phone Number',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FairDropColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        color: FairDropColors.brandNavy,
                      ),
                      decoration: InputDecoration(
                        hintText: '+91 98765 43210',
                        prefixIcon: const Icon(Icons.phone_outlined, color: FairDropColors.brandGreen),
                        fillColor: FairDropColors.mintBg.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Password Field ───────────────────────────────────────
                    Text(
                      'Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FairDropColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        color: FairDropColors.brandNavy,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Minimum 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: FairDropColors.brandGreen),
                        fillColor: FairDropColors.mintBg.withValues(alpha: 0.3),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: FairDropColors.slateMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.length < 4 ? 'Password must be at least 4 characters' : null,
                    ),
                    const SizedBox(height: 20),

                    // ── Vehicle Type Selection ───────────────────────────────
                    Text(
                      'Vehicle Type',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FairDropColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _vehicleOptions.map((opt) {
                        final isSelected = _selectedVehicle == opt['value'];
                        return ChoiceChip(
                          avatar: Icon(
                            opt['icon'] as IconData,
                            size: 18,
                            color: isSelected ? Colors.white : FairDropColors.brandNavy,
                          ),
                          label: Text(
                            opt['label'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : FairDropColors.brandNavy,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: FairDropColors.brandGreen,
                          backgroundColor: FairDropColors.mintBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? FairDropColors.brandGreen : FairDropColors.mintBorder,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedVehicle = opt['value'] as String);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ── Automatic Zone Notice (FR-52) ────────────────────────
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
                          const Icon(Icons.info_outline_rounded, color: FairDropColors.brandGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automatic Zone Assignment (FR-52)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: FairDropColors.brandNavy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'FairDrop automatically assigns you to the zone with the fewest active riders in Kollam to maintain supply balance and protect your hourly earnings.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: FairDropColors.slateMuted,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Submit Button ────────────────────────────────────────
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FairDropColors.brandGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'Create Rider Account',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // ── Link back to Login ───────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: FairDropColors.slateMuted,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                          child: Text(
                            'Log in',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: FairDropColors.brandGreen,
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
        ),
      ),
    );
  }
}
