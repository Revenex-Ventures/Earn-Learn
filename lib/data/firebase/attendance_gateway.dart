import 'package:cloud_functions/cloud_functions.dart';

import '../../core/evidence/evidence_geo.dart';
import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../app_flavor.dart';
import 'firestore_mappers.dart';

/// Failure categories surfaced to the UI after a gateway call.
enum AttendanceFlowErrorKind {
  unlinked,
  permissions,
  invalidArgument,
  notFound,
  stateConflict,
  capacityLimit,
  network,
  unknown,
}

/// Typed error across the gateway boundary (mirrors HttpsError codes).
class AttendanceFlowException implements Exception {
  const AttendanceFlowException(this.kind, [this.message]);

  final AttendanceFlowErrorKind kind;
  final String? message;

  @override
  String toString() => message != null
      ? '$kind: $message'
      : 'Attendance flow error (${kind.name})';
}

/// output of the server-initiated check-in (F1/F3).
class CheckInInit {
  const CheckInInit({
    required this.sessionId,
    required this.requestId,
    required this.uploadTarget,
  });

  final String sessionId;

  /// Idempotency key echoed from the request.
  final String requestId;

  /// Storage path the client must upload check-in evidence to.
  final String uploadTarget;
}

class CheckOutInit {
  const CheckOutInit({
    required this.sessionId,
    required this.requestId,
    required this.uploadTarget,
  });

  final String sessionId;
  final String requestId;
  final String uploadTarget;
}

class CheckInConfirmResult {
  const CheckInConfirmResult({
    required this.status,
    this.checkInVerifiedAt,
    this.geoVerified = false,
  });

  final SessionStatus status;
  final DateTime? checkInVerifiedAt;
  final bool geoVerified;
}

class CheckOutConfirmResult {
  const CheckOutConfirmResult({
    required this.status,
    required this.verifiedHours,
    this.capacityWarning = false,
  });

  final SessionStatus status;
  final double verifiedHours;
  final bool capacityWarning;
}

class ReviewResult {
  const ReviewResult({
    required this.status,
    required this.review,
    this.note,
  });

  final SessionStatus status;
  final ApprovalStatus review;
  final String? note;
}

/// Client → server attendance operations.
///
/// All writes flow through Cloud Functions; the Firestore repositories never
/// write status/verification fields directly.
abstract class AttendanceGateway {
  Future<CheckInInit> checkIn({
    required String requestId,
    required DateTime date,
    required EvidenceGeo geo,
  });

  Future<CheckInConfirmResult> confirmCheckIn({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  });

  Future<CheckOutInit> checkOut({
    required String requestId,
    required String sessionId,
    required EvidenceGeo geo,
  });

  Future<CheckOutConfirmResult> confirmCheckOut({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  });

  Future<ReviewResult> review({
    required String sessionId,
    required String studentId,
    required ApprovalStatus decision,
    String? note,
  });

  Future<List<VerificationItem>> myQueue();

  Future<String> evidenceUrl({
    required String sessionId,
    required String studentId,
    required String kind,
  });
}

/// HTTP/1 callable-backed gateway bound to the Functions emulator by default.
class CloudAttendanceGateway implements AttendanceGateway {
  CloudAttendanceGateway({
    FirebaseFunctions? functions,
    String? host,
    int? port,
  }) : _functions = functions ?? FirebaseFunctions.instance {
    if (host != null) {
      _functions.useFunctionsEmulator(host, port ?? AppFlavor.functionsPort);
    }
  }

  final FirebaseFunctions _functions;

  @override
  Future<CheckInInit> checkIn({
    required String requestId,
    required DateTime date,
    required EvidenceGeo geo,
  }) async {
    final data = await _call('checkIn', <String, Object?>{
      'requestId': requestId,
      'date': _dateKey(date),
      'geo': geo.toMap(),
    });
    return CheckInInit(
      sessionId: data['sessionId'] as String,
      requestId: data['requestId'] as String,
      uploadTarget: data['uploadTarget'] as String,
    );
  }

  @override
  Future<CheckInConfirmResult> confirmCheckIn({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  }) async {
    final data = await _call('confirmCheckIn', <String, Object?>{
      'requestId': requestId,
      'sessionId': sessionId,
      'uploadPath': uploadPath,
      'geo': geo.toMap(),
    });
    return CheckInConfirmResult(
      status: _status(data['status']),
      checkInVerifiedAt: _parseIso(data['checkInVerifiedAt']),
      geoVerified: (data['geoVerified'] as bool?) ?? false,
    );
  }

  @override
  Future<CheckOutInit> checkOut({
    required String requestId,
    required String sessionId,
    required EvidenceGeo geo,
  }) async {
    final data = await _call('checkOut', <String, Object?>{
      'requestId': requestId,
      'sessionId': sessionId,
      'geo': geo.toMap(),
    });
    return CheckOutInit(
      sessionId: data['sessionId'] as String,
      requestId: data['requestId'] as String,
      uploadTarget: data['uploadTarget'] as String,
    );
  }

  @override
  Future<CheckOutConfirmResult> confirmCheckOut({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  }) async {
    final data = await _call('confirmCheckOut', <String, Object?>{
      'requestId': requestId,
      'sessionId': sessionId,
      'uploadPath': uploadPath,
      'geo': geo.toMap(),
    });
    return CheckOutConfirmResult(
      status: _status(data['status']),
      verifiedHours: (data['verifiedHours'] as num?)?.toDouble() ?? 0,
      capacityWarning: (data['capacityWarning'] as bool?) ?? false,
    );
  }

  @override
  Future<ReviewResult> review({
    required String sessionId,
    required String studentId,
    required ApprovalStatus decision,
    String? note,
  }) async {
    final data = await _call('review', <String, Object?>{
      'sessionId': sessionId,
      'studentId': studentId,
      'decision': decision.name,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return ReviewResult(
      status: _status(data['status']),
      review: _approval(data['review']),
      note: data['note'] as String?,
    );
  }

  @override
  Future<List<VerificationItem>> myQueue() async {
    final data = await _call('myQueue', const <String, Object?>{});
    final raw = (data['items'] as List<Object?>?) ?? const [];
    final items = <VerificationItem>[];
    for (final item in raw) {
      if (item is Map) {
        items.add(mapVerificationItem(
          (item).cast<String, Object?>(),
        ));
      }
    }
    return items;
  }

  @override
  Future<String> evidenceUrl({
    required String sessionId,
    required String studentId,
    required String kind,
  }) async {
    final data = await _call('getEvidence', <String, Object?>{
      'sessionId': sessionId,
      'studentId': studentId,
      'kind': kind,
    });
    return data['url'] as String;
  }

  Future<Map<String, Object?>> _call(String name, Map<String, Object?> payload) async {
    try {
      final response = await _functions.httpsCallable(name).call(payload);
      final data = response.data;
      if (data is Map && data['ok'] == true && data['data'] is Map) {
        return (data['data'] as Map).cast<String, Object?>();
      }
      throw AttendanceFlowException(
        AttendanceFlowErrorKind.unknown,
        'Malformed function envelope for $name.',
      );
    } on FirebaseFunctionsException catch (e) {
      final raw = e.details;
      final kind = raw is Map ? raw['kind']?.toString() : null;
      throw AttendanceFlowException(
        kind != null ? _mapCode(kind) : _mapCode(e.code),
        e.message,
      );
    } catch (e) {
      throw AttendanceFlowException(AttendanceFlowErrorKind.network, e.toString());
    }
  }

  AttendanceFlowErrorKind _mapCode(String code) => switch (code) {
        'unlinked' || 'functions/unlinked' => AttendanceFlowErrorKind.unlinked,
        'permission-denied' ||
        'permissions-denied' ||
        'functions/permission-denied' =>
          AttendanceFlowErrorKind.permissions,
        'invalid-argument' ||
        'invalid-evidence' ||
        'functions/invalid-argument' =>
          AttendanceFlowErrorKind.invalidArgument,
        'not-found' || 'functions/not-found' => AttendanceFlowErrorKind.notFound,
        'failed-precondition' ||
        'functions/failed-precondition' =>
          AttendanceFlowErrorKind.stateConflict,
        'aborted' ||
        'functions/aborted' ||
        'already-exists' =>
          AttendanceFlowErrorKind.stateConflict,
        'resource-exhausted' ||
        'functions/resource-exhausted' ||
        'quota-exceeded' =>
          AttendanceFlowErrorKind.capacityLimit,
        _ => AttendanceFlowErrorKind.unknown,
      };

  SessionStatus _status(Object? value) =>
      SessionStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => SessionStatus.scheduled,
      );

  ApprovalStatus _approval(Object? value) => ApprovalStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => ApprovalStatus.pending,
      );

  DateTime? _parseIso(Object? value) => value is String
      ? DateTime.tryParse(value)
      : null;

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}