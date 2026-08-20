import '../../../core/network/api_client.dart';
import '../domain/calendar_event.dart';
import 'calendar_repository.dart';

class DummyCalendarRepository implements CalendarRepository {
  final List<CalendarEvent> _events = [
    CalendarEvent(
      id: '1',
      activityId: '1',
      title: 'Saturday 5v5 Basketball',
      start: DateTime.now().add(const Duration(days: 1, hours: 2)),
      end: DateTime.now().add(const Duration(days: 1, hours: 4)),
      location: 'Central Park Court B, NY',
    ),
    CalendarEvent(
      id: '2',
      activityId: '3',
      title: 'Tennis Singles Sunday',
      start: DateTime.now().add(const Duration(days: 4)),
      end: DateTime.now().add(const Duration(days: 4, hours: 2)),
      location: 'Auckland Domain Tennis Centre',
    ),
    CalendarEvent(
      id: '3',
      activityId: '2',
      title: 'Sunset Basketball 5v5',
      start: DateTime.now().add(const Duration(days: 3, hours: 4)),
      end: DateTime.now().add(const Duration(days: 3, hours: 6)),
      location: 'Brooklyn Public Courts',
    ),
  ];

  @override
  Future<List<CalendarEvent>> upcoming({int days = 30}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_events);
  }

  @override
  Future<void> addToDeviceCalendar(CalendarEvent event) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

class RemoteCalendarRepository implements CalendarRepository {
  RemoteCalendarRepository({ApiClient? client, CalendarRepository? fallback})
      : _client = client ?? ApiClient.instance,
        _fallback = fallback ?? DummyCalendarRepository();

  final ApiClient _client;
  final CalendarRepository _fallback;

  @override
  Future<List<CalendarEvent>> upcoming({int days = 30}) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/calendar/upcoming',
        queryParameters: {'days': days},
      );
      return (res.data as List).map(_parse).toList();
    } catch (_) {
      return _fallback.upcoming(days: days);
    }
  }

  @override
  Future<void> addToDeviceCalendar(CalendarEvent event) async {
    try {
      await _client.dio.post('/api/v1/calendar/sync', data: _toJson(event));
    } catch (_) {
      await _fallback.addToDeviceCalendar(event);
    }
  }

  CalendarEvent _parse(dynamic raw) {
    final json = raw as Map<String, dynamic>;
    return CalendarEvent(
      id: json['id']?.toString() ?? '',
      activityId: json['activity_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      start: DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(json['end'] as String? ?? '') ?? DateTime.now(),
      location: json['location'] as String? ?? '',
      addedToDeviceCalendar: json['synced'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _toJson(CalendarEvent e) => {
        'activity_id': e.activityId,
        'title': e.title,
        'start': e.start.toIso8601String(),
        'end': e.end.toIso8601String(),
        'location': e.location,
      };
}
