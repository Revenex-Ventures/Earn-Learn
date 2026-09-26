import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../../shared/mock_data/mock_data.dart';
import '../dev_only.dart';

@DevOnly('Demo approval queue fixtures.')
class LocalVerificationRepository implements VerificationRepository {
  const LocalVerificationRepository();

  @override
  Future<List<VerificationItem>> items({ApprovalStatus? status}) async {
    if (status == null) return mockVerificationItems;
    return mockVerificationItems.where((v) => v.status == status).toList();
  }

  @override
  Future<int> openCount() async => mockOpenVerifications.length;
}