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
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
        child: NoteBox(
          text: 'No payroll rollup has been generated for this month yet.',
          icon: Icons.payments_outlined,
        ),
      );
    }

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
                        'Earnings ledger',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.slate,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        DateFormat('MMMM yyyy').format(rollup.month),
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
              eyebrow: 'Monthly rollup',
              title: 'Disbursement summary',
            ),
            WarmCard(
              ivory: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Estimated payable'),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_currency.format(rollup.estimatedPayable.toInt())}',
                          style: const TextStyle(
                            fontFamily: AppTextStyles.monoFamily,
                            fontSize: 32,
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
                    label: rollup.status.label,
                    tone: _payrollTone(rollup.status),
                  ),
                ],
              ),
            ),
            const SectionEyebrow(eyebrow: 'This month'),
            MetricTileGrid(
              items: [
                MetricTileData(
                  label: 'Students',
                  value: '${rollup.studentCount}',
                  desc: 'in rollup',
                  tone: BadgeTone.forest,
                ),
                MetricTileData(
                  label: 'Present days',
                  value: '${rollup.presentDays}',
                  desc: 'verified',
                  tone: BadgeTone.slate,
                ),
                MetricTileData(
                  label: 'Paid holidays',
                  value: '${rollup.paidHolidays}',
                  desc: 'credited',
                  tone: BadgeTone.slate,
                ),
                MetricTileData(
                  label: 'Rate / day',
                  value: '₹${_currency.format(rollup.ratePerDay.toInt())}',
                  desc: 'per present day',
                  tone: BadgeTone.gold,
                ),
              ],
            ),
            const SectionEyebrow(
              eyebrow: 'Disbursement ledger',
              title: 'Payment records',
            ),
            if (data.records.isEmpty)
              const NoteBox(
                text:
                    'Per-student records for this month will appear here once '
                    'verified hours are rolled up.',
                icon: Icons.receipt_long_outlined,
              )
            else
              Column(
                children: [
                  for (var i = 0; i < data.records.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _PaymentTicket(record: data.records[i]),
                  ],
                ],
              ),
            const SectionEyebrow(
              eyebrow: 'Actions',
              title: 'Disbursement approval',
            ),
            WarmCard(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
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
            ),
            const SizedBox(height: 12),
            const NoteBox(
              text:
                  'Provisional until the Student Development Officer approves '
                  'the month. Disbursement date is set by the SDO — currently '
                  'not scheduled.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps a payment disbursement state to the kit badge palette.
BadgeTone _payrollTone(PaymentStatus status) => switch (status) {
      PaymentStatus.pending => BadgeTone.gold,
      PaymentStatus.inProgress => BadgeTone.info,
      PaymentStatus.approved => BadgeTone.forest,
      PaymentStatus.paid => BadgeTone.forest,
      PaymentStatus.held => BadgeTone.clay,
    };

/// One per-student payment as a perforated ledger receipt. All figures are the
/// real calculated values; a missing disbursement date reads "Not scheduled".
class _PaymentTicket extends StatelessWidget {
  const _PaymentTicket({required this.record});

  final PaymentRecord record;

  @override
  Widget build(BuildContext context) {
    final currency = _AdminPayrollView._currency;
    final disbursement = record.paymentDate != null
        ? DateFormat('d MMM yyyy').format(record.paymentDate!)
        : 'Not scheduled';
    return LedgerTicket(
      eyebrow: 'Statement of hours',
      name: record.studentName,
      statusLabel: record.status.label,
      statusTone: _payrollTone(record.status),
      figures: [
        LedgerFigure(
          label: 'Verified hrs',
          value: record.verifiedHours.toStringAsFixed(1),
        ),
        LedgerFigure(label: 'Days worked', value: '${record.eligibleDays}'),
        LedgerFigure(
          label: 'Amount',
          value: '₹${currency.format(record.calculatedAmount.toInt())}',
          forest: true,
        ),
      ],
      rows: [
        InfoLineData(
          label: 'Rate applied',
          value: '₹${currency.format(record.ratePerDay.toInt())} / day',
        ),
        InfoLineData(label: 'Paid holidays', value: '${record.paidHolidays}'),
        InfoLineData(
          label: 'Disbursement',
          value: disbursement,
          valueColor: AppColors.slateWarm,
        ),
      ],
      refLeft: 'REF · ${record.receiptId ?? record.id} · ${record.studentId}',
      refRight: 'SDO sign-off',
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
