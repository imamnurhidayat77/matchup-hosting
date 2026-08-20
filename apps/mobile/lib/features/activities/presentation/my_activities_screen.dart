import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/notification_icon_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../activities/domain/activity_model.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

const _mockUserId = 'me'; // TODO: from authStateProvider

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

/// "Today, 4:00 PM" / "Tomorrow, 10:00 AM" / "Sat, Aug 23 · 4:00 PM".
String _relativeDateTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diff = target.difference(today).inDays;
  final time = DateFormat('h:mm a').format(dt);
  if (diff == 0) return 'Today, $time';
  if (diff == 1) return 'Tomorrow, $time';
  return '${DateFormat('E, MMM d').format(dt)} · $time';
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class MyActivitiesScreen extends ConsumerStatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  ConsumerState<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends ConsumerState<MyActivitiesScreen> {
  int _tab = 0;

  static const _tabLabels = ['Upcoming', 'Past', 'Hosting'];

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(_unreadNotifCountProvider).valueOrNull ?? 0;

    return Scaffold(
      // Off-white canvas so the white cards actually stand out — the
      // previous white-on-white left cards looking like flat boxes glued
      // together with borders.
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header sits on surface so the title/bell aren't floating on the
            // off-white; the transition from surface to background happens
            // right below the tab underline, giving the tab bar a subtle
            // "chrome vs content" split.
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x6,
                AppSpacing.x2,
                AppSpacing.x6,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Activities',
                      style: AppTypography.titleScreen,
                    ),
                  ),
                  NotificationIconButton(
                    hasUnread: unreadCount > 0,
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x6,
                AppSpacing.x2,
                AppSpacing.x6,
                0,
              ),
              child: Row(
                children: List.generate(
                  _tabLabels.length,
                  (i) => _UnderlineTab(
                    label: _tabLabels[i],
                    selected: _tab == i,
                    onTap: () => setState(() => _tab = i),
                  ),
                ),
              ),
            ),
            // Hairline separator with a soft shadow spilling into the list —
            // makes the header/tab chrome feel like it sits above the content.
            Container(
              height: 1,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildTab(_tab)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int tab) => switch (tab) {
    0 => _ActivityList(
      provider: _joinedProvider,
      cardBuilder: (a) => _ActivityListCard(
        activity: a,
        onTap: () => context.push('/joined-activity/${a.id}'),
      ),
      emptyTitle: 'No upcoming activities',
      emptySubtitle: 'Discover activities near you and join one!',
      emptyIcon: Icons.calendar_today_outlined,
      emptyActionLabel: 'Discover',
      onEmptyAction: () => context.go('/discovery'),
    ),
    1 => _ActivityList(
      provider: _pastProvider,
      cardBuilder: (a) => _ActivityListCard(
        activity: a,
        statusLabel: 'COMPLETED',
        statusBg: AppColors.border,
        statusFg: AppColors.textSecondary,
        onTap: () => context.push('/past-activity/${a.id}/review'),
      ),
      emptyTitle: 'No past activities',
      emptySubtitle: 'Your completed activities will appear here.',
      emptyIcon: Icons.history_rounded,
    ),
    _ => _ActivityList(
      provider: _hostedProvider,
      cardBuilder: (a) => _ActivityListCard(
        activity: a,
        statusLabel: 'HOSTING',
        statusBg: AppColors.primarySoft,
        statusFg: AppColors.primaryDarker,
        onTap: () => context.push('/manage-activity/${a.id}'),
      ),
      emptyTitle: "You haven't hosted yet",
      emptySubtitle: 'Create an activity and invite others to join.',
      emptyIcon: Icons.emoji_events_outlined,
      emptyActionLabel: 'Create activity',
      onEmptyAction: () => context.push('/create'),
    ),
  };
}

// ─── Underline tab ────────────────────────────────────────────────────────────

class _UnderlineTab extends StatelessWidget {
  const _UnderlineTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.only(bottom: AppSpacing.x3),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelField.copyWith(
                color: selected
                    ? AppColors.primaryDarker
                    : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Generic list ─────────────────────────────────────────────────────────────

typedef _CardBuilder = Widget Function(ActivityModel);

class _ActivityList extends ConsumerWidget {
  const _ActivityList({
    required this.provider,
    required this.cardBuilder,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final ProviderListenable<AsyncValue<List<ActivityModel>>> provider;
  final _CardBuilder cardBuilder;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
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
              AppSpacing.x6,
              AppSpacing.x5,
              AppSpacing.x6,
              AppSpacing.x6,
            ),
            itemCount: activities.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x3),
            itemBuilder: (_, i) => cardBuilder(activities[i]),
          ),
        );
      },
    );
  }
}

// ─── Compact list card ────────────────────────────────────────────────────────
//
// One card shape reused across all three tabs (Upcoming/Past/Hosting) —
// thumbnail + sport chip + status pill + title + time/participants meta.
// Only the status pill's label/color and the tap destination change per tab.

class _ActivityListCard extends StatelessWidget {
  const _ActivityListCard({
    required this.activity,
    required this.onTap,
    this.statusLabel,
    this.statusBg,
    this.statusFg,
  });

  final ActivityModel activity;
  // Status pill is optional: there's no real "confirmed/pending" state in the
  // data model, so the upcoming tab omits it rather than guess. Past/Hosting
  // still show one because those labels just reflect which tab the item is
  // in, not an invented approval state.
  final String? statusLabel;
  final Color? statusBg;
  final Color? statusFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Layered: outer DecoratedBox holds the shadow (Material's clipBehavior
    // would clip the shadow away if we put it inside), Material provides the
    // rounded ink ripple, inner Container draws the hairline border.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: 0.06),
          highlightColor: AppColors.primary.withValues(alpha: 0.03),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: activity.coverImageUrl != null
                      ? Image.asset(
                          activity.coverImageUrl!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _ThumbFallback(),
                        )
                      : const _ThumbFallback(),
                ),
                const SizedBox(width: AppSpacing.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Pill(
                            label: activity.sportType.toUpperCase(),
                            bg: AppColors.primarySoft,
                            fg: AppColors.primaryDarker,
                          ),
                          if (statusLabel != null) ...[
                            const Spacer(),
                            _Pill(
                              label: statusLabel!,
                              bg: statusBg!,
                              fg: statusFg!,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        activity.title,
                        style: AppTypography.labelField.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/images/discovery/icons/clock.svg',
                            width: 13,
                            height: 13,
                            colorFilter: const ColorFilter.mode(
                              AppColors.textSecondary,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _relativeDateTime(activity.dateTime),
                            style: AppTypography.metaSub,
                          ),
                          const SizedBox(width: AppSpacing.x3),
                          SvgPicture.asset(
                            'assets/images/discovery/icons/users.svg',
                            width: 13,
                            height: 13,
                            colorFilter: const ColorFilter.mode(
                              AppColors.textSecondary,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${activity.participantCount}/${activity.capacity}',
                            style: AppTypography.metaSub,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      color: AppColors.surfaceSubtle,
      alignment: Alignment.center,
      child: const Icon(Icons.sports, size: 28, color: AppColors.textTertiary),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: AppTypography.badgeSport.copyWith(color: fg)),
    );
  }
}
