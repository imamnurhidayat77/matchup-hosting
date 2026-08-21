import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_tab_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/home_header.dart';
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
  if (diff == 0) return 'Today · $time';
  if (diff == 1) return 'Tomorrow · $time';
  return '${DateFormat('E, MMM d').format(dt)} · $time';
}

/// Uppercase day badge for the hero overlay: "TODAY" / "TOMORROW" / "SAT".
String _dayBadge(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(dt.year, dt.month, dt.day).difference(today).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'TOMORROW';
  return DateFormat('EEE').format(dt).toUpperCase();
}

/// "Tomorrow · 4:00 PM - 6:00 PM" — the hero shows the full window, derived
/// from the model's `endTime` (start + duration).
String _dateTimeRange(ActivityModel a) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(
    a.dateTime.year,
    a.dateTime.month,
    a.dateTime.day,
  ).difference(today).inDays;
  final day = switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => DateFormat('E, MMM d').format(a.dateTime),
  };
  final start = DateFormat('h:mm a').format(a.dateTime);
  final end = DateFormat('h:mm a').format(a.endTime);
  return '$day · $start - $end';
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
      showHomeIndicator: false, // inside ShellRoute — AppShell draws its own.
      body: Column(
        children: [
          HomeHeader(
            title: 'My Games',
            subtitle: 'All your games in one place',
            actions: [
              HomeHeaderAction(
                icon: Icons.calendar_today_rounded,
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
          // Shared iOS-style pill control: the elevated active segment reads
          // clearly without an icon row or a hard divider under the header.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x1,
              AppSpacing.x5,
              AppSpacing.x2,
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
    0 => _ActivityList(
      key: const ValueKey('upcoming'),
      provider: _joinedProvider,
      // The soonest game is promoted to a full-width hero so the list has a
      // clear focal point instead of three identical rows.
      heroBuilder: (a) => _NextGameCard(
        activity: a,
        onTap: () => context.push('/joined-activity/${a.id}'),
      ),
      cardBuilder: (a) => _GameCard(
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
      key: const ValueKey('hosting'),
      provider: _hostedProvider,
      cardBuilder: (a) => _GameCard(
        activity: a,
        onTap: () => context.push('/manage-activity/${a.id}'),
      ),
      emptyTitle: "You haven't hosted yet",
      emptySubtitle: 'Create an activity and invite others to join.',
      emptyIcon: Icons.emoji_events_outlined,
      emptyActionLabel: 'Create activity',
      onEmptyAction: () => context.push('/create'),
    ),
    _ => _ActivityList(
      key: const ValueKey('past'),
      provider: _pastProvider,
      cardBuilder: (a) => _GameCard(
        activity: a,
        past: true,
        onTap: () => context.push('/past-activity/${a.id}/review'),
      ),
      emptyTitle: 'No past activities',
      emptySubtitle: 'Your completed activities will appear here.',
      emptyIcon: Icons.history_rounded,
    ),
  };
}

// ─── Generic list (Upcoming / Hosting / Past) ────────────────────────────────

typedef _CardBuilder = Widget Function(ActivityModel);

class _ActivityList extends ConsumerWidget {
  const _ActivityList({
    super.key,
    required this.provider,
    required this.cardBuilder,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    this.heroBuilder,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final ProviderListenable<AsyncValue<List<ActivityModel>>> provider;
  final _CardBuilder cardBuilder;

  /// When set, the first item renders with this builder instead of
  /// [cardBuilder] — used to feature the next upcoming game.
  final _CardBuilder? heroBuilder;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const _LoadingList(),
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
              AppSpacing.x8,
            ),
            itemCount: activities.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x4),
            itemBuilder: (_, i) {
              final a = activities[i];
              final card = i == 0 && heroBuilder != null
                  ? heroBuilder!(a)
                  : cardBuilder(a);
              return _FadeSlideIn(index: i, child: card);
            },
          ),
        );
      },
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x5,
        AppSpacing.x6,
        AppSpacing.x6,
      ),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x4),
      itemBuilder: (_, _) => const ActivityListCardSkeleton(),
    );
  }
}

// ─── Game card ────────────────────────────────────────────────────────────────
//
// Horizontal card reused across all tabs: thumbnail + sport pill + status pill
// + title + date + players, with a chevron affordance. Only the status pill
// and tap destination change per tab.

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.activity,
    required this.onTap,
    this.past = false,
  });

  final ActivityModel activity;
  final VoidCallback onTap;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.x3 + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: activity.coverImageUrl != null
                ? Image.asset(
                    activity.coverImageUrl!,
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ThumbFallback(),
                  )
                : const _ThumbFallback(),
          ),
          const SizedBox(width: AppSpacing.x3 + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: _Pill(
                        label: activity.sportType.toUpperCase(),
                        bg: c.primarySoft,
                        fg: c.primaryOnSurface,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(
                      past
                          ? 'Completed'
                          : '${activity.participantCount}/${activity.capacity} Joined',
                      style: AppTypography.metaSub(
                        context,
                      ).copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  activity.title,
                  style: AppTypography.titleMedium(context).copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.x2),
                _MetaRow(
                  icon: AppIcons.clock,
                  text: _relativeDateTime(activity.dateTime),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero "next game" card ────────────────────────────────────────────────────

/// Full-width featured card for the soonest upcoming game: cover photo with a
/// countdown badge, then title, venue and player count. Gives the Upcoming
/// list a focal point rather than a stack of identical rows.
class _NextGameCard extends StatelessWidget {
  const _NextGameCard({required this.activity, required this.onTap});

  final ActivityModel activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      radius: AppRadius.lg,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover + overlay badges (both sit top-left, as in the reference).
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (activity.coverImageUrl != null)
                  Image.asset(
                    activity.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        ColoredBox(color: c.surfaceSubtle),
                  )
                else
                  ColoredBox(color: c.surfaceSubtle),
                Positioned(
                  top: AppSpacing.x3 + 2,
                  left: AppSpacing.x3 + 2,
                  child: Row(
                    children: [
                      _Pill(
                        label: activity.sportType.toUpperCase(),
                        bg: AppColors.scrimGradient,
                        fg: AppColors.textOnPrimary,
                        large: true,
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      _Pill(
                        label: _dayBadge(activity.dateTime),
                        bg: AppColors.primary,
                        fg: AppColors.textOnPrimary,
                        large: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Details.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x4 + 2,
              AppSpacing.x5,
              AppSpacing.x4 + 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: AppTypography.headlineSmall(
                    context,
                  ).copyWith(fontSize: 21, height: 1.22),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.x3),
                // Primary-tinted icons, per the reference.
                _MetaRow(
                  icon: AppIcons.clock,
                  text: _dateTimeRange(activity),
                  iconColor: AppColors.primary,
                  fontSize: 14.5,
                ),
                const SizedBox(height: AppSpacing.x2),
                _MetaRow(
                  icon: AppIcons.mapPin,
                  text: activity.location,
                  iconColor: AppColors.primary,
                  fontSize: 14.5,
                ),
                const SizedBox(height: AppSpacing.x4),
                Divider(height: 1, color: c.border),
                const SizedBox(height: AppSpacing.x3 + 2),
                // Joined count + spots left + progress.
                Row(
                  children: [
                    AppIcon(
                      AppIcons.users,
                      size: AppIconSize.md,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${activity.participantCount} / ${activity.capacity} players joined',
                        style: AppTypography.labelField(
                          context,
                        ).copyWith(fontSize: 14.5, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(
                      '${activity.spotsLeft} spots left',
                      style: AppTypography.labelField(context).copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        // Darker green than the bar: #22C55E on white is
                        // ~2.3:1 and fails WCAG AA for text.
                        color: AppColors.statusSuccessText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),
                ClipRRect(
                  borderRadius: AppRadius.pillR,
                  child: SizedBox(
                    height: 7,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(color: c.surfaceMuted),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: activity.capacity > 0
                              ? (activity.participantCount / activity.capacity)
                                    .clamp(0.0, 1.0)
                              : 0,
                          child: const ColoredBox(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Entrance motion ──────────────────────────────────────────────────────────

/// Staggered fade + rise for list items. Each item owns a controller whose
/// duration grows with [index], and reads its animation through an [Interval]
/// so the delay needs no timers (keeps widget tests deterministic).
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _base = 260;
  static const _step = 70;

  late final int _delay = widget.index.clamp(0, 6) * _step;
  late final AnimationController _controller = AnimationController(
    duration: Duration(milliseconds: _base + _delay),
    vsync: this,
  );
  late final Animation<double> _anim = CurvedAnimation(
    parent: _controller,
    curve: Interval(_delay / (_base + _delay), 1.0, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.07),
          end: Offset.zero,
        ).animate(_anim),
        child: widget.child,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.text,
    this.iconColor,
    this.fontSize,
  });

  final String icon;
  final String text;
  final Color? iconColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(
          icon,
          size: fontSize == null ? AppIconSize.sm : AppIconSize.md,
          color: iconColor ?? context.colors.textSecondary,
        ),
        SizedBox(width: fontSize == null ? 5 : 7),
        Flexible(
          child: Text(
            text,
            style: fontSize == null
                ? AppTypography.metaSub(context)
                : AppTypography.metaSub(context).copyWith(fontSize: fontSize),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      color: context.colors.surfaceSubtle,
      alignment: Alignment.center,
      child: AppIcon.material(
        Icons.sports,
        size: AppIconSize.lg,
        color: context.colors.textTertiary,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.bg,
    required this.fg,
    this.large = false,
  });

  final String label;
  final Color bg;
  final Color fg;

  /// Hero overlay badges are chunkier than the in-card sport chips.
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 13, vertical: 7)
          : const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillR),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.badgeSport(context).copyWith(
          fontSize: large ? 12 : 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: large ? 0.4 : 0.3,
          color: fg,
        ),
      ),
    );
  }
}
