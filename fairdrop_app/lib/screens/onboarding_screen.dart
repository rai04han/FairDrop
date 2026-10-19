// ============================================================================
// FairDrop — Onboarding Screen
// Based on Stitch Design Project #1184075210986276795 (Page 1 of 4, etc.)
// ============================================================================
// FR-46: 4-slide onboarding explaining pay transparency, statutory floor,
// 7-day notice commitment, and required safety/dignity checklist.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final Map<String, bool> _checklist = {
    'I have read the FairDrop upfront pay formula policy': false,
    'I understand rate card changes require 7 days advance notice': false,
    'My vehicle is roadworthy, insured, and has valid PUC': false,
    'I hold a valid two-wheeler driving licence': false,
    'I will wear my helmet and obey traffic rules at all times': false,
    'I understand I can decline any order with zero penalty': false,
  };

  bool get _allChecked => _checklist.values.every((v) => v);

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/rider-home');
    }
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToFinal() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Brand Header ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const FairDropLogo(fontSize: 26),
                  if (_currentPage < 3)
                    TextButton(
                      onPressed: _skipToFinal,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.plusJakartaSans(
                          color: FairDropColors.slateMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Page View Body ───────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _buildSlide(
                    icon: Icons.payments_rounded,
                    iconColor: FairDropColors.brandGreen,
                    title: 'Transparent\nEarnings',
                    subtitle:
                        'See your exact pay before you accept. No surprises, no hidden deductions, and no cliff bonuses.',
                    badge: '100% Upfront Breakdown',
                  ),
                  _buildSlide(
                    icon: Icons.shield_rounded,
                    iconColor: FairDropColors.brandOrange,
                    title: 'Kerala Minimum\nWage Guarantee',
                    subtitle:
                        'Automatic wage top-ups ensure your hourly compensation never drops below the Kerala statutory floor.',
                    badge: 'Guaranteed Safety Net',
                  ),
                  _buildSlide(
                    icon: Icons.notifications_active_rounded,
                    iconColor: FairDropColors.payWait,
                    title: '7-Day Notice\nCommitment',
                    subtitle:
                        'Any revision to base rates, km rates, or incentives is locked with a mandatory 7-day advance notice.',
                    badge: 'No Secret Algorithm Changes',
                  ),
                  _buildChecklistSlide(),
                ],
              ),
            ),

            // ── Bottom Section with Dots & Action Buttons ───────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 4 Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final isActive = _currentPage == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? FairDropColors.brandGreen : const Color(0xFFDCE4EC),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  if (_currentPage < 3) ...[
                    FilledButton(
                      onPressed: _nextPage,
                      style: FilledButton.styleFrom(
                        backgroundColor: FairDropColors.brandGreen,
                        minimumSize: const Size.fromHeight(54),
                        shape: const StadiumBorder(),
                        elevation: 3,
                        shadowColor: FairDropColors.brandGreen.withValues(alpha: 0.3),
                      ),
                      child: Text(
                        'Next',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ] else ...[
                    FilledButton(
                      onPressed: _allChecked ? _completeOnboarding : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: FairDropColors.brandGreen,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        minimumSize: const Size.fromHeight(54),
                        shape: const StadiumBorder(),
                        elevation: _allChecked ? 3 : 0,
                      ),
                      child: Text(
                        'Start Riding With Dignity',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _allChecked ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 72, color: iconColor),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: FairDropColors.mintBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FairDropColors.mintBorder),
            ),
            child: Text(
              badge,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FairDropColors.brandGreen,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: FairDropColors.brandNavy,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: FairDropColors.slateMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: FairDropColors.brandOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'MANDATORY STEP (FR-46)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: FairDropColors.brandOrange,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Safety & Fairwork Checklist',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: FairDropColors.brandNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please verify all 6 requirements before accepting your first delivery.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: FairDropColors.slateMuted,
            ),
          ),
          const SizedBox(height: 16),
          ..._checklist.keys.map((item) {
            final isChecked = _checklist[item] ?? false;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isChecked ? FairDropColors.mintBg : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isChecked ? FairDropColors.brandGreen : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: CheckboxListTile(
                value: isChecked,
                activeColor: FairDropColors.brandGreen,
                checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                title: Text(
                  item,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                onChanged: (val) {
                  setState(() => _checklist[item] = val ?? false);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
