import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/activity_participant.dart';

typedef _ParticipantsData = ({
  List<ActivityParticipant> roster,
  int capacity,
  String activityTitle,
});

final _participantsProvider = FutureProvider.autoDispose
    .family<_ParticipantsData, String>((ref, activityId) async {
      final activityRepo = ref.watch(activityRepositoryProvider);
      final activity = await activityRepo.byId(activityId);
      final roster = await activityRepo.participants(activityId);
      return (
        roster: roster,
        capacity: activity?.capacity ?? roster.length,
        activityTitle: activity?.title ?? 'this activity',
      );
    });

class ActivityParticipantsScreen extends ConsumerWidget {
  final String activityId;

  const ActivityParticipantsScreen({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_participantsProvider(activityId));

    return AppScaffold.detail(
      title: 'Participants',
      showHomeIndicator: false, // reached from inside ShellRoute screens.
      backgroundColor: context.colors.surface,
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (_, _) => ErrorRetry(
          message: 'Could not load participants.',
          onRetry: () => ref.invalidate(_participantsProvider(activityId)),
        ),
        data: (result) {
          final roster = result.roster;
          final capacity = result.capacity;
          final fillRatio = capacity == 0
              ? 0.0
              : (roster.length / capacity).clamp(0.0, 1.0);

          return Column(
            children: [
              _CapacitySummary(
                activityTitle: result.activityTitle,
                joined: roster.length,
                capacity: capacity,
                fillRatio: fillRatio,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x4,
                    AppSpacing.x4,
                    AppSpacing.x4,
                    AppSpacing.x4,
                  ),
                  itemCount: roster.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.x3),
                  itemBuilder: (_, i) => _ParticipantCard(item: roster[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CapacitySummary extends StatelessWidget {
  const _CapacitySummary({
    required this.activityTitle,
    required this.joined,
    required this.capacity,
    required this.fillRatio,
  });

  final String activityTitle;
  final int joined;
  final int capacity;
  final double fillRatio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        0,
        AppSpacing.x5,
        AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activityTitle,
            style: AppTypography.labelField(
              context,
            ).copyWith(color: context.colors.primaryOnSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.x1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$joined/$capacity spots filled',
                style: AppTypography.bodySmall(
                  context,
                ).copyWith(color: context.colors.textSecondary),
              ),
              Text(
                '${(fillRatio * 100).round()}% full',
                style: AppTypography.chipLabel(
                  context,
                ).copyWith(color: context.colors.primaryOnSurface),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: context.colors.border),
                  FractionallySizedBox(
                    widthFactor: fillRatio,
                    child: Container(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.item});
  final ActivityParticipant item;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.push('/player-profile/${item.name}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: item.isOrganizer
              ? context.colors.primarySoft
              : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: item.isOrganizer
                ? context.colors.primaryLight
                : context.colors.border,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.asset(
                'assets/images/discovery/avatars/${item.avatarAsset}',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: AppTypography.labelField(
                            context,
                          ).copyWith(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isOrganizer) ...[
                        const SizedBox(width: AppSpacing.x1 + 2),
                        _OrganizerBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  _SkillChip(label: item.skillLevel),
                ],
              ),
            ),
            Text(
              _timeAgo(item.joinedAt),
              style: AppTypography.caption(context),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime joinedAt) {
    final diff = DateTime.now().difference(joinedAt);
    if (diff.inHours < 1) return 'Joined ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Joined ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Joined 1 day ago';
    return 'Joined ${diff.inDays} days ago';
  }
}

/// "Organizer" role badge. Raised from the original 9px to 11px per PRD
/// Section 3 — 9px sits below practical legibility.
class _OrganizerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x1 + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.colors.warningBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium,
            size: 12,
            color: AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            'Organizer',
            style: AppTypography.chipLabel(
              context,
            ).copyWith(fontSize: 11, color: AppColors.warning, height: 1.0),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.chipLabel(
          context,
        ).copyWith(fontSize: 11, color: context.colors.textSecondary),
      ),
    );
  }
}
