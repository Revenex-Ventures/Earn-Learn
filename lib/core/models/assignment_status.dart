/// Lifecycle state of a work assignment.
enum AssignmentStatus {
  active,
  future,
  temporary,
  inactive,
  completed;

  String get label => switch (this) {
        AssignmentStatus.active => 'Active',
        AssignmentStatus.future => 'Future',
        AssignmentStatus.temporary => 'Temporary',
        AssignmentStatus.inactive => 'Inactive',
        AssignmentStatus.completed => 'Completed',
      };
}