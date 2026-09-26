import 'account_status.dart';

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.rollNumber,
    this.uid,
    this.email,
    this.contact,
    this.department,
    this.className,
    this.status = AccountStatus.active,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? uid;
  final String name;
  final String? email;
  final String? contact;
  final String? department;
  final String? className;
  final String rollNumber;
  final AccountStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get departmentOrNA =>
      (department != null && department!.trim().isNotEmpty) ? department! : 'Not specified';

  String get classOrNA =>
      (className != null && className!.trim().isNotEmpty) ? className! : 'Not specified';

  String get contactOrNA =>
      (contact != null && contact!.trim().isNotEmpty) ? contact! : 'Not available';

  Student copyWith({
    String? id,
    String? uid,
    String? name,
    String? email,
    String? contact,
    String? department,
    String? className,
    String? rollNumber,
    AccountStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Student(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      contact: contact ?? this.contact,
      department: department ?? this.department,
      className: className ?? this.className,
      rollNumber: rollNumber ?? this.rollNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const String collection = 'students';
}