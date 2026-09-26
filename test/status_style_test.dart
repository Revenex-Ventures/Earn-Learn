import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/design_system/app_colors.dart';
import 'package:earn_and_learn/core/design_system/status_style.dart';
import 'package:earn_and_learn/core/models/models.dart';

void main() {
  group('StatusTone -> color mapping', () {
    test('neutral maps to slate', () {
      expect(styleFor(StatusTone.neutral, icon: Icons.circle, label: 'x').color,
          AppColors.slate);
    });

    test('positive maps to sage', () {
      expect(styleFor(StatusTone.positive, icon: Icons.circle, label: 'x').color,
          AppColors.sage);
    });

    test('attention maps to marigold', () {
      expect(
          styleFor(StatusTone.attention, icon: Icons.circle, label: 'x').color,
          AppColors.marigold);
    });

    test('negative maps to clay', () {
      expect(styleFor(StatusTone.negative, icon: Icons.circle, label: 'x').color,
          AppColors.clay);
    });
  });

  group('enum -> StatusStyle extensions', () {
    test('attendance statuses carry labels and icons', () {
      expect(AttendanceStatus.present.style.label, 'Present');
      expect(AttendanceStatus.present.style.icon, Icons.check_circle);
      expect(AttendanceStatus.scheduled.style.color, AppColors.slate);
      expect(AttendanceStatus.absent.style.icon, Icons.cancel);
    });

    test('approval approved is positive', () {
      expect(ApprovalStatus.approved.style.color, AppColors.sage);
      expect(ApprovalStatus.approved.style.icon, Icons.verified);
      expect(ApprovalStatus.pending.style.icon, Icons.hourglass_top);
      expect(ApprovalStatus.flagged.style.color, AppColors.clay);
    });

    test('assignment statuses map sensibly', () {
      expect(AssignmentStatus.active.style.color, AppColors.sage);
      expect(AssignmentStatus.temporary.style.color, AppColors.marigold);
      expect(AssignmentStatus.completed.style.label, 'Completed');
    });

    test('shift states map to tones', () {
      expect(ShiftState.completed.style.color, AppColors.sage);
      expect(ShiftState.working.style.color, AppColors.marigold);
      expect(ShiftState.missed.style.color, AppColors.clay);
      expect(ShiftState.offDay.style.color, AppColors.slate);
    });

    test('location, payment, calendar, supervisor statuses', () {
      expect(LocationStatus.attention.style.icon,
          Icons.notification_important);
      expect(PaymentStatus.paid.style.icon, Icons.payments);
      expect(PaymentStatus.held.style.color, AppColors.clay);
      expect(CalendarEventType.festival.style.icon, Icons.celebration);
      expect(SupervisorStatus.onDuty.style.label, 'On duty');
    });
  });
}