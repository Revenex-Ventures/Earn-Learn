/// Account lifecycle state for users.
enum AccountStatus {
  active,
  inactive,
  pending;

  String get label => switch (this) {
        AccountStatus.active => 'Active',
        AccountStatus.inactive => 'Inactive',
        AccountStatus.pending => 'Pending',
      };
}