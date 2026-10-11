// ============================================================================
// FairDrop — Onboarding Screen
// ============================================================================
// Owner: Shared
// PRD FR-46 (P1)
//
// FR-46: Shows pay policy, 7-day notice commitment, safety checklist.
//        Rider must check all items before proceeding to rider home.
//
// Shown after first login for rider accounts. After completion, stores
// a flag so it's not shown again.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Safety checklist items — all must be checked (FR-46)
  final Map<String, bool> _checklist = {
    'I have read the FairDrop pay policy (base rate, distance pay, surge, floor)': false,
    'I understand pay changes require 7 days advance notice': false,
    'My vehicle is roadworthy and insured': false,
    'I have a valid driving licence': false,
    'I will follow traffic rules at all times': false,
    'I understand I can decline any order without penalty': false,
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
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Page indicator ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('FairDrop Onboarding',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Row(
                    children: List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _currentPage == i ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? cs.primary : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )),
                  ),
                ],
              ),
            ),

            // ── Page content ───────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _currentPage = p),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPayPolicyPage(theme, cs),
                  _buildNoticeCommitmentPage(theme, cs),
                  _buildSafetyChecklistPage(theme, cs),
                ],
              ),
            ),

            // ── Navigation buttons ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton.icon(
                      onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_currentPage < 2)
                    FilledButton.icon(
                      onPressed: _nextPage,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Next'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _allChecked ? _completeOnboarding : null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Get Started'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Pay Policy ─────────────────────────────────────────────────────
  Widget _buildPayPolicyPage(ThemeData theme, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.receipt_long, size: 40, color: cs.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text('Pay Policy', style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'FairDrop pays you transparently for every delivery. '
            'Here\'s exactly how your earnings are calculated:',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          ...[
            ('Base Rate', '₹15 per delivery — guaranteed for every completed delivery.', Icons.attach_money),
            ('Distance Pay', '₹6 per km — distance measured from restaurant to drop-off.', Icons.route),
            ('Surge Bonus', '₹20 flat during lunch (12–2pm) and dinner (7–9pm) peak hours.', Icons.flash_on),
            ('Wait Compensation', '₹10 flat if you wait > 10 minutes at the restaurant.', Icons.timer),
            ('Earnings Floor', '₹70/hr minimum wage protection — any shortfall is topped up automatically.', Icons.shield),
          ].map((item) => _policyItem(theme, cs, item.$1, item.$2, item.$3)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb, color: cs.onPrimaryContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All pay constants are admin-configurable. You\'ll be notified '
                    '7 days before any changes take effect.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyItem(ThemeData t, ColorScheme cs, String title, String desc,
      IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(desc,
                      style: t.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Page 2: 7-day Notice Commitment ───────────────────────────────────────
  Widget _buildNoticeCommitmentPage(ThemeData theme, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child:
                  Icon(Icons.calendar_today, size: 40, color: cs.secondary),
            ),
          ),
          const SizedBox(height: 20),
          Text('7-Day Advance Notice',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'FairDrop follows the Fairwork Fair Contracts principle '
            '(Principle 6). This means:',
            style:
                theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          ...[
            'Any change to pay rates, bonus structures, or working conditions will be communicated to you at least 7 days before taking effect.',
            'The reason for every pay change is documented and visible to you.',
            'You will see an "Upcoming Pay Change" notice on your home screen when a change is scheduled.',
            'You can view the history of all past pay configurations in the app.',
          ].map((text) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(text, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              )),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Commitment',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  'By continuing, you acknowledge that you have been informed '
                  'of FairDrop\'s pay transparency and 7-day notice policy.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 3: Safety Checklist ───────────────────────────────────────────────
  Widget _buildSafetyChecklistPage(ThemeData theme, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.verified_user, size: 40,
                  color: Colors.green),
            ),
          ),
          const SizedBox(height: 20),
          Text('Safety Checklist',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Please confirm all of the following before you start accepting orders. '
            'All items must be checked.',
            style:
                theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ..._checklist.keys.map((item) => CheckboxListTile(
                value: _checklist[item],
                onChanged: (v) =>
                    setState(() => _checklist[item] = v ?? false),
                title: Text(item, style: theme.textTheme.bodyMedium),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              )),
          const SizedBox(height: 12),
          if (!_allChecked)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please check all items to proceed.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
