// ============================================================================
// FairDrop — Grievance & Dispute Resolution Screen (Screen 24, FR-50)
// ============================================================================
// PRD Feature: FR-50 (Grievance / Feedback form posting to core-service)
// Fairwork Principles: Fair Management P2 (Worker Voice & Appeal Mechanism)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/core_api_service.dart';

class GrievanceScreen extends StatefulWidget {
  final Future<Map<String, dynamic>> Function({
    required String category,
    String? orderId,
    required String subject,
    required String description,
  })? onSubmitGrievance;
  final String? initialCategory;
  final String? initialOrderId;
  final String? initialSubject;
  final String? initialDescription;

  const GrievanceScreen({
    super.key,
    this.onSubmitGrievance,
    this.initialCategory,
    this.initialOrderId,
    this.initialSubject,
    this.initialDescription,
  });

  @override
  State<GrievanceScreen> createState() => _GrievanceScreenState();
}

class _GrievanceScreenState extends State<GrievanceScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedCategory;
  late final TextEditingController _orderIdController;
  late final TextEditingController _subjectController;
  late final TextEditingController _descriptionController;

  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> categories = [
    'Pay Discrepancy (Minimum Wage / Distance)',
    'Wait Time Compensation',
    'Out-of-Zone / GPS Routing',
    'Safety & Equipment Concern',
    'App Bug / Technical Issue',
    'General Feedback',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? categories.first;
    _orderIdController = TextEditingController(text: widget.initialOrderId ?? '');
    _subjectController = TextEditingController(text: widget.initialSubject ?? '');
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final category = _selectedCategory;
      final orderId = _orderIdController.text.trim();
      final subject = _subjectController.text.trim();
      final description = _descriptionController.text.trim();

      Map<String, dynamic> result;
      if (widget.onSubmitGrievance != null) {
        result = await widget.onSubmitGrievance!(
          category: category,
          orderId: orderId.isNotEmpty ? orderId : null,
          subject: subject,
          description: description,
        );
      } else {
        result = await CoreApiService.submitGrievance(
          category: category,
          orderId: orderId.isNotEmpty ? orderId : null,
          subject: subject,
          description: description,
        );
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        final caseId = result['case_id'] ??
            result['grievance']?['case_id'] ??
            'GRV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

        _showSuccessDialog(caseId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _showSuccessDialog(String caseId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: FairDropColors.brandGreen, size: 28),
            const SizedBox(width: 10),
            Text(
              'Grievance Lodged',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: FairDropColors.brandNavy,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your grievance has been safely logged with human operations review.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: FairDropColors.mintBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FairDropColors.brandGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 20, color: FairDropColors.brandGreen),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CASE REFERENCE ID',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: FairDropColors.brandGreen),
                      ),
                      Text(
                        caseId,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: FairDropColors.brandNavy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Resolution SLA: Within 48 hours. You will receive an SMS and email notification.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          FilledButton(
            key: const Key('grievance_done_button'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              minimumSize: Size.zero,
              backgroundColor: FairDropColors.brandGreen,
              shape: const StadiumBorder(),
            ),
            child: const Text('Return to Profile'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: FairDropColors.brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Grievance',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: FairDropColors.brandNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Fairwork Principle 2 Banner ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.security_rounded, color: Color(0xFF1D4ED8), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fairwork Fair Management (Principle 2)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Direct dispute channel with human operations review. Zero algorithmic deactivation penalties for lodging an appeal or reporting pay discrepancies.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                height: 1.4,
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Error Banner if any ──────────────────────────────────────
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Category Dropdown Field ──────────────────────────────────
                Text(
                  'Issue Category',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: const Key('grievance_category_dropdown'),
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  items: categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(
                        cat,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // ── Optional Order ID ────────────────────────────────────────
                Text(
                  'Related Order ID (Optional)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('grievance_order_id_field'),
                  controller: _orderIdController,
                  decoration: InputDecoration(
                    hintText: 'e.g., ORD-KL02-9901',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Subject Field ───────────────────────────────────────────
                Text(
                  'Subject / Summary *',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('grievance_subject_field'),
                  controller: _subjectController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a subject summary';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Brief summary of the issue',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Description Field ───────────────────────────────────────
                Text(
                  'Detailed Description *',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FairDropColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('grievance_description_field'),
                  controller: _descriptionController,
                  maxLines: 5,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please describe the issue in detail';
                    }
                    if (val.trim().length < 10) {
                      return 'Description should be at least 10 characters';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Provide complete details (e.g. order circumstances, wait times, timestamps, etc.)...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    contentPadding: const EdgeInsets.all(14),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Fairwork Commitments Checklist ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _slaItem(Icons.timelapse_rounded, '48-Hour Human SLA Guarantee', 'Reviewed by a dedicated operations lead.'),
                      const SizedBox(height: 8),
                      _slaItem(Icons.verified_user_outlined, 'Non-Retaliation Protection', 'Your account rating and shift dispatch are safe.'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Submit Button ───────────────────────────────────────────
                FilledButton(
                  key: const Key('grievance_submit_button'),
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: FilledButton.styleFrom(
                    backgroundColor: FairDropColors.brandNavy,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Submit Grievance',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slaItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: FairDropColors.brandGreen, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FairDropColors.brandNavy,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: FairDropColors.slateMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
