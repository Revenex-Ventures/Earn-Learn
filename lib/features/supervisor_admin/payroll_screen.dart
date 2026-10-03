import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import '../../core/routing/route_paths.dart';
import '../../data/data.dart';
import '../../data/local/notification_store.dart';
import '../../data/local/payroll_store.dart';
import '../../domain/domain.dart';
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
            _PayrollActions(
              month: rollup.month,
              rollup: rollup,
              records: data.records,
            ),
            const SizedBox(height: 12),
            _ApprovalNote(month: rollup.month),
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

/// Contextual footer note: shows who approved the month, or that it is still
/// provisional. Watches [PayrollStore] via the payroll provider indirectly.
class _ApprovalNote extends StatelessWidget {
  const _ApprovalNote({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final approval = PayrollStore.instance.approvalFor(month);
    if (approval == null) {
      return const NoteBox(
        text:
            'Provisional until the Student Development Officer approves the '
            'month. Disbursement date is set by the SDO — currently not '
            'scheduled.',
      );
    }
    final when = DateFormat('d MMM yyyy').format(approval.approvedAt);
    return NoteBox(
      icon: Icons.verified_outlined,
      text:
          'Approved on $when. Prepared by ${approval.preparedBy}; approved by '
          '${approval.approvedBy}. Students have been notified.',
    );
  }
}

/// Live payroll actions: export the ledger as CSV (copied to the clipboard,
/// zero external dependencies), configure the per-day rate, and approve the
/// batch under the two-person rule.
class _PayrollActions extends ConsumerWidget {
  const _PayrollActions({
    required this.month,
    required this.rollup,
    required this.records,
  });

  final DateTime month;
  final PayrollRecord rollup;
  final List<PaymentRecord> records;

  static final _currency = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approved = PayrollStore.instance.isApproved(month);
    return WarmCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: records.isEmpty
                      ? null
                      : () => _exportCsv(context),
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('Export CSV'),
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
                  onPressed: approved ? null : () => _approve(context, ref),
                  icon: Icon(
                    approved
                        ? Icons.verified_outlined
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(approved ? 'Approved' : 'Approve Batch'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestSoft,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _editRate(context, ref),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(
                'Rate settings · ₹${_currency.format(PayrollStore.instance.effectiveRatePerDay.toInt())}/day',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildCsv() {
    final buffer = StringBuffer()
      ..writeln(
          'Student ID,Name,Eligible Days,Verified Hours,Rate Per Day,Amount,Status');
    for (final r in records) {
      final name = r.studentName.replaceAll(',', ' ');
      buffer.writeln(
          '${r.studentId},$name,${r.eligibleDays},${r.verifiedHours.toStringAsFixed(1)},'
          '${r.ratePerDay.toStringAsFixed(0)},${r.calculatedAmount.toStringAsFixed(0)},${r.status.label}');
    }
    buffer.writeln(
        'TOTAL,,${rollup.presentDays},,,${rollup.estimatedPayable.toStringAsFixed(0)},${rollup.status.label}');
    return buffer.toString();
  }

  Future<void> _exportCsv(BuildContext context) async {
    final csv = _buildCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.warmSurface,
        title: Text('${DateFormat('MMMM yyyy').format(month)} payroll CSV'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              csv,
              style: const TextStyle(
                fontFamily: AppTextStyles.monoFamily,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copied to clipboard.')),
      );
    }
  }

  Future<void> _editRate(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: PayrollStore.instance.effectiveRatePerDay.toInt().toString(),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.warmSurface,
        title: const Text('Per-day stipend rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Amount paid per verified duty day. Applies to every student '
              'without a location-specific override.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                labelText: 'Rate per day',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.forestSoft),
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              PayrollStore.instance.setRate(value);
              Navigator.of(context).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == true) {
      ref.invalidate(_adminPayrollProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate updated.')),
        );
      }
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final preparedBy = ref.read(accountDisplayNameProvider).valueOrNull ??
        'Program Office';
    final policy = ref.read(policyConfigProvider);
    final approverCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        String? error;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: AppColors.warmSurface,
            title: const Text('Approve payroll batch'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prepared by $preparedBy. A second, distinct officer must '
                  'record their name to approve this month.',
                  style: const TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: approverCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Approved by',
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestSoft),
                onPressed: () {
                  final approvedBy = approverCtrl.text.trim();
                  final decision = evaluatePayrollApproval(
                    preparedBy: preparedBy,
                    approvedBy: approvedBy,
                    policy: policy,
                  );
                  if (!decision.allowed) {
                    setState(() => error = decision.denialReason);
                    return;
                  }
                  PayrollStore.instance.approve(
                    month: month,
                    preparedBy: preparedBy,
                    approvedBy: approvedBy,
                  );
                  NotificationStore.instance.add(
                    recipientRole: UserRole.student,
                    type: NotificationType.payrollApproved,
                    title: 'Stipend approved',
                    body:
                        'Your ${DateFormat('MMMM yyyy').format(month)} stipend '
                        'has been approved by the SDO.',
                    senderName: 'Program Office',
                  );
                  Navigator.of(context).pop(true);
                },
                child: const Text('Approve'),
              ),
            ],
          ),
        );
      },
    );
    approverCtrl.dispose();
    if (result == true) {
      ref.invalidate(_adminPayrollProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(notificationUnreadProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payroll approved. Students notified.')),
        );
      }
    }
  }
}
