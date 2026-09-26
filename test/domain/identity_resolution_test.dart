import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/domain.dart';

void main() {
  const student = Student(
    id: 'STU-001',
    name: 'Mayur Anil Gaikwad',
    rollNumber: '22CS042',
  );
  const supervisor = Supervisor(
    id: 'SV-01',
    name: 'Mr. K.J. Dhage',
    assignedLocationIds: ['LOC-08'],
    status: SupervisorStatus.onDuty,
  );
  final user = UserProfile(
    uid: 'u-1',
    displayName: 'Mayur',
    role: UserRole.student,
    status: AccountStatus.active,
    createdAt: DateTime(2025, 8, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
  final adminUser = UserProfile(
    uid: 'u-2',
    role: UserRole.admin,
    status: AccountStatus.active,
    createdAt: DateTime(2025, 8, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  test('link resolves to the directory student', () {
    final resolution = resolveIdentity(
      user: user,
      students: const [student],
      supervisors: const [supervisor],
      link: const AccountLink(
        userId: 'u-1',
        role: UserRole.student,
        entityId: 'STU-001',
      ),
    );
    expect(resolution.isUnlinked, isFalse);
    expect(resolution.student!.id, 'STU-001');
    expect(resolution.entityId, 'STU-001');
  });

  test('link resolves to the directory supervisor', () {
    final resolution = resolveIdentity(
      user: user,
      students: const [student],
      supervisors: const [supervisor],
      link: const AccountLink(
        userId: 'u-1',
        role: UserRole.supervisor,
        entityId: 'SV-01',
      ),
    );
    expect(resolution.supervisor!.id, 'SV-01');
  });

  test('admin accounts are unlinked but authenticated', () {
    final resolution = resolveIdentity(
      user: adminUser,
      students: const [student],
      supervisors: const [supervisor],
      link: const AccountLink(userId: 'u-2', role: UserRole.admin),
    );
    expect(resolution.isUnlinked, isTrue);
    expect(resolution.role, UserRole.admin);
  });

  test('missing link yields unlinked, never assumed identity', () {
    final resolution = resolveIdentity(
      user: user,
      students: const [student],
      supervisors: const [supervisor],
    );
    expect(resolution.isUnlinked, isTrue);
    expect(resolution.student, isNull);
  });

  test('link to a missing entity yields unlinked', () {
    final resolution = resolveIdentity(
      user: user,
      students: const [student],
      supervisors: const [supervisor],
      link: const AccountLink(
        userId: 'u-1',
        role: UserRole.student,
        entityId: 'STU-999',
      ),
    );
    expect(resolution.isUnlinked, isTrue);
  });
}