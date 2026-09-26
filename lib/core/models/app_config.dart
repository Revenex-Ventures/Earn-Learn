class AppPolicy {
  const AppPolicy({this.monthlyMaxHours = 40, this.defaultRatePerDay});

  /// Configurable monthly hour limit per student (server authoritative).
  final int monthlyMaxHours;

  /// Per-day rate if configured; null means "not yet set".
  final double? defaultRatePerDay;
}