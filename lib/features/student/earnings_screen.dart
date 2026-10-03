import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../data/local/payroll_store.dart';
import '../../shared/components/components.dart';
import '../auth/auth_session.dart';

/// One student's computed earnings for a single month.
class MonthEarning {
  const MonthEarning({required this.month, required this.record});
  final DateTime month;
  final PaymentRecord record;
}

/// Current-month earnings plus recent history for the signed-in student.
class StudentEarningsData {
  const StudentEarningsData({
    required this.rate,
    required this.current,
    required this.history,
  });

  final double rate;
  final MonthEarning? current;
  final List<MonthEarning> history;
}

final _studentEarningsProvider =
    FutureProvider.autoDispose<StudentEarningsData>((ref) async {
  final payroll = ref.watch(payrollRepositoryProvider);
  final studentId = AuthSession.studentId;
  final now = DateTime.now();

  PaymentRecord? rowFor(List<PaymentRecord> rows) {
    for (final r in rows) {
      if (r.studentId == studentId) return r;
    }
    return null;
  }

  final months = <DateTime>[
    for (var i = 0; i < 4; i++) DateTime(now.year, now.month - i),
  ];

  final earnings = <MonthEarning>[];
  for (final m in months) {
    final rows = await payroll.recordsForMonth(m);
    final row = rowFor(rows);
    if (row != null) earnings.add(MonthEarning(month: m, record: row));
  }

  final current = earnings.isNotEmpty ? earnings.first : null;
  final history = earnings.length > 1
      ? earnings.sublist(1).where((e) => e.record.eligibleDays > 0).toList()
      : <MonthEarning>[];

  return StudentEarningsData(
    rate: PayrollStore.instance.effectiveRatePerDay,
    current: current,
    history: history,
  );
});

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _monthLabel(DateTime m) => '${_monthNames[m.month - 1]} ${m.year}';
String _rupees(double v) => '₹${v.toStringAsFixed(0)}';

/// Student earnings screen — reached from the profile tab. Shows the
/// current-month verified hours, eligible days and estimated stipend computed
/// from real attendance, plus a short payment history. Honest by construction:
/// figures are 0 until duty sessions are approved.
class StudentEarningsScreen extends ConsumerWidget {
  const StudentEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_studentEarningsProvider);

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: AppBar(
        backgroundColor: AppColors.warmSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('My earnings'),
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load earnings',
          message: error.toString(),
        ),
        data: (data) => _EarningsView(data: data),
      ),
    );
  }
}

class _EarningsView extends StatelessWidget {
  const _EarningsView({required this.data});

  final StudentEarningsData data;

  @override
  Widget build(BuildContext context) {
    final current = data.current;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (current == null)
              const EmptyState(
                icon: Icons.savings_outlined,
                title: 'No earnings yet',
                message:
                    'Your stipend is calculated from approved duty days. '
                    'Check in and complete verified sessions to start earning.',
              )
            else
              _CurrentMonthCard(earning: current, rate: data.rate),
            if (data.history.isNotEmpty) ...[
              const SectionEyebrow(
                  eyebrow: 'History', title: 'Previous months'),
              for (final e in data.history) ...[
                _HistoryTile(earning: e),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Stipend is paid per verified duty day at the college-configured '
              'rate. Amounts shown are estimates pending payroll approval.',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.slateWarm),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentMonthCard extends StatelessWidget {
  const _CurrentMonthCard({required this.earning, required this.rate});

  final MonthEarning earning;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final r = earning.record;
    final approved = r.status == PaymentStatus.approved;
    return WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(_monthLabel(earning.month)),
                    const SizedBox(height: 4),
                    Text(
                      _rupees(r.calculatedAmount),
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestSoft,
                      ),
                    ),
                  ],
                ),
              ),
              PremiumBadge(
                label: approved ? 'Approved' : 'In progress',
                tone: approved ? BadgeTone.forest : BadgeTone.gold,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const HairDivider(),
          InfoLine(label: 'Eligible duty days', value: '${r.eligibleDays}'),
          const HairDivider(),
          InfoLine(
            label: 'Verified hours',
            value: r.verifiedHours.toStringAsFixed(1),
          ),
          const HairDivider(),
          InfoLine(label: 'Rate per day', value: _rupees(r.ratePerDay)),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.earning});

  final MonthEarning earning;

  @override
  Widget build(BuildContext context) {
    final r = earning.record;
    final approved = r.status == PaymentStatus.approved;
    return WarmCard(
      ivory: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthLabel(earning.month),
                  style: AppTextStyles.titleSmall
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.eligibleDays} days · ${r.verifiedHours.toStringAsFixed(1)} h',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.slateWarm),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _rupees(r.calculatedAmount),
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.forestSoft,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                approved ? 'Approved' : 'In progress',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.slateWarm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
