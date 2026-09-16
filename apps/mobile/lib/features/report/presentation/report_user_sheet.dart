import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../data/report_repository.dart';
import 'report_sheet_widgets.dart';

/// Bottom sheet for reporting a user — companion to [ReportActivitySheet].
/// Same modal-sheet design avoids the `Navigator` key-collision assertion
/// that the old `/report/:type/:name` route form suffered under
/// double-tap / push race.
///
/// User-specific reasons: harassment, impersonation, inappropriate profile,
/// spam. "Other" routes through the optional details field below.
class ReportUserSheet extends ConsumerStatefulWidget {
  const ReportUserSheet({super.key, required this.userId, required this.userName});

  /// Backend auth uid — sent as the report target. Never the display name.
  final String userId;
  final String userName;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String userName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => ReportUserSheet(userId: userId, userName: userName),
    );
  }

  @override
  ConsumerState<ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends ConsumerState<ReportUserSheet> {
  final _detailsController = TextEditingController();
  String? _reason;
  bool _submitting = false;

  static const _reasons = [
    'Harassment',
    'Impersonation',
    'Inappropriate profile',
    'Spam',
    'Other',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      HapticFeedback.lightImpact();
      AppSnackbar.show(
        context,
        message: 'Please select a reason.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(reportRepositoryProvider).submit(
        targetId: widget.userId,
        targetType: ReportTargetType.user,
        reason: _reason!,
        details: _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackbar.show(
        context,
        message: 'Could not submit report. Check your connection and try again.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();
    AppSnackbar.show(
      context,
      message: 'Report submitted. Thank you.',
      variant: AppSnackbarVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          boxShadow: AppShadows.sheet,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReportSheetHeader(
              title: 'Report User',
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x5,
                  AppSpacing.x2,
                  AppSpacing.x5,
                  AppSpacing.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReportTargetCard(
                      heading: 'Reporting this user',
                      targetName: widget.userName,
                      icon: Icons.person_off_rounded,
                    ),
                    const SizedBox(height: AppSpacing.x5),
                    Text(
                      "What's the issue?",
                      style: AppTypography.labelField(context).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    ReportReasonsCard(
                      reasons: _reasons,
                      selected: _reason,
                      onSelect: (r) => setState(() => _reason = r),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    ReportDetailsField(controller: _detailsController),
                    const SizedBox(height: AppSpacing.x4),
                    const ReportDisclaimer(),
                  ],
                ),
              ),
            ),
            ReportSubmitBar(submitting: _submitting, onSubmit: _submit),
          ],
        ),
      ),
    );
  }
}
