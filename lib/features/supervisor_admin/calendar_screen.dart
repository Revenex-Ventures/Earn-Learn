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

/// Month-navigable calendar of institutional rule days (off days, holidays,
/// paid festivals) pulled from the calendar repository.
class AdminCalendarScreen extends ConsumerStatefulWidget {
  const AdminCalendarScreen({super.key});

  @override
  ConsumerState<AdminCalendarScreen> createState() => _AdminCalendarScreenState();
}

class _AdminCalendarScreenState extends ConsumerState<AdminCalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(_adminCalendarProvider(_month));

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading calendar…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (events) => _build(context, events),
    );
  }

  Widget _build(BuildContext context, List<CalendarEvent> events) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ContextHeader(
              greeting: 'Institutional calendar',
              trailing: AdminIdentityAvatar(),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              eyebrow: 'MONTHLY RULE DAYS',
              title: 'Off days & holidays',
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                  color: AppColors.ink,
                  tooltip: 'Previous month',
                ),
                Expanded(
                  child: SectionHeader(
                    title: DateFormat('MMMM yyyy').format(_month),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right),
                  color: AppColors.ink,
                  tooltip: 'Next month',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (events.isEmpty)
              const EmptyState(
                icon: Icons.event_note_outlined,
                title: 'No closures',
                message: 'No institutional off or holiday days for this month.',
              )
            else
              for (var i = 0; i < events.length; i++) ...[
                _EventRow(event: events[i]),
                if (i != events.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}

final _adminCalendarProvider = FutureProvider.autoDispose
    .family<List<CalendarEvent>, DateTime>((ref, month) async {
  final calendar = ref.watch(calendarRepositoryProvider);
  return calendar.eventsForMonth(DateTime(month.year, month.month));
});

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final style = event.type.style;
    return ListRow(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm - 4),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          '${event.date.day}',
          style: AppTextStyles.statSmall,
        ),
      ),
      title: event.label,
      subtitle: DateFormat('EEEE, d MMM yyyy').format(event.date),
      status: StatusBadge.status(style: style),
      trailing: event.isPaid
          ? StatusBadge(
              label: 'Paid',
              style: styleFor(
                StatusTone.positive,
                icon: Icons.payments_outlined,
                label: 'Paid',
              ),
            )
          : null,
      showChevron: false,
    );
  }
}