/// One row from the college workbook allocation sheet.
///
/// All fields mirror the workbook columns. Missing cells are represented as
/// null so the import can surface data-quality issues instead of guessing.
class StudentSeedEntry {
  const StudentSeedEntry({
    required this.name,
    this.contact,
    this.department,
    this.className,
    this.time,
    this.workAllotted,
    this.remark,
  });

  final String name;
  final String? contact;
  final String? department;
  final String? className;
  final String? time;
  final String? workAllotted;
  final String? remark;
}