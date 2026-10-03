import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../dev_only.dart';

/// A recorded payroll batch approval (two-person rule outcome).
class PayrollApproval {
  const PayrollApproval({
    required this.monthKey,
    required this.preparedBy,
    required this.approvedBy,
    required this.approvedAt,
  });

  final String monthKey; // 'YYYY-MM'
  final String preparedBy;
  final String approvedBy;
  final DateTime approvedAt;

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'preparedBy': preparedBy,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt.toIso8601String(),
      };

  static PayrollApproval fromJson(Map<String, dynamic> j) => PayrollApproval(
        monthKey: j['monthKey'] as String,
        preparedBy: j['preparedBy'] as String? ?? '',
        approvedBy: j['approvedBy'] as String? ?? '',
        approvedAt:
            DateTime.tryParse(j['approvedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// On-device payroll configuration + approvals for the local build.
///
/// Owns the admin-configurable per-day stipend rate (and optional per-location
/// overrides) and the record of which months have been approved. Persisted via
/// `flutter_secure_storage` so both survive an app restart. Payroll amounts are
/// otherwise COMPUTED from real attendance — this store only holds the rate and
/// the approval decisions, never the derived figures.
@DevOnly('Persistent payroll rate config + batch approvals for the demo build.')
class PayrollStore {
  PayrollStore._();

  static final PayrollStore instance = PayrollStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _key = 'el_payroll_v1';

  /// Seed default used until an admin sets a rate. The scheme's real rate is
  /// configured by the college in the admin Payroll settings.
  static const double defaultRatePerDay = 100.0;

  double? _ratePerDay;
  final Map<String, double> _locationRates = {};
  final Map<String, PayrollApproval> _approvals = {}; // key = monthKey

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _ratePerDay = (decoded['ratePerDay'] as num?)?.toDouble();
        final locs = decoded['locationRates'] as Map<String, dynamic>?;
        if (locs != null) {
          _locationRates
            ..clear()
            ..addAll(locs.map((k, v) => MapEntry(k, (v as num).toDouble())));
        }
        final apps = decoded['approvals'] as List?;
        if (apps != null) {
          _approvals
            ..clear()
            ..addEntries(apps.map((e) {
              final a = PayrollApproval.fromJson(e as Map<String, dynamic>);
              return MapEntry(a.monthKey, a);
            }));
        }
      }
    } catch (_) {
      // Corrupt config must never crash the app; fall back to defaults.
    }
    _loaded = true;
  }

  // --- rate -----------------------------------------------------------------

  /// The configured rate, or null when the admin has not set one yet.
  double? get ratePerDay => _ratePerDay;

  /// The rate actually used for computation (configured, else seed default).
  double get effectiveRatePerDay => _ratePerDay ?? defaultRatePerDay;

  Map<String, double> get locationRates => Map.unmodifiable(_locationRates);

  void setRate(double rate) {
    _ratePerDay = rate;
    _persist();
  }

  void setLocationRate(String locationId, double rate) {
    _locationRates[locationId] = rate;
    _persist();
  }

  void clearLocationRate(String locationId) {
    _locationRates.remove(locationId);
    _persist();
  }

  // --- approvals ------------------------------------------------------------

  static String monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  PayrollApproval? approvalFor(DateTime month) => _approvals[monthKey(month)];

  bool isApproved(DateTime month) => _approvals.containsKey(monthKey(month));

  void approve({
    required DateTime month,
    required String preparedBy,
    required String approvedBy,
  }) {
    final key = monthKey(month);
    _approvals[key] = PayrollApproval(
      monthKey: key,
      preparedBy: preparedBy,
      approvedBy: approvedBy,
      approvedAt: DateTime.now(),
    );
    _persist();
  }

  void reset() {
    _ratePerDay = null;
    _locationRates.clear();
    _approvals.clear();
    _storage.delete(key: _key);
  }

  // --- persistence ----------------------------------------------------------

  void _persist() {
    final map = <String, dynamic>{
      'ratePerDay': _ratePerDay,
      'locationRates': _locationRates,
      'approvals': _approvals.values.map((a) => a.toJson()).toList(),
    };
    _storage.write(key: _key, value: jsonEncode(map));
  }
}
