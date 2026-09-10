import '../domain/activity_model.dart';

/// Read-only contract for unauthenticated activity discovery.
///
/// The backend's `GET /api/public/activities` endpoint serves a
/// curated, lightweight list of activities for landing pages and
/// onboarding flows — no auth required. Both
/// [RemotePublicActivityRepository] (the live HTTP path) and
/// [LocalPublicActivityRepository] (used in dev and as a fallback
/// when the request fails) implement this interface.
abstract class PublicActivityRepository {
  /// Returns a small list of recent public activities to surface in
  /// unauthenticated entry points. [limit] is bounded server-side
  /// (1–20) so callers can pass a generous default and trust the
  /// backend to clamp.
  Future<List<ActivityModel>> teasers({int limit = 10});
}
