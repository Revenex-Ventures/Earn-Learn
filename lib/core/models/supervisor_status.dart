/// Duty state of a supervisor.
enum SupervisorStatus {
  onDuty,
  offDuty,
  unavailable;

  String get label => switch (this) {
        SupervisorStatus.onDuty => 'On duty',
        SupervisorStatus.offDuty => 'Off duty',
        SupervisorStatus.unavailable => 'Unavailable',
      };
}