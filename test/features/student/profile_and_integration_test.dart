import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/data/data.dart';
import 'package:earn_and_learn/domain/domain.dart';
import 'package:earn_and_learn/features/student/profile_screen.dart';

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(this.user, this.link);
  final UserProfile? user;
  final AccountLink? link;

  @override
  Future<UserProfile?> currentUser() async => user;

  @override
  Future<AccountLink?> currentAccountLink() async => link;
}

void main() {
  group('Real Student Profile & Onboarding Integration', () {
    late Student testStudent;
    late List<Student> studentStore;

    setUp(() {
      testStudent = Student(
        id: 'STU-001',
        name: 'Prasanna Auti',
        rollNumber: 'TE-COMP-01',
        email: 'prasanna@avcoe.org',
        contact: '+91 9876543210',
        department: 'Computer Engineering',
        className: 'TE-A',
        status: AccountStatus.active,
      );
      studentStore = [testStudent];
    });

    testWidgets('renders student profile and allows opening compact edit form',
        (tester) async {
      final accountRepo = _FakeAccountRepository(
        UserProfile(
          uid: 'uid-001',
          email: 'prasanna@avcoe.org',
          role: UserRole.student,
          status: AccountStatus.active,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        const AccountLink(
          userId: 'uid-001',
          role: UserRole.student,
          entityId: 'STU-001',
        ),
      );
      final studentRepo = LocalStudentRepository(studentStore);
      final assignmentRepo = LocalAssignmentRepository([
        Assignment(
          id: 'ASN-001',
          studentId: 'STU-001',
          locationId: 'LOC-001',
          locationName: 'Central Library',
          supervisorId: 'SV-001',
          supervisorName: 'Prof. K. R. Gunjal',
          workDescription: 'Library Assistant',
          shiftWindows: const [
            ShiftWindow(start: Duration(hours: 10), end: Duration(hours: 12))
          ],
          effectiveFrom: DateTime(2026, 1, 1),
          status: AssignmentStatus.active,
          maxMonthlyHours: 40,
        ),
      ]);
      final supervisorRepo = LocalSupervisorRepository([
        const Supervisor(
          id: 'SV-001',
          name: 'Prof. K. R. Gunjal',
          email: 'gunjal@avcoe.org',
          assignedLocationIds: ['LOC-001'],
          status: SupervisorStatus.onDuty,
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountRepositoryProvider.overrideWithValue(accountRepo),
            studentRepositoryProvider.overrideWithValue(studentRepo),
            assignmentRepositoryProvider.overrideWithValue(assignmentRepo),
            supervisorRepositoryProvider.overrideWithValue(supervisorRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StudentProfileScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify view mode
      expect(find.text('Prasanna Auti'), findsWidgets);
      expect(find.text('Earn & Learn ID · TE-COMP-01'), findsOneWidget);
      expect(find.text('Computer Engineering'), findsWidgets);
      expect(find.text('Amrutvahini College of Engineering'), findsWidgets);
      expect(find.text('Edit Details'), findsOneWidget);

      // Tap Edit Details
      await tester.tap(find.text('Edit Details'));
      await tester.pumpAndSettle();

      // Verify compact sections exist
      expect(find.text('IDENTITY'), findsOneWidget);
      expect(find.text('ACADEMICS'), findsOneWidget);
      expect(find.text('CONTACT'), findsOneWidget);
      expect(find.text('INSTITUTION'), findsOneWidget);
      expect(find.text('Save Profile'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Edit contact number
      final contactField = find.widgetWithText(TextFormField, '+91 9876543210');
      expect(contactField, findsOneWidget);
      await tester.enterText(contactField, '+91 9123456780');

      // Tap Save
      await tester.ensureVisible(find.text('Save Profile'));
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      // Verify returned to view mode and updated in store
      expect(find.text('+91 9123456780'), findsOneWidget);
      expect(studentStore.first.contact, '+91 9123456780');
    });

    testWidgets('edit form enforces field validation rules', (tester) async {
      final accountRepo = _FakeAccountRepository(
        UserProfile(
          uid: 'uid-001',
          email: 'prasanna@avcoe.org',
          role: UserRole.student,
          status: AccountStatus.active,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        const AccountLink(
          userId: 'uid-001',
          role: UserRole.student,
          entityId: 'STU-001',
        ),
      );
      final studentRepo = LocalStudentRepository(studentStore);
      final assignmentRepo = LocalAssignmentRepository([]);
      final supervisorRepo = LocalSupervisorRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountRepositoryProvider.overrideWithValue(accountRepo),
            studentRepositoryProvider.overrideWithValue(studentRepo),
            assignmentRepositoryProvider.overrideWithValue(assignmentRepo),
            supervisorRepositoryProvider.overrideWithValue(supervisorRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StudentProfileScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Details'));
      await tester.pumpAndSettle();

      // Clear full name
      final nameField = find.widgetWithText(TextFormField, 'Prasanna Auti');
      await tester.enterText(nameField, '');

      // Enter invalid phone
      final contactField = find.widgetWithText(TextFormField, '+91 9876543210');
      await tester.enterText(contactField, '123');

      // Enter invalid email
      final emailField = find.widgetWithText(TextFormField, 'prasanna@avcoe.org');
      await tester.enterText(emailField, 'not-an-email');

      await tester.ensureVisible(find.text('Save Profile'));
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      // Verify validation error messages
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Enter valid 10-digit phone'), findsOneWidget);
      expect(find.text('Enter a valid email'), findsOneWidget);
    });
  });
}
