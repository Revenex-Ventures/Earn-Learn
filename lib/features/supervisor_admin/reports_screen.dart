import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import '../../core/routing/route_paths.dart';
import '../../data/data.dart';
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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const InitialsBubble(
                  initials: 'SD',
                  gradient: AppColors.heroForest,
                  foreground: AppColors.onHeroWarm,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Program office',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.slate,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Attendance report',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _RoundIcon(
                  icon: Icons.settings_outlined,
                  onTap: () => context.go(RoutePaths.adminProfile),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionEyebrow(
                eyebrow: 'Coverage', title: 'Reported density'),
            MetricTileGrid(
              items: [
                MetricTileData(
                  label: 'Students',
                  value: '${data.students.length}',
                  desc: 'enrolled',
                  tone: BadgeTone.forest,
                ),
                MetricTileData(
                  label: 'Locations',
                  value: '${data.locations.length}',
                  desc: 'duty sites',
                  tone: BadgeTone.slate,
                ),
                MetricTileData(
                  label: 'Assignments',
                  value: '${data.assignments.length}',
                  desc: 'allotments',
                  tone: BadgeTone.slate,
                ),
                MetricTileData(
                  label: 'Staffed',
                  value: '$staffed',
                  desc: 'with supervisor',
                  tone: BadgeTone.forest,
                ),
              ],
            ),
            const SectionEyebrow(
              eyebrow: 'Coverage',
              title: 'Students per location',
            ),
            Column(
              children: [
                for (var i = 0; i < data.locations.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _DensityRow(
                    location: data.locations[i],
                    studentCount: data.assignments
                        .where((a) => a.locationId == data.locations[i].id)
                        .length,
                  ),
                ],
              ],
            ),
            const SectionEyebrow(
              eyebrow: 'Disbursement',
              title: 'Monthly disbursement',
            ),
            if (data.payroll == null)
              const NoteBox(
                text:
                    'No payroll rollup has been generated for this month yet.',
                icon: Icons.payments_outlined,
              )
            else
              _DisbursementCard(payroll: data.payroll!),
            const SectionEyebrow(
              eyebrow: 'Not available',
              title: 'Not yet derivable',
            ),
            const NoteBox(
              text:
                  'Day-level Present / Hours / Approved / Pending totals require '
                  'verified attendance registers, which are not available in the '
                  'current data.',
              icon: Icons.event_busy_outlined,
            ),
            const SizedBox(height: 10),
            const NoteBox(
              text:
                  'Adherence % is not available — it needs school-day '
                  'normalization across verified registers, which is not '
                  'derivable from the current data.',
              icon: Icons.trending_down_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps a payroll disbursement state to the kit badge palette.
BadgeTone _payrollTone(PaymentStatus status) => switch (status) {
      PaymentStatus.pending => BadgeTone.gold,
      PaymentStatus.inProgress => BadgeTone.info,
      PaymentStatus.approved => BadgeTone.forest,
      PaymentStatus.paid => BadgeTone.forest,
      PaymentStatus.held => BadgeTone.clay,
    };

/// Students-per-location row from the real assignment directory.
class _DensityRow extends StatelessWidget {
  const _DensityRow({required this.location, required this.studentCount});

  final Location location;
  final int studentCount;

  @override
  Widget build(BuildContext context) {
    final staffed = studentCount > 0;
    return AccentRow(
      accent: staffed ? AppColors.forestSoft : AppColors.slateWarm,
      lead: WarmIconWell(
        icon: Icons.location_on_outlined,
        background: staffed ? const Color(0xFFE7F1EA) : AppColors.warmIvory,
        foreground: staffed ? AppColors.forestSoft : AppColors.slateWarm,
      ),
      title: location.name,
      subtitle: location.description ?? 'Campus work area',
      trailing: Text(
        '$studentCount students',
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.slateWarm,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// The real monthly payroll rollup, rendered as a warm ivory summary card.
class _DisbursementCard extends StatelessWidget {
  const _DisbursementCard({required this.payroll});

  final PayrollRecord payroll;

  @override
  Widget build(BuildContext context) {
    final currency = _AdminReportsView._currency;
    return WarmCard(
      ivory: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Estimated payable'),
                    const SizedBox(height: 4),
                    Text(
                      '₹${currency.format(payroll.estimatedPayable.toInt())}',
                      style: const TextStyle(
                        fontFamily: AppTextStyles.monoFamily,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppColors.inkWarm,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              PremiumBadge(
                label: payroll.status.label,
                tone: _payrollTone(payroll.status),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const HairDivider(),
          InfoLine(
              label: 'Enrolled students', value: '${payroll.studentCount}'),
          const HairDivider(),
          InfoLine(
              label: 'Present days (avg)', value: '${payroll.presentDays}'),
          const HairDivider(),
          InfoLine(label: 'Paid holidays', value: '${payroll.paidHolidays}'),
          const HairDivider(),
          InfoLine(
            label: 'Rate per day',
            value: '₹${currency.format(payroll.ratePerDay.toInt())}',
          ),
        ],
      ),
    );
  }
}
/// Small round outlined icon button used in the page header.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}
