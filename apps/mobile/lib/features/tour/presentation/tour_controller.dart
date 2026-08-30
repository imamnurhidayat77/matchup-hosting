import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs_tour_store.dart';
import '../data/tour_store.dart';
import '../domain/tour_state.dart';
import '../domain/tour_step.dart';

final tourStoreProvider = Provider<TourStore>((ref) => PrefsTourStore());

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

  /// Starts [tourId] only if it hasn't been seen before. Safe to call
  /// unconditionally (e.g. every time the user lands on Discovery) — it is
  /// a no-op if the tour was already completed, or if a tour is already
  /// active.
  Future<void> maybeStart(String tourId, List<TourStep> steps) async {
    if (state.isActive) return;
    final seen = await _store.hasSeen(tourId);
    if (seen) return;
    start(tourId, steps);
  }

  /// Starts [tourId] regardless of whether it has been seen before — used
  /// by the "Replay tour" entry point.
  void start(String tourId, List<TourStep> steps) {
    if (steps.isEmpty) return;
    _activeTourId = tourId;
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

  void back() {
    if (!state.isActive || state.index == 0) return;
    state = state.copyWith(index: state.index - 1);
  }

  /// Skipping has the same effect as completing — the tour is dismissed and
  /// marked seen either way, so it will not resurface.
  Future<void> skip() => complete();

  Future<void> complete() async {
    final tourId = _activeTourId;
    state = const TourState.idle();
    _activeTourId = null;
    if (tourId != null) {
      await _store.markSeen(tourId);
    }
  }
}
