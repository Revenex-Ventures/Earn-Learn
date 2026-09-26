/// Operational state of a work location.
enum LocationStatus {
  active,
  attention,
  inactive;

  String get label => switch (this) {
        LocationStatus.active => 'Active',
        LocationStatus.attention => 'Attention',
        LocationStatus.inactive => 'Inactive',
      };
}