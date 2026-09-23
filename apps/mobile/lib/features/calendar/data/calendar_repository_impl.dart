import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../activities/domain/activity_model.dart';
import '../../discovery/data/activity_repository.dart';
import '../domain/calendar_event.dart';
import 'calendar_repository.dart';

/// Offline-only calendar store. Reads return empty, writes report
/// failure — going offline never throws: [upcoming] resolves to an
/// empty list and [addToDeviceCalendar] returns false instead of
/// touching the OS calendar. UID resolution is unchanged (both this
/// repo and My Games read the signed-in uid from [SecureTokenStore] —
/// My Games via `myGamesUidProvider`, this repo directly — so they
/// always agree).
class LocalCalendarRepository implements CalendarRepository {
  @override
  Future<List<CalendarEvent>> upcoming({int days = 30}) async {
    return const <CalendarEvent>[];
  }

  @override
  Future<bool> addToDeviceCalendar(CalendarEvent event) async => false;
}

class RemoteCalendarRepository implements CalendarRepository {
  RemoteCalendarRepository({
    ApiClient? client,
    CalendarRepository? fallback,
    ActivityRepository? activities,
  })  : _client = client ?? ApiClient.instance,
        _fallback = fallback ?? LocalCalendarRepository(),
        _activities = activities; // ignore: prefer_initializing_formals

  final ApiClient _client;
  final CalendarRepository _fallback;

  /// Source of committed games. Injected (instead of constructed) so
  /// tests can substitute a fake. Null = legacy backend mode.
  final ActivityRepository? _activities;

  /// Activity ids successfully written to the OS calendar this
  /// session, surfaced as `addedToDeviceCalendar` checkmarks.
  final Set<String> _syncedIds = {};

  @override
  Future<List<CalendarEvent>> upcoming({int days = 30}) async {
    // Prefer the dedicated endpoint when the backend offers it
    // (`GET /api/calendar/upcoming`). It does not exist on current
    // backends (404), so any transport failure falls through to the
    // derivation below — never to an empty screen or a throw.
    try {
      final res = await _client.dio.get(
        '/calendar/upcoming',
        queryParameters: {'days': days},
      );
      return apiDataList(res.data).map(_parse).toList();
    } catch (e, st) {
      debugPrint('[RemoteCalendarRepository.upcoming:endpoint] $e\n$st');
    }

    final activities = _activities;
    // No injected source → legacy backend mode with no derivation
    // possible: degrade to the offline store (empty, never throws).
    if (activities == null) {
      return _fallback.upcoming(days: days);
    }

    // Derive from committed games (joined + hosted): always consistent
    // with My Games, works offline from cache, no backend endpoint.
    try {
      final uid = await SecureTokenStore.instance.readUserId() ?? '';
      final results = await Future.wait([
        activities.joinedByUser(uid),
        activities.hostedByUser(uid),
      ]);
      final now = DateTime.now();
      final horizon = now.add(Duration(days: days));
      final seen = <String>{};
      final events = <CalendarEvent>[];
      // Joined and hosted are added in separate loops so the hosted
      // flag survives dedup (a game appearing in both reads as hosted).
      for (final activity in results[1]) {
        if (!seen.add(activity.id)) continue;
        if (activity.endTime.isBefore(now)) continue;
        if (activity.dateTime.isAfter(horizon)) continue;
        events.add(
          CalendarEvent(
            id: activity.id,
            activityId: activity.id,
            title: activity.title,
            start: activity.dateTime,
            end: activity.endTime,
            location: activity.location,
            addedToDeviceCalendar: _syncedIds.contains(activity.id),
            isHost: true,
            isPast: activity.status == ActivityStatus.past,
          ),
        );
      }
      for (final activity in results[0]) {
        if (!seen.add(activity.id)) continue;
        if (activity.endTime.isBefore(now)) continue;
        if (activity.dateTime.isAfter(horizon)) continue;
        events.add(
          CalendarEvent(
            id: activity.id,
            activityId: activity.id,
            title: activity.title,
            start: activity.dateTime,
            end: activity.endTime,
            location: activity.location,
            addedToDeviceCalendar: _syncedIds.contains(activity.id),
            isPast: activity.status == ActivityStatus.past,
          ),
        );
      }
      events.sort((a, b) => a.start.compareTo(b.start));
      return events;
    } catch (e, st) {
      debugPrint('[RemoteCalendarRepository.upcoming] $e\n$st');
      return _fallback.upcoming(days: days);
    }
  }

  @override
  Future<bool> addToDeviceCalendar(CalendarEvent event) async {
    try {
      final ok = await CalendarService.instance.addEvent(
        title: event.title,
        start: event.start,
        end: event.end,
        description: 'MatchUp activity',
        location: event.location.isNotEmpty ? event.location : null,
      );
      if (ok) _syncedIds.add(event.activityId);
      return ok;
    } catch (e, st) {
      debugPrint('[RemoteCalendarRepository] $e\n$st');
      return _fallback.addToDeviceCalendar(event);
    }
  }

  CalendarEvent _parse(dynamic raw) {
    final json = raw as Map<String, dynamic>;
    // Backend sends UTC ISO (`Z`); convert to device-local ONCE here so
    // calendar rows render correct local times. Unparseable timestamps
    // fall back to a far-future sentinel (NOT now) so corrupt rows sort
    // last instead of masquerading as starting now.
    return CalendarEvent(
      id: json['id']?.toString() ?? '',
      activityId: json['activity_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      start:
          DateTime.tryParse(json['start'] as String? ?? '')?.toLocal() ??
              DateTime(2100),
      end:
          DateTime.tryParse(json['end'] as String? ?? '')?.toLocal() ??
              DateTime(2100),
      location: json['location'] as String? ?? '',
      addedToDeviceCalendar: json['synced'] as bool? ?? false,
    );
  }

}
