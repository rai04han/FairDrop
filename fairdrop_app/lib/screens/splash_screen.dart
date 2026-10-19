// ============================================================================
// FairDrop — Splash Screen
// Based on Stitch Design Project #1184075210986276795
// ============================================================================
// FR-1: Splash screen checks stored JWT → routes by role; expired → Login
// Modern high-contrast outdoor aesthetic with vibrant brand accents.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/core_api_service.dart';
import '../services/exceptions.dart';
import '../utils/role_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  bool _isChecking = true;
  String? _targetRoute;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _scaleAnim = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    // Check auth in background
    _checkAuth();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    try {
      final token = await CoreApiService.getToken();
      if (token == null) {
        _setTargetRoute('/login');
        return;
      }

      final me = await CoreApiService.getMe();
      final role = me['user']?['role'] as String? ??
          me['role'] as String? ?? 'unknown';

      final target = RoleRouter.getRouteForRole(role);
      _setTargetRoute(target);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await CoreApiService.logout();
      }
      _setTargetRoute('/login');
    } catch (_) {
      _setTargetRoute('/login');
    }
  }

  void _setTargetRoute(String route) {
    if (!mounted) return;
    setState(() {
      _targetRoute = route;
      _isChecking = false;
    });

    // Auto-advance after 1.8 seconds if the user doesn't press button
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _targetRoute != null) {
        _navigate(_targetRoute!);
      }
    });
  }

  void _navigate(String route) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  void _onGetStartedPressed() {
    if (_targetRoute != null) {
      _navigate(_targetRoute!);
    } else {
      _navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // ── Top Brandmark Header ────────────────────────────────
                  const FairDropLogo(
                    fontSize: 38,
                    showSubtitle: true,
                  ),

                  // ── Center Vector Art Container ────────────────────────
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: FairDropColors.mintBg,
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: FairDropColors.mintBorder.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: FairDropColors.brandGreen.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Graphic Delivery Scooter & Shield Icon
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: FairDropColors.brandNavy.withValues(alpha: 0.06),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.electric_moped_rounded,
                                  size: 84,
                                  color: FairDropColors.brandGreen,
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: FairDropColors.brandOrange,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: FairDropColors.mintBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: FairDropColors.brandGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '100% Upfront Pay Formula',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: FairDropColors.brandNavy,
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

                  // ── Bottom Action Footer ─────────────────────────────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: _onGetStartedPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FairDropColors.brandOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(58),
                          elevation: 4,
                          shadowColor: FairDropColors.brandOrange.withValues(alpha: 0.4),
                          shape: const StadiumBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_isChecking)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(Icons.arrow_forward_rounded, size: 22),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kerala Gig Worker Wage Protection • MCA Mini Project',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: FairDropColors.slateMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
