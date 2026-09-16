import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs_tour_store.dart';
import '../data/tour_store.dart';
import '../domain/tour_state.dart';
import '../domain/tour_step.dart';

final tourStoreProvider = Provider<TourStore>((ref) => PrefsTourStore());

/// True once Discovery's feed has finished loading (skeleton gone, real
/// deck / empty state on screen). Written by `DiscoveryScreen`, read by
/// `TourHost` to gate the overlay — without this the "Welcome" popup
/// appears over an empty skeleton while card images are still loading.
final discoveryContentReadyProvider = StateProvider<bool>((ref) => false);

final tourControllerProvider =
    StateNotifierProvider<TourController, TourState>(
      (ref) => TourController(ref.watch(tourStoreProvider)),
    );

/// Drives a coach-mark tour: which step is showing, advancing/going back,
/// and persisting completion so a given tour only plays once per install.
///
/// This class is deliberately widget-free (no `BuildContext`, no
/// `OverlayEntry`) so it can be unit tested without pumping any widgets —
/// `TourHost` (presentation layer) is the only place that turns this state
/// into an actual on-screen overlay.
class TourController extends StateNotifier<TourState> {
  TourController(this._store) : super(const TourState.idle());

  final TourStore _store;

  /// Tracks the tour id currently armed/active so [complete] knows which
  /// flag to persist.
  String? _activeTourId;

  /// Guards [maybeStart] against concurrent invocations racing the
  /// async `hasSeen` check (TOCTOU): while one start is in flight,
  /// further calls are ignored instead of each snapshotting `isActive`
  /// and double-starting.
  bool _starting = false;

  /// Titles of steps auto-skipped because their anchor wasn't mounted
  /// (see `TourHost`). Surfaced on the final card so skipped tips are
  /// disclosed instead of silently dropped.
  final List<String> _skippedTitles = [];

  /// Set by get-to-know-3 after a successful first onboarding: the tour
  /// must start on the NEXT Discovery visit, not immediately (this State
  /// is being disposed by the `go('/discovery')`, and a redirect could
  /// land anywhere). `TourHost` consumes this flag when Discovery is
  /// actually showing with content ready — the destination decides, so
  /// no navigator-key lookup is needed (which also keeps widget tests,
  /// with their own GoRouter, working).
  bool _firstRunPending = false;

  /// Arms the first-run tour for the next Discovery visit. Idempotent.
  void armFirstRun() {
    _firstRunPending = true;
  }

  /// Consumes the first-run arm flag. Returns true exactly once per arm.
  bool consumeFirstRunArm() {
    if (!_firstRunPending) return false;
    _firstRunPending = false;
    return true;
  }

  /// Read-only view of auto-skipped step titles for the current tour.
  List<String> get skippedTitles => List.unmodifiable(_skippedTitles);

  /// Starts [tourId] only if it hasn't been seen before. Safe to call
  /// unconditionally (e.g. every time the user lands on Discovery) — it is
  /// a no-op if the tour was already completed, or if a tour is already
  /// active.
  Future<void> maybeStart(String tourId, List<TourStep> steps) async {
    if (state.isActive || _starting) return;
    _starting = true;
    try {
      final seen = await _store.hasSeen(tourId);
      if (seen) return;
      // Re-check: a concurrent caller (e.g. Replay tour) may have
      // started a tour while `hasSeen` was awaiting.
      if (state.isActive) return;
      start(tourId, steps);
    } finally {
      _starting = false;
    }
  }

  /// Starts [tourId] regardless of whether it has been seen before — used
  /// by the "Replay tour" entry point.
  void start(String tourId, List<TourStep> steps) {
    if (steps.isEmpty) return;
    _activeTourId = tourId;
    _skippedTitles.clear();
    state = TourState(steps: steps, index: 0, isActive: true);
  }

  void next() {
    if (!state.isActive) return;
    if (state.isLast) {
      complete();
      return;
    }
    state = state.copyWith(index: state.index + 1);
  }

  /// Advances past the current step because its anchor isn't on screen.
  /// Records the title so the final card can disclose what was skipped.
  void skipUnavailableStep() {
    if (!state.isActive) return;
    final step = state.current;
    if (step != null) {
      _skippedTitles.add(step.title);
      debugPrint('[Tour] skipping unavailable anchor: ${step.title}');
    }
    next();
  }

  void back() {
    if (!state.isActive || state.index == 0) return;
    state = state.copyWith(index: state.index - 1);
  }

  /// Skipping has the same effect as completing — the tour is dismissed and
  /// marked seen either way, so it will not resurface.
  Future<bool> skip() => complete();

  /// Persists the seen flag BEFORE going idle. Returns true when the tour
  /// is done and persisted; false when persistence failed — in that case
  /// the tour stays active (not marked idle-complete) so the next
  /// completion/skip retries the write instead of losing it.
  Future<bool> complete() async {
    final tourId = _activeTourId;
    if (tourId != null) {
      try {
        await _store.markSeen(tourId);
      } catch (_) {
        return false;
      }
    }
    state = const TourState.idle();
    _activeTourId = null;
    return true;
  }
}
