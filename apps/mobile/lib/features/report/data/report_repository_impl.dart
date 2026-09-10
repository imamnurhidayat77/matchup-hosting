import 'report_repository.dart';

/// Offline-only [ReportRepository]. Reads are N/A; writes throw.
/// The app **always** talks to the live backend for reports — a
/// report must never be faked as submitted.
class LocalReportRepository implements ReportRepository {
  @override
  Future<void> submit({
    required String targetId,
    required ReportTargetType targetType,
    required String reason,
    String? details,
  }) async {
    throw StateError(
      'ReportRepository.submit() requires a live backend — no offline '
      'fallback is provided.',
    );
  }
}
