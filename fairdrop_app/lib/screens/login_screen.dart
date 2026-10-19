// ============================================================================
// FairDrop — Login / Register Screen
// Based on Stitch Design Project #1184075210986276795
// ============================================================================
// Supports login and registration with role selection.
// Designed with outdoor glanceability, clear typography, and pay transparency guarantee.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../services/core_api_service.dart';
import '../services/exceptions.dart';
import '../utils/role_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'rider@fairdrop.in');
  final _passwordController = TextEditingController(text: 'secret123');
  final _nameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String _selectedRole = 'rider';

  final List<Map<String, dynamic>> _roles = [
    {'value': 'rider', 'label': 'Rider', 'icon': Icons.delivery_dining},
    {'value': 'customer', 'label': 'Customer', 'icon': Icons.person},
    {'value': 'restaurant', 'label': 'Restaurant', 'icon': Icons.restaurant},
    {'value': 'admin', 'label': 'Admin', 'icon': Icons.admin_panel_settings},
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> result;

      if (_isLogin) {
        result = await CoreApiService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        result = await CoreApiService.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
        );
      }

      if (!mounted) return;

      final role = result['user']['role'] as String;
      final isNewUser = !_isLogin;

      final prefs = await SharedPreferences.getInstance();
      final onboarded = !isNewUser && (prefs.getBool('onboarding_complete') ?? false);
      final route = RoleRouter.getRouteForRole(role, isOnboarded: onboarded);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLogin
              ? 'Welcome back, ${result['user']['name']}!'
              : 'Account created! Welcome, ${result['user']['name']}!'),
          backgroundColor: FairDropColors.brandGreen,
        ),
      );
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Cannot connect to server. Is it running on port 3003?';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // ── Brand Wordmark ───────────────────────────────────────
                    const Center(
                      child: FairDropLogo(fontSize: 36),
                    ),
                    const SizedBox(height: 28),

                    // ── Header Title ─────────────────────────────────────────
                    Text(
                      _isLogin ? 'Welcome back' : 'Join FairDrop',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: FairDropColors.brandNavy,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? 'Sign in to access your transparent pay ledger'
                          : 'Create your worker equity account in seconds',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: FairDropColors.slateMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // ── Login / Register Pill Switcher ───────────────────────
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: FairDropColors.mintBg,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: FairDropColors.mintBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!_isLogin) {
                                  setState(() {
                                    _isLogin = true;
                                    _errorMessage = null;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isLogin ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: _isLogin
                                      ? [
                                          BoxShadow(
                                            color: FairDropColors.brandNavy.withValues(alpha: 0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'Log in',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: _isLogin ? FontWeight.w800 : FontWeight.w600,
                                    color: _isLogin
                                        ? FairDropColors.brandGreen
                                        : FairDropColors.slateMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/rider-signup');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Text(
                                  'Register',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: FairDropColors.slateMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Full Name Field (Register mode only) ─────────────────
                    if (!_isLogin) ...[
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
                          hintText: 'e.g. John Doe',
                          prefixIcon: const Icon(Icons.person_outline, color: FairDropColors.brandGreen),
                          fillColor: FairDropColors.mintBg.withValues(alpha: 0.3),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

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
                        hintText: 'rider@fairdrop.in',
                        prefixIcon: const Icon(Icons.mail_outline, color: FairDropColors.brandGreen),
                        fillColor: FairDropColors.mintBg.withValues(alpha: 0.3),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) return 'Enter a valid email';
                        return null;
                      },
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
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline, color: FairDropColors.brandGreen),
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

                    // ── Role Selector (Register only) ────────────────────────
                    if (!_isLogin) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Select Your Role',
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
                        children: _roles.map((role) {
                          final isSelected = _selectedRole == role['value'];
                          return ChoiceChip(
                            avatar: Icon(
                              role['icon'] as IconData,
                              size: 18,
                              color: isSelected ? Colors.white : FairDropColors.brandNavy,
                            ),
                            label: Text(
                              role['label'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isSelected ? Colors.white : FairDropColors.brandNavy,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: FairDropColors.brandGreen,
                            backgroundColor: FairDropColors.mintBg,
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: isSelected ? FairDropColors.brandGreen : FairDropColors.mintBorder,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedRole = role['value'] as String);
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    // ── Inline Error Message ─────────────────────────────────
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: FairDropColors.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FairDropColors.errorRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: FairDropColors.errorRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.plusJakartaSans(
                                  color: FairDropColors.errorRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Primary Action Button ────────────────────────────────
                    FilledButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: FairDropColors.brandGreen,
                        minimumSize: const Size.fromHeight(54),
                        shape: const StadiumBorder(),
                        elevation: 3,
                        shadowColor: FairDropColors.brandGreen.withValues(alpha: 0.35),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isLogin ? 'Log in' : 'Create Account',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),

                    const SizedBox(height: 18),

                    // ── Link to Dedicated Rider Signup (FR-51) ───────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'New delivery worker? ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: FairDropColors.slateMuted,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/rider-signup'),
                          child: Text(
                            'Sign up as Rider',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: FairDropColors.brandGreen,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Fairness Guarantee Banner (Stitch Spec) ─────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FairDropColors.mintBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: FairDropColors.mintBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: FairDropColors.brandGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your pay formula is shown before every order.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: FairDropColors.brandGreen,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
