import '../../../core/network/api_client.dart';
import 'report_repository.dart';

/// HTTP-backed [ReportRepository].
///
/// Submits to `POST /api/reports` with a JSON body. Failures
/// propagate to the caller — the sheets translate them into an error
/// snackbar and keep the draft open, so a failed report is never
/// presented as submitted.
class RemoteReportRepository implements ReportRepository {
  RemoteReportRepository({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  @override
  Future<void> submit({
    required String targetId,
    required ReportTargetType targetType,
    required String reason,
    String? details,
  }) async {
    await _client.dio.post(
      '/reports',
      data: {
        'targetId': targetId,
        'targetType': targetType.name, // 'user' | 'activity'
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
  }
}
