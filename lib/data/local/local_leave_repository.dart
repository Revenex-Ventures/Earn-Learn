import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../dev_only.dart';

@DevOnly('No leave fixtures exist; submits are recorded in memory.')
class LocalLeaveRepository implements LeaveRepository {
  LocalLeaveRepository() : _requests = <LeaveRequest>[];

  final List<LeaveRequest> _requests;

  @override
  Future<List<LeaveRequest>> forStudent({
    required String studentId,
    required DateTime month,
  }) async =>
      _requests
          .where((r) =>
              r.studentId == studentId &&
              r.date.year == month.year &&
              r.date.month == month.month)
          .toList();

  @override
  Future<void> submit(LeaveRequest request) async {
    _requests.add(request);
  }

  @override
  Future<void> review({
    required String requestId,
    required LeaveStatus decision,
    required String reviewedBy,
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) {
      throw StateError('Leave request $requestId not found.');
    }
    final current = _requests[index];
    _requests[index] = LeaveRequest(
      id: current.id,
      studentId: current.studentId,
      studentName: current.studentName,
      date: current.date,
      reason: current.reason,
      status: decision,
      submittedAt: current.submittedAt,
      reviewedBy: reviewedBy,
      reviewedAt: DateTime.now(),
    );
  }
}