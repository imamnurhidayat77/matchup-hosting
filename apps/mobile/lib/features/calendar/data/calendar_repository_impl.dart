import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../domain/calendar_event.dart';
import 'calendar_repository.dart';

/// Offline-only calendar store. Reads return empty, writes no-op.
class LocalCalendarRepository implements CalendarRepository {
  @override
  Future<List<CalendarEvent>> upcoming({int days = 30}) async {
    return const <CalendarEvent>[];
  }

  @override
  Future<void> addToDeviceCalendar(CalendarEvent event) async {}
}

class RemoteCalendarRepository implements CalendarRepository {
  RemoteCalendarRepository({ApiClient? client, CalendarRepository? fallback})
    : _client = client ?? ApiClient.instance,
      _fallback = fallback ?? LocalCalendarRepository();

  final ApiClient _client;
  final CalendarRepository _fallback;

  @override
  Future<List<CalendarEvent>> upcoming({int days = 30}) async {
    try {
      final res = await _client.dio.get(
        '/calendar/upcoming',
        queryParameters: {'days': days},
      );
      return apiDataList(res.data).map(_parse).toList();
    } catch (e, st) {
      debugPrint('[RemoteCalendarRepository] $e\n$st');
      return _fallback.upcoming(days: days);
    }
  }

  @override
  Future<void> addToDeviceCalendar(CalendarEvent event) async {
    try {
      await _client.dio.post('/calendar/sync', data: _toJson(event));
    } catch (e, st) {
      debugPrint('[RemoteCalendarRepository] $e\n$st');
      await _fallback.addToDeviceCalendar(event);
    }
  }

  CalendarEvent _parse(dynamic raw) {
    final json = raw as Map<String, dynamic>;
    return CalendarEvent(
      id: json['id']?.toString() ?? '',
      activityId: json['activity_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      start:
          DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime.now(),
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
