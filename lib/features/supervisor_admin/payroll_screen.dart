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

/// Payroll payload: the current-month rollup and its payment records.
class AdminPayrollData {
  const AdminPayrollData({this.rollup, required this.records});

  final PayrollRecord? rollup;
  final List<PaymentRecord> records;
}

final _adminPayrollProvider = FutureProvider.autoDispose<AdminPayrollData>(
    (ref) async {
  final payroll = ref.watch(payrollRepositoryProvider);
  final now = DateTime.now();
  final month = DateTime(now.year, now.month);
  final rollup = await payroll.currentMonth();
  final records = await payroll.recordsForMonth(month);
  return AdminPayrollData(rollup: rollup, records: records);
});

class AdminPayrollScreen extends ConsumerWidget {
  const AdminPayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_adminPayrollProvider);

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading payroll…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (data) => _AdminPayrollView(data: data),
    );
  }
}

class _AdminPayrollView extends StatelessWidget {
  const _AdminPayrollView({required this.data});

  final AdminPayrollData data;

  static final _currency = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context) {
    final rollup = data.rollup;
    if (rollup == null) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: EmptyState(
          icon: Icons.payments_outlined,
          title: 'Payroll not available',
          message: 'No payroll rollup has been generated for this month.',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: 'Payroll',
              dateLine: DateFormat('MMMM yyyy').format(rollup.month),
              trailing: AdminIdentityAvatar(),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              eyebrow: 'MONTHLY ROLLUP',
              title: 'Disbursement summary',
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
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
                          '₹${_currency.format(rollup.estimatedPayable.toInt())}',
                          style: AppTextStyles.currencyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status', style: AppTextStyles.bodySmall),
                      StatusBadge.status(style: rollup.status.style),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            MetricGroup(
              items: [
                MetricItem(
                  label: 'Students',
                  value: '${rollup.studentCount}',
                  icon: Icons.school_outlined,
                  tone: StatusTone.neutral,
                ),
                MetricItem(
                  label: 'Present days',
                  value: '${rollup.presentDays}',
                  icon: Icons.today_outlined,
                  tone: StatusTone.neutral,
                ),
                MetricItem(
                  label: 'Paid holidays',
                  value: '${rollup.paidHolidays}',
                  icon: Icons.event_available_outlined,
                  tone: StatusTone.neutral,
                ),
                MetricItem(
                  label: 'Rate per day',
                  value: '₹${_currency.format(rollup.ratePerDay.toInt())}',
                  icon: Icons.payments_outlined,
                  tone: StatusTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              eyebrow: 'DISBURSEMENT LEDGER',
              title: 'Payment records',
              subtitle: 'Verified hours and calculated stipend per student.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.records.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No payment records',
                message: 'Per-student records for this month will appear here.',
              )
            else
              for (var i = 0; i < data.records.length; i++) ...[
                _PaymentRow(record: data.records[i]),
                if (i != data.records.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              eyebrow: 'ACTIONS',
              title: 'Disbursement approval',
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
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
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.slate,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Pending — the finance approval workflow arrives '
                          'with the disbursement stage.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.picture_as_pdf_outlined,
                              size: 18),
                          label: const Text('Export PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Approve Batch'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.record});

  final PaymentRecord record;

  @override
  Widget build(BuildContext context) {
    final amount = _AdminPayrollView._currency.format(
      record.calculatedAmount.toInt(),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          InitialsAvatar(name: record.studentName, radius: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.studentName,
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${record.verifiedHours.toStringAsFixed(1)}h verified · '
                  '${record.eligibleDays} days',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$amount',
                style: AppTextStyles.currencySmall,
              ),
              const SizedBox(height: 2),
              StatusBadge.status(style: record.status.style),
            ],
          ),
        ],
      ),
    );
  }
}