import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/activity_participant.dart';
import '../../discovery/domain/activity_model.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

typedef _ReviewData = ({
  ActivityModel activity,
  List<ActivityParticipant> participants,
});

final _reviewDataProvider = FutureProvider.autoDispose
    .family<_ReviewData, String>((ref, activityId) async {
  final repo = ref.watch(activityRepositoryProvider);
  final activity = await repo.byId(activityId);
  if (activity == null) throw StateError('Activity not found');
  final participants = await repo.participants(activityId);
  return (activity: activity, participants: participants);
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class PastActivityReviewScreen extends ConsumerStatefulWidget {
  const PastActivityReviewScreen({super.key, required this.activityId});
  final String activityId;

  @override
  ConsumerState<PastActivityReviewScreen> createState() =>
      _PastActivityReviewScreenState();
}

class _PastActivityReviewScreenState
    extends ConsumerState<PastActivityReviewScreen> {
  int _stars = 4;
  final _commentController = TextEditingController();
  /// userId → star rating (1–5). Empty until user rates that participant.
  final Map<String, int> _participantRatings = {};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    AppSnackbar.show(
      context,
      message: 'Review submitted!',
      variant: AppSnackbarVariant.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_reviewDataProvider(widget.activityId));

    return AppScaffold(
      safeAreaTop: true,
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: async.when(
        loading: () => const SkeletonList(count: 4),
        error: (_, _) => ErrorRetry(
          message: 'Could not load this activity.',
          onRetry: () =>
              ref.invalidate(_reviewDataProvider(widget.activityId)),
        ),
        data: (data) => Column(
          children: [
            // Header
            _Header(),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x5,
                  AppSpacing.x4,
                  AppSpacing.x5,
                  AppSpacing.x6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity summary card
                    _SummaryCard(activity: data.activity),
                    const SizedBox(height: AppSpacing.x5),

                    // Star rating + comment
                    _RateActivitySection(
                      stars: _stars,
                      onStarTap: (i) => setState(() => _stars = i),
                      commentController: _commentController,
                    ),
                    const SizedBox(height: AppSpacing.x5),

                    // Rate participants
                    _RateParticipantsSection(
                      participants: data.participants,
                      ratings: _participantRatings,
                      onRate: (id, stars) => setState(
                        () => _participantRatings[id] = stars,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                  ],
                ),
              ),
            ),

            // Pinned submit button
            _SubmitBar(onTap: _submit),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x5,
        AppSpacing.x3,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: PressableScale(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: context.colors.border),
                  boxShadow: AppShadows.card,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              'Activity Review',
              style: AppTypography.titleSheet(context),
              textAlign: TextAlign.center,
            ),
          ),
          // Mirror spacer so title is centred
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("EEE, MMM d '•' h:mm a");

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: activity.coverImageUrl != null
                ? Image.asset(
                    activity.coverImageUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _thumbPlaceholder(),
                  )
                : _thumbPlaceholder(),
          ),
          const SizedBox(width: AppSpacing.x3),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges row
                Row(
                  children: [
                    _Pill(
                      label: activity.sportType.toUpperCase(),
                      bgColor: context.colors.primarySoft,
                      textColor: context.colors.primaryOnSurface,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    _Pill(
                      label: 'COMPLETED',
                      bgColor: context.colors.surfaceMuted,
                      textColor: context.colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),

                // Title
                Text(
                  activity.title,
                  style: AppTypography.labelField(context)
                      .copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Date
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: context.colors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      dateFmt.format(activity.dateTime),
                      style: AppTypography.metaSub(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Location
                Row(
                  children: [
                    Icon(Icons.place_outlined,
                        size: 13, color: context.colors.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        activity.location,
                        style: AppTypography.metaSub(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
    width: 72,
    height: 72,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
      ),
    ),
    alignment: Alignment.center,
    child: Icon(Icons.sports,
        size: 28, color: AppColors.textOnPrimary.withValues(alpha: 0.5)),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });
  final String label;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: AppTypography.chipLabel(context)
            .copyWith(fontSize: 10, color: textColor),
      ),
    );
  }
}

// ─── Rate activity section ────────────────────────────────────────────────────

class _RateActivitySection extends StatelessWidget {
  const _RateActivitySection({
    required this.stars,
    required this.onStarTap,
    required this.commentController,
  });

  final int stars;
  final ValueChanged<int> onStarTap;
  final TextEditingController commentController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rate this activity', style: AppTypography.titleMedium(context)),
        const SizedBox(height: AppSpacing.x4),

        // Stars — centered
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final filled = i < stars;
              return Semantics(
                button: true,
                label: '${i + 1} star${i == 0 ? '' : 's'}',
                child: AppTappable(
                  semanticLabel: '${i + 1} stars',
                  feedback: AppTapFeedback.scale,
                  onTap: () => onStarTap(i + 1),
                  minSize: 44,
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 36,
                    color: filled
                        ? AppColors.warning
                        : context.colors.textTertiary,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.x4),

        // Comment label
        Text(
          'COMMENT',
          style: AppTypography.metaSub(context).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),

        // Comment field
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          child: TextField(
            controller: commentController,
            minLines: 3,
            maxLines: 5,
            cursorColor: AppColors.primary,
            cursorWidth: 1.5,
            style: AppTypography.bodyReading(context),
            decoration: InputDecoration(
              hintText: 'Share your experience...',
              hintStyle: AppTypography.bodyReading(context).copyWith(
                color: context.colors.textTertiary,
              ),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Rate participants section ────────────────────────────────────────────────

class _RateParticipantsSection extends StatelessWidget {
  const _RateParticipantsSection({
    required this.participants,
    required this.ratings,
    required this.onRate,
  });

  final List<ActivityParticipant> participants;
  final Map<String, int> ratings;
  final void Function(String userId, int stars) onRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rate participants', style: AppTypography.titleMedium(context)),
        const SizedBox(height: AppSpacing.x1),
        Text(
          'Your ratings are anonymous and help others find great teammates.',
          style: AppTypography.metaSub(context),
        ),
        const SizedBox(height: AppSpacing.x3),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              for (var i = 0; i < participants.length; i++) ...[
                _ParticipantRow(
                  item: participants[i],
                  stars: ratings[participants[i].userId] ?? 0,
                  onRate: (s) => onRate(participants[i].userId, s),
                ),
                if (i < participants.length - 1)
                  Divider(
                    height: 1,
                    color: context.colors.border,
                    indent: AppSpacing.x4,
                    endIndent: AppSpacing.x4,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.item,
    required this.stars,
    required this.onRate,
  });

  final ActivityParticipant item;
  final int stars;       // 0 = not yet rated
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        children: [
          // Avatar
          AppAvatar(
            assetPath: 'assets/images/discovery/avatars/${item.avatarAsset}',
            name: item.name,
            size: AppAvatarSize.md,
          ),
          const SizedBox(width: AppSpacing.x3),

          // Name + skill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTypography.labelField(context)),
                Text(item.skillLevel, style: AppTypography.metaSub(context)),
              ],
            ),
          ),

          // 5-star mini row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final filled = i < stars;
              return Semantics(
                button: true,
                label: '${i + 1} star${i == 0 ? '' : 's'} for ${item.name}',
                child: AppTappable(
                  semanticLabel: '${i + 1} stars',
                  feedback: AppTapFeedback.scale,
                  onTap: () => onRate(i + 1),
                  minSize: 32,
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 22,
                    color: filled ? AppColors.warning : context.colors.textTertiary,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Submit bar ───────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x3,
        AppSpacing.x5,
        AppSpacing.x5 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: AppShadows.bottomBar,
      ),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.glowPrimary,
          ),
          alignment: Alignment.center,
          child: Text(
            'Submit Review',
            style: AppTypography.buttonPrimary,
          ),
        ),
      ),
    );
  }
}
