import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/home_header.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../tour/presentation/tour_anchors.dart';
import '../domain/activity_model.dart';
import '../domain/discovery_filter.dart';
import '../domain/swipe_decision.dart';
import 'widgets/discovery_actions.dart';
import 'widgets/swipe_deck.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _unreadNotifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final all = await ref.watch(notificationRepositoryProvider).all();
  return all.where((n) => n.unread).length;
});

/// Whether the deck includes passed (left-swiped) cards. Flipped on by
/// "Start over". Right-swiped (joined) cards never come back regardless
/// of this flag — a join is permanent.
///
/// Deliberately NOT autoDispose and NOT widget-local state: the
/// Discover tab's State is destroyed every time the user switches tabs
/// (plain ShellRoute), so a field would reset and force another
/// "Start over" tap on every return. A session-lived provider keeps
/// the user's choice until the app is killed.
final _includeSwipedProvider = StateProvider<bool>((ref) => false);

/// User-configurable discovery filter, written by the Filter screen
/// and read by Discovery. Session-lived for the same reason as
/// `[_includeSwipedProvider]` — the Discover State dies on tab
/// switches, so storing it here survives the round-trip.
final discoveryFilterProvider = StateProvider<DiscoveryFilter>(
  (ref) => const DiscoveryFilter(),
);

// ─── Screen ──────────────────────────────────────────────────────────────────

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  int _topIndex = 0;
  List<ActivityModel> _activities = const [];
  bool _isLoading = true;

  /// ProviderSubscription handle — fired by the listener set up in
  /// [initState]. Stored on the State so [dispose] can release it;
  /// without the release, the listener would keep a strong reference
  /// to a State that's already been unmounted and we'd leak.
  late final ProviderSubscription<DiscoveryFilter> _filterSub;

  /// True after the user has tapped Apply at least once. Distinguishes
  /// the "no filter yet" case (don't render a chip) from "filter
  /// active" (render a chip + tap to reset).
  bool _hasActiveFilter = false;

  @override
  void initState() {
    super.initState();
    // Reload the deck whenever the Filter screen writes a new filter.
    // `listenManual` (vs `listen`) keeps the subscription out of the
    // WidgetRef's auto-cleanup so we can release it in `dispose`.
    _filterSub = ref.listenManual<DiscoveryFilter>(
      discoveryFilterProvider,
      (prev, next) {
        // Value equality lives on the model, so redundant writes are
        // ignored here; `_load` derives `_hasActiveFilter` itself.
        if (prev == next) return;
        debugPrint('[Discovery] filter changed: empty=${next.isEmpty}');
        _load();
      },
      fireImmediately: false,
    );
    _load();
  }

  @override
  void dispose() {
    _filterSub.close();
    super.dispose();
  }

  Future<void> _load() async {
    // Merge the session "show swiped" choice into the user filter so a
    // single object travels to the repo. `copyWith` keeps the stored
    // provider value pristine — "Start over" must not permanently flip
    // the user's saved filter. `_hasActiveFilter` derives here (not in
    // the listener) so fresh mounts with an active filter flag
    // correctly on first paint.
    final filter = ref.read(discoveryFilterProvider).copyWith(
          includeSwiped: ref.read(_includeSwipedProvider),
        );
    // Show the skeleton on EVERY load (first paint, filter apply,
    // Start over) — not just the first. Without this, applying a filter
    // leaves the stale deck frozen on screen with zero feedback until
    // the new feed arrives, which reads as "the tap did nothing".
    if (mounted && !_isLoading) setState(() => _isLoading = true);
    try {
      final list = await ref.read(activityRepositoryProvider).feed(filter: filter);
      if (!mounted) return;
      // Never re-deal a card the user already swiped: the backend
      // attaches `mySwipeDecision` per activity for the signed-in
      // viewer. Cards swiped this session are already skipped via
      // `_topIndex`, so this only matters across launches/restarts.
      // "Start over" opts back into the full deck via
      // [_includeSwipedProvider] — a session-lived provider (not widget
      // state) so the choice survives tab switches, which dispose this
      // State and would otherwise force another "Start over" tap on
      // every return.
      final includeSwiped = ref.read(_includeSwipedProvider);
      setState(() {
        // Committed games (joined or hosted) are taken from the raw
        // feed BEFORE deck filtering — they anchor the time-clash
        // check below and never enter the deck themselves.
        final committed = list
            .where((a) => a.isParticipant || a.isHost)
            .toList();
        _activities = list.where((a) {
          // Joined/hosted games live in My Games — never re-deal
          // them in Discover, not on reload, not even on "Start
          // over".
          if (a.isParticipant || a.isHost) return false;
          // A right-swipe (join) is permanent: a joined game never
          // re-enters the deck. It lives on in My Games instead.
          if (a.mySwipeDecision == 'join') return false;
          // "Start over" re-deals passes; otherwise only unseen cards.
          return includeSwiped || a.mySwipeDecision == null;
        }).toList();
        // Drop anything time-clashing with a committed game — no
        // point dealing a card they can't attend.
        if (committed.isNotEmpty) {
          _activities = _activities.where((a) {
            return !committed.any((b) =>
                b.id != a.id &&
                a.dateTime.isBefore(b.endTime) &&
                b.dateTime.isBefore(a.endTime));
          }).toList();
        }
        _topIndex = 0;
        _isLoading = false;
        _hasActiveFilter = !filter.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _swipeOut(bool liked) {
    if (_topIndex >= _activities.length) return;
    HapticFeedback.lightImpact();
    final activity = _activities[_topIndex];
    final next = _topIndex + 1;
    setState(() => _topIndex = next);

    // Persist the decision to the backend (or local fallback) so the user
    // doesn't see the same card twice on next launch, and so the host
    // gets a `join` notification for right-swipes. Fire-and-forget — UI
    // already advanced, failures are caught inside the repository.
    unawaited(
      ref.read(swipesRepositoryProvider).save(
        activityId: activity.id,
        decision: liked ? SwipeDecision.join : SwipeDecision.pass,
      ),
    );

    if (liked && next < _activities.length) {
      Future.delayed(const Duration(milliseconds: 420), () {
        if (mounted) context.go('/match/${activity.id}');
      });
    }
  }

  void _dislike() => _swipeOut(false);
  void _like() => _swipeOut(true);

  void _reset() {
    // Previously this only rewound the index — a visible no-op whenever
    // the swipe filter had emptied the list. Now it re-deals the full
    // deck (swiped cards included) from the top. The skeleton itself is
    // flipped on inside [_load], which covers every reload path.
    HapticFeedback.lightImpact();
    ref.read(_includeSwipedProvider.notifier).state = true;
    _load();
  }

  void _clearFilters() {
    // One-tap escape hatch from a filter-emptied deck. Writes the empty
    // filter; the provider listener flips `_hasActiveFilter` off and
    // reloads the unfiltered feed. (Writing `const DiscoveryFilter()`
    // is const-canonicalized, so a redundant tap is a no-op write the
    // listener ignores.)
    HapticFeedback.lightImpact();
    ref.read(discoveryFilterProvider.notifier).state =
        const DiscoveryFilter();
  }

  void _openDetails() {
    if (_topIndex >= _activities.length) return;
    final activity = _activities[_topIndex];
    // push (not go): go() replaces the whole navigation stack, which leaves
    // the detail screen's back/dislike buttons (Navigator.maybePop) with
    // nothing to pop — they'd register the tap but do nothing visible.
    context.push('/activity/${activity.id}');
  }

  @override
  Widget build(BuildContext context) {
    final deckExhausted = !_isLoading && _topIndex >= _activities.length;
    final unreadCount = ref.watch(_unreadNotifCountProvider).valueOrNull ?? 0;
    final filterSummary = ref.watch(discoveryFilterProvider).describe();

    return AppScaffold(
      showHomeIndicator: false, // inside ShellRoute — AppShell draws its own.
      body: Column(
        children: [
          HomeHeader(
            title: 'Discover',
            subtitle: _hasActiveFilter ? 'Filtered' : 'Find your next game',
            actions: [
              HomeHeaderAction(
                icon: Icons.tune_rounded,
                semanticLabel: 'Filters',
                onTap: () => context.push('/filter'),
                anchorKey: TourAnchors.filterButton,
                // Subtle dot in the corner when a non-empty filter
                // is active — tells the user the deck is filtered
                // without taking up header space.
                showDot: _hasActiveFilter,
              ),
              HomeHeaderAction(
                icon: Icons.notifications_none_rounded,
                semanticLabel: 'Notifications',
                onTap: () => context.push('/notifications'),
                showDot: unreadCount > 0,
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5,
                AppSpacing.x2,
                AppSpacing.x5,
                AppSpacing.x2,
              ),
              // Tapping the card opens details — a natural gesture that
              // mirrors how the like/dismiss buttons mirror the swipe.
              child: _isLoading
                  ? KeyedSubtree(
                      key: TourAnchors.swipeDeck,
                      child: const ActivityCardSkeleton(),
                    )
                  : deckExhausted
                  ? DiscoveryEmptyDeck(
                      onRestart: _reset,
                      filterSummary: filterSummary,
                      onClearFilters: _hasActiveFilter ? _clearFilters : null,
                    )
                  // KeyedSubtree carries the tour anchor so SwipeDeck keeps
                  // its own `ValueKey(_topIndex)` (needed to force a fresh
                  // State per card — see its comment below) instead of the
                  // anchor key overwriting it.
                  : KeyedSubtree(
                      key: TourAnchors.swipeDeck,
                      child: PressableScale(
                        onTap: _openDetails,
                        child: SwipeDeck(
                          // Force a fresh State each time topIndex advances
                          // so no listener/AnimationController from the
                          // previous card can interfere with the next swipe.
                          key: ValueKey(_topIndex),
                          activities: _activities,
                          topIndex: _topIndex,
                          onSwiped: _swipeOut,
                        ),
                      ),
                    ),
            ),
          ),
          if (!_isLoading && !deckExhausted)
            Padding(
              key: TourAnchors.actionRow,
              padding: const EdgeInsets.only(
                top: AppSpacing.x2,
                bottom: AppSpacing.x4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DiscoveryAction.reject(onTap: _dislike),
                  const SizedBox(width: AppSpacing.x6),
                  DiscoveryAction.info(onTap: _openDetails),
                  const SizedBox(width: AppSpacing.x6),
                  DiscoveryAction.join(onTap: _like),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
