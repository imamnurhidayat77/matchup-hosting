import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../domain/tour_state.dart';
import '../domain/tour_step.dart';
import 'tour_anchors.dart';
import 'tour_controller.dart';
import 'widgets/spotlight_overlay.dart';
import 'widgets/tour_callout_card.dart';

/// Mounts a coach-mark overlay above [child] whenever [tourControllerProvider]
/// has an active tour, and removes it the moment the tour ends.
///
/// This widget owns the `OverlayEntry` lifecycle — insertion, rebuilds, and
/// removal — but delegates all actual rendering to [_TourOverlayContent],
/// [SpotlightOverlay] and [TourCalloutCard], none of which know about
/// `Overlay` or Riverpod directly (see plan §3.2/§5). Keeping this class
/// thin is what makes the rest of the tour testable without a real Overlay.
class TourHost extends ConsumerStatefulWidget {
  const TourHost({super.key, required this.child, required this.location});

  final Widget child;

  /// The shell's current `matchedLocation` (from `AppShell`). The overlay
  /// only shows while this is on Discovery — every tour step spotlights
  /// something reachable from that screen (see plan §2.1), so if the user
  /// switches tabs mid-tour there is nothing correct to point at elsewhere.
  final String location;

  @override
  ConsumerState<TourHost> createState() => _TourHostState();
}

class _TourHostState extends ConsumerState<TourHost> {
  OverlayEntry? _entry;

  bool get _isOnTourScreen => widget.location.startsWith('/discovery');

  @override
  void initState() {
    super.initState();
    // The tour is armed on get-to-know-3, one screen before this widget
    // even exists — by the time AppShell (and this TourHost) first
    // mounts, `TourState.isActive` may already be true. `ref.listen` in
    // `build` only fires on *changes* after that point, so the
    // already-active case has to be picked up explicitly here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(ref.read(tourControllerProvider));
    });
  }

  @override
  void didUpdateWidget(TourHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _sync(ref.read(tourControllerProvider));
    }
  }

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  /// Single decision point for whether the overlay should be mounted right
  /// now: the tour must be active AND the user must currently be on
  /// Discovery. Safe to call redundantly — inserting/removing are both
  /// no-ops if already in the target state.
  void _sync(TourState state) {
    final shouldShow = state.isActive && _isOnTourScreen;
    if (shouldShow && _entry == null) {
      _insertEntry();
    } else if (!shouldShow && _entry != null) {
      _removeEntry();
    }
  }

  void _insertEntry() {
    if (_entry != null) return;
    final entry = OverlayEntry(builder: (_) => const _TourOverlayContent());
    _entry = entry;

    // Defer the actual insert to after this frame. The anchors a step
    // spotlights (swipe deck, tab bar items, …) are laid out as part of
    // the *current* build; inserting synchronously here would try to read
    // their RenderBox before that layout pass has necessarily completed.
    // Waiting a frame guarantees every anchor already has a valid,
    // attached RenderBox by the time the overlay itself first builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entry != entry) return;
      Overlay.of(context).insert(entry);
    });
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    // A tour starting/ending, or the location changing, only ever flips
    // whether the overlay should be mounted; individual step advances are
    // handled entirely inside `_TourOverlayContent` via its own
    // `ref.watch` — this listener's only job is mount/unmount timing.
    ref.listen<TourState>(tourControllerProvider, (previous, next) {
      _sync(next);
    });

    // Only rebuild this PopScope when isActive itself flips, not on every
    // step index change — `select` keeps a tour advancing through its 6
    // steps from re-triggering AppShell's whole subtree on each tap.
    final isActive = ref.watch(
      tourControllerProvider.select((s) => s.isActive),
    );

    // PopScope must live in TourHost's own build() (part of the routed
    // ShellRoute subtree), not inside the OverlayEntry's content — an
    // OverlayEntry's builder sits outside any ModalRoute's context, so a
    // PopScope placed there cannot intercept the system back button at
    // all. Placed here, an active tour swallows a back-press as `skip()`
    // instead of letting it pop/exit the Discover tab out from under the
    // spotlight (plan §6 Phase 5, "Back button Android saat tour aktif").
    return PopScope(
      canPop: !isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(tourControllerProvider.notifier).skip();
      },
      child: widget.child,
    );
  }
}

/// The actual overlay content: watches [tourControllerProvider] directly
/// (it is mounted via `Overlay`, outside the normal parent/child rebuild
/// chain, so it needs its own subscription rather than relying on
/// [TourHost] to push updates to it) and renders the current step's
/// spotlight + callout.
class _TourOverlayContent extends ConsumerWidget {
  const _TourOverlayContent();

  Rect? _resolveAnchorRect(TourAnchorId anchorId, double padding) {
    final key = TourAnchors.keyFor(anchorId);
    if (key == null) return null;

    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      renderObject.size.width,
      renderObject.size.height,
    );
    return rect.inflate(padding);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tourState = ref.watch(tourControllerProvider);
    final step = tourState.current;
    final controller = ref.read(tourControllerProvider.notifier);

    // Nothing to show — either idle, or (defensively) an out-of-range
    // index. TourHost removes the entry on `isActive == false`, so in
    // practice this only guards the brief window between state flipping
    // and the removal taking effect.
    if (step == null) return const SizedBox.shrink();

    // Registering a MediaQuery dependency here (not just inside
    // SpotlightOverlay) means THIS widget rebuilds on rotation/resize too,
    // so the anchor rect below is recomputed with fresh geometry rather
    // than reusing a stale value from before the resize.
    MediaQuery.of(context);

    final holeRect = _resolveAnchorRect(step.anchor, step.padding);

    // A step with a real anchor (not the centered "welcome" step) whose
    // anchor fails to resolve means the widget it should spotlight isn't
    // on screen right now — e.g. the action row is gone because the swipe
    // deck is exhausted (plan §7 risk table). Showing a spotlight with no
    // hole in that case would dim the whole screen for no visible reason,
    // so the step is skipped automatically instead. Deferred to a
    // post-frame callback because `next()` mutates provider state, which
    // must not happen synchronously inside this build().
    if (step.anchor != TourAnchorId.none && holeRect == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.next();
      });
      return const SizedBox.shrink();
    }

    return SpotlightOverlay(
      holeRect: holeRect,
      shape: step.shape,
      holeRadius: AppRadius.card,
      onTapScrim: controller.skip,
      child: TourCalloutCard(
        title: step.title,
        body: step.body,
        currentStep: tourState.index + 1,
        totalSteps: tourState.steps.length,
        isLastStep: tourState.isLast,
        onSkip: controller.skip,
        onNext: controller.next,
      ),
    );
  }
}
