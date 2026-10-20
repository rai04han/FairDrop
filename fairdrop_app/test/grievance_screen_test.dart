// ============================================================================
// FairDrop — Grievance Screen Widget Tests (Screen 24, FR-50)
// ============================================================================
// PRD Feature: FR-50 (Grievance / Feedback form posting to core-service)
// Fairwork Principles: Fair Management P2 (Worker Voice & Appeal Mechanism)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairdrop_app/screens/grievance_screen.dart';
import 'package:fairdrop_app/screens/profile_screen.dart';

void main() {
  group('GrievanceScreen Widget Tests (Screen 24, FR-50)', () {
    // ── Test 1: Renders all grievance form elements and Fairwork notices ─────
    testWidgets('Renders all fields, categories and Fairwork SLA guarantees', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: GrievanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Help & Grievance'), findsOneWidget);
      expect(find.textContaining('Fairwork Fair Management (Principle 2)'), findsOneWidget);
      expect(find.text('Issue Category'), findsOneWidget);
      expect(find.byKey(const Key('grievance_category_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('grievance_order_id_field')), findsOneWidget);
      expect(find.byKey(const Key('grievance_subject_field')), findsOneWidget);
      expect(find.byKey(const Key('grievance_description_field')), findsOneWidget);
      expect(find.text('48-Hour Human SLA Guarantee'), findsOneWidget);
      expect(find.text('Non-Retaliation Protection'), findsOneWidget);
      expect(find.byKey(const Key('grievance_submit_button')), findsOneWidget);
    });

    // ── Test 2: Validates empty required fields ─────────────────────────────
    testWidgets('Shows validation errors when required fields are empty', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: GrievanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('grievance_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please provide a subject summary'), findsOneWidget);
      expect(find.text('Please describe the issue in detail'), findsOneWidget);
    });

    // ── Test 3: Submits grievance successfully and shows Case ID dialog ──────
    testWidgets('Submits grievance with data and shows Case ID reference dialog (FR-50)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Map<String, dynamic>? submittedPayload;

      await tester.pumpWidget(
        MaterialApp(
          home: GrievanceScreen(
            initialCategory: 'Wait Time Compensation',
            initialOrderId: 'ORD-KL02-8877',
            initialSubject: 'Excess wait time at Grand Malabar',
            initialDescription: 'Waited 22 minutes at the kitchen counter; only 5 minutes were auto-credited.',
            onSubmitGrievance: ({
              required String category,
              String? orderId,
              required String subject,
              required String description,
            }) async {
              submittedPayload = {
                'category': category,
                'order_id': orderId,
                'subject': subject,
                'description': description,
              };
              return {
                'success': true,
                'case_id': 'GRV-990088',
                'message': 'Grievance submitted successfully.',
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('grievance_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify payload
      expect(submittedPayload, isNotNull);
      expect(submittedPayload!['category'], 'Wait Time Compensation');
      expect(submittedPayload!['order_id'], 'ORD-KL02-8877');
      expect(submittedPayload!['subject'], 'Excess wait time at Grand Malabar');
      expect(submittedPayload!['description'], 'Waited 22 minutes at the kitchen counter; only 5 minutes were auto-credited.');

      // Verify success dialog
      expect(find.text('Grievance Lodged'), findsOneWidget);
      expect(find.text('GRV-990088'), findsOneWidget);
      expect(find.text('Resolution SLA: Within 48 hours. You will receive an SMS and email notification.'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byKey(const Key('grievance_done_button')));
      await tester.pumpAndSettle();
      expect(find.text('Grievance Lodged'), findsNothing);
    });

    // ── Test 4: Handles submission errors gracefully ────────────────────────
    testWidgets('Displays error banner when server submission fails', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: GrievanceScreen(
            initialSubject: 'GPS routing penalty',
            initialDescription: 'App miscalculated distance around Kollam beach.',
            onSubmitGrievance: ({
              required String category,
              String? orderId,
              required String subject,
              required String description,
            }) async {
              throw Exception('Grievance service temporarily unavailable');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('grievance_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Grievance service temporarily unavailable'), findsOneWidget);
      expect(find.text('Grievance Lodged'), findsNothing);
    });

    // ── Test 5: ProfileScreen navigation to /grievance ──────────────────────
    testWidgets('ProfileScreen navigates to /grievance on Help & Grievance tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool navigatedToGrievance = false;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => const ProfileScreen(
                  initialUser: {
                    'name': 'Rahul Nair',
                    'email': 'rahul.rider@fairdrop.in',
                    'phone': '+91 94471 23456',
                    'role': 'rider',
                  },
                  autoFetch: false,
                ),
            '/grievance': (context) {
              navigatedToGrievance = true;
              return const Scaffold(body: Text('Grievance Screen Mock'));
            },
          },
        ),
      );
      await tester.pumpAndSettle();

      final grievanceTile = find.text('Help & Grievance');
      expect(grievanceTile, findsOneWidget);

      await tester.ensureVisible(grievanceTile);
      await tester.tap(grievanceTile);
      await tester.pumpAndSettle();

      expect(navigatedToGrievance, isTrue);
      expect(find.text('Grievance Screen Mock'), findsOneWidget);
    });
  });
}
