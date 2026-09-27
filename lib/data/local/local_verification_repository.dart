import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../../shared/mock_data/mock_data.dart';
import '../dev_only.dart';
import 'local_review_store.dart';

@DevOnly('Demo approval queue fixtures.')
class LocalVerificationRepository implements VerificationRepository {
  const LocalVerificationRepository();

  /// Applies any supervisor decisions taken during this session so the queue
  /// stays truthful after an approve / flag / reject.
  List<VerificationItem> get _resolved {
    final store = LocalReviewStore.instance;
    return mockVerificationItems.map((item) {
      final decision = store.decisionFor(item.id);
      return decision == null ? item : item.copyWith(status: decision);
    }).toList();
  }

  @override
  Future<List<VerificationItem>> items({ApprovalStatus? status}) async {
    final resolved = _resolved;
    if (status == null) return resolved;
    return resolved.where((v) => v.status == status).toList();
  }

  @override
  Future<int> openCount() async =>
      _resolved.where((v) => v.status != ApprovalStatus.approved).length;
}
