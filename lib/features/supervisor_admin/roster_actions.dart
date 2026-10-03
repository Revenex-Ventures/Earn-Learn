import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../data/local/roster_store.dart';

/// Shared supervisor / admin roster mutations (add & remove students and
/// supervisors, adjust shift timings) for the local build.
///
/// Every action writes through [RosterStore] (persisted on-device) and then
/// invalidates the repository providers so every open screen — the student's
/// own portal, the supervisor roster, the admin directories — rebuilds against
/// the live roster. Deliberately built from plain Material widgets so it stays
/// self-contained and portable across the three portals.

/// Rebuilds everything that reads the roster after a mutation.
void refreshRoster(WidgetRef ref) {
  ref.invalidate(studentRepositoryProvider);
  ref.invalidate(supervisorRepositoryProvider);
  ref.invalidate(assignmentRepositoryProvider);
  ref.invalidate(locationRepositoryProvider);
}

String _fmt(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$h:$m $ap';
}

TimeOfDay _toTod(Duration d) =>
    TimeOfDay(hour: d.inHours % 24, minute: d.inMinutes % 60);

/// Bottom sheet to enrol a new student and assign their duty in one step.
/// When [lockedSupervisorId] is given (supervisor portal), the supervisor is
/// fixed to the signed-in user and only their locations are offered.
Future<void> showAddStudentSheet(
  BuildContext context,
  WidgetRef ref, {
  String? lockedSupervisorId,
}) async {
  final store = RosterStore.instance;
  final nameCtrl = TextEditingController();
  final deptCtrl = TextEditingController();
  final classCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final workCtrl = TextEditingController(text: 'General duty');

  final supervisors = store.supervisors;
  String? supervisorId = lockedSupervisorId ??
      (supervisors.isNotEmpty ? supervisors.first.id : null);

  List<Location> locsFor(String? svId) {
    if (svId == null) return store.locations;
    final sv = supervisors.where((s) => s.id == svId).toList();
    if (sv.isEmpty || sv.first.assignedLocationIds.isEmpty) {
      return store.locations;
    }
    final ids = sv.first.assignedLocationIds.toSet();
    final scoped = store.locations.where((l) => ids.contains(l.id)).toList();
    return scoped.isEmpty ? store.locations : scoped;
  }

  var locations = locsFor(supervisorId);
  String? locationId = locations.isNotEmpty ? locations.first.id : null;
  TimeOfDay start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 21, minute: 0);
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add student',
                        style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'A unique Earn & Learn ID is generated. The student can '
                      'sign in with that ID and the shared password.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (lockedSupervisorId == null) ...[
                      DropdownButtonFormField<String>(
                        initialValue: supervisorId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Supervisor',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final s in supervisors)
                            DropdownMenuItem(
                                value: s.id, child: Text(s.name)),
                        ],
                        onChanged: (v) => setSheet(() {
                          supervisorId = v;
                          locations = locsFor(v);
                          locationId = locations.isNotEmpty
                              ? locations.first.id
                              : null;
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: locationId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Work location',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final l in locations)
                          DropdownMenuItem(value: l.id, child: Text(l.name)),
                      ],
                      onChanged: (v) => setSheet(() => locationId = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: workCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Duty / work description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: 'Shift start',
                            value: start,
                            onPick: (t) => setSheet(() => start = t),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeField(
                            label: 'Shift end',
                            value: end,
                            onPick: (t) => setSheet(() => end = t),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: deptCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: classCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Class',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          if (locationId == null || supervisorId == null) {
                            return;
                          }
                          String? trimOrNull(String s) =>
                              s.trim().isEmpty ? null : s.trim();
                          final created = store.addStudent(
                            name: nameCtrl.text,
                            locationId: locationId!,
                            supervisorId: supervisorId!,
                            workDescription: workCtrl.text.trim().isEmpty
                                ? 'General duty'
                                : workCtrl.text.trim(),
                            shiftWindows: [
                              ShiftWindow(
                                start: Duration(
                                    hours: start.hour, minutes: start.minute),
                                end: Duration(
                                    hours: end.hour, minutes: end.minute),
                              ),
                            ],
                            department: trimOrNull(deptCtrl.text),
                            className: trimOrNull(classCtrl.text),
                            contact: trimOrNull(contactCtrl.text),
                          );
                          Navigator.of(sheetCtx).pop();
                          refreshRoster(ref);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added ${created.name} · login ID '
                                '${created.rollNumber}',
                              ),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Add student'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Dialog to adjust a student's shift start / end. Edits the first window;
/// additional split-shift windows are preserved.
Future<void> showEditShiftDialog(
  BuildContext context,
  WidgetRef ref, {
  required String studentId,
  required Assignment assignment,
}) async {
  final store = RosterStore.instance;
  final first = assignment.shiftWindows.isNotEmpty
      ? assignment.shiftWindows.first
      : const ShiftWindow(
          start: Duration(hours: 18), end: Duration(hours: 21));
  TimeOfDay start = _toTod(first.start);
  TimeOfDay end = _toTod(first.end);

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialog) {
          return AlertDialog(
            title: const Text('Adjust shift timing'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TimeField(
                  label: 'Shift start',
                  value: start,
                  onPick: (t) => setDialog(() => start = t),
                ),
                const SizedBox(height: 12),
                _TimeField(
                  label: 'Shift end',
                  value: end,
                  onPick: (t) => setDialog(() => end = t),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final windows = [
                    ShiftWindow(
                      start:
                          Duration(hours: start.hour, minutes: start.minute),
                      end: Duration(hours: end.hour, minutes: end.minute),
                    ),
                    ...assignment.shiftWindows.skip(1),
                  ];
                  store.updateStudentShift(studentId, windows);
                  Navigator.of(dialogCtx).pop();
                  refreshRoster(ref);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shift updated')),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Confirms and removes a student (and their assignment) from the roster.
Future<void> confirmRemoveStudent(
  BuildContext context,
  WidgetRef ref, {
  required Student student,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Remove student?'),
      content: Text(
        '${student.name} (${student.rollNumber}) will be removed from the '
        'roster and can no longer sign in. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (ok == true) {
    RosterStore.instance.removeStudent(student.id);
    refreshRoster(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${student.name}')),
      );
    }
  }
}

/// Bottom sheet to add a supervisor (admin only).
Future<void> showAddSupervisorSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final store = RosterStore.instance;
  final nameCtrl = TextEditingController();
  final deptCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final selected = <String>{};
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add supervisor',
                        style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: deptCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Assigned locations',
                          style: Theme.of(ctx).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final l in store.locations)
                          FilterChip(
                            label: Text(l.name),
                            selected: selected.contains(l.id),
                            onSelected: (on) => setSheet(() {
                              if (on) {
                                selected.add(l.id);
                              } else {
                                selected.remove(l.id);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          String? trimOrNull(String s) =>
                              s.trim().isEmpty ? null : s.trim();
                          final created = store.addSupervisor(
                            name: nameCtrl.text,
                            department: trimOrNull(deptCtrl.text),
                            email: trimOrNull(emailCtrl.text),
                            contact: trimOrNull(contactCtrl.text),
                            locationIds: selected.toList(),
                          );
                          Navigator.of(sheetCtx).pop();
                          refreshRoster(ref);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added ${created.name} · login ID '
                                '${created.id}',
                              ),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Add supervisor'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Confirms and removes a supervisor (admin only).
Future<void> confirmRemoveSupervisor(
  BuildContext context,
  WidgetRef ref, {
  required Supervisor supervisor,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Remove supervisor?'),
      content: Text(
        '${supervisor.name} will be removed. Their students remain on the '
        'roster and should be reassigned to another supervisor.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (ok == true) {
    RosterStore.instance.removeSupervisor(supervisor.id);
    refreshRoster(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${supervisor.name}')),
      );
    }
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked =
            await showTimePicker(context: context, initialTime: value);
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(_fmt(value)),
      ),
    );
  }
}


