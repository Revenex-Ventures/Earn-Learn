import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../../shared/mock_data/mock_data.dart';
import '../dev_only.dart';

@DevOnly('Demo payroll rollup and fixture payment records.')
class LocalPayrollRepository implements PayrollRepository {
  const LocalPayrollRepository();

  @override
  Future<PayrollRecord?> currentMonth() async => mockCurrentPayroll;

  @override
  Future<List<PaymentRecord>> recordsForMonth(DateTime month) async =>
      mockPaymentRecords
          .where((r) => r.month.year == month.year && r.month.month == month.month)
          .toList();
}