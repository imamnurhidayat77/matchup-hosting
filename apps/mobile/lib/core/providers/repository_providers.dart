import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/data/remote_auth_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/data/calendar_repository_impl.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/chat/data/chat_repository_impl.dart';
import '../../features/chat/data/dm_repository.dart';
import '../../features/chat/data/local_typing_repository.dart';
import '../../features/chat/data/remote_typing_repository.dart';
import '../../features/chat/data/typing_repository.dart';
import '../../features/discovery/data/activity_repository.dart';
import '../../features/discovery/data/activity_repository_impl.dart';
import '../../features/discovery/data/local_swipes_repository.dart';
import '../../features/discovery/data/public_activity_repository.dart';
import '../../features/discovery/data/remote_activity_repository.dart';
import '../../features/discovery/data/remote_public_activity_repository.dart';
import '../../features/discovery/data/remote_swipes_repository.dart';
import '../../features/discovery/data/swipes_repository.dart';
import '../../features/activities/data/local_places_repository.dart';
import '../../features/activities/data/places_repository.dart';
import '../../features/activities/data/remote_places_repository.dart';
import '../../features/notifications/data/device_repository.dart';
import '../../features/notifications/data/local_device_repository.dart';
import '../../features/notifications/data/local_presence_repository.dart';
import '../../features/notifications/data/notification_repository_impl.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/notifications/data/presence_repository.dart';
import '../../features/notifications/data/remote_device_repository.dart';
import '../../features/notifications/data/remote_presence_repository.dart';
import '../../features/appeals/data/appeal_repository.dart';
import '../../features/sports/data/sports_repository.dart';
import '../../features/sports/domain/sport_config.dart';import '../../features/profile/data/user_repository_impl.dart';
import '../../features/profile/data/user_repository.dart';
import '../../features/ratings/data/ratings_repository.dart';
import '../../features/ratings/data/ratings_repository_impl.dart';
import '../../features/ratings/data/remote_ratings_repository.dart';
import '../../features/report/data/report_repository_impl.dart';
import '../../features/report/data/remote_report_repository.dart';
import '../../features/report/data/report_repository.dart';
import '../config/env.dart';
import 'auth_state_provider.dart';

/// Master toggle for live vs in-memory data. Set to `false` for now (backend
/// still in development) and flip to `true` once endpoints ship. Providers
/// below read this so screens never touch the flag directly.
final useRemoteApiProvider = Provider<bool>((ref) => Env.useRemoteApi);

/// Auth operations: sign-in, register, OTP, password reset.
/// All auth screens use this — never call AuthStateNotifier with local tokens
/// directly from the UI layer.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteAuthRepository();
  return LocalAuthRepository();
});

/// Repositories below are scoped to the signed-in user: every user-scoped
/// provider watches the auth uid so that an account switch (logout Benjamin
/// → login Lisa) discards the old instance — including its in-memory
/// caches (`RemoteActivityRepository._feedCache` carries Benjamin's viewer
/// context, `RemoteUserRepository._meCache` holds his profile) — and every
/// watcher (My Games tabs, chat inbox, …) refetches for the new user.
/// Without this Lisa keeps seeing Benjamin's cached My Games. Public,
/// no-auth providers (public teasers, sports config) intentionally skip it.
void _scopeToUser(Ref ref) {
  ref.watch(authStateProvider.select((s) => s.userId));
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  _scopeToUser(ref);
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteActivityRepository();
  return LocalActivityRepository();
});

/// Discovery deck swipes (left = pass, right = join). The remote flavour
/// posts to `POST /api/swipes`; the local flavour records in memory for
/// the rest of the session.
final swipesRepositoryProvider = Provider<SwipesRepository>((ref) {
  _scopeToUser(ref);
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteSwipesRepository();
  return LocalSwipesRepository();
});

/// Unauthenticated public teasers for landing / onboarding screens.
/// The remote flavour calls `GET /api/public/activities` (no auth
/// required); the local flavour reuses the seeded discovery feed.
final publicActivityRepositoryProvider = Provider<PublicActivityRepository>((
  ref,
) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemotePublicActivityRepository();
  return LocalPublicActivityRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  _scopeToUser(ref);
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteUserRepository();
  return LocalUserRepository();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  _scopeToUser(ref);
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteChatRepository();
  return LocalChatRepository();
});

/// 1-on-1 direct messages (`/api/dm/:uid/...`). Remote-only by design
/// (like chat, there is no offline fallback) — always the live repo.
final dmRepositoryProvider = Provider<DmRepository>((ref) {
  _scopeToUser(ref);
  return RemoteDmRepository();
});

/// "X is typing…" indicator for activity chats. The remote flavour
/// posts to `/api/typing`; the local flavour is in-memory.
final typingRepositoryProvider = Provider<TypingRepository>((ref) {
  _scopeToUser(ref);
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteTypingRepository();
  return LocalTypingRepository();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  _scopeToUser(ref);
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteNotificationRepository();
  return LocalNotificationRepository();
});

/// Push-notification device roster. The remote flavour posts to the
/// backend's `/api/devices` endpoints; the local flavour is an in-memory
/// list used as a fallback when the network call fails.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  _scopeToUser(ref);
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteDeviceRepository();
  return LocalDeviceRepository();
});

/// Online / offline presence. The remote flavour posts to the backend's
/// `/api/presence` endpoint; the local flavour is in-memory.
final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  _scopeToUser(ref);
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemotePresenceRepository();
  return LocalPresenceRepository();
});

/// Venue autocomplete for the create wizard. Backed by the api-server
/// `/api/places` proxy; the local fallback returns no suggestions so
/// the field degrades to plain free text.
final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  _scopeToUser(ref);
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemotePlacesRepository();
  return LocalPlacesRepository();
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) {
    return RemoteCalendarRepository(
      activities: ref.watch(activityRepositoryProvider),
    );
  }
  return LocalCalendarRepository();
});

/// Report submissions: user and activity moderation reports.
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteReportRepository();
  return LocalReportRepository();
});

/// Post-activity 1-5 rating submissions. Remote flavour posts to
/// `/api/activities/{id}/ratings`; local flavour records in memory for the
/// rest of the session.
final ratingsRepositoryProvider = Provider<RatingsRepository>((ref) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteRatingsRepository();
  return LocalRatingsRepository();
});

/// Suspension appeals. Remote-only by design — a "submitted" appeal that
/// never reaches triage would be a lie, so there is no offline fallback.
/// The unavailable repo throws a friendly [ApiException] (caught by the
/// suspended interstitial) instead of crashing offline.
final appealRepositoryProvider = Provider<AppealRepository>((ref) {
  try {
    final remote = ref.watch(useRemoteApiProvider);
    if (remote) return RemoteAppealRepository();
    return UnavailableAppealRepository();
  } catch (_) {
    return UnavailableAppealRepository();
  }
});

/// Master sports config (`GET /api/public/sports`, no auth). Screens
/// select per-surface subsets (onboarding / filter / hostable) and fall
/// back to their bundled lists while loading or offline.
final sportsRepositoryProvider = Provider<SportsRepository>((ref) {
  try {
    final remote = ref.watch(useRemoteApiProvider);
    if (remote) return RemoteSportsRepository();
    return UnavailableSportsRepository();
  } catch (_) {
    return UnavailableSportsRepository();
  }
});

final sportsConfigProvider = FutureProvider<List<SportConfig>>((ref) async {
  try {
    return await ref.watch(sportsRepositoryProvider).configs();
  } catch (_) {
    return const <SportConfig>[];
  }
});

/// Async provider of the discovery feed. Screens read this and render based
/// on AsyncValue (loading/error/data).
///
/// NOTE: no screen watches this today — `DiscoveryScreen` calls
/// `repo.feed(filter: ...)` directly so it can merge the session
/// "Start over" flag and serve the repo cache first. Kept (rather than
/// deleted) because `JoinedActivityDetailScreen` invalidates it after a
/// leave and the `discovery_feed_test.dart` contract tests read it.
/// Calls the bare feed path (no filter) — pass an explicit filter at the
/// call site if filtered reads are ever routed through here.
final activityFeedProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.feed();
});
