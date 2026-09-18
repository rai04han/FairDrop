// ============================================================================
// FairDrop — Login / Register Screen
// ============================================================================
// Owner: Hari (25MCA025)
//
// Supports both login and registration with role selection.
// On success, stores JWT token and navigates to the appropriate dashboard.

import 'package:flutter/material.dart';
import '../services/core_api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers hold the text the user types in each field
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;          // Toggle between login and register
  bool _isLoading = false;       // Show spinner during API call
  String? _errorMessage;         // Show error from server
  String _selectedRole = 'customer';  // Default role for registration

  final List<Map<String, dynamic>> _roles = [
    {'value': 'customer', 'label': 'Customer', 'icon': Icons.person},
    {'value': 'rider', 'label': 'Rider', 'icon': Icons.delivery_dining},
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

      // Navigate to home after successful login/register
      Navigator.pushReplacementNamed(context, '/');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLogin
              ? 'Welcome back, ${result['user']['name']}!'
              : 'Account created! Welcome, ${result['user']['name']}!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.body['message'] ?? 'Something went wrong';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Cannot connect to server. Is it running on port 3003?';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo ────────────────────────────────────────────
                    Icon(
                      Icons.delivery_dining,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'FairDrop',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Fair pay for every delivery',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ── Login / Register Toggle ────────────────────────
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Login')),
                        ButtonSegment(value: false, label: Text('Register')),
                      ],
                      selected: {_isLogin},
                      onSelectionChanged: (selected) {
                        setState(() {
                          _isLogin = selected.first;
                          _errorMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Name field (register only) ─────────────────────
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Name is required'
                                : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Email field ─────────────────────────────────────
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
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

                    // ── Password field ──────────────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.length < 4
                              ? 'Password must be at least 4 characters'
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Role selector (register only) ──────────────────
                    if (!_isLogin) ...[
                      Text(
                        'Select Role',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _roles.map((role) {
                          final isSelected = _selectedRole == role['value'];
                          return ChoiceChip(
                            avatar: Icon(
                              role['icon'] as IconData,
                              size: 18,
                              color: isSelected ? colorScheme.onPrimary : null,
                            ),
                            label: Text(role['label'] as String),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedRole = role['value'] as String);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Error message ──────────────────────────────────
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: colorScheme.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Submit button ──────────────────────────────────
                    FilledButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isLogin ? 'Login' : 'Create Account',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),

                    const SizedBox(height: 24),

                    // ── Seed data hint ──────────────────────────────────
                    if (_isLogin)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Demo Accounts',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'admin@fairdrop.in • ajith@fairdrop.in\nhari@fairdrop.in • arun@fairdrop.in\nPassword: password123',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
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
