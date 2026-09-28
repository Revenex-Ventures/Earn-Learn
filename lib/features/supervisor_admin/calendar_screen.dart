import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Institutional calendar'),
                      const SizedBox(height: 2),
                      Text(
                        'Rule days',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const AdminIdentityAvatar(),
              ],
            ),
            const SectionEyebrow(
              eyebrow: 'Monthly rule days',
              title: 'Off days & holidays',
            ),
            WarmCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.inkWarm,
                    tooltip: 'Previous month',
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_month),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right),
                    color: AppColors.inkWarm,
                    tooltip: 'Next month',
                  ),
                ],
              ),
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
                if (i != events.length - 1) const SizedBox(height: 10),
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

/// Maps an event category to its warm-premium tone + accent colour.
({BadgeTone tone, Color accent}) _toneFor(CalendarEventType type) {
  return switch (type) {
    CalendarEventType.offDay => (tone: BadgeTone.slate, accent: AppColors.slateWarm),
    CalendarEventType.holiday => (tone: BadgeTone.clay, accent: AppColors.claySoftReject),
    CalendarEventType.festival => (tone: BadgeTone.gold, accent: AppColors.goldSoftAccent),
    CalendarEventType.event => (tone: BadgeTone.forest, accent: AppColors.forestSoft),
  };
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final t = _toneFor(event.type);
    return AccentRow(
      accent: t.accent,
      lead: _DayBadge(day: event.date.day, accent: t.accent),
      title: event.label,
      subtitle: DateFormat('EEEE, d MMM yyyy').format(event.date),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PremiumBadge(label: event.type.label, tone: t.tone),
          if (event.isPaid) ...[
            const SizedBox(height: 5),
            const PremiumBadge(label: 'Paid', tone: BadgeTone.forest, dot: true),
          ],
        ],
      ),
    );
  }
}

/// Rounded tinted square showing the day-of-month for a calendar event.
class _DayBadge extends StatelessWidget {
  const _DayBadge({required this.day, required this.accent});

  final int day;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        '$day',
        style: AppTextStyles.statSmall.copyWith(
          fontFamily: AppTextStyles.monoFamily,
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
