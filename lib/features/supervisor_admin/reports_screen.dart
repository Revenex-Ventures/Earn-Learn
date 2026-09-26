import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import 'admin_identity_avatar.dart';
import '../../shared/components/components.dart';

/// Honest report payload: real directories, assignment joins and the real
/// payroll fixture. Nothing is invented or normalized into fake ratios.
class AdminReportsData {
  const AdminReportsData({
    required this.students,
    required this.locations,
    required this.assignments,
    this.payroll,
  });

  final List<Student> students;
  final List<Location> locations;
  final List<Assignment> assignments;
  final PayrollRecord? payroll;
}

final _adminReportsProvider = FutureProvider.autoDispose<AdminReportsData>(
    (ref) async {
  final students = ref.watch(studentRepositoryProvider);
  final locations = ref.watch(locationRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);
  final payroll = ref.watch(payrollRepositoryProvider);

  return AdminReportsData(
    students: await students.all(),
    locations: await locations.all(),
    assignments: await assignments.all(),
    payroll: await payroll.currentMonth(),
  );
});

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_adminReportsProvider);

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading reports…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (data) => _AdminReportsView(data: data),
    );
  }
}

class _AdminReportsView extends StatelessWidget {
  const _AdminReportsView({required this.data});

  final AdminReportsData data;

  static final _currency = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context) {
    final staffed = data.locations
        .where((l) => data.assignments.any((a) => a.locationId == l.id))
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ContextHeader(
              greeting: 'Reports',
              trailing: AdminIdentityAvatar(),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              eyebrow: 'COVERAGE',
              title: 'Reported density',
            ),
            const SizedBox(height: AppSpacing.md),
            MetricGroup(
              items: [
                MetricItem(
                  label: 'Students',
                  value: '${data.students.length}',
                  icon: Icons.school_outlined,
                  tone: StatusTone.neutral,
                ),
                MetricItem(
                  label: 'Locations',
                  value: '${data.locations.length}',
                  icon: Icons.location_on_outlined,
                  tone: StatusTone.neutral,
                ),
                MetricItem(
                  label: 'Assignments',
                  value: '${data.assignments.length}',
                  icon: Icons.assignment_outlined,
                  tone: StatusTone.neutral,
                ),
                MetricItem(
                  label: 'Staffed locations',
                  value: '$staffed',
                  icon: Icons.storefront_outlined,
                  tone: StatusTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              eyebrow: 'COVERAGE',
              title: 'Students per location',
              subtitle: 'Real counts from the assignment directory.',
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < data.locations.length; i++) ...[
              _DensityRow(
                location: data.locations[i],
                studentCount: data.assignments
                    .where((a) => a.locationId == data.locations[i].id)
                    .length,
              ),
              if (i != data.locations.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              eyebrow: 'DISBURSEMENT',
              title: 'Monthly disbursement',
              subtitle: 'The real payroll rollup for the current month.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.payroll == null)
              const EmptyState(
                icon: Icons.payments_outlined,
                title: 'Payroll not available',
                message: 'No payroll rollup has been generated for this month.',
              )
            else
              _DisbursementSurface(payroll: data.payroll!),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              eyebrow: 'NOT AVAILABLE',
              title: 'Not yet derivable',
            ),
            const SizedBox(height: AppSpacing.md),
            const EmptyState(
              icon: Icons.trending_down_outlined,
              title: 'Adherence % not available',
              message:
                  'Requires school-day normalization across verified registers, '
                  'which is not derivable from the current data.',
            ),
          ],
        ),
      ),
    );
  }
}

class _DensityRow extends StatelessWidget {
  const _DensityRow({required this.location, required this.studentCount});

  final Location location;
  final int studentCount;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      leading: const IconWell(icon: Icons.location_on_outlined),
      title: location.name,
      subtitle: location.description ?? 'Campus work area',
      trailing: Text(
        '$studentCount students',
        style: AppTextStyles.labelMedium,
      ),
      showChevron: false,
    );
  }
}

class _DisbursementSurface extends StatelessWidget {
  const _DisbursementSurface({required this.payroll});

  final PayrollRecord payroll;

  @override
  Widget build(BuildContext context) {
    final currency = _AdminReportsView._currency;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Estimated payable',
                  style: AppTextStyles.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  '₹${currency.format(payroll.estimatedPayable.toInt())}',
                  style: AppTextStyles.currencyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.md),
          _reportRow(context, 'Enrolled students', '${payroll.studentCount}'),
          _reportRow(context, 'Present days (avg)', '${payroll.presentDays}'),
          _reportRow(context, 'Paid holidays', '${payroll.paidHolidays}'),
          _reportRow(
            context,
            'Rate per day',
            '₹${currency.format(payroll.ratePerDay.toInt())}',
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status', style: AppTextStyles.bodySmall),
              StatusBadge.status(style: payroll.status.style),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}