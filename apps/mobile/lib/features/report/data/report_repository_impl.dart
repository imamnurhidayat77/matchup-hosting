import 'report_repository.dart';

/// In-memory [ReportRepository] — always succeeds after a short delay.
/// Used in development when [Env.useRemoteApi] is false.
class LocalReportRepository implements ReportRepository {
  @override
  Future<void> submit({
    required String targetId,
    required ReportTargetType targetType,
    required String reason,
    String? details,
  }) async {
    // Simulate network latency so the loading state is visible in tests.
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }
}
