import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../../features/auth/auth_session.dart';
import '../../shared/mock_data/mock_data.dart';
import '../dev_only.dart';
import 'runtime_store.dart';

/// Local supervisor approval queue.
///
/// This is the join that connects the portals: it derives live items from the
/// real submitted sessions a student produced when they checked out (persisted
/// in [RuntimeStore]), scoped to the signed-in supervisor's own students, and
/// merges the demo fixtures (overlaid with any persisted decision). A student's
/// check-out therefore appears here immediately, and an approve / flag / reject
/// flows straight back to that student's record.
@DevOnly('Live approval queue derived from real submitted sessions + fixtures.')
class LocalVerificationRepository implements VerificationRepository {
  const LocalVerificationRepository();

  static bool _reviewable(SessionStatus status) =>
      status == SessionStatus.submitted ||
      status == SessionStatus.underReview ||
      status == SessionStatus.correctionRequested ||
      status == SessionStatus.approved ||
      status == SessionStatus.flagged ||
      status == SessionStatus.rejected;

  /// Student ids the signed-in supervisor is responsible for, or null for an
  /// admin / plain preview (which sees everything).
  Set<String>? get _myStudentIds {
    final supId = AuthSession.supervisorId;
    if (supId == null) return null;
    return mockAssignments
        .where((a) => a.supervisorId == supId)
        .map((a) => a.studentId)
        .toSet();
  }

  List<VerificationItem> _liveItems() {
    final scope = _myStudentIds;
    final items = <VerificationItem>[];

    // Real, student-produced sessions (a genuine check event happened).
    for (final s in RuntimeStore.instance.allSessions()) {
      if (!_reviewable(s.status)) continue;
      if (s.checkInVerifiedAt == null && s.checkOutVerifiedAt == null) continue;
      if (scope != null && !scope.contains(s.studentId)) continue;
      items.add(_itemFromSession(s));
    }

    // Demo fixtures (historical), overlaid with any persisted decision.
    for (final item in mockVerificationItems) {
      if (scope != null && !scope.contains(item.studentId)) continue;
      final decision = RuntimeStore.instance.decisionFor(item.id);
      items.add(decision == null ? item : item.copyWith(status: decision));
    }

    items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  VerificationItem _itemFromSession(Session s) {
    final checkedOut = s.checkOutVerifiedAt != null;
    return VerificationItem(
      id: s.id,
      studentName: mockStudentName(s.studentId),
      studentId: s.studentId,
      location: mockStudentLocation(s.studentId),
      type: checkedOut ? VerificationType.checkOut : VerificationType.checkIn,
      submittedAt: s.checkOutVerifiedAt ??
          s.checkOutRequestedAt ??
          s.checkInVerifiedAt ??
          s.date,
      status: s.review,
      summary: _summary(s),
      evidenceTime: s.checkInVerifiedAt,
    );
  }

  String _summary(Session s) {
    final parts = <String>[];
    if (s.checkInVerifiedAt != null) {
      parts.add('In ${_hhmm(s.checkInVerifiedAt!)}');
    }
    if (s.checkOutVerifiedAt != null) {
      parts.add('out ${_hhmm(s.checkOutVerifiedAt!)}');
    }
    final when = parts.isEmpty ? 'Submitted' : parts.join(' → ');
    final hours = s.verifiedHours > 0
        ? ' · ${s.verifiedHours.toStringAsFixed(1)} h verified'
        : '';
    return '$when$hours';
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Future<List<VerificationItem>> items({ApprovalStatus? status}) async {
    final resolved = _liveItems();
    if (status == null) return resolved;
    return resolved.where((v) => v.status == status).toList();
  }

  @override
  Future<int> openCount() async => _liveItems()
      .where((v) =>
          v.status != ApprovalStatus.approved &&
          v.status != ApprovalStatus.rejected)
      .length;
}
