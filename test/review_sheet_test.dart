import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/data/firebase/attendance_gateway.dart';
import 'package:earn_and_learn/domain/domain.dart';
import 'package:earn_and_learn/features/supervisor/review_sheet.dart';

VerificationItem _item() => VerificationItem(
      id: '2026-09-19',
      studentId: 'STU-9001',
      studentName: 'Synthetic Student One',
      location: 'Synthetic Test Location',
      type: VerificationType.checkOut,
      submittedAt: DateTime.utc(2026, 9, 19, 18, 0, 5),
      status: ApprovalStatus.pending,
      summary: 'Duty recorded — verify the check-out (selfie + GPS).',
    );

Future<void> _pump({
  required WidgetTester tester,
  required Future<ReviewResult> Function(ApprovalStatus, String?) onSubmit,
}) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ReviewSheet(item: _item(), onSubmit: onSubmit),
      ),
    ),
  ));
}

void main() {
  testWidgets('renders the item and submits an approval with the note',
      (tester) async {
    final decisions = <(ApprovalStatus, String?)>[];
    await _pump(
      tester: tester,
      onSubmit: (decision, note) async {
        decisions.add((decision, note));
        return ReviewResult(
          status: SessionStatus.approved,
          review: decision,
          note: note,
        );
      },
    );

    expect(find.text('Synthetic Student One'), findsOneWidget);
    expect(find.text('Check-out · Synthetic Test Location'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Note for the student (optional)'),
      'Evidence looks authentic',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(decisions, hasLength(1));
    expect(decisions.single.$1, ApprovalStatus.approved);
    expect(decisions.single.$2, 'Evidence looks authentic');
  });

  testWidgets('reject reaches the callback', (tester) async {
    final decisions = <(ApprovalStatus, String?)>[];
    await _pump(
      tester: tester,
      onSubmit: (decision, note) async {
        decisions.add((decision, note));
        return ReviewResult(
          status: SessionStatus.flagged,
          review: decision,
          note: note,
        );
      },
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(decisions.single.$1, ApprovalStatus.rejected);
  });

  testWidgets('flag reaches the callback', (tester) async {
    final decisions = <(ApprovalStatus, String?)>[];
    await _pump(
      tester: tester,
      onSubmit: (decision, note) async {
        decisions.add((decision, note));
        return ReviewResult(
          status: SessionStatus.flagged,
          review: decision,
          note: note,
        );
      },
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Flag'));
    await tester.pumpAndSettle();
    expect(decisions.single.$1, ApprovalStatus.flagged);
  });

  testWidgets('a failing submit surfaces a snackbar and stays open',
      (tester) async {
    await _pump(
      tester: tester,
      onSubmit: (_, _) async => throw const AttendanceFlowException(
        AttendanceFlowErrorKind.network,
        'offline',
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Review failed'), findsOneWidget);
    expect(find.text('Synthetic Student One'), findsOneWidget);
  });
}