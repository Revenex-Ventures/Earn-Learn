/// Disbursement state of earnings/payroll.
enum PaymentStatus {
  pending,
  inProgress,
  approved,
  paid,
  held;

  String get label => switch (this) {
        PaymentStatus.pending => 'Pending',
        PaymentStatus.inProgress => 'Processing',
        PaymentStatus.approved => 'Approved',
        PaymentStatus.paid => 'Paid',
        PaymentStatus.held => 'Held',
      };
}