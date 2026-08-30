import '../domain/calendar_event.dart';

abstract class CalendarRepository {
  Future<List<CalendarEvent>> upcoming({int days = 30});
  Future<void> addToDeviceCalendar(CalendarEvent event);
}
