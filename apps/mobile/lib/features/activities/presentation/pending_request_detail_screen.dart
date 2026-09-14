import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/skeleton.dart';
import '../../discovery/domain/activity_model.dart';

/// Read-only detail for an activity the viewer requested to join but
/// the host hasn't approved yet.
///
/// Deliberately sparse: no chat entry, no check-in, no join actions —
/// the viewer isn't a participant. The only action is cancelling the
/// request (backend deletes the pending row via `leave`). All colors
/// come from theme tokens for dark-mode parity.
class PendingRequestDetailScreen extends ConsumerWidget {
  const PendingRequestDetailScreen({super.key, required this.activityId});
  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_pendingDetailProvider(activityId));
    return AppScaffold(
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: async.when(
        loading: () => const SkeletonList(count: 3),
        error: (_, _) => ErrorRetry(
          message: 'Could not load this activity.',
          onRetry: () =>
              ref.invalidate(_pendingDetailProvider(activityId)),
        ),
        data: (activity) {
          if (activity == null) {
            return const Center(child: Text('Activity not found.'));
          }
          return _PendingBody(activity: activity);
        },
      ),
    );
  }
}

final _pendingDetailProvider = FutureProvider.autoDispose
    .family<ActivityModel?, String>((ref, id) {
  return ref.watch(activityRepositoryProvider).byId(id);
});

class _PendingBody extends ConsumerWidget {
  const _PendingBody({required this.activity});
  final ActivityModel activity;

  Future<void> _cancelRequest(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Cancel Request?',
      body:
          'Your join request for "${activity.title}" will be withdrawn. You can request again later.',
      confirmLabel: 'Cancel Request',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(activityRepositoryProvider).leave(activity.id);
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'Request withdrawn.',
        variant: AppSnackbarVariant.success,
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not withdraw. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat('EEEE, MMMM d').format(activity.dateTime);
    final time = DateFormat('h:mm a').format(activity.dateTime);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                activity.coverImageUrl != null
                    ? AssetImageWithFallback(
                        imagePath: activity.coverImageUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: context.colors.primarySoft,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.sports_basketball_rounded,
                          size: 56,
                          color: context.colors.primaryOnSurface,
                        ),
                      ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.x4),
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.scrimControl,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.input),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x4,
              AppSpacing.x5,
              AppSpacing.x8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status banner
                Container(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: context.colors.warningBg,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: context.colors.warningText
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        size: 22,
                        color: context.colors.warningText,
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Waiting for host approval',
                              style: AppTypography.labelField(context).copyWith(
                                color: context.colors.warningText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'You can look around, but chat and check-in unlock after approval.',
                              style: AppTypography.metaSub(context).copyWith(
                                color: context.colors.warningText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),

                Text(
                  activity.title,
                  style: AppTypography.headingDisplay(context),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  '$date · $time',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  activity.location,
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                if (activity.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    'About this Activity',
                    style: AppTypography.titleMedium(context),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    activity.description,
                    style: AppTypography.bodyReading(context),
                  ),
                ],
                const SizedBox(height: AppSpacing.x6),

                // The only action: withdraw.
                AppButton.secondary(
                  label: 'Cancel Request',
                  onPressed: () => _cancelRequest(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
