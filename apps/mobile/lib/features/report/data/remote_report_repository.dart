import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'dummy_report_repository.dart';
import 'report_repository.dart';

/// HTTP-backed [ReportRepository].
///
/// Submits to `POST /api/v1/reports` with a JSON body. Falls back to
/// [DummyReportRepository] on network failure so the UI always closes —
/// a report submission silently failing is acceptable UX; the user has
/// already signalled their intent and the local state (sheet dismisses,
/// success snackbar) should not be blocked by a transient error.
///
/// If the backend uses separate endpoints per target type, swap the single
/// path for a switch on [ReportTargetType] here without touching the UI.
class RemoteReportRepository implements ReportRepository {
  RemoteReportRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;
  final _dummy = DummyReportRepository();

  @override
  Future<void> submit({
    required String targetId,
    required ReportTargetType targetType,
    required String reason,
    String? details,
  }) async {
    try {
      await _client.dio.post(
        '/reports',
        data: {
          'target_id': targetId,
          'target_type': targetType.name, // 'user' | 'activity'
          'reason': reason,
          if (details != null && details.isNotEmpty) 'details': details,
        },
      );
    } on DioException catch (e, st) {
      debugPrint('[RemoteReportRepository.submit] DioException: $e\n$st');
      await _dummy.submit(
        targetId: targetId,
        targetType: targetType,
        reason: reason,
        details: details,
      );
    } catch (e, st) {
      debugPrint('[RemoteReportRepository.submit] unexpected: $e\n$st');
      await _dummy.submit(
        targetId: targetId,
        targetType: targetType,
        reason: reason,
        details: details,
      );
    }
  }
}
