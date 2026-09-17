import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/auth_state_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/nav_guard.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/home_header.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../tour/presentation/tour_anchors.dart';
import '../../tour/presentation/tour_controller.dart';
import '../../activities/presentation/my_activities_screen.dart';
import '../domain/activity_model.dart';
import '../data/remote_activity_repository.dart';
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
///
/// Rebuilt on account switch (watches the auth uid) so Lisa never
/// inherits Benjamin's "Start over" session flag.
final _includeSwipedProvider = StateProvider<bool>((ref) {
  ref.watch(authStateProvider.select((s) => s.userId));
  return false;
});

/// User-configurable discovery filter, written by the Filter screen
/// and read by Discovery. Session-lived for the same reason as
/// `[_includeSwipedProvider]` — the Discover State dies on tab
/// switches, so storing it here survives the round-trip. Persisted to
/// SharedPreferences on every change (see [_persistFilter]) so it also
/// survives app restart; the persisted value is restored in
/// [_seedDefaultFilter] before the first load.
///
/// Rebuilt to empty on account switch (watches the auth uid) AND
/// persisted per-user (see [_filterKeyFor]) — without both, Lisa
/// inherits Benjamin's filter: in-memory directly, or from disk on the
/// next seed.
final discoveryFilterProvider = StateProvider<DiscoveryFilter>((ref) {
  ref.watch(authStateProvider.select((s) => s.userId));
  return const DiscoveryFilter();
});

/// Per-user SharedPreferences key for the persisted discovery filter.
/// A global key leaks filters across accounts on shared devices.
String _filterKeyFor(String? uid) => 'discovery_filter_v1_${uid ?? 'anon'}';

/// Best-effort write-through of the user filter. Never blocks UI and
/// never throws — a failed save just means "session only" this time.
Future<void> _persistFilter(DiscoveryFilter filter, String? uid) async {
  try {
    final store = await LocalStorage.create().timeout(
      const Duration(seconds: 2),
    );
    await store
        .setString(_filterKeyFor(uid), jsonEncode(filter.toJson()))
        .timeout(const Duration(seconds: 2));
  } catch (_) {
    // Best-effort only.
  }
}

/// Opens the filter store, or null when unavailable (fresh install
/// without the plugin, widget tests without a SharedPreferences mock,
/// corrupt platform channel). The 2s cap matters: without it a hanging
/// store would block the first deck load forever (and `pumpAndSettle`
/// in widget tests would time out on the shimmer).
Future<LocalStorage?> _openFilterStore() async {
  try {
    return await LocalStorage.create().timeout(const Duration(seconds: 2));
  } catch (_) {
    return null;
  }
}

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

  /// True when the last [_load] failed. Renders [ErrorRetry] (with a
  /// retry that re-runs [_load]) instead of the empty deck — a network
  /// error must not masquerade as "you're all caught up".
  bool _loadError = false;

  /// End of the most recent drag gesture on the deck. [_openDetails]
  /// ignores taps within 300ms of this so a swipe that ends over the
  /// card doesn't mis-fire into the detail screen.
  DateTime? _lastDragEnd;

  /// In-flight guard for the swipe-to-join/request flow. Right-swipes
  /// await a network call before advancing the deck; without this,
  /// rapid double-taps on the join button fire duplicate joins.
  /// Set before kicking off [_joinAndShowMatch]/[_requestAndShowPending],
  /// cleared in their `finally` blocks.
  bool _swiping = false;

  /// ProviderSubscription handle — fired by the listener set up in
  /// [initState]. Stored on the State so [dispose] can release it;
  /// without the release, the listener would keep a strong reference
  /// to a State that's already been unmounted and we'd leak.
  late final ProviderSubscription<DiscoveryFilter> _filterSub;

  /// True while [_seedDefaultFilter] writes the restored filter. The
  /// [_filterSub] listener skips its own `_load()` in that window —
  /// the seed calls `_load()` explicitly right after, so without the
  /// guard every cold start with a saved filter would fetch twice.
  bool _restoringFilter = false;

  /// True after the user has tapped Apply at least once. Distinguishes
  /// the "no filter yet" case (don't render a chip) from "filter
  /// active" (render a chip + tap to reset).
  bool _hasActiveFilter = false;

  @override
  void initState() {
    super.initState();
    // Tour gate: hide the coach-mark overlay until the feed finishes.
    // Without this the "Welcome" popup appears over the skeleton while
    // card images are still loading (issue: popup duluan, gambar belum).
    // Deferred post-frame: writing a provider inside initState throws
    // ("tried to modify a provider while the widget tree was building")
    // on remounts sharing a container.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(discoveryContentReadyProvider.notifier).state = false;
    });
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
        // Write-through so the choice survives app restart. Reset also
        // flows through here (empty filter overwrites the stored one).
        // Per-user key: Benjamin's saved filter must not follow Lisa.
        unawaited(
          _persistFilter(
            next,
            ref.read(authStateProvider).userId,
          ),
        );
        // Skip during seed-restore: the seed calls _load() explicitly
        // right after, so loading here would fetch twice.
        if (_restoringFilter) return;
        _load();
      },
      fireImmediately: false,
    );
    // Restore the persisted filter (or seed from onboarding prefs on
    // first ever launch) before the first load, then deal the deck.
    _seedDefaultFilter().then((_) {
      if (mounted) _load();
    });
  }

  /// Restores the filter in priority order:
  /// 1. Persisted user filter (survives restart). Custom "Pick dates"
  ///    ranges that already ended are dropped — a stored range from
  ///    last week must not silently empty the deck. Relative presets
  ///    (Today/Tomorrow/Weekend) recompute from "now" on every load,
  ///    so they are always fresh.
  /// 2. Onboarding sport prefs (first launch, no stored filter).
  /// An explicit Apply/Reset mid-session is never overwritten.
  Future<void> _seedDefaultFilter() async {
    if (!ref.read(discoveryFilterProvider).isEmpty) return;
    try {
      final store = await _openFilterStore();
      // Per-user key: a persisted filter belongs to whoever saved it.
      final raw = store?.getString(
        _filterKeyFor(ref.read(authStateProvider).userId),
      );
      if (raw != null && raw.isNotEmpty && mounted) {
        final restored = DiscoveryFilter.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        final fresh = _dropStaleDates(restored);
        if (!fresh.isEmpty) {
          // Guarded: the listener skips its _load(), the explicit one
          // after the seed covers this restore (single fetch).
          _restoringFilter = true;
          ref.read(discoveryFilterProvider.notifier).state = fresh;
          _restoringFilter = false;
          return;
        }
      }
    } catch (_) {
      // Corrupt JSON — fall through to prefs.
    }
    if (!mounted) return;
    var prefs = ref.read(sportPreferencesProvider);
    if (prefs.isEmpty) {
      // Cross-device: local prefs are per-install. Hydrate once from the
      // backend profile, then keep them locally.
      try {
        final me = await ref.read(userRepositoryProvider).me();
        if (!mounted) return;
        if (me.sports.isNotEmpty) {
          final hydrated = {
            for (final s in me.sports)
              s.sport: s.level.isNotEmpty ? s.level : 'Intermediate',
          };
          ref.read(sportPreferencesProvider.notifier).setAll(hydrated);
          prefs = hydrated;
        }
      } catch (_) {
        // Offline — fall through with whatever local prefs exist.
      }
    }
    if (prefs.isEmpty) return;
    ref.read(discoveryFilterProvider.notifier).state = DiscoveryFilter(
      sportSkills: [
        for (final e in prefs.entries)
          DiscoverySportSkill(sport: e.key, skill: _discoverySkill(e.value)),
      ],
      maxDistanceKm: ref.read(distanceFilterProvider),
    );
  }

  /// Drops a custom "Pick dates" range whose end already passed. The
  /// rest of the restored filter (sports, distance) is still valid and
  /// kept — only the stale dates go, so the deck never opens empty
  /// because of last week's range.
  DiscoveryFilter _dropStaleDates(DiscoveryFilter filter) {
    final end = filter.startBefore;
    if (end != null && end.isBefore(DateTime.now())) {
      return DiscoveryFilter(
        sportSkills: filter.sportSkills,
        datePreset: DiscoveryDatePreset.anyTime,
        maxDistanceKm: filter.maxDistanceKm,
      );
    }
    return filter;
  }

  /// Maps a saved skill label ('Beginner', …) to the filter enum.
  /// Unknown/empty levels become `any` — the sport still filters,
  /// just without a skill restriction.
  DiscoverySkillLevel _discoverySkill(String label) {
    return switch (label.trim().toLowerCase()) {
      'beginner' => DiscoverySkillLevel.beginner,
      'intermediate' => DiscoverySkillLevel.intermediate,
      'advanced' => DiscoverySkillLevel.advanced,
      _ => DiscoverySkillLevel.any,
    };
  }

  @override
  void dispose() {
    _filterSub.close();
    super.dispose();
  }

  /// Manual refresh (header button) bypasses the cache and always
  /// shows the skeleton; every other caller serves cache-first.
  Future<void> _load({bool forceRefresh = false}) async {
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
    // Flip the tour gate off while the skeleton is up so the overlay
    // can't pop over an empty deck mid-reload.
    if (mounted && !_isLoading) setState(() => _isLoading = true);
    if (mounted && _loadError) setState(() => _loadError = false);
    ref.read(discoveryContentReadyProvider.notifier).state = false;
    // Anchor for manual refresh: the id on top right now, so the
    // reload can restore the swipe position instead of rewinding to 0.
    // Only the explicit refresh path uses it — filter changes,
    // Start over and silent refreshes intentionally re-deal from top.
    final anchorId = forceRefresh && _topIndex < _activities.length
        ? _activities[_topIndex].id
        : null;
    try {
      final repo = ref.read(activityRepositoryProvider);
      // Committed games (joined + hosted) anchor the time-clash filter.
      // They come from the viewer's own lists — not the current feed
      // page, which may not contain them — so clashes are caught even
      // when the committed game isn't in this page. The backend derives
      // the viewer from the Bearer token, so an empty uid is fine.
      // Best-effort: on failure [_applyDeck] falls back to the feed
      // page's own participant/host flags.
      List<ActivityModel> committed = const [];
      try {
        final results = await Future.wait([
          repo.joinedByUser('', limit: 50),
          repo.hostedByUser('', limit: 50),
        ]);
        committed = [...results[0], ...results[1]];
      } catch (_) {
        // Offline — feed-derived fallback inside [_applyDeck].
      }
      // Cache-hit serves instantly (tab switches dispose this State,
      // so without the repo cache every return trip replays HTTP +
      // GPS behind the skeleton). When we know the hit is fresh, kick
      // a silent background refresh afterwards so the deck still
      // converges without ever flashing the skeleton.
      final remote = repo is RemoteActivityRepository ? repo : null;
      final wasFresh =
          !forceRefresh && (remote?.isFeedFresh(filter: filter) ?? false);
      final list =
          await repo.feed(filter: filter, forceRefresh: forceRefresh);
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
      _applyDeck(list, filter, committed: committed, anchorId: anchorId);
      // Silent background refresh when the render above came from a
      // fresh cache entry: the deck converges to live data without
      // ever flashing the skeleton. Skipped on cold loads (nothing
      // cached — the fetch above already went to the network).
      if (wasFresh && remote != null) {
        unawaited(_refreshSilently(remote, filter));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = true;
        });
      }
      // Skeleton gone (error path shows the empty deck) — release the
      // tour gate so the welcome step can still appear over it.
      ref.read(discoveryContentReadyProvider.notifier).state = true;
    }
  }

  /// Builds [_activities] from a raw feed inside setState. Shared by
  /// [_load] (skeleton path) and [_refreshSilently] (no-skeleton path
  /// that preserves the user's swipe position).
  void _applyDeck(
    List<ActivityModel> list,
    DiscoveryFilter filter, {
    List<ActivityModel>? committed,
    String? anchorId,
  }) {
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
      // Committed games (joined or hosted) anchor the time-clash check
      // below and never enter the deck themselves. Prefer the viewer's
      // own joined+hosted lists (fetched in [_load]) — the raw feed
      // page may not contain the committed game at all. Falls back to
      // the feed page's flags when those fetches failed (offline).
      final known = (committed == null || committed.isEmpty)
          ? list.where((a) => a.isParticipant || a.isHost).toList()
          : committed;
      _activities = list.where((a) {
        // Stale `open` rows (backend expiry is eventual): never deal a
        // game that already started — the join would 409 anyway, so the
        // card only sets up a rejection.
        if (!a.dateTime.isAfter(DateTime.now())) return false;
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
      if (known.isNotEmpty) {
        _activities = _activities.where((a) {
          return !known.any((b) =>
              b.id != a.id &&
              a.dateTime.isBefore(b.endTime) &&
              b.dateTime.isBefore(a.endTime));
        }).toList();
      }
      // Manual-refresh anchor: restore the pre-reload top card when
      // it's still in the deck (clamped, fallback 0) instead of
      // rewinding to the top.
      if (anchorId != null && _activities.isNotEmpty) {
        final at = _activities.indexWhere((a) => a.id == anchorId);
        _topIndex = at < 0 ? 0 : at.clamp(0, _activities.length - 1);
      } else {
        _topIndex = 0;
      }
      _isLoading = false;
      _hasActiveFilter = !filter.isEmpty;
    });
    // Feed painted (deck or empty state) — skeleton gone, anchors
    // measurable. Release the tour gate; TourHost shows the overlay on
    // the next frame. Set outside setState: provider writes must not
    // happen synchronously inside a widget build, and _applyDeck is
    // always called from async load paths, so this is safe.
    ref.read(discoveryContentReadyProvider.notifier).state = true;
  }

  /// Re-fetches bypassing the cache and swaps the deck silently — no
  /// skeleton, and the swipe position is preserved so a mid-deck user
  /// is never yanked back to the top. No-op when the fresh feed is
  /// identical or the user already started swiping.
  Future<void> _refreshSilently(
    RemoteActivityRepository repo,
    DiscoveryFilter filter,
  ) async {
    try {
      final fresh = await repo.feed(filter: filter, forceRefresh: true);
      if (!mounted || _topIndex > 0) return;
      final sameIds = fresh.map((a) => a.id).join(',') ==
          _activities.map((a) => a.id).join(',');
      if (sameIds) return;
      _applyDeck(fresh, filter);
    } catch (_) {
      // Silent path — stale deck simply stays.
    }
  }

  void _swipeOut(bool liked) {
    if (_topIndex >= _activities.length) return;
    // Ignore join taps while a join/request is still pending.
    if (liked && _swiping) return;
    HapticFeedback.lightImpact();
    final activity = _activities[_topIndex];
    final needsApproval = activity.joinPolicy == 'approval';

    // Approval-gated games file a join request (awaited — the pending
    // screen would lie if the request failed) instead of the instant
    // match flow.
    if (liked && needsApproval) {
      _swiping = true;
      unawaited(_requestAndShowPending(activity));
      return;
    }

    // Open games join for real on a right-swipe (awaited — the match
    // screen + My Games would lie if the join failed). A swipe alone
    // only records `POST /swipes` and never creates a participant row,
    // so without this the card vanishes from Discover but never shows
    // up in My Games (isParticipant stays false).
    if (liked && !needsApproval) {
      _swiping = true;
      unawaited(_joinAndShowMatch(activity));
      return;
    }

    final next = _topIndex + 1;
    setState(() => _topIndex = next);

    // Persist the decision to the backend (or local fallback) so the user
    // doesn't see the same card twice on next launch, and so the host
    // gets a `join` notification for right-swipes. Fire-and-forget — UI
    // already advanced; failures surface via [_onPersistError] since the
    // repository rethrows instead of swallowing.
    _persistSwipe(activityId: activity.id, decision: SwipeDecision.pass);

    // Drop cached feeds so a just-swiped card can't be re-dealt from
    // a stale entry within the TTL window (e.g. tab switch → back).
    final repo = ref.read(activityRepositoryProvider);
    if (repo is RemoteActivityRepository) repo.invalidateFeed();
  }

  /// Fire-and-forget swipe persistence with a visible failure path.
  Future<void> _persistSwipe({
    required String activityId,
    required SwipeDecision decision,
  }) async {
    try {
      await ref.read(swipesRepositoryProvider).save(
            activityId: activityId,
            decision: decision,
          );
    } catch (_) {
      if (mounted) _onPersistError();
    }
  }

  /// Shared handler for swipe-persist failures (also wired to the
  /// deck's `onPersistError`): the swipe already advanced, so this is
  /// informational — the card may reappear next launch.
  Future<void> _onPersistError() async {
    if (!mounted) return;
    AppSnackbar.show(
      context,
      message: 'Could not save your swipe. Please try again.',
      variant: AppSnackbarVariant.error,
    );
  }

  /// Joins the activity, records the swipe decision, advances past the
  /// card, and opens the match screen. On failure the card stays put
  /// with an error snackbar — navigating anyway would promise a join
  /// that never happened and leave My Games empty. The one exception
  /// is "already joined": she is already a participant, so the match
  /// screen is the truth and is shown instead of an error.
  Future<void> _joinAndShowMatch(ActivityModel activity) async {
    try {
      await ref.read(activityRepositoryProvider).join(activity.id);
    } catch (e) {
      if (!mounted) return;
      if (_isAlreadyJoined(e)) {
        _openMatch(activity);
        return;
      }
      AppSnackbar.show(
        context,
        message: _joinErrorMessage(e, isRequest: false),
        variant: AppSnackbarVariant.error,
      );
      return;
    } finally {
      _swiping = false;
    }
    if (!mounted) return;
    _openMatch(activity);
  }

  /// Records the swipe, advances past the card, and opens the match
  /// screen. Shared by the fresh-join and already-joined paths.
  /// Navigates immediately: the card's fly-off animation already
  /// completed before onSwiped fired, so any extra delay is dead air
  /// staring at the next card.
  void _openMatch(ActivityModel activity) {
    _persistSwipe(activityId: activity.id, decision: SwipeDecision.join);
    final repo = ref.read(activityRepositoryProvider);
    if (repo is RemoteActivityRepository) repo.invalidateFeed();
    // The Upcoming tab caches keepAlive-side: without this it keeps
    // serving the pre-join list until a manual pull-to-refresh.
    ref.invalidate(joinedGamesProvider);
    setState(() => _topIndex += 1);
    HapticFeedback.heavyImpact();
    // The joined activity rides along as route extra so the match
    // screen can render from cache when the byId refetch fails
    // (offline right after joining).
    if (mounted) context.go('/match/${activity.id}', extra: activity);
  }

  /// Files the join request, records the swipe decision, advances past
  /// the card, and opens the pending screen. On failure the card stays
  /// put with an error snackbar — navigating anyway would promise a
  /// request that was never sent. The one exception is a duplicate
  /// request (409 "already pending"): she is already in the queue, so
  /// the pending screen is the truth and is shown instead of an error.
  Future<void> _requestAndShowPending(ActivityModel activity) async {
    try {
      await ref.read(activityRepositoryProvider).requestJoin(activity.id);
    } catch (e) {
      if (!mounted) return;
      if (_isAlreadyPending(e)) {
        _openPending(activity);
        return;
      }
      AppSnackbar.show(
        context,
        message: _joinErrorMessage(e),
        variant: AppSnackbarVariant.error,
      );
      return;
    } finally {
      _swiping = false;
    }
    if (!mounted) return;
    _openPending(activity);
  }

  /// Records the swipe, advances past the card, and opens the pending
  /// screen. Shared by the fresh-request and already-pending paths.
  void _openPending(ActivityModel activity) {
    _persistSwipe(activityId: activity.id, decision: SwipeDecision.join);
    final repo = ref.read(activityRepositoryProvider);
    if (repo is RemoteActivityRepository) repo.invalidateFeed();
    // Same staleness contract as _openMatch, for the Pending tab.
    ref.invalidate(pendingGamesProvider);
    setState(() => _topIndex += 1);
    HapticFeedback.heavyImpact();
    context.go('/request-sent/${activity.id}', extra: activity);
  }

  /// True when the backend rejected the request as a duplicate of an
  /// existing pending one (409 + the backend's exact message). The
  /// message match is deliberate: other 409s (full, already joined)
  /// must stay errors.
  bool _isAlreadyPending(Object e) {
    return e is DioException &&
        e.error is ApiException &&
        (e.error as ApiException).statusCode == 409 &&
        (e.error as ApiException).userMessage ==
            'Join request already pending';
  }

  /// True when the instant-join failed because the viewer is already a
  /// participant. She is already in My Games, so the match screen is
  /// the truth and is shown instead of an error.
  bool _isAlreadyJoined(Object e) {
    return e is DioException &&
        e.error is ApiException &&
        (e.error as ApiException).statusCode == 409 &&
        (e.error as ApiException).userMessage ==
            'User already joined this activity';
  }

  /// Prefers the backend's own message (full, not open, …) over the
  /// generic fallback so failures explain themselves.
  String _joinErrorMessage(Object e, {bool isRequest = true}) {
    if (e is DioException && e.error is ApiException) {
      return (e.error as ApiException).userMessage;
    }
    return isRequest
        ? 'Could not send the request. Please try again.'
        : 'Could not join. Please try again.';
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

  /// Start-over latch release: back to unseen cards only.
  void _showUnseenOnly() {
    HapticFeedback.lightImpact();
    ref.read(_includeSwipedProvider.notifier).state = false;
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

  void _onDragState(bool dragging) {
    // The deck reports false both at drag end and when the settle/exit
    // animation finishes — either way, taps from here on are 300ms away
    // from a gesture and safe to treat as intentional.
    if (!dragging) _lastDragEnd = DateTime.now();
  }

  void _openDetails() {
    if (_topIndex >= _activities.length) return;
    // Suppress tap-to-details when a drag just ended over the card: a
    // swipe release also lands a tap, which would otherwise yank the
    // user into details on every mis-tap.
    final lastEnd = _lastDragEnd;
    if (lastEnd != null &&
        DateTime.now().difference(lastEnd) <
            const Duration(milliseconds: 300)) {
      return;
    }
    final activity = _activities[_topIndex];
    // push (not go): go() replaces the whole navigation stack, which leaves
    // the detail screen's back/dislike buttons (Navigator.maybePop) with
    // nothing to pop — they'd register the tap but do nothing visible.
    // Guarded per activity with an in-flight set (not a time debounce):
    // the key stays reserved until the pushed page is popped, so a second
    // tap — however late, however slow the transition — can never create
    // a duplicate `activity-<id>` page ('!keyReservation' red screen).
    NavGuard.push(context,
      '/activity/${activity.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final deckExhausted = !_isLoading && _topIndex >= _activities.length;
    final unreadCount = ref.watch(_unreadNotifCountProvider).valueOrNull ?? 0;
    final filterSummary = ref.watch(discoveryFilterProvider).describe();
    final includeSwiped = ref.watch(_includeSwipedProvider);

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
                onTap: () => NavGuard.push(context, '/filter'),
                anchorKey: TourAnchors.filterButton,
                // Subtle dot in the corner when a non-empty filter
                // is active — tells the user the deck is filtered
                // without taking up header space.
                showDot: _hasActiveFilter,
              ),
              HomeHeaderAction(
                icon: Icons.refresh_rounded,
                semanticLabel: 'Refresh',
                onTap: () => _load(forceRefresh: true),
              ),
              HomeHeaderAction(
                icon: Icons.notifications_none_rounded,
                semanticLabel: 'Notifications',
                onTap: () => NavGuard.push(context, '/notifications'),
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
                  : (_loadError && _activities.isEmpty)
                  ? ErrorRetry(
                      message:
                          "Couldn't load activities. Check your connection and try again.",
                      onRetry: () => _load(),
                    )
                  : deckExhausted
                  ? DiscoveryEmptyDeck(
                      onRestart: _reset,
                      filterSummary: filterSummary,
                      onClearFilters: _hasActiveFilter ? _clearFilters : null,
                      // Start-over latch release: flip back to unseen
                      // cards without re-picking filters.
                      onShowUnseen: includeSwiped ? _showUnseenOnly : null,
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
                          onDragging: _onDragState,
                          onPersistError: _onPersistError,
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
                // Center (not start): buttons have different diameters
                // (54/62/68) and start-alignment left the info button
                // visibly higher than its neighbours.
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DiscoveryAction.reject(onTap: _dislike),
                  const SizedBox(width: AppSpacing.x6),
                  DiscoveryAction.info(onTap: _openDetails),
                  const SizedBox(width: AppSpacing.x6),
                  // Approval-gated games get the Request variant so
                  // the cost of the swipe is visible upfront.
                  if (_activities[_topIndex].joinPolicy == 'approval')
                    DiscoveryAction.request(onTap: _like)
                  else
                    DiscoveryAction.join(onTap: _like),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
