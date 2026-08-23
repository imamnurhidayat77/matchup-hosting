import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_tab_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/home_header.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../activities/domain/activity_model.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

const _mockUserId = 'me';

final _joinedProvider = FutureProvider.autoDispose<List<ActivityModel>>(
  (ref) => ref.watch(activityRepositoryProvider).joinedByUser(_mockUserId),
);

final _hostedProvider = FutureProvider.autoDispose<List<ActivityModel>>(
  (ref) => ref.watch(activityRepositoryProvider).hostedByUser(_mockUserId),
);

final _pastProvider = FutureProvider.autoDispose<List<ActivityModel>>(
  (ref) => ref.watch(activityRepositoryProvider).pastByUser(_mockUserId),
);

final _unreadNotifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final all = await ref.watch(notificationRepositoryProvider).all();
  return all.where((n) => n.unread).length;
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _relativeDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(dt.year, dt.month, dt.day).difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return DateFormat('E, MMM d').format(dt);
}

String _timeRange(ActivityModel a) {
  final start = DateFormat('h:mm a').format(a.dateTime);
  final end = DateFormat('h:mm a').format(a.endTime);
  return '${_relativeDate(a.dateTime)} · $start – $end';
}

String _dayBadge(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(dt.year, dt.month, dt.day).difference(today).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'TOMORROW';
  return DateFormat('EEE').format(dt).toUpperCase();
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class MyActivitiesScreen extends ConsumerStatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  ConsumerState<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends ConsumerState<MyActivitiesScreen> {
  int _tab = 0;
  static const _tabLabels = ['Upcoming', 'Hosting', 'Past'];

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(_unreadNotifCountProvider).valueOrNull ?? 0;

    return AppScaffold(
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          HomeHeader(
            title: 'My Games',
            subtitle: 'All your games in one place',
            actions: [
              HomeHeaderAction(
                icon: Icons.calendar_month_outlined,
                semanticLabel: 'Calendar',
                onTap: () => context.push('/calendar'),
              ),
              HomeHeaderAction(
                icon: Icons.notifications_none_rounded,
                semanticLabel: 'Notifications',
                onTap: () => context.push('/notifications'),
                showDot: unreadCount > 0,
              ),
            ],
          ),

          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x1,
              AppSpacing.x5,
              AppSpacing.x3,
            ),
            child: AppTabBar(
              labels: _tabLabels,
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: AppDurations.fast,
              child: _buildTab(_tab),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int tab) => switch (tab) {
    0 => _UpcomingList(
        key: const ValueKey('upcoming'),
        onTap: (a) => context.push('/joined-activity/${a.id}'),
      ),
    1 => _SimpleList(
        key: const ValueKey('hosting'),
        provider: _hostedProvider,
        onTap: (a) => context.push('/manage-activity/${a.id}'),
        emptyTitle: "You haven't hosted yet",
        emptySubtitle: 'Create an activity and invite others to join.',
        emptyIcon: Icons.emoji_events_outlined,
        emptyActionLabel: 'Create activity',
        onEmptyAction: () => context.push('/create'),
      ),
    _ => _SimpleList(
        key: const ValueKey('past'),
        provider: _pastProvider,
        onTap: (a) => context.push('/past-activity/${a.id}/review'),
        past: true,
        emptyTitle: 'No past activities',
        emptySubtitle: 'Your completed activities will appear here.',
        emptyIcon: Icons.history_rounded,
      ),
  };
}

// ─── Upcoming tab — featured card + "Other Registered" ───────────────────────

class _UpcomingList extends ConsumerWidget {
  const _UpcomingList({super.key, required this.onTap});
  final ValueChanged<ActivityModel> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_joinedProvider);
    return async.when(
      loading: () => const SkeletonList(count: 3),
      error: (_, _) => ErrorRetry(
        message: 'Could not load activities.',
        onRetry: () => ref.invalidate(_joinedProvider),
      ),
      data: (activities) {
        if (activities.isEmpty) {
          return EmptyState(
            icon: Icons.calendar_today_outlined,
            title: 'No upcoming activities',
            subtitle: 'Discover activities near you and join one!',
            actionLabel: 'Discover',
            onAction: () => GoRouter.of(context).go('/discovery'),
          );
        }

        final featured = activities.first;
        final others = activities.skip(1).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_joinedProvider),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              0,
              AppSpacing.x5,
              AppSpacing.x8,
            ),
            children: [
              // Featured card
              _FeaturedCard(
                activity: featured,
                onTap: () => onTap(featured),
              ),

              // "Other Registered" section
              if (others.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x5),
                Text(
                  'Other Registered',
                  style: AppTypography.titleMedium(context),
                ),
                const SizedBox(height: AppSpacing.x3),
                ...others.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                    child: _CompactCard(
                      activity: a,
                      onTap: () => onTap(a),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Featured card — left blue accent bar ────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.activity, required this.onTap});
  final ActivityModel activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fillRatio = activity.capacity > 0
        ? (activity.participantCount / activity.capacity).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      button: true,
      label: activity.title,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left blue accent bar
                  Container(
                    width: 4,
                    color: AppColors.primary,
                  ),

                  // Card content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.x4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sport badge + day badge
                          Row(
                            children: [
                              _SportBadge(label: activity.sportType),
                              const Spacer(),
                              _DayBadge(dt: activity.dateTime),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.x3),

                          // Title
                          Text(
                            activity.title,
                            style: AppTypography.titleSheet(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.x2),

                          // Time row
                          _IconRow(
                            icon: Icons.access_time_rounded,
                            text: _timeRange(activity),
                          ),
                          const SizedBox(height: AppSpacing.x1 + 2),

                          // Location row
                          _IconRow(
                            icon: Icons.place_outlined,
                            text: activity.location,
                          ),
                          const SizedBox(height: AppSpacing.x3),

                          Divider(height: 1, color: context.colors.border),
                          const SizedBox(height: AppSpacing.x3),

                          // Joined count + spots left
                          Row(
                            children: [
                              Text(
                                '${activity.participantCount} / ${activity.capacity} Joined',
                                style: AppTypography.labelField(context)
                                    .copyWith(fontSize: 14),
                              ),
                              const Spacer(),
                              Text(
                                '${activity.spotsLeft} spots left',
                                style: AppTypography.labelField(context)
                                    .copyWith(
                                      color: context.colors.successText,
                                      fontSize: 14,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.x2),

                          // Progress bar — green
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            child: SizedBox(
                              height: 6,
                              child: Stack(
                                children: [
                                  Container(color: context.colors.surfaceMuted),
                                  FractionallySizedBox(
                                    widthFactor: fillRatio,
                                    child: Container(
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Compact card — thumbnail + info ─────────────────────────────────────────

class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.activity, required this.onTap});
  final ActivityModel activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: activity.title,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Row(
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
                        errorBuilder: (_, _, _) => _ThumbFallback(),
                      )
                    : _ThumbFallback(),
              ),
              const SizedBox(width: AppSpacing.x3),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sport badge + joined count
                    Row(
                      children: [
                        _SportBadge(label: activity.sportType, small: true),
                        const Spacer(),
                        Text(
                          '${activity.participantCount}/${activity.capacity} Joined',
                          style: AppTypography.metaSub(context).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x2),

                    // Title
                    Text(
                      activity.title,
                      style: AppTypography.titleMedium(context).copyWith(
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.x1 + 2),

                    // Time
                    _IconRow(
                      icon: Icons.access_time_rounded,
                      text: '${DateFormat('E, MMM d').format(activity.dateTime)} · ${DateFormat('h:mm a').format(activity.dateTime)}',
                      color: context.colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Simple list (Hosting + Past) ────────────────────────────────────────────

class _SimpleList extends ConsumerWidget {
  const _SimpleList({
    super.key,
    required this.provider,
    required this.onTap,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    this.past = false,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final ProviderListenable<AsyncValue<List<ActivityModel>>> provider;
  final ValueChanged<ActivityModel> onTap;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final bool past;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const SkeletonList(count: 4),
      error: (_, _) => ErrorRetry(
        message: 'Could not load activities.',
        onRetry: () => ref.invalidate(provider as ProviderOrFamily),
      ),
      data: (activities) {
        if (activities.isEmpty) {
          return EmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            subtitle: emptySubtitle,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(provider as ProviderOrFamily),
          color: AppColors.primary,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              0,
              AppSpacing.x5,
              AppSpacing.x8,
            ),
            itemCount: activities.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.x3),
            itemBuilder: (_, i) => _CompactCard(
              activity: activities[i],
              onTap: () => onTap(activities[i]),
            ),
          ),
        );
      },
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SportBadge extends StatelessWidget {
  const _SportBadge({required this.label, this.small = false});
  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: context.colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.chipLabel(context).copyWith(
          color: context.colors.primaryOnSurface,
          fontSize: small ? 10 : 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  const _DayBadge({required this.dt});
  final DateTime dt;

  @override
  Widget build(BuildContext context) {
    final label = _dayBadge(dt);
    final isToday = label == 'TODAY';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isToday
            ? context.colors.errorLight
            : context.colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: AppTypography.chipLabel(context).copyWith(
          color: isToday ? context.colors.errorText : context.colors.primaryOnSurface,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.icon,
    required this.text,
    this.color,
  });
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.textSecondary;
    return Row(
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: AppTypography.metaSub(context).copyWith(
              color: c,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      color: context.colors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(
        Icons.sports,
        size: 28,
        color: context.colors.textTertiary,
      ),
    );
  }
}
