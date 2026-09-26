import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../../shared/mock_data/mock_data.dart';
import '../dev_only.dart';

@DevOnly('Synthesized monthly calendar: weekly Sundays, state holidays, paid '
    'foundation day. No leave fixtures exist yet.')
class LocalCalendarRepository implements CalendarRepository {
  const LocalCalendarRepository();

  @override
  Future<List<CalendarEvent>> eventsForMonth(DateTime month) async =>
      mockMonthCalendar(month);

  @override
  Future<List<LeaveRequest>> leavesFor({
    required String studentId,
    required DateTime month,
  }) async =>
      const <LeaveRequest>[];
}