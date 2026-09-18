import '../domain/calendar_event.dart';

abstract class CalendarRepository {
  Future<List<CalendarEvent>> upcoming({int days = 30});

  /// Writes [event] to the device calendar. Returns true when the event
  /// was actually created, false when permission was denied, no writable
  /// calendar exists, or the write failed — so callers can surface the
  /// outcome instead of assuming success.
  Future<bool> addToDeviceCalendar(CalendarEvent event);
}
