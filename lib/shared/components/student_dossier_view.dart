import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import 'context_header.dart';
import 'empty_state.dart';
import 'monthly_hours_meter.dart';
import 'section_header.dart';
import 'status_badge.dart';

/// View-model for the shared student dossier used by supervisor and admin
/// detail views. Data comes from real repositories; missing data renders
/// honest empty states. Never surfaces pay/earnings.
class StudentDossierData {
  const StudentDossierData({
    required this.student,
    this.assignment,
    this.records = const [],
    this.month,
    this.maxMonthlyHours = 40,
    this.headerTrailing,
    this.resolveEvidence,
  });

  final Student student;
  final Assignment? assignment;
  final List<AttendanceRecord> records;
  final DateTime? month;
  final int maxMonthlyHours;
  final Widget? headerTrailing;

  /// Optional per-day duty-photograph resolver. Null disables the thumbnail
  /// entirely and each row states plainly that no photograph is available.
  final DayEvidenceResolver? resolveEvidence;
}

/// Shared identity + metrics + assignment + attendance composition.
/// Composable (renders a [Column], not a scroll view) so detail screens can
/// add their own headers and actions.
class StudentDossierView extends StatelessWidget {
  const StudentDossierView({super.key, required this.data});

  final StudentDossierData data;

  @override
  Widget build(BuildContext context) {
    final student = data.student;
    final verified = data.records.fold<double>(0, (s, r) => s + r.verifiedHours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Surface(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(name: student.name, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      '${student.rollNumber} · ${student.departmentOrNA} · ${student.classOrNA}',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge.status(style: student.status.style),
                        Text(
                          student.contactOrNA,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (data.headerTrailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                data.headerTrailing!,
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (data.assignment != null) ...[
          _Surface(
            child: MonthlyHoursMeter(
              verifiedHours: verified,
              maxMonthlyHours: data.maxMonthlyHours,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _assignmentSection(context),
          const SizedBox(height: AppSpacing.lg),
        ] else ...[
          _Surface(
            child: MonthlyHoursMeter(
              verifiedHours: 0,
              maxMonthlyHours: data.maxMonthlyHours,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No active assignment',
            message: 'This student is not yet assigned to a work location.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _historySection(context),
      ],
    );
  }

  Widget _assignmentSection(BuildContext context) {
    final assignment = data.assignment!;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            eyebrow: 'ASSIGNMENT',
            title: 'Current duty',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: assignment.locationName.isNotEmpty
                ? assignment.locationName
                : 'Assigned location',
          ),
          _InfoRowIcon(
            icon: Icons.schedule,
            label: 'Shift window',
            value: assignment.shiftLabel,
          ),
          _InfoRowIcon(
            icon: Icons.badge_outlined,
            label: 'In-charge',
            value: assignment.supervisorName.isNotEmpty
                ? assignment.supervisorName
                : 'Unassigned',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            assignment.workDescription,
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _historySection(BuildContext context) {
    final records = data.records;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: 'ATTENDANCE',
          title: '${_monthLabel()} register',
          trailing: records.isEmpty
              ? null
              : Text(
                  '${records.length} days',
                  style: AppTextStyles.labelMedium,
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (records.isEmpty)
          const EmptyState(
            icon: Icons.event_note_outlined,
            title: 'No attendance recorded',
            message: 'Verified attendance for this student will appear here.',
          )
        else
          _Surface(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < records.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.divider),
                  _HistoryRow(
                    record: records[i],
                    resolveEvidence: data.resolveEvidence,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _monthLabel() {
    final month = data.month ?? DateTime.now();
    return DateFormat('MMMM yyyy').format(month);
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.padding = const EdgeInsets.all(AppSpacing.lg)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.slate),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 96,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRowIcon extends StatelessWidget {
  const _InfoRowIcon({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _InfoRow(icon: icon, label: label, value: value);
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, this.resolveEvidence});

  final AttendanceRecord record;
  final DayEvidenceResolver? resolveEvidence;

  static final DateFormat _clock = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.fromAttendance(record.status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, d MMM').format(record.date),
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                if (record.location != null) ...[
                  const SizedBox(height: 1),
                  Text(record.location!, style: AppTextStyles.bodySmall),
                ],
                if (record.hasAnyTime) ...[
                  const SizedBox(height: 3),
                  _TimesLine(record: record),
                ],
                if (record.exception != null && record.exception!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 13, color: AppColors.clay),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          record.exception!,
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.clay),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusBadge.status(style: style),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    record.hours > 0 ? '${record.hours.toStringAsFixed(1)}h' : '—',
                    style: AppTextStyles.statSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _DayEvidenceThumb(
                record: record,
                resolve: resolveEvidence,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Attended 6:02 PM · Left 8:01 PM" — the two measured times of the day, in
/// Space Grotesk. A missing check-in or check-out reads "—" rather than being
/// hidden, so a half-recorded day is visibly half-recorded.
class _TimesLine extends StatelessWidget {
  const _TimesLine({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final checkIn = record.checkIn;
    final checkOut = record.checkOut;

    return DefaultTextStyle.merge(
      style: AppTextStyles.statInline.copyWith(color: AppColors.slate),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          Text('Attended ${checkIn == null ? '—' : _HistoryRow._clock.format(checkIn)}'),
          Text('·', style: AppTextStyles.statInline.copyWith(color: AppColors.divider)),
          Text('Left ${checkOut == null ? '—' : _HistoryRow._clock.format(checkOut)}'),
        ],
      ),
    );
  }
}

/// Per-day duty photograph, resolved lazily so opening a month-long register
/// does not fan out one request per row.
///
/// Three honest outcomes, never a broken image:
///   - a photograph was expected and resolved  -> the image
///   - a photograph was expected but is missing -> "Photo not available"
///   - no photograph was ever expected          -> nothing rendered
class _DayEvidenceThumb extends StatelessWidget {
  const _DayEvidenceThumb({required this.record, this.resolve});

  final AttendanceRecord record;
  final DayEvidenceResolver? resolve;

  @override
  Widget build(BuildContext context) {
    final resolve = this.resolve;
    if (resolve == null || !record.expectsEvidence) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      key: ValueKey('day-evidence-${record.id}'),
      width: 132,
      child: FutureBuilder<String?>(
        future: resolve(record),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ThumbShell(
              key: ValueKey('evidence-pending'),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const _ThumbShell(
              key: ValueKey('evidence-unavailable'),
              child: Text('Photo not available', style: AppTextStyles.labelSmall),
            );
          }
          return ClipRRect(
            key: ValueKey('evidence-image'),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              height: 56,
              width: 132,
              errorBuilder: (context, error, stack) => const _ThumbShell(
                key: ValueKey('evidence-unavailable'),
                child: Text('Photo not available', style: AppTextStyles.labelSmall),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThumbShell extends StatelessWidget {
  const _ThumbShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}