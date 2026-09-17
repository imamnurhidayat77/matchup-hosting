import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_state_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/utils/nav_guard.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/app_tab_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/home_header.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../activities/domain/activity_model.dart';

// ─── Providers ───────────────────────────────────────────────────────────────
// keepAlive (bukan autoDispose): pindah tab tidak dispose + fetch ulang.
// Tab tetap di-cache selama My Games masih di navigation stack.

/// Signed-in uid used by the My Games tabs. Watches the auth uid so an
/// account switch (logout Benjamin → login Lisa) re-reads secure storage
/// and cascades a refetch to every tab below — otherwise the keepAlive
/// tabs keep serving Benjamin's cached UID + cached lists to Lisa.
/// The backend also derives the viewer from the Bearer token, so an empty
/// uid still returns the viewer's own lists server-side.
final myGamesUidProvider = FutureProvider<String>((ref) async {
  ref.watch(authStateProvider.select((s) => s.userId));
  return await SecureTokenStore.instance.readUserId() ?? '';
});

/// Ukuran satu halaman My Games. List merender bertahap 15-15
/// agar 100+ activity tidak di-layout sekaligus.
const _pageSize = 15;

// Public (bukan private) agar layar detail bisa invalidate tab My Games
// yang relevan setelah mutasi (leave/cancel/approve/dll).
final joinedGamesProvider = FutureProvider<List<ActivityModel>>((ref) async {
  final uid = await ref.watch(myGamesUidProvider.future);
  return ref.watch(activityRepositoryProvider).joinedByUser(uid);
});

final hostedGamesProvider = FutureProvider<List<ActivityModel>>((ref) async {
  final uid = await ref.watch(myGamesUidProvider.future);
  return ref.watch(activityRepositoryProvider).hostedByUser(uid);
});

final pastGamesProvider = FutureProvider<List<ActivityModel>>((ref) async {
  final uid = await ref.watch(myGamesUidProvider.future);
  return ref.watch(activityRepositoryProvider).pastByUser(uid);
});

final pendingGamesProvider = FutureProvider<List<ActivityModel>>(
  (ref) => ref.watch(activityRepositoryProvider).pendingRequests(),
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

/// Soonest-first for Upcoming / Hosting / Pending (featured card =
/// the closest game). Most-recent-first for Past.
List<ActivityModel> _sortedForMyGames(
  List<ActivityModel> activities, {
  bool mostRecentFirst = false,
}) {
  final sorted = List<ActivityModel>.of(activities);
  sorted.sort(
    (a, b) => mostRecentFirst
        ? b.dateTime.compareTo(a.dateTime)
        : a.dateTime.compareTo(b.dateTime),
  );
  return sorted;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class MyActivitiesScreen extends ConsumerStatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  ConsumerState<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends ConsumerState<MyActivitiesScreen> {
  int _tab = 0;
  static const _tabLabels = ['Upcoming', 'Hosting', 'Pending', 'Past'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Same one-shot badge as Messages: re-fetch on (re)show so reads
    // done on /notifications are reflected.
    ref.invalidate(_unreadNotifCountProvider);
  }

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
                onTap: () => NavGuard.push(context, '/calendar'),
              ),
              HomeHeaderAction(
                icon: Icons.notifications_none_rounded,
                semanticLabel: 'Notifications',
                onTap: () {
                  NavGuard.push(context, '/notifications').then(
                    (_) => ref.invalidate(_unreadNotifCountProvider),
                  );
                },
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
            // IndexedStack (bukan AnimatedSwitcher): state + scroll position
            // tiap tab tetap hidup, tidak rebuild + skeleton ulang tiap tap.
            child: IndexedStack(
              index: _tab,
              children: [
                _UpcomingList(
                  // Guarded per activity: a double-tap before the first
                  // push registers creates two id-keyed pages and throws
                  // '!keyReservation.contains(key)'. See NavGuard.
                  onTap: (a) => NavGuard.onceFor(
                    'joined-activity-${a.id}',
                    () => NavGuard.push(context, '/joined-activity/${a.id}'),
                  ),
                ),
                _SimpleList(
                  provider: hostedGamesProvider,
                  onTap: (a) => NavGuard.onceFor(
                    'manage-activity-${a.id}',
                    () => NavGuard.push(context, '/manage-activity/${a.id}'),
                  ),
                  emptyTitle: "You haven't hosted yet",
                  emptySubtitle: 'Create an activity and invite others to join.',
                  emptyIcon: Icons.emoji_events_outlined,
                  emptyActionLabel: 'Create activity',
                  onEmptyAction: () => NavGuard.push(context, '/create'),
                ),
                _SimpleList(
                  provider: pendingGamesProvider,
                  onTap: (a) => NavGuard.onceFor(
                    'pending-request-${a.id}',
                    () => NavGuard.push(context, '/pending-request/${a.id}'),
                  ),
                  pending: true,
                  emptyTitle: 'No pending requests',
                  emptySubtitle:
                      'Request to join an approval-gated game and it will wait here.',
                  emptyIcon: Icons.hourglass_top_rounded,
                ),
                _SimpleList(
                  provider: pastGamesProvider,
                  onTap: (a) => NavGuard.onceFor(
                    'past-activity-${a.id}',
                    () => NavGuard.push(context, '/past-activity/${a.id}/review'),
                  ),
                  past: true,
                  emptyTitle: 'No past activities',
                  emptySubtitle: 'Your completed activities will appear here.',
                  emptyIcon: Icons.history_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tab bodies live in the IndexedStack above so each tab keeps its
  // scroll position + cached provider data across tab switches.
}

// ─── Upcoming tab — featured card + "Other Registered" ───────────────────────

class _UpcomingList extends ConsumerStatefulWidget {
  const _UpcomingList({required this.onTap});
  final ValueChanged<ActivityModel> onTap;

  @override
  ConsumerState<_UpcomingList> createState() => _UpcomingListState();
}

class _UpcomingListState extends ConsumerState<_UpcomingList>
    with AutomaticKeepAliveClientMixin {
  int _visibleOthers = _pageSize;
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 400) {
      setState(() => _visibleOthers += _pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(joinedGamesProvider);
    // Stale-while-revalidate: saat refresh, tampilkan data lama
    // jangan balik ke skeleton kosong.
    if (async.isLoading && async.hasValue) {
      return _buildList(context, ref, async.valueOrNull!, isRefreshing: true);
    }
    return async.when(
      loading: () => const _MyGamesSkeleton(count: 4),
      error: (_, _) => ErrorRetry(
        message: 'Could not load activities.',
        onRetry: () => ref.invalidate(joinedGamesProvider),
      ),
      data: (activities) => _buildList(context, ref, activities),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<ActivityModel> activities, {
    bool isRefreshing = false,
  }) {
    if (activities.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No upcoming activities',
        subtitle: 'Discover activities near you and join one!',
        actionLabel: 'Discover',
        onAction: () => GoRouter.of(context).go('/discovery'),
      );
    }

    _precacheCovers(context, activities.take(6));

    // Defensive: backend + repository already sort soonest-first, but
    // re-sort here so the featured card is always the closest game even
    // when a mocked/fallback repository returns unsorted rows.
    final sorted = _sortedForMyGames(activities);
    final featured = sorted.first;
    final others = sorted.skip(1).toList();
    final shownOthers = others.take(_visibleOthers).toList();
    final hasMore = shownOthers.length < others.length;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _visibleOthers = _pageSize);
        ref.invalidate(joinedGamesProvider);
        // Tunggu fetch selesai agar indikator tidak hilang duluan.
        await ref.read(joinedGamesProvider.future).then((_) {}).catchError((_) {});
      },
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x5,
          0,
          AppSpacing.x5,
          AppSpacing.x8,
        ),
        // featured + header + shownOthers + loader
        itemCount: 1 + (shownOthers.isEmpty ? 0 : 1 + shownOthers.length) + (hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Stack(
              children: [
                _FeaturedCard(
                  activity: featured,
                  onTap: () => widget.onTap(featured),
                ),
                if (isRefreshing)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            );
          }
          var idx = i - 1;
          if (shownOthers.isNotEmpty) {
            if (idx == 0) {
              return Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.x5,
                  bottom: AppSpacing.x3,
                ),
                child: Text(
                  'Other Registered',
                  style: AppTypography.titleMedium(context),
                ),
              );
            }
            idx -= 1;
            if (idx < shownOthers.length) {
              final a = shownOthers[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                child: RepaintBoundary(
                  child: _CompactCard(
                    activity: a,
                    onTap: () => widget.onTap(a),
                  ),
                ),
              );
            }
          }
          // Tail loader saat masih ada sisa yang belum dirender.
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
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
  const _CompactCard(
      {required this.activity, required this.onTap, this.pending = false});
  final ActivityModel activity;
  final VoidCallback onTap;

  /// Pending requests show an amber status pill instead of the count.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    // Past-tab rows for called-off games. `lifecycleStatus` carries the
    // raw backend string; payloads without one never match.
    final isCancelled =
        activity.lifecycleStatus.toLowerCase() == 'cancelled';
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
                    ? AssetImageWithFallback(
                        imagePath: activity.coverImageUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      )
                    : _ThumbFallback(),
              ),
              const SizedBox(width: AppSpacing.x3),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sport badge + joined count (pending pill / cancelled
                    // pill instead where applicable).
                    Row(
                      children: [
                        _SportBadge(label: activity.sportType, small: true),
                        const Spacer(),
                        if (pending)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.warningBg,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              'WAITING APPROVAL',
                              style: AppTypography.chipLabel(context).copyWith(
                                color: context.colors.warningText,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          )
                        else if (isCancelled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.errorLight,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              'CANCELLED',
                              style: AppTypography.chipLabel(context).copyWith(
                                color: context.colors.errorText,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          )
                        else
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

class _SimpleList extends ConsumerStatefulWidget {
  const _SimpleList({
    required this.provider,
    required this.onTap,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    this.past = false,
    this.pending = false,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final FutureProvider<List<ActivityModel>> provider;
  final ValueChanged<ActivityModel> onTap;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final bool past;

  /// Pending-request rows render an amber "waiting approval" badge
  /// instead of the joined count. Cancelled games (Past tab) render a
  /// red "cancelled" badge the same way so a called-off game never
  /// reads as a normal completed one.
  final bool pending;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  ConsumerState<_SimpleList> createState() => _SimpleListState();
}

class _SimpleListState extends ConsumerState<_SimpleList>
    with AutomaticKeepAliveClientMixin {
  int _visible = _pageSize;
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 400) {
      setState(() => _visible += _pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(widget.provider);
    if (async.isLoading && async.hasValue) {
      return _buildList(context, async.valueOrNull!, isRefreshing: true);
    }
    return async.when(
      loading: () => const _MyGamesSkeleton(count: 5),
      error: (_, _) => ErrorRetry(
        message: 'Could not load activities.',
        onRetry: () => ref.invalidate(widget.provider),
      ),
      data: (activities) => _buildList(context, activities),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<ActivityModel> activities, {
    bool isRefreshing = false,
  }) {
    if (activities.isEmpty) {
      return EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
        actionLabel: widget.emptyActionLabel,
        onAction: widget.onEmptyAction,
      );
    }
    _precacheCovers(context, activities.take(6));

    // Same defensive sort as Upcoming: Hosting + Pending soonest-first,
    // Past most-recent-first.
    final sorted = _sortedForMyGames(
      activities,
      mostRecentFirst: widget.past,
    );
    final shown = sorted.take(_visible).toList();
    final hasMore = shown.length < sorted.length;
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _visible = _pageSize);
        ref.invalidate(widget.provider);
        await ref.read(widget.provider.future).then((_) {}).catchError((_) {});
      },
      color: AppColors.primary,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x5,
          0,
          AppSpacing.x5,
          AppSpacing.x8,
        ),
        // Optimasi list panjang: matikan keepAlive per-item, nyalakan
        // repaint boundary agar scroll 100+ card tidak jank.
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        // Selalu scrollable agar pull-to-refresh hidup walau item sedikit.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: shown.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x3),
        itemBuilder: (_, i) {
          if (i >= shown.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final a = shown[i];
          return RepaintBoundary(
            child: _CompactCard(
              activity: a,
              pending: widget.pending,
              onTap: () => widget.onTap(a),
            ),
          );
        },
      ),
    );
  }
}

// ─── Skeleton yang mirror card asli ──────────────────────────────────────────
// SkeletonList generik (avatar 44px) bentuknya beda dari _CompactCard
// (thumbnail 72px) sehingga terjadi layout jump. Versi ini memakai
// ActivityListCardSkeleton agar tinggi tiap placeholder ≈ card asli.

class _MyGamesSkeleton extends StatelessWidget {
  const _MyGamesSkeleton({this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        0,
        AppSpacing.x5,
        AppSpacing.x8,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.x3),
        child: ActivityListCardSkeleton(),
      ),
    );
  }
}

/// Precache cover pertama agar thumbnail tidak muncul satu-satu rebutan
/// bandwidth saat list pertama render. Pakai [CachedNetworkImageProvider]
/// agar SHARE cache dengan [AssetImageWithFallback] — jangan NetworkImage
/// polos (itu fetch dobel di luar cache). Best-effort: gagal precache
/// dibiarkan, gambar tetap load seperti biasa.
void _precacheCovers(BuildContext context, Iterable<ActivityModel> items) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    for (final a in items) {
      final url = a.coverImageUrl;
      if (url == null || !isRemoteImage(url)) continue;
      precacheImage(CachedNetworkImageProvider(url), context).catchError(
        (_) {},
      );
    }
  });
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
