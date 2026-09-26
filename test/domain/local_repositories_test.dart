import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/data/data.dart';
import 'package:earn_and_learn/domain/domain.dart';
import 'package:earn_and_learn/shared/mock_data/mock_data.dart';

void main() {
  group('local repositories (Stage 1B dev wiring)', () {
    test('student repository reads the workbook seed', () async {
      final repo = LocalStudentRepository(mockStudents);
      final first = await repo.byId('STU-001');
      expect(first, isNotNull);
      expect(first!.name, 'DHANWATE RUTUJA NITIN');
      expect(first.rollNumber, 'EL2627-001');
      expect(first.contact, isNull, reason: 'the sheet records no contact');
      expect(await repo.byUid('missing'), isNull);
      expect(await repo.all(), hasLength(68));
    });

    test('assignment repository returns the live assignment for a student',
        () async {
      final repo = LocalAssignmentRepository(mockAssignments);
      final assignment = await repo.forStudent('STU-001');
      expect(assignment, isNotNull);
      expect(assignment!.locationId, 'LOC-01');
      expect(assignment.locationName, 'Kalsubai Hostel (Old)');
      expect(assignment.supervisorId, 'SV-02');
      expect(assignment.plannedHoursPerDay, 3.0);
      expect(await repo.forStudent('STU-999'), isNull);
    });

    test('attendance repository returns today checkpoint and stores sessions',
        () async {
      final repo = LocalAttendanceRepository(goldenRecords: mockAttendance);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final record = await repo.recordForDay(
        studentId: mockCurrentStudent.id,
        day: today,
      );
      expect(record, isNotNull);
      expect(record!.date, today);

      final session = Session(
        id: 'SE-T',
        studentId: mockCurrentStudent.id,
        date: today,
        windows: const [
          ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20)),
        ],
        status: SessionStatus.approved,
        review: ApprovalStatus.approved,
        checkInVerifiedAt: DateTime(now.year, now.month, now.day, 17, 0),
        checkOutVerifiedAt: DateTime(now.year, now.month, now.day, 20, 0),
        verifiedHours: 3,
      );
      repo.submitSession(session);

      final dayRecord = await repo.recordForDay(
        studentId: mockCurrentStudent.id,
        day: today,
      );
      expect(dayRecord!.review, ApprovalStatus.approved);
    });

    test('account repository resolves the demo identity link', () async {
      final repo = LocalAccountRepository(user: mockStudentUser);
      expect((await repo.currentUser())!.uid, 'u-stu-001');

      final link = await repo.currentAccountLink();
      expect(link, isNotNull);
      expect(link!.role, UserRole.student);
      expect(link.entityId, 'STU-001');

      final resolution = resolveIdentity(
        user: mockStudentUser,
        students: mockStudents,
        supervisors: mockSupervisors,
        link: link,
      );
      expect(resolution.student!.id, 'STU-001');
    });

    test('verification and payroll repositories expose fixtures', () async {
      const verification = LocalVerificationRepository();
      expect(await verification.openCount(), mockOpenVerifications.length);

      const payroll = LocalPayrollRepository();
      final rollup = await payroll.currentMonth();
      expect(rollup!.studentCount, 68);
    });
  });

  group('provider wiring', () {
    test('providers resolve the dev implementations', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(accountRepositoryProvider), isA<AccountRepository>());
      expect(container.read(studentRepositoryProvider), isA<StudentRepository>());
      expect(container.read(assignmentRepositoryProvider),
          isA<AssignmentRepository>());
      expect(container.read(attendanceRepositoryProvider),
          isA<AttendanceRepository>());
      expect(container.read(calendarRepositoryProvider), isA<CalendarRepository>());
      expect(container.read(verificationRepositoryProvider),
          isA<VerificationRepository>());
      expect(container.read(payrollRepositoryProvider), isA<PayrollRepository>());
      expect(container.read(auditRepositoryProvider), isA<AuditRepository>());
      expect(container.read(leaveRepositoryProvider), isA<LeaveRepository>());
    });

    test('confirmed policy surfaces and unresolved rates stay null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final policy = container.read(policyConfigProvider);
      expect(policy.monthlyMaxHours, 40);
      expect(policy.defaultRatePerDay, isNull);
      expect(policy.confirmedFields, ['monthlyMaxHours']);
      expect(policy.unresolvedFields, contains('defaultRatePerDay'));
      expect(policy.isFullyResolved, isFalse);
    });
  });
}