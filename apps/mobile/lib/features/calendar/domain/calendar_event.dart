/// Domain model for a calendar entry — wraps an [ActivityModel] occurrence
/// with its scheduled start/end times and whether it has been added to the
/// device calendar.
class CalendarEvent {
  final String id;
  final String activityId;
  final String title;
  final DateTime start;
  final DateTime end;
  final String location;
  final bool addedToDeviceCalendar;

  const CalendarEvent({
    required this.id,
    required this.activityId,
    required this.title,
    required this.start,
    required this.end,
    required this.location,
    this.addedToDeviceCalendar = false,
  });
}
