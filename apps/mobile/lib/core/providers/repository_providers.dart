import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/data/remote_auth_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/data/calendar_repository_impl.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/chat/data/chat_repository_impl.dart';
import '../../features/discovery/data/activity_repository.dart';
import '../../features/discovery/data/activity_repository_impl.dart';
import '../../features/discovery/data/remote_activity_repository.dart';
import '../../features/notifications/data/notification_repository_impl.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/profile/data/user_repository_impl.dart';
import '../../features/profile/data/user_repository.dart';
import '../../features/report/data/report_repository_impl.dart';
import '../../features/report/data/remote_report_repository.dart';
import '../../features/report/data/report_repository.dart';
import '../config/env.dart';

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

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteActivityRepository();
  return LocalActivityRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteUserRepository();
  return LocalUserRepository();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteChatRepository();
  return LocalChatRepository();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteNotificationRepository();
  return LocalNotificationRepository();
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteCalendarRepository();
  return LocalCalendarRepository();
});

/// Report submissions: user and activity moderation reports.
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final remote = ref.watch(useRemoteApiProvider);
  if (remote) return RemoteReportRepository();
  return LocalReportRepository();
});

/// Async provider of the discovery feed. Screens read this and render based
/// on AsyncValue (loading/error/data).
final activityFeedProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.feed();
});
