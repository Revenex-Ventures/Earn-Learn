import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/domain.dart';

void main() {
  const student = Student(
    id: 'STU-001',
    name: 'Mayur Anil Gaikwad',
    rollNumber: '22CS042',
  );
  const otherStudent = Student(
    id: 'STU-002',
    name: 'Pooja Sanjay Tambe',
    rollNumber: '23IT018',
  );

  const studentActor = Actor(
    userId: 'u-stu-001',
    role: UserRole.student,
    studentId: 'STU-001',
  );
  const supervisorActor = Actor(
    userId: 'u-sup-001',
    role: UserRole.supervisor,
    supervisorId: 'SV-01',
    zoneIds: {'LOC-03', 'LOC-08'},
  );
  const adminActor = Actor(
    userId: 'u-admin-001',
    role: UserRole.admin,
  );

  group('student scoping', () {
    test('sees its own profile, assignment and attendance', () {
      for (final permission in [
        DomainPermission.viewOwnProfile,
        DomainPermission.viewOwnAssignment,
        DomainPermission.viewOwnAttendance,
      ]) {
        expect(
          checkPermission(
            actor: studentActor,
            permission: permission,
            targetStudent: student,
          ).allowed,
          isTrue,
        );
      }
    });

    test('cannot view another student', () {
      final decision = checkPermission(
        actor: studentActor,
        permission: DomainPermission.viewOwnAttendance,
        targetStudent: otherStudent,
      );
      expect(decision.allowed, isFalse);
    });

    test('cannot review attendance', () {
      final decision = checkPermission(
        actor: studentActor,
        permission: DomainPermission.reviewAttendance,
      );
      expect(decision.allowed, isFalse);
    });
  });

  group('supervisor zone scoping', () {
    test('reviews sessions in an assigned zone', () {
      final decision = checkPermission(
        actor: supervisorActor,
        permission: DomainPermission.reviewAttendance,
        targetLocationId: 'LOC-08',
      );
      expect(decision.allowed, isTrue);
    });

    test('cannot review outside its assigned zones', () {
      final decision = checkPermission(
        actor: supervisorActor,
        permission: DomainPermission.reviewAttendance,
        targetLocationId: 'LOC-14',
      );
      expect(decision.allowed, isFalse);
      expect(decision.denialReason, contains('not assigned'));
    });

    test('cannot target another supervisor', () {
      final decision = checkPermission(
        actor: supervisorActor,
        permission: DomainPermission.reviewAttendance,
        targetSupervisor: const Supervisor(
          id: 'SV-02',
          name: 'Mr. S.B. Shinde',
          assignedLocationIds: ['LOC-01'],
          status: SupervisorStatus.onDuty,
        ),
      );
      expect(decision.allowed, isFalse);
    });
  });

  group('admin rights', () {
    test('manages payroll and approves runs', () {
      for (final permission in [
        DomainPermission.managePayroll,
        DomainPermission.approvePayroll,
        DomainPermission.manageAssignments,
        DomainPermission.managePolicy,
      ]) {
        expect(
          checkPermission(actor: adminActor, permission: permission).allowed,
          isTrue,
        );
      }
    });
  });

  group('critical fields', () {
    test('writeCriticalFields is always denied', () {
      for (final actor in [studentActor, supervisorActor, adminActor]) {
        final decision = checkPermission(
          actor: actor,
          permission: DomainPermission.writeCriticalFields,
        );
        expect(decision.allowed, isFalse);
      }
    });

    test('flags the server-only columns', () {
      expect(
        criticalFields,
        containsAll(['role', 'verifiedHours', 'review', 'checkInVerifiedAt']),
      );
    });
  });
}