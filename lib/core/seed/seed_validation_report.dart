import 'student_seed_entry.dart';

/// Result of validating a batch of workbook rows before import.
class SeedValidationReport {
  const SeedValidationReport({
    required this.rows,
    required this.missingEmail,
    required this.missingDepartment,
    required this.missingClass,
    required this.missingTime,
    required this.missingWork,
    required this.duplicates,
  });

  final List<StudentSeedEntry> rows;

  /// Rows with no name (cannot be imported at all).
  final List<StudentSeedEntry> missingEmail;

  /// Rows with no department noted in the workbook.
  final List<StudentSeedEntry> missingDepartment;

  /// Rows with no class/year noted.
  final List<StudentSeedEntry> missingClass;

  /// Rows with no shift time noted.
  final List<StudentSeedEntry> missingTime;

  /// Rows with no work allotted noted.
  final List<StudentSeedEntry> missingWork;

  /// Rows whose name appears more than once.
  final List<String> duplicates;

  int get total => rows.length;

  int get importable =>
      rows.length - missingEmail.where((r) => r.name.isEmpty).length;

  bool get hasIssues =>
      missingEmail.isNotEmpty ||
      missingDepartment.isNotEmpty ||
      missingClass.isNotEmpty ||
      missingTime.isNotEmpty ||
      missingWork.isNotEmpty ||
      duplicates.isNotEmpty;
}

/// Validation rules, shared by future importers and tests.
const Set<String> knownDepartments = {
  'Computer Science',
  'Information Technology',
  'Electrical Engineering',
  'Mechanical Engineering',
  'Civil Engineering',
  'Electronics',
};

SeedValidationReport validateSeedEntries(List<StudentSeedEntry> rows) {
  final seen = <String>{};
  final dupes = <String>[];
  for (final r in rows) {
    final key = r.name.trim().toLowerCase();
    if (key.isEmpty) continue;
    if (!seen.add(key)) dupes.add(r.name.trim());
  }

  return SeedValidationReport(
    rows: rows,
    missingEmail: rows.where((r) => r.name.trim().isEmpty).toList(),
    missingDepartment: rows.where((r) => r.department == null).toList(),
    missingClass: rows.where((r) => r.className == null).toList(),
    missingTime: rows.where((r) => r.time == null).toList(),
    missingWork: rows.where((r) => r.workAllotted == null).toList(),
    duplicates: dupes,
  );
}