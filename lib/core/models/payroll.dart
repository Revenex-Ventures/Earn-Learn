import 'payment_status.dart';

/// Admin-side payroll rollup for a month.
class PayrollRecord {
  const PayrollRecord({
    required this.month,
    required this.studentCount,
    required this.presentDays,
    required this.paidHolidays,
    required this.ratePerDay,
    required this.estimatedPayable,
    this.status = PaymentStatus.inProgress,
  });

  /// First day of the month this payroll covers.
  final DateTime month;
  final int studentCount;
  final int presentDays;
  final int paidHolidays;
  final double ratePerDay;
  final double estimatedPayable;
  final PaymentStatus status;

  static const String collection = 'payroll';
}

/// Per-student monthly payment record (admin authoritative).
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.month,
    required this.studentId,
    required this.studentName,
    required this.verifiedHours,
    required this.eligibleDays,
    required this.paidHolidays,
    required this.ratePerDay,
    required this.calculatedAmount,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.paymentDate,
    this.receiptId,
  });

  final String id;
  final DateTime month;
  final String studentId;
  final String studentName;
  final double verifiedHours;
  final int eligibleDays;
  final int paidHolidays;
  final double ratePerDay;
  final double calculatedAmount;
  final PaymentStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? paymentDate;
  final String? receiptId;

  static const String collection = 'payment_records';
}

/// Receipt issued after a payment is disbursed.
class PaymentReceipt {
  const PaymentReceipt({
    required this.id,
    required this.paymentId,
    required this.studentId,
    required this.issuedAt,
    this.amount,
    this.note,
  });

  final String id;
  final String paymentId;
  final String studentId;
  final DateTime issuedAt;
  final double? amount;
  final String? note;

  static const String collection = 'payment_receipts';
}