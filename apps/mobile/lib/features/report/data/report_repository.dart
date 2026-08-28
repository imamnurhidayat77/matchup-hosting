/// The kind of content being reported.
enum ReportTargetType { user, activity }

/// Abstract contract for submitting moderation reports.
///
/// Implementations: [DummyReportRepository] (no-op, always succeeds),
/// [RemoteReportRepository] (live API).
abstract class ReportRepository {
  /// Submits a report for a user or activity.
  ///
  /// [targetId]   — user ID or activity ID being reported.
  /// [targetType] — discriminates between user and activity reports.
  /// [reason]     — the selected reason string shown to the moderator.
  /// [details]    — optional free-text elaboration from the reporter.
  Future<void> submit({
    required String targetId,
    required ReportTargetType targetType,
    required String reason,
    String? details,
  });
}
